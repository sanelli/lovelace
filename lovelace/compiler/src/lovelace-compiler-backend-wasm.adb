with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Compiler.Backend.Leb128;
with Lovelace.Compiler.Backend.Lowering;
with Lovelace.Compiler.Backend.Model;
with Lovelace.Compiler.Backend.Names;
with Lovelace.Compiler.Backend.Wit;

package body Lovelace.Compiler.Backend.Wasm is

   --  Simple-name renames so gnatcov can instrument call coverage (no dotted callees).
   function Get_Export
     (The_Model : Model.Component_Model; Index : Positive) return Model.Lifted_Export
     renames Model.Get_Export;
   function Get_Function
     (The_Model : Model.Component_Model; Index : Positive) return Model.Core_Function
     renames Model.Get_Function;
   function Export_Count (The_Model : Model.Component_Model) return Natural renames Model.Export_Count;
   function Function_Count (The_Model : Model.Component_Model) return Natural renames Model.Function_Count;

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

   Opcode_Of : constant array (Model.Core_Instruction_Kind) of Interfaces.Unsigned_8 :=
     [Model.Call_Function    => 16#10#,
      Model.Call_Import      => 16#10#,
      Model.I32_Constant     => 16#41#,
      Model.I64_Constant     => 16#42#,
      Model.Local_Get        => 16#20#,
      Model.Local_Set        => 16#21#,
      Model.I32_Add          => 16#6A#,
      Model.I32_Sub          => 16#6B#,
      Model.I32_Mul          => 16#6C#,
      Model.I32_Div_S        => 16#6D#,
      Model.I32_Rem_S        => 16#6F#,
      Model.I32_Eqz          => 16#45#,
      Model.I32_Eq           => 16#46#,
      Model.I32_Ne           => 16#47#,
      Model.I32_Lt_S         => 16#48#,
      Model.I32_Gt_S         => 16#4A#,
      Model.I32_Le_S         => 16#4C#,
      Model.I32_Ge_S         => 16#4E#,
      Model.I32_Store8       => 16#3A#,
      Model.I32_Load8_U      => 16#2D#,
      Model.I32_Wrap_I64     => 16#A7#,
      Model.I64_Extend_I32_U => 16#AD#,
      Model.I64_Shr_U        => 16#88#,
      Model.Unreachable      => 16#00#,
      Model.If_Empty         => 16#04#,
      Model.Else_Op          => 16#05#,
      Model.End_Op           => 16#0B#,
      Model.Loop_Empty       => 16#03#,
      Model.Br               => 16#0C#,
      Model.Br_If            => 16#0D#];
   --  Leading opcode byte per instruction kind; immediates are appended separately.

   procedure Append_Operand
     (Sequence : in out Byte_Sequence; The_Model : Model.Component_Model; Item : Model.Core_Instruction);
   --  LEB128 immediate for call, const, local and branch instructions (after the opcode byte).

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

   type Component_Bases is record
      Type_Base           : Natural;
      Core_Func_Base      : Natural;
      Lifted_Func_Base    : Natural;
      Instance_Base       : Natural;
      Guest_Core_Instance : Natural;
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
     (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model; Guest_Core_Instance : Natural);
   --  Alias section for every Core_Exported guest function (omitted when there are none).

   procedure Append_Canon_Lifts
     (Component_Bytes : in out Byte_Sequence;
      The_Model       : Model.Component_Model;
      Layout          : Export_Type_Layout;
      Core_Func_Base  : Natural);
   --  Canon lift section, one lift per lifted export.

   procedure Append_Component_Header (Component_Bytes : in out Byte_Sequence);
   --  Component preamble: magic, version and layer.

   procedure Append_Component_Name_Section (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model);
   --  Custom "component-name" section.

   procedure Append_Core_Function_Type (Contents : in out Byte_Sequence; The_Function : Model.Core_Function);
   --  One core functype entry for The_Function.

   procedure Append_Core_Instances
     (Component_Bytes : in out Byte_Sequence; Core_Module : Byte_Sequence; Stdout : Boolean);
   --  Core module(s), their instances and (with stdout) the prelude of types, imports and builtins.

   procedure Append_Dependency_Sections (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model);
   --  One "lovelace-dependency" custom section per dependency.

   procedure Append_Export_Section
     (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model; Bases : Component_Bases);
   --  Component export section for lifted exports.

   procedure Append_Import_Func (Contents : in out Byte_Sequence; Field : String; Type_Index : Natural);
   --  Append a core function import from module "" named Field.

   procedure Append_Lifted_Exports
     (Component_Bytes : in out Byte_Sequence;
      The_Model       : Model.Component_Model;
      Layout          : Export_Type_Layout;
      Bases           : Component_Bases);
   --  Canon lifts, result instances and exports (omitted when there are no exports).

   procedure Append_Result_Instances
     (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model; Lifted_Func_Base : Natural);
   --  Instance bundles ("run") for exports that return a result.

   procedure Append_Stdout_Functypes (Type_Contents : in out Byte_Sequence);
   --  Core functypes of the six stdout imports.

   procedure Append_Stdout_Guest_Instances (Component_Bytes : in out Byte_Sequence; Core_Module : Byte_Sequence);
   --  Guest core module plus the import bundle and guest core instances.

   procedure Append_Stdout_Imports (Component_Bytes : in out Byte_Sequence);
   --  Stdout prelude: wasi:cli/types and wasi:cli/stdout types and imports.

   procedure Append_Stdout_Libc (Component_Bytes : in out Byte_Sequence);
   --  Stdout prelude: libc core module, its instance and the memory alias.

   procedure Append_Stdout_Streams (Component_Bytes : in out Byte_Sequence);
   --  Stdout prelude: stream/future types and canon builtins.

   procedure Append_Type_Section
     (Component_Bytes : in out Byte_Sequence; Layout : Export_Type_Layout; Type_Base : Natural);
   --  Component type section for the allocated export functypes (omitted when none).

   function Assign_Export_Types (The_Model : Model.Component_Model; Type_Base : Natural) return Export_Type_Layout;
   --  Allocate unit / result type indices for the lifted exports, starting at Type_Base.

   function Component_Bases_For (Stdout : Boolean) return Component_Bases;
   --  Index bases with or without the stdout prelude.

   function Core_Code_Contents (The_Model : Model.Component_Model) return Byte_Sequence;
   --  Core code section contents.

   function Core_Export_Contents (The_Model : Model.Component_Model; Function_Base : Natural) return Byte_Sequence;
   --  Core export section contents.

   function Core_Export_Count (The_Model : Model.Component_Model) return Natural;
   --  Number of Core_Exported functions.

   function Core_Function_Contents (Function_Count : Natural; Function_Base : Natural) return Byte_Sequence;
   --  Core function section contents (type indices).

   function Core_Import_Contents (Function_Base : Natural) return Byte_Sequence;
   --  Core import section contents for the stdout imports.

   function Core_Type_Contents
     (The_Model : Model.Component_Model; Stdout : Boolean; Function_Base : Natural) return Byte_Sequence;
   --  Core type section contents: stdout import functypes then one per function.

   function Result_Export_Count (The_Model : Model.Component_Model) return Natural;
   --  Number of lifted exports that return a result.

   procedure Append_Alias_Section
     (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model; Guest_Core_Instance : Natural)
   is
      Alias_Count : constant Natural := Core_Export_Count (The_Model);
      Contents    : Byte_Sequence := Empty_Bytes;
   begin
      if Alias_Count > 0 then
         Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Alias_Count));

         for Func_Index in 1 .. Model.Function_Count (The_Model) loop
            declare
               The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
            begin
               if The_Function.Core_Exported then
                  Append_Raw (Contents, [16#00#, 16#00#, 16#01#]); -- core sort, func, alias core export
                  Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Guest_Core_Instance));
                  Append_Name (Contents, Ada.Strings.Unbounded.To_String (The_Function.Name));
               end if;
            end;
         end loop;

         Append_Section (Component_Bytes, 6, Contents);
      end if;
   end Append_Alias_Section;

   procedure Append_Canon_Lifts
     (Component_Bytes : in out Byte_Sequence;
      The_Model       : Model.Component_Model;
      Layout          : Export_Type_Layout;
      Core_Func_Base  : Natural)
   is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Model.Export_Count (The_Model)));

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
            Alias_Index : constant Natural := Core_Func_Alias_Index (The_Model, The_Export.Core_Function_Index);
            Type_Index  : constant Natural :=
              Natural (if The_Export.Returns_Result then Layout.Result_Functype_Index else Layout.Unit_Type_Index);
         begin
            Append_Raw (Contents, [16#00#, 16#00#]); -- lift, core func sort
            Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Alias_Index + Core_Func_Base));
            Leb128.Append_Unsigned (Contents, 0); -- empty opts
            Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Type_Index));
         end;
      end loop;

      Append_Section (Component_Bytes, 8, Contents);
   end Append_Canon_Lifts;

   procedure Append_Component_Header (Component_Bytes : in out Byte_Sequence) is
   begin
      Append_Raw (Component_Bytes, [16#00#, 16#61#, 16#73#, 16#6D#, 16#0D#, 16#00#, 16#01#, 16#00#]);
   end Append_Component_Header;

   procedure Append_Component_Name_Section (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model)
   is
      Identity   : constant String :=
        Names.Component_Identity (Model.Module_Name (The_Model), Model.Module_Version (The_Model));
      Payload    : Byte_Sequence := Empty_Bytes;
      Contents   : Byte_Sequence := Empty_Bytes;
      Name_Bytes : Byte_Sequence := Empty_Bytes;
   begin
      --  Custom "component-name" section (same shape wasm-tools emits for
      --  `(component $lovelace:name@version)`): subsection 0 + sized name.
      Append (Payload, 16#00#);
      Append_Name (Name_Bytes, Identity);
      Leb128.Append_Unsigned (Payload, Interfaces.Unsigned_32 (Length (Name_Bytes)));
      Append_Bytes (Payload, Name_Bytes);
      Append_Name (Contents, "component-name");
      Append_Bytes (Contents, Payload);
      Append_Section (Component_Bytes, 0, Contents);
   end Append_Component_Name_Section;

   procedure Append_Core_Function_Type (Contents : in out Byte_Sequence; The_Function : Model.Core_Function) is
   begin
      Append (Contents, 16#60#);
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Model.Length (The_Function.Parameter_Types)));

      for Parameter_Index in 1 .. Model.Length (The_Function.Parameter_Types) loop
         Append (Contents, Core_Value_Type_Byte (Model.Element (The_Function.Parameter_Types, Parameter_Index)));
      end loop;

      if The_Function.Result_Is_I32 then
         Leb128.Append_Unsigned (Contents, 1);
         Append (Contents, 16#7F#);
      else
         Leb128.Append_Unsigned (Contents, 0);
      end if;
   end Append_Core_Function_Type;

   procedure Append_Core_Instances
     (Component_Bytes : in out Byte_Sequence; Core_Module : Byte_Sequence; Stdout : Boolean)
   is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      if Stdout then
         Append_Stdout_Imports (Component_Bytes);
         Append_Stdout_Libc (Component_Bytes);
         Append_Stdout_Streams (Component_Bytes);
         Append_Stdout_Guest_Instances (Component_Bytes, Core_Module);
      else
         Append_Section (Component_Bytes, 1, Core_Module);

         --  core instance: instantiate module 0 with no args
         Append_Raw (Contents, [1, 16#00#, 0, 0]);
         Append_Section (Component_Bytes, 2, Contents);
      end if;
   end Append_Core_Instances;

   procedure Append_Dependency_Sections (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model) is
   begin
      for Dependency_Index in 1 .. Model.Dependency_Count (The_Model) loop
         declare
            Dep      : constant Model.Dependency := Model.Get_Dependency (The_Model, Dependency_Index);
            Identity : constant String :=
              Names.Component_Identity
                (Ada.Strings.Unbounded.To_String (Dep.Name), Ada.Strings.Unbounded.To_String (Dep.Version));
            Contents : Byte_Sequence := Empty_Bytes;
         begin
            Append_Name (Contents, "lovelace-dependency");
            for Index in Identity'Range loop
               Append (Contents, Interfaces.Unsigned_8 (Character'Pos (Identity (Index))));
            end loop;
            Append_Section (Component_Bytes, 0, Contents);
         end;
      end loop;
   end Append_Dependency_Sections;

   procedure Append_Export_Section
     (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model; Bases : Component_Bases)
   is
      Contents           : Byte_Sequence := Empty_Bytes;
      Lifted_Func_Cursor : Natural := Bases.Lifted_Func_Base;
      Instance_Cursor    : Natural := Bases.Instance_Base;
   begin
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Model.Export_Count (The_Model)));

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
         begin
            Append (Contents, 16#00#); -- nameattributes plain
            Append_Name (Contents, Ada.Strings.Unbounded.To_String (The_Export.Export_Name));

            if The_Export.Returns_Result then
               Append (Contents, 16#05#); -- sort: instance
               Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Instance_Cursor));
               Instance_Cursor := Instance_Cursor + 1;
            else
               Append (Contents, 16#01#); -- sort: func
               Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Lifted_Func_Cursor));
            end if;

            Append (Contents, 16#00#); -- no externtype
            Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
         end;
      end loop;

      Append_Section (Component_Bytes, 11, Contents);
   end Append_Export_Section;

   procedure Append_Import_Func (Contents : in out Byte_Sequence; Field : String; Type_Index : Natural) is
   begin
      Append_Name (Contents, "");
      Append_Name (Contents, Field);
      Append (Contents, 16#00#);
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Type_Index));
   end Append_Import_Func;

   procedure Append_Instruction
     (Sequence : in out Byte_Sequence; The_Model : Model.Component_Model; Item : Model.Core_Instruction) is
   begin
      Append (Sequence, Opcode_Of (Item.Kind));

      case Item.Kind is
         when Model.Call_Function
            | Model.Call_Import
            | Model.I32_Constant
            | Model.I64_Constant
            | Model.Local_Get
            | Model.Local_Set
            | Model.Br
            | Model.Br_If                          =>
            Append_Operand (Sequence, The_Model, Item);

         when Model.I32_Store8 | Model.I32_Load8_U =>
            Append_Raw (Sequence, [0, 0]); -- align 0, offset 0

         when Model.If_Empty | Model.Loop_Empty    =>
            Append (Sequence, 16#40#); -- empty blocktype

         when others                               =>
            null;
      end case;
   end Append_Instruction;

   procedure Append_Lifted_Exports
     (Component_Bytes : in out Byte_Sequence;
      The_Model       : Model.Component_Model;
      Layout          : Export_Type_Layout;
      Bases           : Component_Bases) is
   begin
      if Model.Export_Count (The_Model) > 0 then
         Append_Canon_Lifts (Component_Bytes, The_Model, Layout, Bases.Core_Func_Base);
         Append_Result_Instances (Component_Bytes, The_Model, Bases.Lifted_Func_Base);
         Append_Export_Section (Component_Bytes, The_Model, Bases);
      end if;
   end Append_Lifted_Exports;

   procedure Append_Locals (Sequence : in out Byte_Sequence; The_Function : Model.Core_Function) is
      use type Model.Core_Value_Type;

      Total       : constant Natural := Model.Length (The_Function.Local_Types);
      Group_Size  : Natural := 0;
      Group_Type  : Model.Core_Value_Type := Model.I32;
      Groups      : Byte_Sequence := Empty_Bytes;
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

   procedure Append_Operand
     (Sequence : in out Byte_Sequence; The_Model : Model.Component_Model; Item : Model.Core_Instruction)
   is
      Function_Base : constant Natural :=
        (if Model.Has_Wasi_Stdout (The_Model) then Model.Wasi_Stdout_Import_Count else 0);
   begin
      case Item.Kind is
         when Model.Call_Function               =>
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Function_Base + Item.Target_Index - 1));

         when Model.Call_Import                 =>
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Import_Index));

         when Model.I32_Constant                =>
            Leb128.Append_Signed (Sequence, Item.Value);

         when Model.I64_Constant                =>
            Append_Signed_64 (Sequence, Item.Value_I64);

         when Model.Local_Get | Model.Local_Set =>
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Local_Index));

         when Model.Br | Model.Br_If            =>
            Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Item.Label_Depth));

         when others                            =>
            null;
      end case;
   end Append_Operand;

   procedure Append_Raw (Sequence : in out Byte_Sequence; Bytes : Byte_Array) is
   begin
      for Byte of Bytes loop
         Append (Sequence, Byte);
      end loop;
   end Append_Raw;

   procedure Append_Result_Instances
     (Component_Bytes : in out Byte_Sequence; The_Model : Model.Component_Model; Lifted_Func_Base : Natural)
   is
      Instance_Count     : constant Natural := Result_Export_Count (The_Model);
      Contents           : Byte_Sequence := Empty_Bytes;
      Lifted_Func_Cursor : Natural := Lifted_Func_Base;
   begin
      if Instance_Count > 0 then
         Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Instance_Count));

         for Export_Index in 1 .. Export_Count (The_Model) loop
            declare
               The_Export : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
            begin
               if The_Export.Returns_Result then
                  Append_Raw (Contents, [16#01#, 1, 16#00#]); -- export bundle, one export, plain name
                  Append_Name (Contents, "run");
                  Append (Contents, 16#01#); -- sort: func
                  Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Lifted_Func_Cursor));
               end if;
            end;

            Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
         end loop;

         Append_Section (Component_Bytes, 5, Contents);
      end if;
   end Append_Result_Instances;

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

   procedure Append_Stdout_Functypes (Type_Contents : in out Byte_Sequence) is
   begin
      Append_Raw (Type_Contents, [16#60#, 0, 1, 16#7E#]); -- stream-new: () -> i64
      Append_Raw (Type_Contents, [16#60#, 3, 16#7F#, 16#7F#, 16#7F#, 1, 16#7F#]); -- stream-write
      Append_Raw (Type_Contents, [16#60#, 1, 16#7F#, 0]); -- stream-drop-writable
      Append_Raw (Type_Contents, [16#60#, 2, 16#7F#, 16#7F#, 1, 16#7F#]); -- future-read
      Append_Raw (Type_Contents, [16#60#, 1, 16#7F#, 0]); -- future-drop-readable
      Append_Raw (Type_Contents, [16#60#, 1, 16#7F#, 1, 16#7F#]); -- write-via-stream
   end Append_Stdout_Functypes;

   procedure Append_Stdout_Guest_Instances (Component_Bytes : in out Byte_Sequence; Core_Module : Byte_Sequence) is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      --  core module 1 (guest).
      Append_Section (Component_Bytes, 1, Core_Module);

      --  core instance 1: bundle of core exports; core instance 2: guest.
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
   end Append_Stdout_Guest_Instances;

   procedure Append_Stdout_Imports (Component_Bytes : in out Byte_Sequence) is
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
   end Append_Stdout_Imports;

   procedure Append_Stdout_Libc (Component_Bytes : in out Byte_Sequence) is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      --  core module 0 (libc) and its instance (core instance 0).
      Append_Section (Component_Bytes, 1, Encode_Libc_Module);

      Append_Raw (Contents, [1, 16#00#, 0, 0]);
      Append_Section (Component_Bytes, 2, Contents);

      --  core memory 0 from libc; component func 0 = stdout write-via-stream.
      Contents := Empty_Bytes;
      Append_Raw (Contents, [2, 16#00#, 16#02#, 16#01#, 0]);
      Append_Name (Contents, "memory");
      Append_Raw (Contents, [16#01#, 16#00#, 1]);
      Append_Name (Contents, "write-via-stream");
      Append_Section (Component_Bytes, 6, Contents);
   end Append_Stdout_Libc;

   procedure Append_Stdout_Streams (Component_Bytes : in out Byte_Sequence) is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      --  types 3 .. 5: stream<u8>, result<_, error-code>, future<result-error>.
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
   end Append_Stdout_Streams;

   procedure Append_Type_Section
     (Component_Bytes : in out Byte_Sequence; Layout : Export_Type_Layout; Type_Base : Natural)
   is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      if Layout.Next_Type_Index > Type_Base then
         Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Layout.Next_Type_Index - Type_Base));

         for Type_Index in Type_Base .. Layout.Next_Type_Index - 1 loop
            if Layout.Unit_Type_Index = Integer (Type_Index) then
               --  func ()
               Append (Contents, 16#40#);
               Leb128.Append_Unsigned (Contents, 0); -- empty params
               Append (Contents, 16#01#); -- empty resultlist
               Append (Contents, 16#00#);
            elsif Layout.Result_Valtype_Index = Integer (Type_Index) then
               --  (result) with no ok/err payloads
               Append_Raw (Contents, [16#6A#, 16#00#, 16#00#]);
            elsif Layout.Result_Functype_Index = Integer (Type_Index) then
               --  func () -> <Result_Valtype_Index>
               Append (Contents, 16#40#);
               Leb128.Append_Unsigned (Contents, 0);
               Append (Contents, 16#00#); -- one result
               Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Layout.Result_Valtype_Index));
            else
               raise Program_Error with "unassigned export type index in Append_Type_Section";
            end if;
         end loop;

         Append_Section (Component_Bytes, 7, Contents);
      end if;
   end Append_Type_Section;

   function Assign_Export_Types (The_Model : Model.Component_Model; Type_Base : Natural) return Export_Type_Layout is
      Layout : Export_Type_Layout := (Next_Type_Index => Type_Base, others => <>);
   begin
      for Export_Index in 1 .. Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               --  LIR Validate allows at most one entrypoint (one result functype).
               if Layout.Result_Functype_Index >= 0 then
                  raise Program_Error with "duplicate result functype in Assign_Export_Types";
               end if;
               --  Bare (result) is a defvaltype; functype may only reference it by typeidx.
               Layout.Result_Valtype_Index := Layout.Next_Type_Index;
               Layout.Result_Functype_Index := Layout.Next_Type_Index + 1;
               Layout.Next_Type_Index := Layout.Next_Type_Index + 2;
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
         --  Component type indices 0 .. 5 are the stdout prelude: types instance type,
         --  error-code alias, stdout instance type, stream-u8, result-error, future-result.
         --  Core funcs before guest exports: stream.new/write/drop-writable,
         --  future.read/drop-readable, and the lowered write-via-stream.
         return
           (Type_Base => 6, Core_Func_Base => 6, Lifted_Func_Base => 1, Instance_Base => 2, Guest_Core_Instance => 2);
      end if;

      return (others => 0);
   end Component_Bases_For;

   function Core_Code_Contents (The_Model : Model.Component_Model) return Byte_Sequence is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Model.Function_Count (The_Model)));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
            Code_Body    : Byte_Sequence := Empty_Bytes;
            Body_Size    : Byte_Sequence := Empty_Bytes;
         begin
            Append_Locals (Code_Body, The_Function);

            for Instr_Index in 1 .. Model.Length (The_Function.Instructions) loop
               Append_Instruction (Code_Body, The_Model, Model.Element (The_Function.Instructions, Instr_Index));
            end loop;

            Append (Code_Body, 16#0B#); -- end
            Leb128.Append_Unsigned (Body_Size, Interfaces.Unsigned_32 (Length (Code_Body)));
            Append_Bytes (Contents, Body_Size);
            Append_Bytes (Contents, Code_Body);
         end;
      end loop;

      return Contents;
   end Core_Code_Contents;

   function Core_Export_Contents (The_Model : Model.Component_Model; Function_Base : Natural) return Byte_Sequence is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Core_Export_Count (The_Model)));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
         begin
            if The_Function.Core_Exported then
               Append_Name (Contents, Ada.Strings.Unbounded.To_String (The_Function.Name));
               Append (Contents, 16#00#); -- func
               Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Function_Base + Func_Index - 1));
            end if;
         end;
      end loop;

      return Contents;
   end Core_Export_Contents;

   function Core_Export_Count (The_Model : Model.Component_Model) return Natural is
      Total : Natural := 0;
   begin
      for Func_Index in 1 .. Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Get_Function (The_Model, Func_Index);
         begin
            if The_Function.Core_Exported then
               Total := Total + 1;
            end if;
         end;
      end loop;

      return Total;
   end Core_Export_Count;

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

   function Core_Function_Contents (Function_Count : Natural; Function_Base : Natural) return Byte_Sequence is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Function_Count));

      for Func_Index in 1 .. Function_Count loop
         Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Function_Base + Func_Index - 1));
      end loop;

      return Contents;
   end Core_Function_Contents;

   function Core_Import_Contents (Function_Base : Natural) return Byte_Sequence is
      Contents : Byte_Sequence := Empty_Bytes;
   begin
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Function_Base + 1));
      Append_Name (Contents, "");
      Append_Name (Contents, "memory");
      Append_Raw (Contents, [16#02#, 16#00#, 1]); -- memory, min 1
      Append_Import_Func (Contents, "stream-new", Model.Stream_New_Import_Index);
      Append_Import_Func (Contents, "stream-write", Model.Stream_Write_Import_Index);
      Append_Import_Func (Contents, "stream-drop-writable", Model.Stream_Drop_Writable_Import_Index);
      Append_Import_Func (Contents, "future-read", Model.Future_Read_Import_Index);
      Append_Import_Func (Contents, "future-drop-readable", Model.Future_Drop_Readable_Import_Index);
      Append_Import_Func (Contents, "write-via-stream", Model.Write_Via_Stream_Import_Index);
      return Contents;
   end Core_Import_Contents;

   function Core_Type_Contents
     (The_Model : Model.Component_Model; Stdout : Boolean; Function_Base : Natural) return Byte_Sequence
   is
      Function_Count : constant Natural := Model.Function_Count (The_Model);
      Contents       : Byte_Sequence := Empty_Bytes;
   begin
      --  Functypes: imports first (when present), then one per core function.
      Leb128.Append_Unsigned (Contents, Interfaces.Unsigned_32 (Function_Base + Function_Count));

      if Stdout then
         Append_Stdout_Functypes (Contents);
      end if;

      for Func_Index in 1 .. Function_Count loop
         Append_Core_Function_Type (Contents, Get_Function (The_Model, Func_Index));
      end loop;

      return Contents;
   end Core_Type_Contents;

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
      Component_Bytes : Byte_Sequence := Empty_Bytes;
      Stdout          : constant Boolean := Model.Has_Wasi_Stdout (The_Model);
      Bases           : constant Component_Bases := Component_Bases_For (Stdout);
      Layout          : constant Export_Type_Layout := Assign_Export_Types (The_Model, Bases.Type_Base);
   begin
      Append_Component_Header (Component_Bytes);
      Append_Core_Instances (Component_Bytes, Encode_Core_Module (The_Model), Stdout);
      Append_Alias_Section (Component_Bytes, The_Model, Bases.Guest_Core_Instance);
      Append_Type_Section (Component_Bytes, Layout, Bases.Type_Base);
      Append_Lifted_Exports (Component_Bytes, The_Model, Layout, Bases);
      Append_Component_Name_Section (Component_Bytes, The_Model);
      Append_Dependency_Sections (Component_Bytes, The_Model);
      return Component_Bytes;
   end Encode_Component;

   function Encode_Core_Module (The_Model : Model.Component_Model) return Byte_Sequence is
      Stdout         : constant Boolean := Model.Has_Wasi_Stdout (The_Model);
      Module_Bytes   : Byte_Sequence := Empty_Bytes;
      Function_Count : constant Natural := Model.Function_Count (The_Model);
      --  Imported functions occupy the first function indices and the first functypes.
      Function_Base  : constant Natural := (if Stdout then Model.Wasi_Stdout_Import_Count else 0);
   begin
      Append_Raw (Module_Bytes, [16#00#, 16#61#, 16#73#, 16#6D#, 16#01#, 16#00#, 16#00#, 16#00#]);

      if Function_Count > 0 then
         Append_Section (Module_Bytes, 1, Core_Type_Contents (The_Model, Stdout, Function_Base));

         if Stdout then
            Append_Section (Module_Bytes, 2, Core_Import_Contents (Function_Base));
         end if;

         Append_Section (Module_Bytes, 3, Core_Function_Contents (Function_Count, Function_Base));
      end if;

      if Core_Export_Count (The_Model) > 0 then
         Append_Section (Module_Bytes, 7, Core_Export_Contents (The_Model, Function_Base));
      end if;

      if Function_Count > 0 then
         Append_Section (Module_Bytes, 10, Core_Code_Contents (The_Model));
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

   function Result_Export_Count (The_Model : Model.Component_Model) return Natural is
      Total : Natural := 0;
   begin
      for Export_Index in 1 .. Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               Total := Total + 1;
            end if;
         end;
      end loop;

      return Total;
   end Result_Export_Count;

end Lovelace.Compiler.Backend.Wasm;
