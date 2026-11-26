with Ada.Strings.Bounded;
with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Compiler.Backend.Lowering;
with Lovelace.Compiler.Backend.Model;
with Lovelace.Compiler.Backend.Names;
with Lovelace.Compiler.Backend.Wit;

package body Lovelace.Compiler.Backend.Wat is

   --  Simple-name renames so gnatcov can instrument call coverage (no dotted callees).
   function Get_Export
     (The_Model : Model.Component_Model; Index : Positive) return Model.Lifted_Export
     renames Model.Get_Export;
   function Get_Function
     (The_Model : Model.Component_Model; Index : Positive) return Model.Core_Function
     renames Model.Get_Function;
   function Export_Count (The_Model : Model.Component_Model) return Natural renames Model.Export_Count;
   function Function_Count (The_Model : Model.Component_Model) return Natural renames Model.Function_Count;
   function Unbounded_Text
     (Source : Ada.Strings.Unbounded.Unbounded_String) return String
     renames Ada.Strings.Unbounded.To_String;

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural;
   --  0-based alias index among Core_Exported functions for Core_Function_Index.

   function Core_Value_Type_Name (The_Type : Model.Core_Value_Type) return String;
   --  WAT spelling for a core value type.

   function Dollar_Name (Name : String) return String;
   --  WAT $Name form (Name is already a safe identifier in this slice).

   function Function_Text (The_Model : Model.Component_Model; Func_Index : Positive) return String;
   --  "(func ...)" definition for core function Func_Index.

   function Image_Without_Leading_Space (Value : Integer) return String;
   --  Decimal image without the leading blank Ada puts on positive'Image.

   function Import_Name (Import_Index : Natural) return String;
   --  WAT $name of the fixed WASI stdout core import slot Import_Index.

   function Instruction_Text (The_Model : Model.Component_Model; Item : Model.Core_Instruction) return String;
   --  One WAT instruction line (indented, LF-terminated) for Item.

   function Is_Wat_Id_Char (Byte : Character) return Boolean;
   --  True when Byte may appear unescaped in a WAT `$id`.

   function Locals_Text (The_Function : Model.Core_Function) return String;
   --  Optional "(local ...)" line (LF-terminated); empty when there are no locals.

   package Mnemonic_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length (Max => 16);

   function M (Text : String; Drop : Ada.Strings.Truncation := Ada.Strings.Error) return Mnemonic_Strings.Bounded_String
   renames Mnemonic_Strings.To_Bounded_String;

   Mnemonic_Table : constant array (Model.Core_Instruction_Kind) of Mnemonic_Strings.Bounded_String :=
     [Model.Call_Function    => M ("call"),
      Model.Call_Import      => M ("call"),
      Model.I32_Constant     => M ("i32.const"),
      Model.I64_Constant     => M ("i64.const"),
      Model.Local_Get        => M ("local.get"),
      Model.Local_Set        => M ("local.set"),
      Model.I32_Add          => M ("i32.add"),
      Model.I32_Sub          => M ("i32.sub"),
      Model.I32_Mul          => M ("i32.mul"),
      Model.I32_Div_S        => M ("i32.div_s"),
      Model.I32_Rem_S        => M ("i32.rem_s"),
      Model.I32_Eqz          => M ("i32.eqz"),
      Model.I32_Eq           => M ("i32.eq"),
      Model.I32_Ne           => M ("i32.ne"),
      Model.I32_Lt_S         => M ("i32.lt_s"),
      Model.I32_Gt_S         => M ("i32.gt_s"),
      Model.I32_Le_S         => M ("i32.le_s"),
      Model.I32_Ge_S         => M ("i32.ge_s"),
      Model.I32_Store8       => M ("i32.store8"),
      Model.I32_Load8_U      => M ("i32.load8_u"),
      Model.I32_Wrap_I64     => M ("i32.wrap_i64"),
      Model.I64_Extend_I32_U => M ("i64.extend_i32_u"),
      Model.I64_Shr_U        => M ("i64.shr_u"),
      Model.Unreachable      => M ("unreachable"),
      Model.If_Empty         => M ("if"),
      Model.Else_Op          => M ("else"),
      Model.End_Op           => M ("end"),
      Model.Loop_Empty       => M ("loop"),
      Model.Br               => M ("br"),
      Model.Br_If            => M ("br_if")];
   --  WAT mnemonic per instruction kind; operands are appended by Operand_Text.

   function Mnemonic_Name (Kind : Model.Core_Instruction_Kind) return String;
   --  WAT mnemonic for Kind (without operands).

   function Name_Count (The_Model : Model.Component_Model; Name : String) return Natural;
   --  How many core functions share Name (overloads share a LIR name).

   function Needs_Dollar_Prefix_Guard (First : Character) return Boolean;
   --  True when a leading digit or '-' requires a `$n_` prefix.

   function Operand_Text (The_Model : Model.Component_Model; Item : Model.Core_Instruction) return String;
   --  WAT operand text for call, const, local and branch instructions.

   function To_Wat (The_Model : Model.Component_Model) return String;
   --  Render The_Model as component WAT text.

   type Component_Bases is record
      Type_Base        : Natural;
      Core_Func_Base   : Natural;
      Lifted_Func_Base : Natural;
      Instance_Base    : Natural;
   end record;
   --  Index bases that shift when the stdout prelude (component types, funcs, instances) is present.

   type Export_Type_Layout is record
      Unit_Type_Index       : Integer := -1;
      Result_Valtype_Index  : Integer := -1;
      Result_Functype_Index : Integer := -1;
      Next_Type_Index       : Natural := 0;
   end record;
   --  Component type indices allocated for lifted exports (-1 when unused).

   procedure Append_Alias_Section
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model; Stdout : Boolean);
   --  Alias lines for every Core_Exported guest function.

   procedure Append_Canon_Lifts
     (Buffer    : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model : Model.Component_Model;
      Layout    : Export_Type_Layout;
      Bases     : Component_Bases);
   --  Canon lift lines, one per lifted export.

   procedure Append_Core_Instances
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model; Stdout : Boolean);
   --  Stdout prelude (when present), the guest core module and its core instance.

   procedure Append_Core_Module_Functions
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model);
   --  Core function definitions, core exports and the closing paren of the core module.

   procedure Append_Dependency_Sections
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model);
   --  One "lovelace-dependency" custom line per dependency.

   procedure Append_Export_Section
     (Buffer    : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model : Model.Component_Model;
      Bases     : Component_Bases);
   --  Component export lines for lifted exports.

   procedure Append_Lifted_Exports
     (Buffer    : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model : Model.Component_Model;
      Layout    : Export_Type_Layout;
      Bases     : Component_Bases);
   --  Canon lifts, result instances and exports.

   procedure Append_Line (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Text : String);
   --  Append Text and a line feed to Buffer.

   procedure Append_Result_Instances
     (Buffer           : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model        : Model.Component_Model;
      Lifted_Func_Base : Natural);
   --  Instance bundles ("run") for exports that return a result.

   procedure Append_Stdout_Guest_Instances (Buffer : in out Ada.Strings.Unbounded.Unbounded_String);
   --  Stdout guest core instance with the import bundle.

   procedure Append_Stdout_Guest_Module_Header (Buffer : in out Ada.Strings.Unbounded.Unbounded_String);
   --  Opening of the stdout guest core module with its imports.

   procedure Append_Stdout_Imports (Buffer : in out Ada.Strings.Unbounded.Unbounded_String);
   --  Stdout prelude: wasi:cli/types and wasi:cli/stdout types and imports.

   procedure Append_Stdout_Libc (Buffer : in out Ada.Strings.Unbounded.Unbounded_String);
   --  Stdout prelude: libc core module, its instance and the memory alias.

   procedure Append_Stdout_Streams (Buffer : in out Ada.Strings.Unbounded.Unbounded_String);
   --  Stdout prelude: stream/future types and canon builtins.

   procedure Append_Type_Section
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Layout : Export_Type_Layout; Type_Base : Natural);
   --  Component type lines for the allocated export functypes.

   function Assign_Export_Types (The_Model : Model.Component_Model; Type_Base : Natural) return Export_Type_Layout;
   --  Allocate unit / result type indices for the lifted exports, starting at Type_Base.

   function Component_Bases_For (Stdout : Boolean) return Component_Bases;
   --  Index bases with or without the stdout prelude.

   function Wat_Func_Id (The_Model : Model.Component_Model; Func_Index : Positive) return String;
   --  Unique WAT $id for Func_Index; appends _<index> when the LIR name is shared.

   procedure Append_Alias_Section
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model; Stdout : Boolean) is
   begin
      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Append_Line
                 (Buffer,
                  "  (alias core export " & (if Stdout then "$guest" else "0") & " """ & Func_Name & """ (core func))");
            end if;
         end;
      end loop;
   end Append_Alias_Section;

   procedure Append_Canon_Lifts
     (Buffer    : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model : Model.Component_Model;
      Layout    : Export_Type_Layout;
      Bases     : Component_Bases) is
   begin
      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
            Alias_Index : constant Natural := Core_Func_Alias_Index (The_Model, The_Export.Core_Function_Index);
            Type_Index  : constant Natural :=
              Natural (if The_Export.Returns_Result then Layout.Result_Functype_Index else Layout.Unit_Type_Index);
         begin
            Append_Line
              (Buffer,
               "  (func (type "
               & Image_Without_Leading_Space (Integer (Type_Index))
               & ") (canon lift (core func "
               & Image_Without_Leading_Space (Integer (Alias_Index + Bases.Core_Func_Base))
               & ")))");
         end;
      end loop;
   end Append_Canon_Lifts;

   procedure Append_Core_Instances
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model; Stdout : Boolean) is
   begin
      if Stdout then
         Append_Stdout_Imports (Buffer);
         Append_Stdout_Libc (Buffer);
         Append_Stdout_Streams (Buffer);
         Append_Stdout_Guest_Module_Header (Buffer);
      else
         Append_Line (Buffer, "  (core module");
      end if;

      Append_Core_Module_Functions (Buffer, The_Model);

      if Stdout then
         Append_Stdout_Guest_Instances (Buffer);
      else
         Append_Line (Buffer, "  (core instance (instantiate 0))");
      end if;
   end Append_Core_Instances;

   procedure Append_Core_Module_Functions
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model) is
   begin
      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         Ada.Strings.Unbounded.Append (Buffer, Function_Text (The_Model, Func_Index));
      end loop;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Append_Line
                 (Buffer, "    (export """ & Func_Name & """ (func " & Wat_Func_Id (The_Model, Func_Index) & "))");
            end if;
         end;
      end loop;

      Append_Line (Buffer, "  )");
   end Append_Core_Module_Functions;

   procedure Append_Dependency_Sections
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; The_Model : Model.Component_Model) is
   begin
      for Dependency_Index in 1 .. Model.Dependency_Count (The_Model) loop
         declare
            Dep : constant Model.Dependency := Model.Get_Dependency (The_Model, Dependency_Index);
         begin
            Append_Line
              (Buffer,
               "  (@custom ""lovelace-dependency"" """
               & Names.Component_Identity
                   (Ada.Strings.Unbounded.To_String (Dep.Name), Ada.Strings.Unbounded.To_String (Dep.Version))
               & """)");
         end;
      end loop;
   end Append_Dependency_Sections;

   procedure Append_Export_Section
     (Buffer    : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model : Model.Component_Model;
      Bases     : Component_Bases)
   is
      Lifted_Func_Cursor : Natural := Bases.Lifted_Func_Base;
      Instance_Cursor    : Natural := Bases.Instance_Base;
   begin
      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
            Export_Name : constant String := Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
         begin
            if The_Export.Returns_Result then
               Append_Line
                 (Buffer,
                  "  (export """
                  & Export_Name
                  & """ (instance "
                  & Image_Without_Leading_Space (Integer (Instance_Cursor))
                  & "))");
               Instance_Cursor := Instance_Cursor + 1;
            else
               Append_Line
                 (Buffer,
                  "  (export """
                  & Export_Name
                  & """ (func "
                  & Image_Without_Leading_Space (Integer (Lifted_Func_Cursor))
                  & "))");
            end if;

            Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
         end;
      end loop;
   end Append_Export_Section;

   procedure Append_Lifted_Exports
     (Buffer    : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model : Model.Component_Model;
      Layout    : Export_Type_Layout;
      Bases     : Component_Bases) is
   begin
      Append_Canon_Lifts (Buffer, The_Model, Layout, Bases);
      Append_Result_Instances (Buffer, The_Model, Bases.Lifted_Func_Base);
      Append_Export_Section (Buffer, The_Model, Bases);
   end Append_Lifted_Exports;

   procedure Append_Line (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Text : String) is
   begin
      Ada.Strings.Unbounded.Append (Buffer, Text & ASCII.LF);
   end Append_Line;

   procedure Append_Result_Instances
     (Buffer           : in out Ada.Strings.Unbounded.Unbounded_String;
      The_Model        : Model.Component_Model;
      Lifted_Func_Base : Natural)
   is
      Lifted_Func_Cursor : Natural := Lifted_Func_Base;
   begin
      for Export_Index in 1 .. Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               Append_Line
                 (Buffer,
                  "  (instance (export ""run"" (func "
                  & Image_Without_Leading_Space (Integer (Lifted_Func_Cursor))
                  & ")))");
            end if;
         end;

         Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
      end loop;
   end Append_Result_Instances;

   procedure Append_Stdout_Guest_Instances (Buffer : in out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Append_Line (Buffer, "  (core instance $guest (instantiate $guest (with """" (instance");
      Append_Line (Buffer, "    (export ""memory"" (memory $mem))");
      Append_Line (Buffer, "    (export ""stream-new"" (func $stream-new))");
      Append_Line (Buffer, "    (export ""stream-write"" (func $stream-write))");
      Append_Line (Buffer, "    (export ""stream-drop-writable"" (func $stream-drop-writable))");
      Append_Line (Buffer, "    (export ""future-read"" (func $future-read))");
      Append_Line (Buffer, "    (export ""future-drop-readable"" (func $future-drop-readable))");
      Append_Line (Buffer, "    (export ""write-via-stream"" (func $write-lower))");
      Append_Line (Buffer, "  ))))");
   end Append_Stdout_Guest_Instances;

   procedure Append_Stdout_Guest_Module_Header (Buffer : in out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Append_Line (Buffer, "  (core module $guest");
      Append_Line (Buffer, "    (import """" ""memory"" (memory 1))");
      Append_Line (Buffer, "    (import """" ""stream-new"" (func $stream-new (result i64)))");
      Append_Line (Buffer, "    (import """" ""stream-write"" (func $stream-write (param i32 i32 i32) (result i32)))");
      Append_Line (Buffer, "    (import """" ""stream-drop-writable"" (func $stream-drop-writable (param i32)))");
      Append_Line (Buffer, "    (import """" ""future-read"" (func $future-read (param i32 i32) (result i32)))");
      Append_Line (Buffer, "    (import """" ""future-drop-readable"" (func $future-drop-readable (param i32)))");
      Append_Line (Buffer, "    (import """" ""write-via-stream"" (func $write-via-stream (param i32) (result i32)))");
   end Append_Stdout_Guest_Module_Header;

   procedure Append_Stdout_Imports (Buffer : in out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Append_Line (Buffer, "  (type $ty-types");
      Append_Line (Buffer, "    (instance");
      Append_Line (Buffer, "      (type (;0;) (enum ""io"" ""illegal-byte-sequence"" ""pipe""))");
      Append_Line (Buffer, "      (export (;1;) ""error-code"" (type (eq 0)))");
      Append_Line (Buffer, "    )");
      Append_Line (Buffer, "  )");
      Append_Line
        (Buffer, "  (import """ & Model.Wasi_Cli_Types_Import_Name & """ (instance $types (type $ty-types)))");
      Append_Line (Buffer, "  (alias export $types ""error-code"" (type $error-code))");
      Append_Line (Buffer, "  (type $ty-stdout");
      Append_Line (Buffer, "    (instance");
      Append_Line (Buffer, "      (alias outer 1 $error-code (type (;0;)))");
      Append_Line (Buffer, "      (export (;1;) ""error-code"" (type (eq 0)))");
      Append_Line (Buffer, "      (type (;2;) (stream u8))");
      Append_Line (Buffer, "      (type (;3;) (result (error 1)))");
      Append_Line (Buffer, "      (type (;4;) (future 3))");
      Append_Line (Buffer, "      (type (;5;) (func (param ""data"" 2) (result 4)))");
      Append_Line (Buffer, "      (export (;0;) ""write-via-stream"" (func (type 5)))");
      Append_Line (Buffer, "    )");
      Append_Line (Buffer, "  )");
      Append_Line
        (Buffer, "  (import """ & Model.Wasi_Cli_Stdout_Import_Name & """ (instance $stdout (type $ty-stdout)))");
   end Append_Stdout_Imports;

   procedure Append_Stdout_Libc (Buffer : in out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Append_Line (Buffer, "  (core module $libc");
      Append_Line (Buffer, "    (memory (export ""memory"") 1)");
      Append_Line (Buffer, "    (func (export ""cabi_realloc"") (param i32 i32 i32 i32) (result i32)");
      Append_Line (Buffer, "      local.get 3)");
      Append_Line (Buffer, "  )");
      Append_Line (Buffer, "  (core instance $libc (instantiate $libc))");
      Append_Line (Buffer, "  (alias core export $libc ""memory"" (core memory $mem))");
      Append_Line (Buffer, "  (alias export $stdout ""write-via-stream"" (func $write-via-stream))");
   end Append_Stdout_Libc;

   procedure Append_Stdout_Streams (Buffer : in out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Append_Line (Buffer, "  (type $stream-u8 (stream u8))");
      Append_Line (Buffer, "  (type $result-error (result (error $error-code)))");
      Append_Line (Buffer, "  (type $future-result (future $result-error))");
      Append_Line (Buffer, "  (core func $stream-new (canon stream.new $stream-u8))");
      Append_Line (Buffer, "  (core func $stream-write (canon stream.write $stream-u8 async (memory $mem)))");
      Append_Line (Buffer, "  (core func $stream-drop-writable (canon stream.drop-writable $stream-u8))");
      Append_Line (Buffer, "  (core func $future-read (canon future.read $future-result async (memory $mem)))");
      Append_Line (Buffer, "  (core func $future-drop-readable (canon future.drop-readable $future-result))");
      Append_Line (Buffer, "  (core func $write-lower (canon lower (func $write-via-stream)))");
   end Append_Stdout_Streams;

   procedure Append_Type_Section
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Layout : Export_Type_Layout; Type_Base : Natural) is
   begin
      for Type_Index in Integer (Type_Base) .. Layout.Next_Type_Index - 1 loop
         if Layout.Unit_Type_Index = Type_Index then
            Append_Line (Buffer, "  (type (func))");
         elsif Layout.Result_Valtype_Index = Type_Index then
            Append_Line (Buffer, "  (type (result))");
         elsif Layout.Result_Functype_Index = Type_Index then
            Append_Line
              (Buffer, "  (type (func (result " & Image_Without_Leading_Space (Layout.Result_Valtype_Index) & ")))");
         end if;
      end loop;
   end Append_Type_Section;

   function Assign_Export_Types (The_Model : Model.Component_Model; Type_Base : Natural) return Export_Type_Layout is
      Layout : Export_Type_Layout := (Next_Type_Index => Type_Base, others => <>);
   begin
      for Export_Index in 1 .. Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               if Layout.Result_Functype_Index < 0 then
                  Layout.Result_Valtype_Index := Layout.Next_Type_Index;
                  Layout.Result_Functype_Index := Layout.Next_Type_Index + 1;
                  Layout.Next_Type_Index := Layout.Next_Type_Index + 2;
               end if;
            elsif Layout.Unit_Type_Index < 0 then
               Layout.Unit_Type_Index := Layout.Next_Type_Index;
               Layout.Next_Type_Index := Layout.Next_Type_Index + 1;
            end if;
         end;
      end loop;

      return Layout;
   end Assign_Export_Types;

   function Component_Bases_For (Stdout : Boolean) return Component_Bases is
   begin
      if Stdout then
         --  Component type indices 0 .. 5 are the stdout prelude (types, error-code,
         --  stdout instance type, stream-u8, result-error, future-result).
         --  Core funcs defined before guest exports: 5 stream/future builtins + lowered write-via-stream.
         return (Type_Base => 6, Core_Func_Base => 6, Lifted_Func_Base => 1, Instance_Base => 2);
      end if;

      return (others => 0);
   end Component_Bases_For;

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural is
      Alias_Index : Natural := 0;
   begin
      for Index in 1 .. Core_Function_Index loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Index);
         begin
            if The_Function.Core_Exported then
               if Index = Core_Function_Index then
                  return Alias_Index;
               end if;

               Alias_Index := Alias_Index + 1;
            end if;
         end;
      end loop;

      return 0;
   end Core_Func_Alias_Index;

   function Core_Value_Type_Name (The_Type : Model.Core_Value_Type) return String is
   begin
      case The_Type is
         when Model.I32 =>
            return "i32";

         when Model.I64 =>
            return "i64";

         when Model.F32 =>
            return "f32";

         when Model.F64 =>
            return "f64";
      end case;
   end Core_Value_Type_Name;

   function Dollar_Name (Name : String) return String is
      --  WAT `$id` only allows a closed ASCII idchar set; map other bytes to `_HH`.
      Hex    : constant String := "0123456789abcdef";
      Buffer : String (1 .. 1 + Name'Length * 3);
      Last   : Natural := 0;
   begin
      for Index in Name'Range loop
         declare
            Byte : constant Character := Name (Index);
            Code : constant Natural := Character'Pos (Byte);
         begin
            if Is_Wat_Id_Char (Byte) then
               Last := Last + 1;
               Buffer (Last) := Byte;
            else
               Last := Last + 1;
               Buffer (Last) := '_';
               Last := Last + 1;
               Buffer (Last) := Hex (1 + Code / 16);
               Last := Last + 1;
               Buffer (Last) := Hex (1 + Code mod 16);
            end if;
         end;
      end loop;

      if Last = 0 or else Needs_Dollar_Prefix_Guard (Buffer (1)) then
         return "$n_" & Buffer (1 .. Last);
      end if;

      return "$" & Buffer (1 .. Last);
   end Dollar_Name;

   function Emit_Wat (The_Module : Lovelace.Lir.Modules.Module) return Wat_Emit_Result is
      Lowered : constant Lowering.Lower_Result := Lowering.Lower (The_Module);
   begin
      case Lowered.Ok is
         when False =>
            return (Ok => False, Error => Lowered.Error);

         when True  =>
            return
              (Ok       => True,
               Wat_Text => Ada.Strings.Unbounded.To_Unbounded_String (To_Wat (Lowered.The_Model)),
               Wit_Text => Ada.Strings.Unbounded.To_Unbounded_String (Wit.To_Wit (Lowered.The_Model)));
      end case;
   end Emit_Wat;

   function Function_Text (The_Model : Model.Component_Model; Func_Index : Positive) return String is
      Buffer       : Ada.Strings.Unbounded.Unbounded_String;
      The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
   begin
      Ada.Strings.Unbounded.Append (Buffer, "    (func " & Wat_Func_Id (The_Model, Func_Index));

      if Model.Length (The_Function.Parameter_Types) > 0 then
         Ada.Strings.Unbounded.Append (Buffer, " (param");
         for Parameter_Index in 1 .. Model.Length (The_Function.Parameter_Types) loop
            Ada.Strings.Unbounded.Append
              (Buffer, " " & Core_Value_Type_Name (Model.Element (The_Function.Parameter_Types, Parameter_Index)));
         end loop;
         Ada.Strings.Unbounded.Append (Buffer, ")");
      end if;

      if The_Function.Result_Is_I32 then
         Ada.Strings.Unbounded.Append (Buffer, " (result i32)");
      end if;

      Ada.Strings.Unbounded.Append (Buffer, ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, Locals_Text (The_Function));

      for Instr_Index in 1 .. Model.Length (The_Function.Instructions) loop
         Ada.Strings.Unbounded.Append
           (Buffer, Instruction_Text (The_Model, Model.Element (The_Function.Instructions, Instr_Index)));
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, "    )" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end Function_Text;

   function Image_Without_Leading_Space (Value : Integer) return String is
      Raw : constant String := Integer'Image (Value);
   begin
      if Raw'Length > 0 and then Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      end if;

      return Raw;
   end Image_Without_Leading_Space;

   function Import_Name (Import_Index : Natural) return String is
   begin
      case Import_Index is
         when Model.Stream_New_Import_Index           =>
            return "$stream-new";

         when Model.Stream_Write_Import_Index         =>
            return "$stream-write";

         when Model.Stream_Drop_Writable_Import_Index =>
            return "$stream-drop-writable";

         when Model.Future_Read_Import_Index          =>
            return "$future-read";

         when Model.Future_Drop_Readable_Import_Index =>
            return "$future-drop-readable";

         when Model.Write_Via_Stream_Import_Index     =>
            return "$write-via-stream";

         when others                                  =>
            return "$import-" & Image_Without_Leading_Space (Import_Index);
      end case;
   end Import_Name;

   function Instruction_Text (The_Model : Model.Component_Model; Item : Model.Core_Instruction) return String is
      Indent : constant String := "      ";
      Name   : constant String := Mnemonic_Name (Item.Kind);
   begin
      case Item.Kind is
         when Model.Call_Function
            | Model.Call_Import
            | Model.I32_Constant
            | Model.I64_Constant
            | Model.Local_Get
            | Model.Local_Set
            | Model.Br
            | Model.Br_If =>
            return Indent & Name & " " & Operand_Text (The_Model, Item) & ASCII.LF;

         when others      =>
            return Indent & Name & ASCII.LF;
      end case;
   end Instruction_Text;

   function Is_Wat_Id_Char (Byte : Character) return Boolean is
   begin
      case Byte is
         when 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '-' =>
            return True;
         when others =>
            return False;
      end case;
   end Is_Wat_Id_Char;

   function Locals_Text (The_Function : Model.Core_Function) return String is
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if Model.Length (The_Function.Local_Types) = 0 then
         return "";
      end if;

      Ada.Strings.Unbounded.Append (Buffer, "      (local");

      for Local_Index in 1 .. Model.Length (The_Function.Local_Types) loop
         Ada.Strings.Unbounded.Append
           (Buffer, " " & Core_Value_Type_Name (Model.Element (The_Function.Local_Types, Local_Index)));
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, ")" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end Locals_Text;

   function Mnemonic_Name (Kind : Model.Core_Instruction_Kind) return String is
   begin
      return Mnemonic_Strings.To_String (Mnemonic_Table (Kind));
   end Mnemonic_Name;

   function Name_Count (The_Model : Model.Component_Model; Name : String) return Natural is
      Total : Natural := 0;
   begin
      for Index in 1 .. Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Index);
            Func_Name    : constant String := Unbounded_Text (The_Function.Name);
         begin
            if Func_Name = Name then
               Total := Total + 1;
            end if;
         end;
      end loop;
      return Total;
   end Name_Count;

   function Needs_Dollar_Prefix_Guard (First : Character) return Boolean is
   begin
      return First in '0' .. '9' or else First = '-';
   end Needs_Dollar_Prefix_Guard;

   function Operand_Text (The_Model : Model.Component_Model; Item : Model.Core_Instruction) return String is
   begin
      case Item.Kind is
         when Model.Call_Function               =>
            return Wat_Func_Id (The_Model, Item.Target_Index);

         when Model.Call_Import                 =>
            return Import_Name (Item.Import_Index);

         when Model.I32_Constant                =>
            return Image_Without_Leading_Space (Integer (Item.Value));

         when Model.I64_Constant                =>
            declare
               Raw : constant String := Interfaces.Integer_64'Image (Item.Value_I64);
            begin
               if Raw (Raw'First) = ' ' then
                  return Raw (Raw'First + 1 .. Raw'Last);
               end if;

               return Raw;
            end;

         when Model.Local_Get | Model.Local_Set =>
            return Image_Without_Leading_Space (Item.Local_Index);

         when Model.Br | Model.Br_If            =>
            return Image_Without_Leading_Space (Item.Label_Depth);

         when others                            =>
            return "";
      end case;
   end Operand_Text;

   function To_Wat (The_Model : Model.Component_Model) return String is
      Stdout : constant Boolean := Model.Has_Wasi_Stdout (The_Model);
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
      Bases  : constant Component_Bases := Component_Bases_For (Stdout);
      Layout : constant Export_Type_Layout := Assign_Export_Types (The_Model, Bases.Type_Base);
   begin
      Append_Line
        (Buffer,
         "(component $" & Names.Component_Identity (Model.Module_Name (The_Model), Model.Module_Version (The_Model)));
      Append_Core_Instances (Buffer, The_Model, Stdout);
      Append_Alias_Section (Buffer, The_Model, Stdout);
      Append_Type_Section (Buffer, Layout, Bases.Type_Base);
      Append_Lifted_Exports (Buffer, The_Model, Layout, Bases);
      Append_Dependency_Sections (Buffer, The_Model);
      Ada.Strings.Unbounded.Append (Buffer, ")" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end To_Wat;

   function Wat_Func_Id (The_Model : Model.Component_Model; Func_Index : Positive) return String is
      The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
      Func_Name    : constant String := Unbounded_Text (The_Function.Name);
      Base         : constant String := Dollar_Name (Func_Name);
   begin
      if Name_Count (The_Model, Func_Name) > 1 then
         return Base & "_" & Image_Without_Leading_Space (Func_Index);
      end if;
      return Base;
   end Wat_Func_Id;

end Lovelace.Compiler.Backend.Wat;
