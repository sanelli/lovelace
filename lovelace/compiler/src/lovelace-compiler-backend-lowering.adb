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

   use type Interfaces.Unsigned_32;
   use type Model.Core_Value_Type;
   use type Types.Value_Type;

   function Failure (Code : Backend_Error_Code; Detail : String) return Lower_Result;
   --  Build a Lower_Result failure.

   function Kebab_Export_Name (Name : String) return String;
   --  Component/WIT extern name: ASCII letters/digits lowercased; other bytes become '-'.

   procedure Lower_Instruction_Body
     (The_Instructions : Instructions.Instruction_Sequence;
      Body_Out         : out Model.Instruction_Sequence;
      Outcome          : out Lower_Result);
   --  Fill Body_Out from The_Instructions; Outcome.Ok False on failure.

   function Map_Core_Parameter_Type (The_Type : Types.Value_Type; Mapped : out Model.Core_Value_Type) return Boolean;
   --  Map a non-Unit LIR parameter type to a core WASM value type. False when unsupported.

   function Map_Locals
     (Locals : Types.Parameter_Sequence;
      Mapped : out Model.Core_Local_Sequence;
      Detail : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   --  Map LIR named locals to core local types. False when a local type is unsupported.

   function Map_Parameters
     (Parameters : Types.Parameter_Sequence;
      Mapped     : out Model.Core_Parameter_Sequence;
      Detail     : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   --  Map LIR named parameters to core types. False when a parameter type is unsupported.

   function Failure (Code : Backend_Error_Code; Detail : String) return Lower_Result is
   begin
      return (Ok => False, Error => Make_Error (Code, Detail));
   end Failure;

   function Kebab_Export_Name (Name : String) return String is
      Buffer : String (1 .. Name'Length);
      Last   : Natural := 0;
   begin
      for Index in Name'Range loop
         declare
            Byte : constant Character := Name (Index);
         begin
            if Byte in 'A' .. 'Z' then
               Last := Last + 1;
               Buffer (Last) := Ada.Characters.Handling.To_Lower (Byte);
            elsif Byte in 'a' .. 'z' or else Byte in '0' .. '9' then
               Last := Last + 1;
               Buffer (Last) := Byte;
            else
               Last := Last + 1;
               Buffer (Last) := '-';
            end if;
         end;
      end loop;

      if Last = 0 then
         return "export";
      end if;

      return Buffer (1 .. Last);
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
         The_Model        : Model.Component_Model := Model.Create (Modules.Name (The_Module));
         Entrypoint_Index : Natural := 0;
         Entrypoint_Found : Boolean := False;
      begin
         for Subroutine_Index in 1 .. Modules.Subroutine_Count (The_Module) loop
            declare
               The_Subroutine   : constant Subroutines.Subroutine :=
                 Modules.Get_Subroutine (The_Module, Subroutine_Index);
               The_Signature    : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
               The_Flags        : constant Subroutines.Subroutine_Flags := Subroutines.Get_Flags (The_Subroutine);
               Body_Out         : Model.Instruction_Sequence;
               Body_Outcome     : Lower_Result;
               Parameter_Types  : Model.Core_Parameter_Sequence;
               Parameter_Detail : Ada.Strings.Unbounded.Unbounded_String;
               Source_Name      : constant String := Ada.Strings.Unbounded.To_String (The_Signature.Name);
               Parameter_Count  : constant Natural := Types.Length (The_Signature.Parameters);
               Component_Export : constant Boolean := Subroutines.Has_Export (The_Flags) and then Parameter_Count = 0;
            begin
               if The_Signature.Return_Type /= Types.Unit then
                  return
                    Failure
                      (Unsupported_Type, "backend this slice supports only Unit return; got subroutine " & Source_Name);
               end if;

               if Subroutines.Has_Entrypoint (The_Flags) and then Parameter_Count > 0 then
                  return
                    Failure
                      (Unsupported_Type,
                       "backend this slice supports parameters only on non-entrypoint procedures; got subroutine "
                       & Source_Name);
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
                  Local_Types   : Model.Core_Local_Sequence := Model.Empty_Locals;
                  Local_Detail  : Ada.Strings.Unbounded.Unbounded_String;
                  Lir_Locals    : constant Types.Parameter_Sequence :=
                    Subroutines.Get_Locals (The_Subroutine);
               begin
                  if Subroutines.Has_Intrinsic (The_Flags) then
                     declare
                        Owner_Module : Ada.Strings.Unbounded.Unbounded_String;
                        Proc_Name    : Ada.Strings.Unbounded.Unbounded_String;
                        Matched      : Intrinsics.Intrinsic_Kind_Option;
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
                           return
                             Failure
                               (Internal_Error,
                                "backend intrinsic table miss for subroutine " & Source_Name);
                        end if;

                        case Matched.Kind is
                           when Intrinsics.Print_Integer_Stdout =>
                              if Parameter_Count /= 1
                                or else Model.Element (Parameter_Types, 1) /= Model.I32
                              then
                                 return
                                   Failure
                                     (Unsupported_Type,
                                      "print integer intrinsic requires a single integer parameter; got "
                                      & Source_Name);
                              end if;

                              Native_Print.Synthesize (Local_Types, Body_Out);
                              Model.Enable_Wasi_Stdout (The_Model);
                        end case;
                     end;
                  elsif Subroutines.Has_Native (The_Flags) then
                     --  `@native` FFI is parse/LIR-only in this slice; emit an empty noop body.
                     null;
                  else
                     if not Map_Locals
                              (Locals => Lir_Locals, Mapped => Local_Types, Detail => Local_Detail)
                     then
                        return
                          Failure
                            (Unsupported_Type,
                             "unsupported local type in subroutine "
                             & Source_Name
                             & ": "
                             & Ada.Strings.Unbounded.To_String (Local_Detail));
                     end if;

                     Lower_Instruction_Body
                       (The_Instructions => Subroutines.Get_Instructions (The_Subroutine),
                        Body_Out         => Body_Out,
                        Outcome          => Body_Outcome);

                     case Body_Outcome.Ok is
                        when False =>
                           return Body_Outcome;

                        when True  =>
                           null;
                     end case;
                  end if;

                  Model.Append_Function
                    (The_Model,
                     (Name            => The_Signature.Name,
                      Parameter_Types => Parameter_Types,
                      Local_Types     => Local_Types,
                      Result_Is_I32   => False,
                      Instructions    => Body_Out,
                      Core_Exported   => Component_Export));
               end;

               if Component_Export then
                  Model.Append_Export
                    (The_Model,
                     (Export_Name         =>
                        Ada.Strings.Unbounded.To_Unbounded_String (Kebab_Export_Name (Source_Name)),
                      Core_Function_Index => Subroutine_Index,
                      Returns_Result      => False));
               end if;

               if Subroutines.Has_Entrypoint (The_Flags) then
                  if Entrypoint_Found then
                     return Failure (Internal_Error, "duplicate entrypoint after Validate");
                  end if;

                  Entrypoint_Found := True;
                  Entrypoint_Index := Subroutine_Index;
               end if;
            end;
         end loop;

         if Entrypoint_Found then
            declare
               Start_Body  : Model.Instruction_Sequence := Model.Empty_Instructions;
               Start_Index : constant Positive := Model.Function_Count (The_Model) + 1;
            begin
               Model.Append (Start_Body, (Kind => Model.Call_Function, Target_Index => Positive (Entrypoint_Index)));
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
            end;
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
         declare
            Item : constant Instructions.Instruction := Instructions.Element (The_Instructions, Index);
         begin
            case Item.Operation is
               when Opcodes.No_Operation =>
                  null;

               when Opcodes.Constant_I32 =>
                  Model.Append (Body_Out, (Kind => Model.I32_Constant, Value => Item.Immediate_I32));

               when Opcodes.Call         =>
                  if Item.Target_Index = 0 then
                     Outcome := Failure (Internal_Error, "Call Target_Index is zero");
                     return;
                  end if;
                  Model.Append (Body_Out, (Kind => Model.Call_Function, Target_Index => Positive (Item.Target_Index)));
            end case;
         end;
      end loop;
   end Lower_Instruction_Body;

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
      Mapped : out Model.Core_Local_Sequence;
      Detail : out Ada.Strings.Unbounded.Unbounded_String) return Boolean
   is
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
      Mapped     : out Model.Core_Parameter_Sequence;
      Detail     : out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
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

end Lovelace.Compiler.Backend.Lowering;
