with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Compiler.Backend.Leb128;
with Lovelace.Compiler.Backend.Lowering;
with Lovelace.Compiler.Backend.Model;
with Lovelace.Compiler.Backend.Names;
with Lovelace.Compiler.Backend.Wit;

package body Lovelace.Compiler.Backend.Wasm is

   procedure Append_Name (Sequence : in out Byte_Sequence; Name : String);
   --  Length-prefixed UTF-8 name (core:name / externname bytes).

   procedure Append_Section
     (Sequence : in out Byte_Sequence; Section_Id : Interfaces.Unsigned_8; Contents : Byte_Sequence);
   --  Component/core style section: id, size, contents.

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural;
   --  0-based alias index among Core_Exported functions.

   function Core_Value_Type_Byte (The_Type : Model.Core_Value_Type) return Interfaces.Unsigned_8;
   --  Core WASM valtype encoding byte for The_Type.

   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;

   procedure Append_Raw (Sequence : in out Byte_Sequence; Bytes : Byte_Array);
   --  Append each byte of Bytes in order.

   procedure Append_Signed_64 (Sequence : in out Byte_Sequence; Value : Interfaces.Integer_64);
   --  Signed LEB128 for an i64 immediate.

   procedure Append_Instruction
     (Sequence : in out Byte_Sequence; The_Model : Model.Component_Model; Item : Model.Core_Instruction);
   --  Encode one core instruction.

   procedure Append_Locals (Sequence : in out Byte_Sequence; The_Function : Model.Core_Function);
   --  Local declarations vector (grouped by consecutive equal type).

   function Encode_Libc_Module return Byte_Sequence;
   --  Core module exporting memory and cabi_realloc.

   function Encode_Component (The_Model : Model.Component_Model) return Byte_Sequence;
   --  Full component binary for The_Model.

   function Encode_Core_Module (The_Model : Model.Component_Model) return Byte_Sequence;
   --  Nested core module binary for The_Model.

   procedure Append_Instruction
     (Sequence : in out Byte_Sequence; The_Model : Model.Component_Model; Item : Model.Core_Instruction)
   is
      Function_Base : constant Natural :=
        (if Model.Has_Wasi_Stdout (The_Model) then Model.Wasi_Stdout_Import_Count else 0);
   begin
      case Item.Kind is
         when Model.Call_Function    =>
            Append (Sequence, 16#10#);
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Function_Base + Item.Target_Index - 1));

         when Model.Call_Import      =>
            Append (Sequence, 16#10#);
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Import_Index));

         when Model.I32_Constant     =>
            Append (Sequence, 16#41#);
            Leb128.Append_Signed (Sequence, Item.Value);

         when Model.I64_Constant     =>
            Append (Sequence, 16#42#);
            Append_Signed_64 (Sequence, Item.Value_I64);

         when Model.Local_Get        =>
            Append (Sequence, 16#20#);
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Local_Index));

         when Model.Local_Set        =>
            Append (Sequence, 16#21#);
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Local_Index));

         when Model.I32_Add          =>
            Append (Sequence, 16#6A#);

         when Model.I32_Sub          =>
            Append (Sequence, 16#6B#);

         when Model.I32_Mul          =>
            Append (Sequence, 16#6C#);

         when Model.I32_Div_S        =>
            Append (Sequence, 16#6D#);

         when Model.I32_Rem_S        =>
            Append (Sequence, 16#6F#);

         when Model.I32_Eqz          =>
            Append (Sequence, 16#45#);

         when Model.I32_Eq           =>
            Append (Sequence, 16#46#);

         when Model.I32_Ne           =>
            Append (Sequence, 16#47#);

         when Model.I32_Lt_S         =>
            Append (Sequence, 16#48#);

         when Model.I32_Gt_S         =>
            Append (Sequence, 16#4A#);

         when Model.I32_Le_S         =>
            Append (Sequence, 16#4C#);

         when Model.I32_Ge_S         =>
            Append (Sequence, 16#4E#);

         when Model.I32_Store8       =>
            Append_Raw (Sequence, [16#3A#, 0, 0]); -- align 0, offset 0

         when Model.I32_Load8_U      =>
            Append_Raw (Sequence, [16#2D#, 0, 0]); -- align 0, offset 0

         when Model.I32_Wrap_I64     =>
            Append (Sequence, 16#A7#);

         when Model.I64_Extend_I32_U =>
            Append (Sequence, 16#AD#);

         when Model.I64_Shr_U        =>
            Append (Sequence, 16#88#);

         when Model.Unreachable      =>
            Append (Sequence, 16#00#);

         when Model.If_Empty         =>
            Append_Raw (Sequence, [16#04#, 16#40#]);

         when Model.Else_Op          =>
            Append (Sequence, 16#05#);

         when Model.End_Op           =>
            Append (Sequence, 16#0B#);

         when Model.Loop_Empty       =>
            Append_Raw (Sequence, [16#03#, 16#40#]);

         when Model.Br               =>
            Append (Sequence, 16#0C#);
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Label_Depth));

         when Model.Br_If            =>
            Append (Sequence, 16#0D#);
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Label_Depth));
      end case;
   end Append_Instruction;

   procedure Append_Locals (Sequence : in out Byte_Sequence; The_Function : Model.Core_Function) is
      use type Model.Core_Value_Type;

      Total      : constant Natural := Model.Length (The_Function.Local_Types);
      Group_Size : Natural := 0;
      Group_Type : Model.Core_Value_Type := Model.I32;
      Groups     : Byte_Sequence := Empty_Bytes;
      Group_Count : Natural := 0;

      procedure Flush;
      --  Emit the pending local group, if any.

      procedure Flush is
      begin
         if Group_Size > 0 then
            Leb128.Append_Unsigned (Groups, Interfaces.Unsigned_32 (Group_Size));
            Append (Groups, Core_Value_Type_Byte (Group_Type));
            Group_Count := Group_Count + 1;
            Group_Size := 0;
         end if;
      end Flush;
   begin
      for Index in 1 .. Total loop
         declare
            Local_Type : constant Model.Core_Value_Type := Model.Element (The_Function.Local_Types, Index);
         begin
            if Group_Size > 0 and then Local_Type /= Group_Type then
               Flush;
            end if;

            Group_Type := Local_Type;
            Group_Size := Group_Size + 1;
         end;
      end loop;

      Flush;
      Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Group_Count));
      Append_Bytes (Sequence, Groups);
   end Append_Locals;

   procedure Append_Name (Sequence : in out Byte_Sequence; Name : String) is
   begin
      Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Name'Length));

      for Index in Name'Range loop
         Append (Sequence, Interfaces.Unsigned_8 (Character'Pos (Name (Index))));
      end loop;
   end Append_Name;

   procedure Append_Raw (Sequence : in out Byte_Sequence; Bytes : Byte_Array) is
   begin
      for Byte of Bytes loop
         Append (Sequence, Byte);
      end loop;
   end Append_Raw;

   procedure Append_Section
     (Sequence : in out Byte_Sequence; Section_Id : Interfaces.Unsigned_8; Contents : Byte_Sequence) is
   begin
      Append (Sequence, Section_Id);
      Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Length (Contents)));
      Append_Bytes (Sequence, Contents);
   end Append_Section;

   procedure Append_Signed_64 (Sequence : in out Byte_Sequence; Value : Interfaces.Integer_64) is
      use type Interfaces.Integer_64;

      Remaining : Interfaces.Integer_64 := Value;
      Low       : Interfaces.Integer_64;
      Done      : Boolean := False;
   begin
      while not Done loop
         Low := Remaining mod 128;
         Remaining := (Remaining - Low) / 128; -- exact, so equals an arithmetic shift right by 7

         if (Remaining = 0 and then Low < 64) or else (Remaining = -1 and then Low >= 64) then
            Done := True;
            Append (Sequence, Interfaces.Unsigned_8 (Low));
         else
            Append (Sequence, Interfaces.Unsigned_8 (Low + 128));
         end if;
      end loop;
   end Append_Signed_64;

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

   function Core_Value_Type_Byte (The_Type : Model.Core_Value_Type) return Interfaces.Unsigned_8 is
   begin
      case The_Type is
         when Model.I32 =>
            return 16#7F#;

         when Model.I64 =>
            return 16#7E#;

         when Model.F32 =>
            return 16#7D#;

         when Model.F64 =>
            return 16#7C#;
      end case;
   end Core_Value_Type_Byte;

   function Emit_Wasm (The_Module : Lovelace.Lir.Modules.Module) return Wasm_Emit_Result is
      Lowered : constant Lowering.Lower_Result := Lowering.Lower (The_Module);
   begin
      case Lowered.Ok is
         when False =>
            return (Ok => False, Error => Lowered.Error);

         when True  =>
            return
              (Ok         => True,
               Wasm_Bytes => Encode_Component (Lowered.The_Model),
               Wit_Text   => Ada.Strings.Unbounded.To_Unbounded_String (Wit.To_Wit (Lowered.The_Model)));
      end case;
   end Emit_Wasm;

   function Encode_Component (The_Model : Model.Component_Model) return Byte_Sequence is
      Component_Bytes       : Byte_Sequence := Empty_Bytes;
      Instance_Contents     : Byte_Sequence := Empty_Bytes;
      Alias_Contents        : Byte_Sequence := Empty_Bytes;
      Type_Contents         : Byte_Sequence := Empty_Bytes;
      Canon_Contents        : Byte_Sequence := Empty_Bytes;
      Export_Contents       : Byte_Sequence := Empty_Bytes;
      Core_Module           : constant Byte_Sequence := Encode_Core_Module (The_Model);
      Alias_Count           : Natural := 0;
      Unit_Type_Index       : Integer := -1;
      Result_Valtype_Index  : Integer := -1;
      Result_Functype_Index : Integer := -1;
      Stdout                : constant Boolean := Model.Has_Wasi_Stdout (The_Model);
      --  Component type indices 0 .. 5 are the stdout prelude: types instance type,
      --  error-code alias, stdout instance type, stream-u8, result-error, future-result.
      Type_Base             : constant Natural := (if Stdout then 6 else 0);
      --  Core funcs before guest exports: stream.new/write/drop-writable,
      --  future.read/drop-readable, and the lowered write-via-stream.
      Core_Func_Base        : constant Natural := (if Stdout then 6 else 0);
      Lifted_Func_Base      : constant Natural := (if Stdout then 1 else 0);
      Instance_Base         : constant Natural := (if Stdout then 2 else 0);
      Guest_Core_Instance   : constant Natural := (if Stdout then 2 else 0);
      Next_Type_Index       : Natural := Type_Base;
   begin
      Append (Component_Bytes, 16#00#);
      Append (Component_Bytes, 16#61#);
      Append (Component_Bytes, 16#73#);
      Append (Component_Bytes, 16#6D#);
      Append (Component_Bytes, 16#0D#);
      Append (Component_Bytes, 16#00#);
      Append (Component_Bytes, 16#01#);
      Append (Component_Bytes, 16#00#);

      if Stdout then
         declare
            Contents : Byte_Sequence;
         begin
            --  type 0: instance type for wasi:cli/types (enum error-code, exported eq type).
            Contents := Empty_Bytes;
            Append_Raw (Contents, [1, 16#42#, 2]);
            Append_Raw (Contents, [16#01#, 16#6D#, 3]);
            Append_Name (Contents, "io");
            Append_Name (Contents, "illegal-byte-sequence");
            Append_Name (Contents, "pipe");
            Append_Raw (Contents, [16#04#, 16#00#]);
            Append_Name (Contents, "error-code");
            Append_Raw (Contents, [16#03#, 16#00#, 16#00#]);
            Append_Section (Component_Bytes, 7, Contents);

            --  import wasi:cli/types (instance 0).
            Contents := Empty_Bytes;
            Append_Raw (Contents, [1, 16#00#]);
            Append_Name (Contents, Model.Wasi_Cli_Types_Import_Name);
            Append_Raw (Contents, [16#05#, 0]);
            Append_Section (Component_Bytes, 10, Contents);

            --  type 1: alias export instance 0 "error-code".
            Contents := Empty_Bytes;
            Append_Raw (Contents, [1, 16#03#, 16#00#, 0]);
            Append_Name (Contents, "error-code");
            Append_Section (Component_Bytes, 6, Contents);

            --  type 2: instance type for wasi:cli/stdout.
            Contents := Empty_Bytes;
            Append_Raw (Contents, [1, 16#42#, 7]);
            Append_Raw (Contents, [16#02#, 16#03#, 16#02#, 1, 1]); -- alias outer 1 type 1 -> local 0
            Append_Raw (Contents, [16#04#, 16#00#]);
            Append_Name (Contents, "error-code");
            Append_Raw (Contents, [16#03#, 16#00#, 16#00#]); -- export type (eq 0) -> local 1
            Append_Raw (Contents, [16#01#, 16#66#, 1, 16#7D#]); -- local 2: stream<u8>
            Append_Raw (Contents, [16#01#, 16#6A#, 0, 1, 1]); -- local 3: result<_, error-code>
            Append_Raw (Contents, [16#01#, 16#65#, 1, 3]); -- local 4: future<local 3>
            Append_Raw (Contents, [16#01#, 16#40#, 1]); -- local 5: func (data: local 2) -> local 4
            Append_Name (Contents, "data");
            Append_Raw (Contents, [2, 16#00#, 4]);
            Append_Raw (Contents, [16#04#, 16#00#]);
            Append_Name (Contents, "write-via-stream");
            Append_Raw (Contents, [16#01#, 5]);
            Append_Section (Component_Bytes, 7, Contents);

            --  import wasi:cli/stdout (instance 1).
            Contents := Empty_Bytes;
            Append_Raw (Contents, [1, 16#00#]);
            Append_Name (Contents, Model.Wasi_Cli_Stdout_Import_Name);
            Append_Raw (Contents, [16#05#, 2]);
            Append_Section (Component_Bytes, 10, Contents);

            --  core module 0 (libc) and its instance (core instance 0).
            Append_Section (Component_Bytes, 1, Encode_Libc_Module);

            Contents := Empty_Bytes;
            Append_Raw (Contents, [1, 16#00#, 0, 0]);
            Append_Section (Component_Bytes, 2, Contents);

            --  core memory 0 from libc; component func 0 = stdout write-via-stream.
            Contents := Empty_Bytes;
            Append_Raw (Contents, [2, 16#00#, 16#02#, 16#01#, 0]);
            Append_Name (Contents, "memory");
            Append_Raw (Contents, [16#01#, 16#00#, 1]);
            Append_Name (Contents, "write-via-stream");
            Append_Section (Component_Bytes, 6, Contents);

            --  types 3 .. 5: stream<u8>, result<_, error-code>, future<result-error>.
            Contents := Empty_Bytes;
            Append_Raw (Contents, [3, 16#66#, 1, 16#7D#]);
            Append_Raw (Contents, [16#6A#, 0, 1, 1]);
            Append_Raw (Contents, [16#65#, 1, 4]);
            Append_Section (Component_Bytes, 7, Contents);

            --  core funcs 0 .. 5.
            Contents := Empty_Bytes;
            Append_Raw (Contents, [6, 16#0E#, 3]); -- stream.new
            Append_Raw (Contents, [16#10#, 3, 2, 16#06#, 16#03#, 0]); -- stream.write async (memory 0)
            Append_Raw (Contents, [16#14#, 3]); -- stream.drop-writable
            Append_Raw (Contents, [16#16#, 5, 2, 16#06#, 16#03#, 0]); -- future.read async (memory 0)
            Append_Raw (Contents, [16#1A#, 5]); -- future.drop-readable
            Append_Raw (Contents, [16#01#, 16#00#, 0, 0]); -- lower component func 0
            Append_Section (Component_Bytes, 8, Contents);

            --  core module 1 (guest).
            Append_Section (Component_Bytes, 1, Core_Module);

            --  core instance 1: bundle of core exports; core instance 2: guest.
            Contents := Empty_Bytes;
            Append_Raw (Contents, [2, 16#01#, 7]);
            Append_Name (Contents, "memory");
            Append_Raw (Contents, [16#02#, 0]);
            Append_Name (Contents, "stream-new");
            Append_Raw (Contents, [16#00#, 0]);
            Append_Name (Contents, "stream-write");
            Append_Raw (Contents, [16#00#, 1]);
            Append_Name (Contents, "stream-drop-writable");
            Append_Raw (Contents, [16#00#, 2]);
            Append_Name (Contents, "future-read");
            Append_Raw (Contents, [16#00#, 3]);
            Append_Name (Contents, "future-drop-readable");
            Append_Raw (Contents, [16#00#, 4]);
            Append_Name (Contents, "write-via-stream");
            Append_Raw (Contents, [16#00#, 5]);
            Append_Raw (Contents, [16#00#, 1, 1]); -- instantiate module 1 with one arg
            Append_Name (Contents, "");
            Append_Raw (Contents, [16#12#, 1]);
            Append_Section (Component_Bytes, 2, Contents);
         end;
      else
         Append_Section (Component_Bytes, 1, Core_Module);

         --  core instance: instantiate module 0 with no args
         Leb128.Append_Unsigned (Instance_Contents, 1);
         Append (Instance_Contents, 16#00#); -- instantiate
         Leb128.Append_Unsigned (Instance_Contents, 0); -- moduleidx
         Leb128.Append_Unsigned (Instance_Contents, 0); -- empty args
         Append_Section (Component_Bytes, 2, Instance_Contents);
      end if;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         if Model.Get_Function (The_Model, Func_Index).Core_Exported then
            Alias_Count := Alias_Count + 1;
         end if;
      end loop;

      Leb128.Append_Unsigned (Alias_Contents, Interfaces.Unsigned_32 (Alias_Count));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Append (Alias_Contents, 16#00#); -- sort: core
               Append (Alias_Contents, 16#00#); -- core sort: func
               Append (Alias_Contents, 16#01#); -- alias core export
               Leb128.Append_Unsigned (Alias_Contents, Interfaces.Unsigned_32 (Guest_Core_Instance));
               Append_Name (Alias_Contents, Func_Name);
            end if;
         end;
      end loop;

      if Alias_Count > 0 then
         Append_Section (Component_Bytes, 6, Alias_Contents);
      end if;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               if Result_Functype_Index < 0 then
                  --  Bare (result) is a defvaltype; functype may only reference it by typeidx.
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

      if Next_Type_Index > Type_Base then
         Leb128.Append_Unsigned (Type_Contents, Interfaces.Unsigned_32 (Next_Type_Index - Type_Base));

         for Type_Index in Type_Base .. Next_Type_Index - 1 loop
            if Unit_Type_Index = Integer (Type_Index) then
               --  func ()
               Append (Type_Contents, 16#40#);
               Leb128.Append_Unsigned (Type_Contents, 0); -- empty params
               Append (Type_Contents, 16#01#); -- empty resultlist
               Append (Type_Contents, 16#00#);
            elsif Result_Valtype_Index = Integer (Type_Index) then
               --  (result) with no ok/err payloads
               Append (Type_Contents, 16#6A#);
               Append (Type_Contents, 16#00#);
               Append (Type_Contents, 16#00#);
            elsif Result_Functype_Index = Integer (Type_Index) then
               --  func () -> <Result_Valtype_Index>
               Append (Type_Contents, 16#40#);
               Leb128.Append_Unsigned (Type_Contents, 0);
               Append (Type_Contents, 16#00#); -- one result
               Leb128.Append_Unsigned (Type_Contents, Interfaces.Unsigned_32 (Result_Valtype_Index));
            end if;
         end loop;

         Append_Section (Component_Bytes, 7, Type_Contents);
      end if;

      if Model.Export_Count (The_Model) > 0 then
         Leb128.Append_Unsigned (Canon_Contents, Interfaces.Unsigned_32 (Model.Export_Count (The_Model)));

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

               Append (Canon_Contents, 16#00#); -- lift
               Append (Canon_Contents, 16#00#); -- core func sort
               Leb128.Append_Unsigned (Canon_Contents, Interfaces.Unsigned_32 (Alias_Index + Core_Func_Base));
               Leb128.Append_Unsigned (Canon_Contents, 0); -- empty opts
               Leb128.Append_Unsigned (Canon_Contents, Interfaces.Unsigned_32 (Type_Index));
            end;
         end loop;

         Append_Section (Component_Bytes, 8, Canon_Contents);

         declare
            Component_Instance_Contents : Byte_Sequence := Empty_Bytes;
            Instance_Count              : Natural := 0;
            Lifted_Func_Cursor          : Natural := Lifted_Func_Base;
            Instance_Cursor             : Natural := Instance_Base;
         begin
            for Export_Index in 1 .. Model.Export_Count (The_Model) loop
               if Model.Get_Export (The_Model, Export_Index).Returns_Result then
                  Instance_Count := Instance_Count + 1;
               end if;
            end loop;

            if Instance_Count > 0 then
               Leb128.Append_Unsigned (Component_Instance_Contents, Interfaces.Unsigned_32 (Instance_Count));

               for Export_Index in 1 .. Model.Export_Count (The_Model) loop
                  declare
                     The_Export : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
                  begin
                     if The_Export.Returns_Result then
                        Append (Component_Instance_Contents, 16#01#); -- export bundle
                        Leb128.Append_Unsigned (Component_Instance_Contents, 1);
                        Append (Component_Instance_Contents, 16#00#); -- plain name
                        Append_Name (Component_Instance_Contents, "run");
                        Append (Component_Instance_Contents, 16#01#); -- sort: func
                        Leb128.Append_Unsigned
                          (Component_Instance_Contents, Interfaces.Unsigned_32 (Lifted_Func_Cursor));
                     end if;
                     Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
                  end;
               end loop;

               Append_Section (Component_Bytes, 5, Component_Instance_Contents);
            end if;

            Leb128.Append_Unsigned (Export_Contents, Interfaces.Unsigned_32 (Model.Export_Count (The_Model)));

            Lifted_Func_Cursor := Lifted_Func_Base;
            for Export_Index in 1 .. Model.Export_Count (The_Model) loop
               declare
                  The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
                  Export_Name : constant String := Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
               begin
                  Append (Export_Contents, 16#00#); -- nameattributes plain
                  Append_Name (Export_Contents, Export_Name);
                  if The_Export.Returns_Result then
                     Append (Export_Contents, 16#05#); -- sort: instance
                     Leb128.Append_Unsigned (Export_Contents, Interfaces.Unsigned_32 (Instance_Cursor));
                     Instance_Cursor := Instance_Cursor + 1;
                  else
                     Append (Export_Contents, 16#01#); -- sort: func
                     Leb128.Append_Unsigned (Export_Contents, Interfaces.Unsigned_32 (Lifted_Func_Cursor));
                  end if;
                  Append (Export_Contents, 16#00#); -- no externtype
                  Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
               end;
            end loop;

            Append_Section (Component_Bytes, 11, Export_Contents);
         end;
      end if;

      declare
         Identity : constant String :=
           Names.Component_Identity
             (Model.Module_Name (The_Model), Model.Module_Version (The_Model));
         Payload  : Byte_Sequence := Empty_Bytes;
         Contents : Byte_Sequence := Empty_Bytes;
      begin
         --  Custom "component-name" section (same shape wasm-tools emits for
         --  `(component $lovelace:…@…)`): subsection 0 + sized name.
         Append (Payload, 16#00#);
         declare
            Name_Bytes : Byte_Sequence := Empty_Bytes;
         begin
            Append_Name (Name_Bytes, Identity);
            Leb128.Append_Unsigned
              (Payload, Interfaces.Unsigned_32 (Length (Name_Bytes)));
            Append_Bytes (Payload, Name_Bytes);
         end;
         Append_Name (Contents, "component-name");
         Append_Bytes (Contents, Payload);
         Append_Section (Component_Bytes, 0, Contents);
      end;

      for Dependency_Index in 1 .. Model.Dependency_Count (The_Model) loop
         declare
            Dep      : constant Model.Dependency :=
              Model.Get_Dependency (The_Model, Dependency_Index);
            Identity : constant String :=
              Names.Component_Identity
                (Ada.Strings.Unbounded.To_String (Dep.Name),
                 Ada.Strings.Unbounded.To_String (Dep.Version));
            Contents : Byte_Sequence := Empty_Bytes;
         begin
            Append_Name (Contents, "lovelace-dependency");
            for Index in Identity'Range loop
               Append
                 (Contents,
                  Interfaces.Unsigned_8 (Character'Pos (Identity (Index))));
            end loop;
            Append_Section (Component_Bytes, 0, Contents);
         end;
      end loop;

      return Component_Bytes;
   end Encode_Component;

   function Encode_Core_Module (The_Model : Model.Component_Model) return Byte_Sequence is
      Stdout            : constant Boolean := Model.Has_Wasi_Stdout (The_Model);
      Module_Bytes      : Byte_Sequence := Empty_Bytes;
      Type_Contents     : Byte_Sequence := Empty_Bytes;
      Import_Contents   : Byte_Sequence := Empty_Bytes;
      Function_Contents : Byte_Sequence := Empty_Bytes;
      Export_Contents   : Byte_Sequence := Empty_Bytes;
      Code_Contents     : Byte_Sequence := Empty_Bytes;
      Function_Count    : constant Natural := Model.Function_Count (The_Model);
      --  Imported functions occupy the first function indices and the first functypes.
      Function_Base     : constant Natural := (if Stdout then Model.Wasi_Stdout_Import_Count else 0);
      Export_Count      : Natural := 0;

      procedure Append_Import_Func (Field : String; Type_Index : Natural);
      --  Append a function import from module "" named Field.

      procedure Append_Import_Func (Field : String; Type_Index : Natural) is
      begin
         Append_Name (Import_Contents, "");
         Append_Name (Import_Contents, Field);
         Append (Import_Contents, 16#00#);
         Leb128.Append_Unsigned (Import_Contents, Interfaces.Unsigned_32 (Type_Index));
      end Append_Import_Func;
   begin
      Append (Module_Bytes, 16#00#);
      Append (Module_Bytes, 16#61#);
      Append (Module_Bytes, 16#73#);
      Append (Module_Bytes, 16#6D#);
      Append (Module_Bytes, 16#01#);
      Append (Module_Bytes, 16#00#);
      Append (Module_Bytes, 16#00#);
      Append (Module_Bytes, 16#00#);

      --  Functypes: imports first (when present), then one per core function.
      Leb128.Append_Unsigned (Type_Contents, Interfaces.Unsigned_32 (Function_Base + Function_Count));

      if Stdout then
         Append_Raw (Type_Contents, [16#60#, 0, 1, 16#7E#]); -- stream-new: () -> i64
         Append_Raw (Type_Contents, [16#60#, 3, 16#7F#, 16#7F#, 16#7F#, 1, 16#7F#]); -- stream-write
         Append_Raw (Type_Contents, [16#60#, 1, 16#7F#, 0]); -- stream-drop-writable
         Append_Raw (Type_Contents, [16#60#, 2, 16#7F#, 16#7F#, 1, 16#7F#]); -- future-read
         Append_Raw (Type_Contents, [16#60#, 1, 16#7F#, 0]); -- future-drop-readable
         Append_Raw (Type_Contents, [16#60#, 1, 16#7F#, 1, 16#7F#]); -- write-via-stream

         Leb128.Append_Unsigned (Import_Contents, Interfaces.Unsigned_32 (Function_Base + 1));
         Append_Name (Import_Contents, "");
         Append_Name (Import_Contents, "memory");
         Append_Raw (Import_Contents, [16#02#, 16#00#, 1]); -- memory, min 1
         Append_Import_Func ("stream-new", Model.Stream_New_Import_Index);
         Append_Import_Func ("stream-write", Model.Stream_Write_Import_Index);
         Append_Import_Func ("stream-drop-writable", Model.Stream_Drop_Writable_Import_Index);
         Append_Import_Func ("future-read", Model.Future_Read_Import_Index);
         Append_Import_Func ("future-drop-readable", Model.Future_Drop_Readable_Import_Index);
         Append_Import_Func ("write-via-stream", Model.Write_Via_Stream_Import_Index);
      end if;

      for Func_Index in 1 .. Function_Count loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
         begin
            Append (Type_Contents, 16#60#);
            Leb128.Append_Unsigned
              (Type_Contents, Interfaces.Unsigned_32 (Model.Length (The_Function.Parameter_Types)));

            for Parameter_Index in 1 .. Model.Length (The_Function.Parameter_Types) loop
               Append
                 (Type_Contents, Core_Value_Type_Byte (Model.Element (The_Function.Parameter_Types, Parameter_Index)));
            end loop;

            if The_Function.Result_Is_I32 then
               Leb128.Append_Unsigned (Type_Contents, 1);
               Append (Type_Contents, 16#7F#);
            else
               Leb128.Append_Unsigned (Type_Contents, 0);
            end if;
         end;
      end loop;

      Leb128.Append_Unsigned (Function_Contents, Interfaces.Unsigned_32 (Function_Count));

      for Func_Index in 1 .. Function_Count loop
         Leb128.Append_Unsigned (Function_Contents, Interfaces.Unsigned_32 (Function_Base + Func_Index - 1));
      end loop;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         if Model.Get_Function (The_Model, Func_Index).Core_Exported then
            Export_Count := Export_Count + 1;
         end if;
      end loop;

      Leb128.Append_Unsigned (Export_Contents, Interfaces.Unsigned_32 (Export_Count));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Append_Name (Export_Contents, Func_Name);
               Append (Export_Contents, 16#00#); -- func
               Leb128.Append_Unsigned (Export_Contents, Interfaces.Unsigned_32 (Function_Base + Func_Index - 1));
            end if;
         end;
      end loop;

      Leb128.Append_Unsigned (Code_Contents, Interfaces.Unsigned_32 (Model.Function_Count (The_Model)));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Code_Body    : Byte_Sequence := Empty_Bytes;
            Body_Size    : Byte_Sequence := Empty_Bytes;
         begin
            Append_Locals (Code_Body, The_Function);

            for Instr_Index in 1 .. Model.Length (The_Function.Instructions) loop
               Append_Instruction
                 (Code_Body, The_Model, Model.Element (The_Function.Instructions, Instr_Index));
            end loop;

            Append (Code_Body, 16#0B#); -- end
            Leb128.Append_Unsigned (Body_Size, Interfaces.Unsigned_32 (Length (Code_Body)));
            Append_Bytes (Code_Contents, Body_Size);
            Append_Bytes (Code_Contents, Code_Body);
         end;
      end loop;

      if Function_Count > 0 then
         Append_Section (Module_Bytes, 1, Type_Contents);

         if Stdout then
            Append_Section (Module_Bytes, 2, Import_Contents);
         end if;

         Append_Section (Module_Bytes, 3, Function_Contents);
      end if;

      if Export_Count > 0 then
         Append_Section (Module_Bytes, 7, Export_Contents);
      end if;

      if Function_Count > 0 then
         Append_Section (Module_Bytes, 10, Code_Contents);
      end if;

      return Module_Bytes;
   end Encode_Core_Module;

   function Encode_Libc_Module return Byte_Sequence is
      Module_Bytes : Byte_Sequence := Empty_Bytes;
      Contents     : Byte_Sequence;
   begin
      Append_Raw (Module_Bytes, [16#00#, 16#61#, 16#73#, 16#6D#, 16#01#, 16#00#, 16#00#, 16#00#]);

      --  type 0: (i32 i32 i32 i32) -> i32
      Contents := Empty_Bytes;
      Append_Raw (Contents, [1, 16#60#, 4, 16#7F#, 16#7F#, 16#7F#, 16#7F#, 1, 16#7F#]);
      Append_Section (Module_Bytes, 1, Contents);

      --  function 0 : type 0
      Contents := Empty_Bytes;
      Append_Raw (Contents, [1, 0]);
      Append_Section (Module_Bytes, 3, Contents);

      --  memory 0 : min 1 page
      Contents := Empty_Bytes;
      Append_Raw (Contents, [1, 0, 1]);
      Append_Section (Module_Bytes, 5, Contents);

      --  exports: memory, cabi_realloc
      Contents := Empty_Bytes;
      Leb128.Append_Unsigned (Contents, 2);
      Append_Name (Contents, "memory");
      Append_Raw (Contents, [16#02#, 0]);
      Append_Name (Contents, "cabi_realloc");
      Append_Raw (Contents, [16#00#, 0]);
      Append_Section (Module_Bytes, 7, Contents);

      --  code: no locals, local.get 3, end
      Contents := Empty_Bytes;
      Append_Raw (Contents, [1, 4, 0, 16#20#, 3, 16#0B#]);
      Append_Section (Module_Bytes, 10, Contents);

      return Module_Bytes;
   end Encode_Libc_Module;

end Lovelace.Compiler.Backend.Wasm;
