with Ada.Characters.Handling;
with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Compiler.Backend.Native_Print;
with Lovelace.Compiler.Intrinsics;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Backend.Lowering is

   package Errors renames Lovelace.Lir.Errors;
   package Instructions renames Lovelace.Lir.Instructions;
   package Modules renames Lovelace.Lir.Modules;
   package Opcodes renames Lovelace.Lir.Opcodes;
   package Subroutines renames Lovelace.Lir.Subroutines;
   package Types renames Lovelace.Lir.Types;

   --  Simple-name renames so gnatcov can instrument call coverage (no dotted callees).
   function Get_Signature
     (The_Subroutine : Subroutines.Subroutine) return Subroutines.Signature
     renames Subroutines.Get_Signature;
   function Unbounded_Text
     (Source : Ada.Strings.Unbounded.Unbounded_String) return String
     renames Ada.Strings.Unbounded.To_String;

   use type Interfaces.Unsigned_32;
   use type Model.Core_Value_Type;
   use type Types.Value_Type;

   procedure Append_Kebab_Byte (Byte : Character; Buffer : in out String; Last : in out Natural);
   --  Map one source byte into Buffer as lowercase alnum or a single '-'.

   procedure Append_Start_Function (The_Model : in out Model.Component_Model; Entrypoint_Index : Positive);
   --  Append the synthesized `_start` wrapper and its WASI run export.

   function Check_Signature (The_Subroutine : Subroutines.Subroutine) return Lower_Result;
   --  Reject non-Unit returns and entrypoints with parameters.

   function Failure (Code : Backend_Error_Code; Detail : String) return Lower_Result;
   --  Build a Lower_Result failure.

   function Is_Component_Export (The_Flags : Subroutines.Subroutine_Flags; Parameter_Count : Natural) return Boolean;
   --  True for exported subroutines with no parameters (component-level export).

   function Kebab_Export_Name (Name : String) return String;
   --  Component/WIT extern name: ASCII letters/digits lowercased; other bytes become '-'.

   procedure Lower_Instruction_Body
     (The_Instructions : Instructions.Instruction_Sequence;
      Body_Out         : out Model.Instruction_Sequence;
      Outcome          : out Lower_Result);
   --  Fill Body_Out from The_Instructions; Outcome.Ok False on failure.

   function Lower_Intrinsic_Body
     (The_Module      : Modules.Module;
      The_Model       : in out Model.Component_Model;
      The_Subroutine  : Subroutines.Subroutine;
      Parameter_Types : Model.Core_Parameter_Sequence;
      Local_Types     : out Model.Core_Local_Sequence;
      Body_Out        : out Model.Instruction_Sequence) return Lower_Result;
   --  Synthesize the body of a matched intrinsic.

   procedure Lower_One_Instruction
     (Item     : Instructions.Instruction;
      Body_Out : in out Model.Instruction_Sequence;
      Outcome  : in out Lower_Result);
   --  Append the lowered form of one LIR instruction, or set Outcome on failure.

   function Lower_Subroutine
     (The_Module       : Modules.Module;
      The_Model        : in out Model.Component_Model;
      Subroutine_Index : Positive;
      Entrypoint_Index : in out Natural) return Lower_Result;
   --  Lower one LIR subroutine into The_Model (function, export, entrypoint tracking).

   function Lower_Subroutine_Body
     (The_Module      : Modules.Module;
      The_Model       : in out Model.Component_Model;
      The_Subroutine  : Subroutines.Subroutine;
      Parameter_Types : Model.Core_Parameter_Sequence;
      Local_Types     : out Model.Core_Local_Sequence;
      Body_Out        : out Model.Instruction_Sequence) return Lower_Result;
   --  Produce locals and body for an intrinsic, native, or ordinary subroutine.

   function Map_Core_Parameter_Type (The_Type : Types.Value_Type; Mapped : out Model.Core_Value_Type) return Boolean;
   --  Map a non-Unit LIR parameter type to a core WASM value type. False when unsupported.

   function Map_Locals
     (Locals : Types.Parameter_Sequence;
      Mapped : in out Model.Core_Local_Sequence;
      Detail : in out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   --  Map LIR named locals to core local types. False when a local type is unsupported.

   function Map_Parameters
     (Parameters : Types.Parameter_Sequence;
      Mapped     : in out Model.Core_Parameter_Sequence;
      Detail     : in out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   --  Map LIR named parameters to core types. False when a parameter type is unsupported.

   function Record_Entrypoint
     (The_Flags : Subroutines.Subroutine_Flags; Subroutine_Index : Positive; Entrypoint_Index : in out Natural)
      return Lower_Result;
   --  Remember the entrypoint index; fail on a duplicate.

   function Success return Lower_Result;
   --  Build a successful Lower_Result with an empty placeholder model.

   function Trim_Kebab_Dashes (Buffer : String; Last : Natural) return String;
   --  Strip leading/trailing '-' from Buffer (1 .. Last); "export" if empty.

   procedure Append_Kebab_Byte (Byte : Character; Buffer : in out String; Last : in out Natural) is
   begin
      if Byte in 'A' .. 'Z' then
         Last := Last + 1;
         Buffer (Last) := Ada.Characters.Handling.To_Lower (Byte);
      elsif Byte in 'a' .. 'z' or else Byte in '0' .. '9' then
         Last := Last + 1;
         Buffer (Last) := Byte;
      elsif Last = 0 or else Buffer (Last) /= '-' then
         --  '.' and other non-alnum become '-'; skip consecutive dashes.
         Last := Last + 1;
         Buffer (Last) := '-';
      end if;
   end Append_Kebab_Byte;

   procedure Append_Start_Function (The_Model : in out Model.Component_Model; Entrypoint_Index : Positive) is
      Start_Body  : Model.Instruction_Sequence := Model.Empty_Instructions;
      Start_Index : constant Positive := Model.Function_Count (The_Model) + 1;
   begin
      Model.Append (Start_Body, (Kind => Model.Call_Function, Target_Index => Entrypoint_Index));
      Model.Append (Start_Body, (Kind => Model.I32_Constant, Value => 0));

      Model.Append_Function
        (The_Model,
         (Name            => Ada.Strings.Unbounded.To_Unbounded_String ("_start"),
          Parameter_Types => Model.Empty_Parameters,
          Local_Types     => Model.Empty_Locals,
          Result_Is_I32   => True,
          Instructions    => Start_Body,
          Core_Exported   => True));

      Model.Append_Export
        (The_Model,
         (Export_Name         => Ada.Strings.Unbounded.To_Unbounded_String (Model.Wasi_Cli_Run_Export_Name),
          Core_Function_Index => Start_Index,
          Returns_Result      => True));
   end Append_Start_Function;

   function Check_Signature (The_Subroutine : Subroutines.Subroutine) return Lower_Result is
      The_Signature   : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
      Source_Name     : constant String := Ada.Strings.Unbounded.To_String (The_Signature.Name);
      Parameter_Count : constant Natural := Types.Length (The_Signature.Parameters);
   begin
      if The_Signature.Return_Type /= Types.Unit then
         return
           Failure (Unsupported_Type, "backend this slice supports only Unit return; got subroutine " & Source_Name);
      end if;

      if Subroutines.Has_Entrypoint (Subroutines.Get_Flags (The_Subroutine)) and then Parameter_Count > 0 then
         return
           Failure
             (Unsupported_Type,
              "backend this slice supports parameters only on non-entrypoint procedures; got subroutine "
              & Source_Name);
      end if;

      return Success;
   end Check_Signature;

   function Failure (Code : Backend_Error_Code; Detail : String) return Lower_Result is
   begin
      return (Ok => False, Error => Make_Error (Code, Detail));
   end Failure;

   function Is_Component_Export (The_Flags : Subroutines.Subroutine_Flags; Parameter_Count : Natural) return Boolean is
   begin
      return Subroutines.Has_Export (The_Flags) and then Parameter_Count = 0;
   end Is_Component_Export;

   function Kebab_Export_Name (Name : String) return String is
      --  COMPONENT/WIT export: Module.Name -> module-name (kebab; dots to dashes).
      Buffer : String (1 .. Name'Length);
      Last   : Natural := 0;
   begin
      for Index in Name'Range loop
         Append_Kebab_Byte (Name (Index), Buffer, Last);
      end loop;

      return Trim_Kebab_Dashes (Buffer, Last);
   end Kebab_Export_Name;

   function Lower (The_Module : Lovelace.Lir.Modules.Module) return Lower_Result is
      Validation : constant Errors.Validation_Results.Result := Modules.Validate (The_Module);
   begin
      case Validation.Ok is
         when False =>
            return Failure (Invalid_Module, "LIR Validate failed: " & Errors.Error_Code'Image (Validation.Error));

         when True  =>
            null;
      end case;

      declare
         The_Model        : Model.Component_Model :=
           Model.Create (Modules.Name (The_Module), Modules.Module_Version (The_Module));
         Entrypoint_Index : Natural := 0;
      begin
         for Dependency_Index in 1 .. Modules.Dependency_Count (The_Module) loop
            Model.Append_Dependency
              (The_Model,
               Modules.Dependency_Name (The_Module, Dependency_Index),
               Modules.Dependency_Version (The_Module, Dependency_Index));
         end loop;

         for Subroutine_Index in 1 .. Modules.Subroutine_Count (The_Module) loop
            declare
               Outcome : constant Lower_Result :=
                 Lower_Subroutine
                   (The_Module       => The_Module,
                    The_Model        => The_Model,
                    Subroutine_Index => Subroutine_Index,
                    Entrypoint_Index => Entrypoint_Index);
            begin
               if not Outcome.Ok then
                  return Outcome;
               end if;
            end;
         end loop;

         if Entrypoint_Index /= 0 then
            Append_Start_Function (The_Model, Entrypoint_Index);
         end if;

         return (Ok => True, The_Model => The_Model);
      end;
   end Lower;

   procedure Lower_Instruction_Body
     (The_Instructions : Instructions.Instruction_Sequence;
      Body_Out         : out Model.Instruction_Sequence;
      Outcome          : out Lower_Result) is
   begin
      Body_Out := Model.Empty_Instructions;
      Outcome := (Ok => True, The_Model => Model.Create (""));

      for Index in 1 .. Instructions.Length (The_Instructions) loop
         --  LIR Validate already rejected zero Target_Index / Local_Index.
         Lower_One_Instruction (Instructions.Element (The_Instructions, Index), Body_Out, Outcome);
      end loop;
   end Lower_Instruction_Body;

   function Lower_Intrinsic_Body
     (The_Module      : Modules.Module;
      The_Model       : in out Model.Component_Model;
      The_Subroutine  : Subroutines.Subroutine;
      Parameter_Types : Model.Core_Parameter_Sequence;
      Local_Types     : out Model.Core_Local_Sequence;
      Body_Out        : out Model.Instruction_Sequence) return Lower_Result
   is
      pragma Unreferenced (Parameter_Types);
      The_Signature : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
      Source_Name   : constant String := Ada.Strings.Unbounded.To_String (The_Signature.Name);
      Owner_Module  : Ada.Strings.Unbounded.Unbounded_String;
      Proc_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Matched       : Intrinsics.Intrinsic_Kind_Option;
   begin
      Intrinsics.Split_Lir_Subroutine_Name
        (Root_Module_Name => Modules.Name (The_Module),
         Lir_Name         => Source_Name,
         Module_Name      => Owner_Module,
         Subroutine_Name  => Proc_Name);
      Matched :=
        Intrinsics.Match_Intrinsic
          (Module_Name     => Ada.Strings.Unbounded.To_String (Owner_Module),
           Subroutine_Name => Ada.Strings.Unbounded.To_String (Proc_Name),
           Return_Type     => The_Signature.Return_Type,
           Parameters      => The_Signature.Parameters);

      if not Matched.Present then
         return Failure (Internal_Error, "backend intrinsic table miss for subroutine " & Source_Name);
      end if;

      case Matched.Kind is
         when Intrinsics.Print_Integer_Stdout =>
            --  Match_Intrinsic already requires a single I32 parameter.
            Native_Print.Synthesize (Local_Types, Body_Out);
            Model.Enable_Wasi_Stdout (The_Model);
      end case;

      return Success;
   end Lower_Intrinsic_Body;

   procedure Lower_One_Instruction
     (Item     : Instructions.Instruction;
      Body_Out : in out Model.Instruction_Sequence;
      Outcome  : in out Lower_Result) is
      pragma Unreferenced (Outcome);
   begin
      case Item.Operation is
         when Opcodes.No_Operation =>
            null;

         when Opcodes.Constant_I32 =>
            Model.Append (Body_Out, (Kind => Model.I32_Constant, Value => Item.Immediate_I32));

         when Opcodes.Call         =>
            Model.Append (Body_Out, (Kind => Model.Call_Function, Target_Index => Positive (Item.Target_Index)));

         when Opcodes.Local_Get    =>
            Model.Append (Body_Out, (Kind => Model.Local_Get, Local_Index => Natural (Item.Local_Index) - 1));

         when Opcodes.Local_Set    =>
            Model.Append (Body_Out, (Kind => Model.Local_Set, Local_Index => Natural (Item.Local_Index) - 1));
      end case;
   end Lower_One_Instruction;

   function Lower_Subroutine
     (The_Module       : Modules.Module;
      The_Model        : in out Model.Component_Model;
      Subroutine_Index : Positive;
      Entrypoint_Index : in out Natural) return Lower_Result
   is
      The_Subroutine   : constant Subroutines.Subroutine := Modules.Get_Subroutine (The_Module, Subroutine_Index);
      The_Signature    : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
      The_Flags        : constant Subroutines.Subroutine_Flags := Subroutines.Get_Flags (The_Subroutine);
      Source_Name      : constant String := Ada.Strings.Unbounded.To_String (The_Signature.Name);
      Component_Export : constant Boolean := Is_Component_Export (The_Flags, Types.Length (The_Signature.Parameters));
      Body_Out         : Model.Instruction_Sequence;
      Local_Types      : Model.Core_Local_Sequence;
      Parameter_Types  : Model.Core_Parameter_Sequence;
      Parameter_Detail : Ada.Strings.Unbounded.Unbounded_String;
      --  Do not keep a mutable Lower_Result across Ok True/False: assigning a
      --  different discriminant finalizes/adjusts controlled The_Model and
      --  CONSTRAINT_ERROR/PROGRAM_ERROR under gnatcov (build-in-place).
      Signature_Outcome : constant Lower_Result := Check_Signature (The_Subroutine);
   begin
      if not Signature_Outcome.Ok then
         return Signature_Outcome;
      end if;

      if not Map_Parameters
               (Parameters => The_Signature.Parameters, Mapped => Parameter_Types, Detail => Parameter_Detail)
      then
         return
           Failure
             (Unsupported_Type,
              "unsupported parameter type in subroutine "
              & Source_Name
              & ": "
              & Ada.Strings.Unbounded.To_String (Parameter_Detail));
      end if;

      declare
         Body_Outcome : constant Lower_Result :=
           Lower_Subroutine_Body
             (The_Module      => The_Module,
              The_Model       => The_Model,
              The_Subroutine  => The_Subroutine,
              Parameter_Types => Parameter_Types,
              Local_Types     => Local_Types,
              Body_Out        => Body_Out);
      begin
         if not Body_Outcome.Ok then
            return Body_Outcome;
         end if;
      end;

      Model.Append_Function
        (The_Model,
         (Name            =>
            Ada.Strings.Unbounded.To_Unbounded_String
              (if Component_Export then Kebab_Export_Name (Source_Name) else Source_Name),
          Parameter_Types => Parameter_Types,
          Local_Types     => Local_Types,
          Result_Is_I32   => False,
          Instructions    => Body_Out,
          Core_Exported   => Component_Export));

      if Component_Export then
         Model.Append_Export
           (The_Model,
            (Export_Name         => Ada.Strings.Unbounded.To_Unbounded_String (Kebab_Export_Name (Source_Name)),
             Core_Function_Index => Subroutine_Index,
             Returns_Result      => False));
      end if;

      return Record_Entrypoint (The_Flags, Subroutine_Index, Entrypoint_Index);
   end Lower_Subroutine;

   function Lower_Subroutine_Body
     (The_Module      : Modules.Module;
      The_Model       : in out Model.Component_Model;
      The_Subroutine  : Subroutines.Subroutine;
      Parameter_Types : Model.Core_Parameter_Sequence;
      Local_Types     : out Model.Core_Local_Sequence;
      Body_Out        : out Model.Instruction_Sequence) return Lower_Result
   is
      The_Flags : constant Subroutines.Subroutine_Flags := Subroutines.Get_Flags (The_Subroutine);
   begin
      Local_Types := Model.Empty_Locals;
      Body_Out := Model.Empty_Instructions;

      if Subroutines.Has_Intrinsic (The_Flags) then
         return
           Lower_Intrinsic_Body
             (The_Module      => The_Module,
              The_Model       => The_Model,
              The_Subroutine  => The_Subroutine,
              Parameter_Types => Parameter_Types,
              Local_Types     => Local_Types,
              Body_Out        => Body_Out);
      end if;

      if Subroutines.Has_Native (The_Flags) then
         --  `@native` FFI is parse/LIR-only in this slice; emit an empty noop body.
         return Success;
      end if;

      declare
         Local_Detail : Ada.Strings.Unbounded.Unbounded_String;
         Locals_Ok    : constant Boolean :=
           Map_Locals
             (Locals => Subroutines.Get_Locals (The_Subroutine), Mapped => Local_Types, Detail => Local_Detail);
      begin
         if not Locals_Ok then
            declare
               The_Signature   : constant Subroutines.Signature := Get_Signature (The_Subroutine);
               Subroutine_Name : constant String := Unbounded_Text (The_Signature.Name);
               Detail_Text     : constant String := Unbounded_Text (Local_Detail);
            begin
               return
                 Failure
                   (Unsupported_Type,
                    "unsupported local type in subroutine " & Subroutine_Name & ": " & Detail_Text);
            end;
         end if;
      end;

      declare
         Body_Outcome : Lower_Result;
      begin
         Lower_Instruction_Body
           (The_Instructions => Subroutines.Get_Instructions (The_Subroutine),
            Body_Out         => Body_Out,
            Outcome          => Body_Outcome);
         return Body_Outcome;
      end;
   end Lower_Subroutine_Body;

   function Map_Core_Parameter_Type (The_Type : Types.Value_Type; Mapped : out Model.Core_Value_Type) return Boolean is
   begin
      case The_Type is
         when Types.Unit                                                          =>
            return False;

         when Types.I8 | Types.I16 | Types.I32 | Types.U8 | Types.U16 | Types.U32 =>
            Mapped := Model.I32;
            return True;

         when Types.I64 | Types.U64                                               =>
            Mapped := Model.I64;
            return True;

         when Types.F32                                                           =>
            Mapped := Model.F32;
            return True;

         when Types.F64                                                           =>
            Mapped := Model.F64;
            return True;
      end case;
   end Map_Core_Parameter_Type;

   function Map_Locals
     (Locals : Types.Parameter_Sequence;
      Mapped : in out Model.Core_Local_Sequence;
      Detail : in out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
   begin
      Mapped := Model.Empty_Locals;
      Detail := Ada.Strings.Unbounded.Null_Unbounded_String;

      for Index in 1 .. Types.Length (Locals) loop
         declare
            The_Local : constant Types.Parameter := Types.Element (Locals, Index);
            Core_Type : Model.Core_Value_Type;
         begin
            if not Map_Core_Parameter_Type (The_Local.The_Type, Core_Type) then
               Detail :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Ada.Strings.Unbounded.To_String (The_Local.Name)
                    & " has type "
                    & Types.Value_Type'Image (The_Local.The_Type));
               return False;
            end if;

            Model.Append (Sequence => Mapped, The_Type => Core_Type);
         end;
      end loop;

      return True;
   end Map_Locals;

   function Map_Parameters
     (Parameters : Types.Parameter_Sequence;
      Mapped     : in out Model.Core_Parameter_Sequence;
      Detail     : in out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
   begin
      Mapped := Model.Empty_Parameters;
      Detail := Ada.Strings.Unbounded.Null_Unbounded_String;

      for Index in 1 .. Types.Length (Parameters) loop
         declare
            The_Parameter : constant Types.Parameter := Types.Element (Parameters, Index);
            Core_Type     : Model.Core_Value_Type;
         begin
            if not Map_Core_Parameter_Type (The_Parameter.The_Type, Core_Type) then
               Detail :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Ada.Strings.Unbounded.To_String (The_Parameter.Name)
                    & " has type "
                    & Types.Value_Type'Image (The_Parameter.The_Type));
               return False;
            end if;

            Model.Append (Sequence => Mapped, The_Type => Core_Type);
         end;
      end loop;

      return True;
   end Map_Parameters;

   function Record_Entrypoint
     (The_Flags : Subroutines.Subroutine_Flags; Subroutine_Index : Positive; Entrypoint_Index : in out Natural)
      return Lower_Result is
   begin
      if Subroutines.Has_Entrypoint (The_Flags) then
         --  LIR Validate already rejected a second Entrypoint_Flag.
         Entrypoint_Index := Subroutine_Index;
      end if;

      return Success;
   end Record_Entrypoint;

   function Success return Lower_Result is
   begin
      return (Ok => True, The_Model => Model.Create (""));
   end Success;

   function Trim_Kebab_Dashes (Buffer : String; Last : Natural) return String is
      First : Natural := 1;
      Stop  : Natural := Last;
   begin
      while First <= Stop and then Buffer (First) = '-' loop
         First := First + 1;
      end loop;

      while Stop >= First and then Buffer (Stop) = '-' loop
         Stop := Stop - 1;
      end loop;

      if Stop < First then
         return "export";
      end if;

      return Buffer (First .. Stop);
   end Trim_Kebab_Dashes;

end Lovelace.Compiler.Backend.Lowering;
