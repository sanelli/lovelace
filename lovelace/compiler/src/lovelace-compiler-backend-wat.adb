with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Compiler.Backend.Lowering;
with Lovelace.Compiler.Backend.Model;
with Lovelace.Compiler.Backend.Wit;

package body Lovelace.Compiler.Backend.Wat is

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural;
   --  0-based alias index among Core_Exported functions for Core_Function_Index.

   function Core_Value_Type_Name (The_Type : Model.Core_Value_Type) return String;
   --  WAT spelling for a core value type.

   function Dollar_Name (Name : String) return String;
   --  WAT $Name form (Name is already a safe identifier in this slice).

   function Image_Without_Leading_Space (Value : Integer) return String;
   --  Decimal image without the leading blank Ada puts on positive'Image.

   function Import_Name (Import_Index : Natural) return String;
   --  WAT $name of the fixed WASI stdout core import slot Import_Index.

   function Instruction_Text
     (The_Model : Model.Component_Model; Item : Model.Core_Instruction) return String;
   --  One WAT instruction line (indented, LF-terminated) for Item.

   function Locals_Text (The_Function : Model.Core_Function) return String;
   --  Optional "(local ...)" line (LF-terminated); empty when there are no locals.

   function Function_Text (The_Model : Model.Component_Model; The_Function : Model.Core_Function) return String;
   --  "(func ...)" definition for The_Function inside a core module.

   function To_Wat (The_Model : Model.Component_Model) return String;
   --  Render The_Model as component WAT text.

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural is
      Alias_Index : Natural := 0;
   begin
      for Index in 1 .. Core_Function_Index loop
         if Model.Get_Function (The_Model, Index).Core_Exported then
            if Index = Core_Function_Index then
               return Alias_Index;
            end if;

            Alias_Index := Alias_Index + 1;
         end if;
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
   begin
      return "$" & Name;
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

   function Function_Text (The_Model : Model.Component_Model; The_Function : Model.Core_Function) return String is
      Buffer    : Ada.Strings.Unbounded.Unbounded_String;
      Func_Name : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
   begin
      Ada.Strings.Unbounded.Append (Buffer, "    (func " & Dollar_Name (Func_Name));

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

   function Instruction_Text
     (The_Model : Model.Component_Model; Item : Model.Core_Instruction) return String
   is
      Indent : constant String := "      ";

      function Plain (Text : String) return String;
      --  Indented instruction line.

      function Plain (Text : String) return String is
      begin
         return Indent & Text & ASCII.LF;
      end Plain;
   begin
      case Item.Kind is
         when Model.Call_Function    =>
            return
              Plain
                ("call "
                 & Dollar_Name
                     (Ada.Strings.Unbounded.To_String (Model.Get_Function (The_Model, Item.Target_Index).Name)));

         when Model.Call_Import      =>
            return Plain ("call " & Import_Name (Item.Import_Index));

         when Model.I32_Constant     =>
            return Plain ("i32.const " & Image_Without_Leading_Space (Integer (Item.Value)));

         when Model.I64_Constant     =>
            declare
               Raw : constant String := Interfaces.Integer_64'Image (Item.Value_I64);
            begin
               if Raw (Raw'First) = ' ' then
                  return Plain ("i64.const " & Raw (Raw'First + 1 .. Raw'Last));
               end if;

               return Plain ("i64.const " & Raw);
            end;

         when Model.Local_Get        =>
            return Plain ("local.get " & Image_Without_Leading_Space (Item.Local_Index));

         when Model.Local_Set        =>
            return Plain ("local.set " & Image_Without_Leading_Space (Item.Local_Index));

         when Model.I32_Add          =>
            return Plain ("i32.add");

         when Model.I32_Sub          =>
            return Plain ("i32.sub");

         when Model.I32_Mul          =>
            return Plain ("i32.mul");

         when Model.I32_Div_S        =>
            return Plain ("i32.div_s");

         when Model.I32_Rem_S        =>
            return Plain ("i32.rem_s");

         when Model.I32_Eqz          =>
            return Plain ("i32.eqz");

         when Model.I32_Eq           =>
            return Plain ("i32.eq");

         when Model.I32_Ne           =>
            return Plain ("i32.ne");

         when Model.I32_Lt_S         =>
            return Plain ("i32.lt_s");

         when Model.I32_Gt_S         =>
            return Plain ("i32.gt_s");

         when Model.I32_Le_S         =>
            return Plain ("i32.le_s");

         when Model.I32_Ge_S         =>
            return Plain ("i32.ge_s");

         when Model.I32_Store8       =>
            return Plain ("i32.store8");

         when Model.I32_Load8_U      =>
            return Plain ("i32.load8_u");

         when Model.I32_Wrap_I64     =>
            return Plain ("i32.wrap_i64");

         when Model.I64_Extend_I32_U =>
            return Plain ("i64.extend_i32_u");

         when Model.I64_Shr_U        =>
            return Plain ("i64.shr_u");

         when Model.Unreachable      =>
            return Plain ("unreachable");

         when Model.If_Empty         =>
            return Plain ("if");

         when Model.Else_Op          =>
            return Plain ("else");

         when Model.End_Op           =>
            return Plain ("end");

         when Model.Loop_Empty       =>
            return Plain ("loop");

         when Model.Br               =>
            return Plain ("br " & Image_Without_Leading_Space (Item.Label_Depth));

         when Model.Br_If            =>
            return Plain ("br_if " & Image_Without_Leading_Space (Item.Label_Depth));
      end case;
   end Instruction_Text;

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

   function To_Wat (The_Model : Model.Component_Model) return String is
      Stdout                : constant Boolean := Model.Has_Wasi_Stdout (The_Model);
      Buffer                : Ada.Strings.Unbounded.Unbounded_String;
      Unit_Type_Index       : Integer := -1;
      Result_Valtype_Index  : Integer := -1;
      Result_Functype_Index : Integer := -1;
      --  Component type indices 0 .. 5 are the stdout prelude (types, error-code,
      --  stdout instance type, stream-u8, result-error, future-result).
      Type_Base             : constant Natural := (if Stdout then 6 else 0);
      Next_Type_Index       : Natural := Type_Base;
      --  Core funcs defined before guest exports: 5 stream/future builtins + lowered write-via-stream.
      Core_Func_Base        : constant Natural := (if Stdout then 6 else 0);
      Lifted_Func_Base      : constant Natural := (if Stdout then 1 else 0);
      Instance_Base         : constant Natural := (if Stdout then 2 else 0);

      procedure Line (Text : String);
      --  Append Text and a line feed to Buffer.

      procedure Line (Text : String) is
      begin
         Ada.Strings.Unbounded.Append (Buffer, Text & ASCII.LF);
      end Line;
   begin
      Line ("(component");

      if Stdout then
         Line ("  (type $ty-types");
         Line ("    (instance");
         Line ("      (type (;0;) (enum ""io"" ""illegal-byte-sequence"" ""pipe""))");
         Line ("      (export (;1;) ""error-code"" (type (eq 0)))");
         Line ("    )");
         Line ("  )");
         Line ("  (import """ & Model.Wasi_Cli_Types_Import_Name & """ (instance $types (type $ty-types)))");
         Line ("  (alias export $types ""error-code"" (type $error-code))");
         Line ("  (type $ty-stdout");
         Line ("    (instance");
         Line ("      (alias outer 1 $error-code (type (;0;)))");
         Line ("      (export (;1;) ""error-code"" (type (eq 0)))");
         Line ("      (type (;2;) (stream u8))");
         Line ("      (type (;3;) (result (error 1)))");
         Line ("      (type (;4;) (future 3))");
         Line ("      (type (;5;) (func (param ""data"" 2) (result 4)))");
         Line ("      (export (;0;) ""write-via-stream"" (func (type 5)))");
         Line ("    )");
         Line ("  )");
         Line ("  (import """ & Model.Wasi_Cli_Stdout_Import_Name & """ (instance $stdout (type $ty-stdout)))");
         Line ("  (core module $libc");
         Line ("    (memory (export ""memory"") 1)");
         Line ("    (func (export ""cabi_realloc"") (param i32 i32 i32 i32) (result i32)");
         Line ("      local.get 3)");
         Line ("  )");
         Line ("  (core instance $libc (instantiate $libc))");
         Line ("  (alias core export $libc ""memory"" (core memory $mem))");
         Line ("  (alias export $stdout ""write-via-stream"" (func $write-via-stream))");
         Line ("  (type $stream-u8 (stream u8))");
         Line ("  (type $result-error (result (error $error-code)))");
         Line ("  (type $future-result (future $result-error))");
         Line ("  (core func $stream-new (canon stream.new $stream-u8))");
         Line ("  (core func $stream-write (canon stream.write $stream-u8 async (memory $mem)))");
         Line ("  (core func $stream-drop-writable (canon stream.drop-writable $stream-u8))");
         Line ("  (core func $future-read (canon future.read $future-result async (memory $mem)))");
         Line ("  (core func $future-drop-readable (canon future.drop-readable $future-result))");
         Line ("  (core func $write-lower (canon lower (func $write-via-stream)))");
         Line ("  (core module $guest");
         Line ("    (import """" ""memory"" (memory 1))");
         Line ("    (import """" ""stream-new"" (func $stream-new (result i64)))");
         Line ("    (import """" ""stream-write"" (func $stream-write (param i32 i32 i32) (result i32)))");
         Line ("    (import """" ""stream-drop-writable"" (func $stream-drop-writable (param i32)))");
         Line ("    (import """" ""future-read"" (func $future-read (param i32 i32) (result i32)))");
         Line ("    (import """" ""future-drop-readable"" (func $future-drop-readable (param i32)))");
         Line ("    (import """" ""write-via-stream"" (func $write-via-stream (param i32) (result i32)))");
      else
         Line ("  (core module");
      end if;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         Ada.Strings.Unbounded.Append (Buffer, Function_Text (The_Model, Model.Get_Function (The_Model, Func_Index)));
      end loop;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Ada.Strings.Unbounded.Append
                 (Buffer, "    (export """ & Func_Name & """ (func " & Dollar_Name (Func_Name) & "))" & ASCII.LF);
            end if;
         end;
      end loop;

      Line ("  )");

      if Stdout then
         Line ("  (core instance $guest (instantiate $guest (with """" (instance");
         Line ("    (export ""memory"" (memory $mem))");
         Line ("    (export ""stream-new"" (func $stream-new))");
         Line ("    (export ""stream-write"" (func $stream-write))");
         Line ("    (export ""stream-drop-writable"" (func $stream-drop-writable))");
         Line ("    (export ""future-read"" (func $future-read))");
         Line ("    (export ""future-drop-readable"" (func $future-drop-readable))");
         Line ("    (export ""write-via-stream"" (func $write-lower))");
         Line ("  ))))");
      else
         Line ("  (core instance (instantiate 0))");
      end if;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Line
                 ("  (alias core export "
                  & (if Stdout then "$guest" else "0")
                  & " """
                  & Func_Name
                  & """ (core func))");
            end if;
         end;
      end loop;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               if Result_Functype_Index < 0 then
                  Result_Valtype_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
                  Result_Functype_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
               end if;
            else
               if Unit_Type_Index < 0 then
                  Unit_Type_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
               end if;
            end if;
         end;
      end loop;

      for Type_Index in Integer (Type_Base) .. Integer (Next_Type_Index) - 1 loop
         if Unit_Type_Index = Type_Index then
            Ada.Strings.Unbounded.Append (Buffer, "  (type (func))" & ASCII.LF);
         elsif Result_Valtype_Index = Type_Index then
            Ada.Strings.Unbounded.Append (Buffer, "  (type (result))" & ASCII.LF);
         elsif Result_Functype_Index = Type_Index then
            Ada.Strings.Unbounded.Append
              (Buffer,
               "  (type (func (result " & Image_Without_Leading_Space (Result_Valtype_Index) & ")))" & ASCII.LF);
         end if;
      end loop;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
            Alias_Index : constant Natural := Core_Func_Alias_Index (The_Model, The_Export.Core_Function_Index);
            Type_Index  : Natural;
         begin
            if The_Export.Returns_Result then
               Type_Index := Natural (Result_Functype_Index);
            else
               Type_Index := Natural (Unit_Type_Index);
            end if;

            Ada.Strings.Unbounded.Append
              (Buffer,
               "  (func (type "
               & Image_Without_Leading_Space (Integer (Type_Index))
               & ") (canon lift (core func "
               & Image_Without_Leading_Space (Integer (Alias_Index + Core_Func_Base))
               & ")))"
               & ASCII.LF);
         end;
      end loop;

      declare
         Lifted_Func_Cursor : Natural := Lifted_Func_Base;
         Instance_Cursor    : Natural := Instance_Base;
      begin
         for Export_Index in 1 .. Model.Export_Count (The_Model) loop
            declare
               The_Export : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
            begin
               if The_Export.Returns_Result then
                  Ada.Strings.Unbounded.Append
                    (Buffer,
                     "  (instance (export ""run"" (func "
                     & Image_Without_Leading_Space (Integer (Lifted_Func_Cursor))
                     & ")))"
                     & ASCII.LF);
               end if;
               Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
            end;
         end loop;

         Lifted_Func_Cursor := Lifted_Func_Base;
         for Export_Index in 1 .. Model.Export_Count (The_Model) loop
            declare
               The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
               Export_Name : constant String := Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
            begin
               if The_Export.Returns_Result then
                  Ada.Strings.Unbounded.Append
                    (Buffer,
                     "  (export """
                     & Export_Name
                     & """ (instance "
                     & Image_Without_Leading_Space (Integer (Instance_Cursor))
                     & "))"
                     & ASCII.LF);
                  Instance_Cursor := Instance_Cursor + 1;
               else
                  Ada.Strings.Unbounded.Append
                    (Buffer,
                     "  (export """
                     & Export_Name
                     & """ (func "
                     & Image_Without_Leading_Space (Integer (Lifted_Func_Cursor))
                     & "))"
                     & ASCII.LF);
               end if;
               Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
            end;
         end loop;
      end;

      Ada.Strings.Unbounded.Append (Buffer, ")" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end To_Wat;

end Lovelace.Compiler.Backend.Wat;
