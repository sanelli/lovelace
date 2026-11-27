with Ada.Strings.Unbounded;
with Ada.Unchecked_Conversion;
with GNAT.OS_Lib;

with Lovelace.Common.Source;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Binary is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Ada.Strings.Unbounded.Unbounded_String;
   use type Opcodes.Opcode;
   use type Types.Value_Type;

   package Source renames Lovelace.Common.Source;

   function Integer_32_Bits is new
     Ada.Unchecked_Conversion (Source => Interfaces.Integer_32, Target => Interfaces.Unsigned_32);
   function Bits_To_Integer_32 is new
     Ada.Unchecked_Conversion (Source => Interfaces.Unsigned_32, Target => Interfaces.Integer_32);

   Magic_0 : constant Interfaces.Unsigned_8 := 16#4C#;
   Magic_1 : constant Interfaces.Unsigned_8 := 16#49#;
   Magic_2 : constant Interfaces.Unsigned_8 := 16#52#;
   Magic_3 : constant Interfaces.Unsigned_8 := 16#00#;

   Format_Major : constant Interfaces.Unsigned_16 := 1;
   Format_Minor : constant Interfaces.Unsigned_16 := 0;

   Origin_Absent  : constant Interfaces.Unsigned_8 := 0;
   Origin_Present : constant Interfaces.Unsigned_8 := 1;

   procedure Append_Byte (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_8);
   procedure Append_Instruction (Buffer : in out Byte_Sequence; Item : Instructions.Instruction);
   procedure Append_Module_Origin (Buffer : in out Byte_Sequence; The_Module : Modules.Module);
   procedure Append_Position (Buffer : in out Byte_Sequence; The_Position : Source.Source_Position);
   procedure Append_Signature_Index (Buffer : in out Byte_Sequence; The_Signature : Subroutines.Signature);
   --  Preamble index row: name, return type, parameters (no offset).
   procedure Append_Span (Buffer : in out Byte_Sequence; The_Span : Source.Source_Span);
   procedure Append_String (Buffer : in out Byte_Sequence; Text : String);
   procedure Append_Subroutine (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine);
   procedure Append_Subroutine_From_Dependency (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine);
   procedure Append_Subroutine_Native (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine);
   procedure Append_Subroutine_Origin (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine);
   procedure Append_U16 (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_16);
   procedure Append_U32 (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_32);
   function Read_Signature_Index
     (Bytes         : Byte_Sequence;
      Cursor        : in out Natural;
      The_Signature : out Subroutines.Signature;
      Code          : out Errors.Error_Code) return Boolean;
   --  Read preamble signature fields (name / result / params).
   function Signatures_Match (Left : Subroutines.Signature; Right : Subroutines.Signature) return Boolean;

   type Magic_Array is array (1 .. 4) of Interfaces.Unsigned_8;

   Magic_Bytes : constant Magic_Array := [Magic_0, Magic_1, Magic_2, Magic_3];

   package Offset_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Interfaces.Unsigned_32);

   package Signature_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Subroutines.Signature, "=" => Signatures_Match);

   --  Preamble index rows: signatures and body offsets, in file order.
   type Preamble_Table is record
      Signatures : Signature_Vectors.Vector;
      Offsets    : Offset_Vectors.Vector;
   end record;
   function Parse_Module_Origin
     (Bytes : Byte_Sequence; Cursor : in out Natural; The_Module : in out Modules.Module; Code : out Errors.Error_Code)
      return Boolean;
   function Parse_Position
     (Bytes : Byte_Sequence; Cursor : in out Natural; The_Position : out Source.Source_Position) return Boolean;
   function Parse_Span
     (Bytes : Byte_Sequence; Cursor : in out Natural; The_Span : out Source.Source_Span) return Boolean;
   function Parse_Subroutine
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean;
   function Parse_Subroutine_From_Dependency
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean;
   function Parse_Subroutine_Native
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean;
   function Parse_Subroutine_Origin
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean;
   procedure Patch_U32 (Buffer : in out Byte_Sequence; At_Index : Positive; Value : Interfaces.Unsigned_32);
   function Position_Fields_Ok
     (Byte_Index_Value : Interfaces.Unsigned_32;
      Line_Value       : Interfaces.Unsigned_32;
      Column_Value     : Interfaces.Unsigned_32) return Boolean;
   --  True when all three fields are non-zero and fit in Positive.
   function Read_Byte
     (Bytes : Byte_Sequence; Cursor : in out Natural; Value : out Interfaces.Unsigned_8) return Boolean;
   function Read_String
     (Bytes : Byte_Sequence; Cursor : in out Natural; Text : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   function Read_U16
     (Bytes : Byte_Sequence; Cursor : in out Natural; Value : out Interfaces.Unsigned_16) return Boolean;
   function Read_U32
     (Bytes : Byte_Sequence; Cursor : in out Natural; Value : out Interfaces.Unsigned_32) return Boolean;
   function Remaining (Bytes : Byte_Sequence; Cursor : Natural) return Natural;
   procedure Append_Locals (The_Subroutine : in out Subroutines.Subroutine; Locals : Types.Parameter_Sequence);
   function Build_Instruction
     (Operation : Opcodes.Opcode; Operand : Interfaces.Unsigned_32) return Instructions.Instruction;
   function Parse_Bodies
     (Bytes      : Byte_Sequence;
      Cursor     : in out Natural;
      Table      : Preamble_Table;
      The_Module : in out Modules.Module;
      Code       : out Errors.Error_Code) return Boolean;
   function Parse_Dependencies
     (Bytes            : Byte_Sequence;
      Cursor           : in out Natural;
      The_Module       : in out Modules.Module;
      Dependency_Total : Interfaces.Unsigned_32;
      Code             : out Errors.Error_Code) return Boolean;
   function Parse_Header
     (Bytes            : Byte_Sequence;
      Cursor           : in out Natural;
      The_Module       : in out Modules.Module;
      Dependency_Total : out Interfaces.Unsigned_32;
      Code             : out Errors.Error_Code) return Boolean;
   function Parse_Instruction
     (Bytes : Byte_Sequence; Cursor : in out Natural; Item : out Instructions.Instruction; Code : out Errors.Error_Code)
      return Boolean;
   function Parse_Instruction_Stream
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean;
   function Parse_Locals
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Locals : in out Types.Parameter_Sequence;
      Code   : out Errors.Error_Code) return Boolean;
   function Parse_Magic_Version
     (Bytes : Byte_Sequence; Cursor : in out Natural; Code : out Errors.Error_Code) return Boolean;
   function Parse_Parameters
     (Bytes      : Byte_Sequence;
      Cursor     : in out Natural;
      Parameters : in out Types.Parameter_Sequence;
      Code       : out Errors.Error_Code) return Boolean;
   function Parse_Preamble
     (Bytes : Byte_Sequence; Cursor : in out Natural; Table : in out Preamble_Table; Code : out Errors.Error_Code)
      return Boolean;
   function Parse_Signature
     (Bytes       : Byte_Sequence;
      Cursor      : in out Natural;
      Name_Text   : out Ada.Strings.Unbounded.Unbounded_String;
      Return_Kind : out Types.Value_Type;
      Parameters  : out Types.Parameter_Sequence;
      Code        : out Errors.Error_Code) return Boolean;
   function Read_Typed_Name
     (Bytes      : Byte_Sequence;
      Cursor     : in out Natural;
      Name_Text  : out Ada.Strings.Unbounded.Unbounded_String;
      Value_Kind : out Types.Value_Type;
      Code       : out Errors.Error_Code) return Boolean;

   procedure Append_Byte (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_8) is
   begin
      Buffer.Items.Append (Value);
   end Append_Byte;

   procedure Append_Instruction (Buffer : in out Byte_Sequence; Item : Instructions.Instruction) is
   begin
      Append_U16 (Buffer, Opcodes.To_Word (Item.Operation));
      case Item.Operation is
         when Opcodes.No_Operation                  =>
            null;

         when Opcodes.Constant_I32                  =>
            Append_U32 (Buffer, Integer_32_Bits (Item.Immediate_I32));

         when Opcodes.Call                          =>
            Append_U32 (Buffer, Item.Target_Index);

         when Opcodes.Local_Get | Opcodes.Local_Set =>
            Append_U32 (Buffer, Item.Local_Index);
      end case;
   end Append_Instruction;

   procedure Append_Locals (The_Subroutine : in out Subroutines.Subroutine; Locals : Types.Parameter_Sequence) is
   begin
      for Local_Index in 1 .. Types.Length (Locals) loop
         declare
            The_Local : constant Types.Parameter := Types.Element (Locals, Local_Index);
         begin
            Subroutines.Append_Local
              (The_Subroutine, Ada.Strings.Unbounded.To_String (The_Local.Name), The_Local.The_Type);
         end;
      end loop;
   end Append_Locals;

   procedure Append_Module_Origin (Buffer : in out Byte_Sequence; The_Module : Modules.Module) is
      The_Origin : constant Modules.Origin_Option := Modules.Origin (The_Module);
   begin
      case The_Origin.Present is
         when False =>
            Append_Byte (Buffer, Origin_Absent);

         when True  =>
            Append_Byte (Buffer, Origin_Present);
            Append_String (Buffer, Source.To_Utf_8 (The_Origin.Value.Filename));
            Append_Span (Buffer, The_Origin.Value.Name_Span);
            Append_Span (Buffer, The_Origin.Value.Span);
      end case;
   end Append_Module_Origin;

   procedure Append_Position (Buffer : in out Byte_Sequence; The_Position : Source.Source_Position) is
   begin
      Append_U32 (Buffer, Interfaces.Unsigned_32 (The_Position.Byte_Index));
      Append_U32 (Buffer, Interfaces.Unsigned_32 (The_Position.Line));
      Append_U32 (Buffer, Interfaces.Unsigned_32 (The_Position.Column));
   end Append_Position;

   procedure Append_Signature_Index (Buffer : in out Byte_Sequence; The_Signature : Subroutines.Signature) is
      Params : constant Types.Parameter_Sequence := The_Signature.Parameters;
   begin
      Append_String (Buffer, Ada.Strings.Unbounded.To_String (The_Signature.Name));
      Append_Byte (Buffer, Types.To_Code (The_Signature.Return_Type));
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Types.Length (Params)));
      for Parameter_Index in 1 .. Types.Length (Params) loop
         declare
            The_Parameter : constant Types.Parameter := Types.Element (Params, Parameter_Index);
         begin
            Append_String (Buffer, Ada.Strings.Unbounded.To_String (The_Parameter.Name));
            Append_Byte (Buffer, Types.To_Code (The_Parameter.The_Type));
         end;
      end loop;
   end Append_Signature_Index;

   procedure Append_Span (Buffer : in out Byte_Sequence; The_Span : Source.Source_Span) is
   begin
      Append_Position (Buffer, The_Span.First);
      Append_Position (Buffer, The_Span.Last);
   end Append_Span;

   procedure Append_String (Buffer : in out Byte_Sequence; Text : String) is
   begin
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Text'Length));
      for Index in Text'Range loop
         Append_Byte (Buffer, Interfaces.Unsigned_8 (Character'Pos (Text (Index))));
      end loop;
   end Append_String;

   procedure Append_Subroutine (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine) is
      The_Signature : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
      Locals        : constant Types.Parameter_Sequence := Subroutines.Get_Locals (The_Subroutine);
      Body_Instrs   : constant Instructions.Instruction_Sequence := Subroutines.Get_Instructions (The_Subroutine);
   begin
      Append_Signature_Index (Buffer, The_Signature);
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Types.Length (Locals)));
      for Local_Index in 1 .. Types.Length (Locals) loop
         declare
            The_Local : constant Types.Parameter := Types.Element (Locals, Local_Index);
         begin
            Append_U32 (Buffer, Interfaces.Unsigned_32 (Local_Index));
            Append_String (Buffer, Ada.Strings.Unbounded.To_String (The_Local.Name));
            Append_Byte (Buffer, Types.To_Code (The_Local.The_Type));
         end;
      end loop;
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Subroutines.Get_Flags (The_Subroutine)));
      Append_Subroutine_Origin (Buffer, The_Subroutine);
      Append_Subroutine_From_Dependency (Buffer, The_Subroutine);
      Append_Subroutine_Native (Buffer, The_Subroutine);
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Instructions.Length (Body_Instrs)));
      for Instruction_Index in 1 .. Instructions.Length (Body_Instrs) loop
         Append_Instruction (Buffer, Instructions.Element (Body_Instrs, Instruction_Index));
      end loop;
   end Append_Subroutine;

   procedure Append_Subroutine_From_Dependency (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine)
   is
      From_Dep : constant Subroutines.From_Dependency_Option := Subroutines.From_Dependency (The_Subroutine);
   begin
      case From_Dep.Present is
         when False =>
            Append_Byte (Buffer, Origin_Absent);

         when True  =>
            Append_Byte (Buffer, Origin_Present);
            Append_String (Buffer, Ada.Strings.Unbounded.To_String (From_Dep.Module_Name));
      end case;
   end Append_Subroutine_From_Dependency;

   procedure Append_Subroutine_Native (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine) is
      The_Native : constant Subroutines.Native_Binding_Option := Subroutines.Native (The_Subroutine);
   begin
      case The_Native.Present is
         when False =>
            Append_Byte (Buffer, Origin_Absent);

         when True  =>
            Append_Byte (Buffer, Origin_Present);
            Append_String (Buffer, Ada.Strings.Unbounded.To_String (The_Native.Value.Library));
            Append_String (Buffer, Ada.Strings.Unbounded.To_String (The_Native.Value.Function_Name));
      end case;
   end Append_Subroutine_Native;

   procedure Append_Subroutine_Origin (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine) is
      The_Origin : constant Subroutines.Origin_Option := Subroutines.Origin (The_Subroutine);
   begin
      case The_Origin.Present is
         when False =>
            Append_Byte (Buffer, Origin_Absent);

         when True  =>
            Append_Byte (Buffer, Origin_Present);
            Append_String (Buffer, Source.To_Utf_8 (The_Origin.Value.Filename));
            Append_Span (Buffer, The_Origin.Value.Name_Span);
            Append_Span (Buffer, The_Origin.Value.Span);
      end case;
   end Append_Subroutine_Origin;

   procedure Append_U16 (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_16) is
   begin
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Value and 16#FF#));
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#));
   end Append_U16;

   procedure Append_U32 (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_32) is
   begin
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Value and 16#FF#));
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#));
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 16) and 16#FF#));
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 24) and 16#FF#));
   end Append_U32;

   function Build_Instruction
     (Operation : Opcodes.Opcode; Operand : Interfaces.Unsigned_32) return Instructions.Instruction is
   begin
      case Operation is
         when Opcodes.No_Operation =>
            return (Operation => Opcodes.No_Operation);

         when Opcodes.Constant_I32 =>
            return (Operation => Opcodes.Constant_I32, Immediate_I32 => Bits_To_Integer_32 (Operand));

         when Opcodes.Call         =>
            return (Operation => Opcodes.Call, Target_Index => Operand);

         when Opcodes.Local_Get    =>
            return (Operation => Opcodes.Local_Get, Local_Index => Operand);

         when Opcodes.Local_Set    =>
            return (Operation => Opcodes.Local_Set, Local_Index => Operand);
      end case;
   end Build_Instruction;

   function Decode (Bytes : Byte_Sequence) return Decode_Result is
      Cursor           : Natural := 1;
      Dependency_Total : Interfaces.Unsigned_32;
      Table            : Preamble_Table;
      The_Module       : Modules.Module;
      Code             : Errors.Error_Code := Errors.Internal_Error;
   begin
      if not Parse_Magic_Version (Bytes, Cursor, Code)
        or else not Parse_Header (Bytes, Cursor, The_Module, Dependency_Total, Code)
      then
         return (Ok => False, Error => Code);
      end if;
      if not Parse_Dependencies (Bytes, Cursor, The_Module, Dependency_Total, Code) then
         return (Ok => False, Error => Code);
      end if;
      if not Parse_Module_Origin (Bytes, Cursor, The_Module, Code) then
         return (Ok => False, Error => Code);
      end if;
      if not Parse_Preamble (Bytes, Cursor, Table, Code) then
         return (Ok => False, Error => Code);
      end if;
      if not Parse_Bodies (Bytes, Cursor, Table, The_Module, Code) then
         return (Ok => False, Error => Code);
      end if;
      if Remaining (Bytes, Cursor) /= 0 then
         return (Ok => False, Error => Errors.Trailing_Bytes);
      end if;

      declare
         Validation : constant Errors.Validation_Results.Result := Modules.Validate (The_Module);
      begin
         if not Validation.Ok then
            return (Ok => False, Error => Validation.Error);
         end if;
      end;
      return (Ok => True, Value => The_Module);
   end Decode;

   function Decode (Bytes : Ada.Streams.Stream_Element_Array) return Decode_Result is
      Sequence : Byte_Sequence;
   begin
      for Index in Bytes'Range loop
         Sequence.Items.Append (Interfaces.Unsigned_8 (Bytes (Index)));
      end loop;
      return Decode (Sequence);
   end Decode;

   function Element (Sequence : Byte_Sequence; Index : Positive) return Interfaces.Unsigned_8 is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Encode (The_Module : Modules.Module) return Encode_Result is
      package Slot_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Positive);

      Validation : constant Errors.Validation_Results.Result := Modules.Validate (The_Module);
   begin
      case Validation.Ok is
         when False =>
            return (Ok => False, Error => Validation.Error);

         when True  =>
            null;
      end case;

      declare
         Buffer           : Byte_Sequence;
         Subroutine_Total : constant Natural := Modules.Subroutine_Count (The_Module);
         Offset_Slots     : Slot_Vectors.Vector;
      begin
         Append_Byte (Buffer, Magic_0);
         Append_Byte (Buffer, Magic_1);
         Append_Byte (Buffer, Magic_2);
         Append_Byte (Buffer, Magic_3);
         Append_U16 (Buffer, Format_Major);
         Append_U16 (Buffer, Format_Minor);
         Append_String (Buffer, Modules.Module_Version (The_Module));

         Append_String (Buffer, Modules.Name (The_Module));
         Append_U32 (Buffer, Interfaces.Unsigned_32 (Modules.Flags (The_Module)));
         Append_U32 (Buffer, Interfaces.Unsigned_32 (Modules.Dependency_Count (The_Module)));
         for Dependency_Index in 1 .. Modules.Dependency_Count (The_Module) loop
            Append_String (Buffer, Modules.Dependency_Name (The_Module, Dependency_Index));
            Append_String (Buffer, Modules.Dependency_Version (The_Module, Dependency_Index));
         end loop;
         Append_Module_Origin (Buffer, The_Module);

         Append_U32 (Buffer, Interfaces.Unsigned_32 (Subroutine_Total));
         for Subroutine_Index in 1 .. Subroutine_Total loop
            declare
               The_Subroutine : constant Subroutines.Subroutine :=
                 Modules.Get_Subroutine (The_Module, Subroutine_Index);
               The_Signature  : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
            begin
               --  Index id is 1-based position (same as Call Target_Index).
               Append_Signature_Index (Buffer, The_Signature);
               Offset_Slots.Append (Length (Buffer) + 1);
               Append_U32 (Buffer, 0);
            end;
         end loop;

         for Subroutine_Index in 1 .. Subroutine_Total loop
            declare
               File_Offset : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Length (Buffer));
            begin
               Patch_U32 (Buffer, Offset_Slots.Element (Subroutine_Index), File_Offset);
               Append_Subroutine (Buffer, Modules.Get_Subroutine (The_Module, Subroutine_Index));
            end;
         end loop;

         return (Ok => True, Value => Buffer);
      end;
   end Encode;

   function Length (Sequence : Byte_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Parse_Bodies
     (Bytes      : Byte_Sequence;
      Cursor     : in out Natural;
      Table      : Preamble_Table;
      The_Module : in out Modules.Module;
      Code       : out Errors.Error_Code) return Boolean is
   begin
      for Subroutine_Index in 1 .. Natural (Table.Offsets.Length) loop
         declare
            Expected_Offset : constant Interfaces.Unsigned_32 := Table.Offsets.Element (Subroutine_Index);
            The_Subroutine  : Subroutines.Subroutine;
         begin
            --  Cursor only advances, so matching the absolute offset also
            --  guarantees offsets are strictly increasing.
            if Expected_Offset /= Interfaces.Unsigned_32 (Cursor - 1) then
               Code := Errors.Invalid_Offset;
               return False;
            end if;

            if not Parse_Subroutine (Bytes, Cursor, The_Subroutine, Code) then
               return False;
            end if;
            if not Signatures_Match
                     (Table.Signatures.Element (Subroutine_Index), Subroutines.Get_Signature (The_Subroutine))
            then
               Code := Errors.Invalid_Offset;
               return False;
            end if;

            Modules.Append_Subroutine (The_Module, The_Subroutine);
         end;
      end loop;
      return True;
   end Parse_Bodies;

   function Parse_Dependencies
     (Bytes            : Byte_Sequence;
      Cursor           : in out Natural;
      The_Module       : in out Modules.Module;
      Dependency_Total : Interfaces.Unsigned_32;
      Code             : out Errors.Error_Code) return Boolean is
   begin
      for Unused in 1 .. Natural (Dependency_Total) loop
         declare
            Depend_Name    : Ada.Strings.Unbounded.Unbounded_String;
            Depend_Version : Ada.Strings.Unbounded.Unbounded_String;
         begin
            if not Read_String (Bytes, Cursor, Depend_Name) or else not Read_String (Bytes, Cursor, Depend_Version) then
               Code := Errors.Truncated;
               return False;
            end if;
            Modules.Append_Dependency
              (The_Module,
               Ada.Strings.Unbounded.To_String (Depend_Name),
               Ada.Strings.Unbounded.To_String (Depend_Version));
         end;
      end loop;
      return True;
   end Parse_Dependencies;

   function Parse_Header
     (Bytes            : Byte_Sequence;
      Cursor           : in out Natural;
      The_Module       : in out Modules.Module;
      Dependency_Total : out Interfaces.Unsigned_32;
      Code             : out Errors.Error_Code) return Boolean
   is
      Module_Version_Text : Ada.Strings.Unbounded.Unbounded_String;
      Module_Name_Text    : Ada.Strings.Unbounded.Unbounded_String;
      Module_Flags_Value  : Interfaces.Unsigned_32;
   begin
      Dependency_Total := 0;
      if not Read_String (Bytes, Cursor, Module_Version_Text)
        or else not Read_String (Bytes, Cursor, Module_Name_Text)
        or else not Read_U32 (Bytes, Cursor, Module_Flags_Value)
        or else not Read_U32 (Bytes, Cursor, Dependency_Total)
      then
         Code := Errors.Truncated;
         return False;
      end if;

      The_Module := Modules.Create (Ada.Strings.Unbounded.To_String (Module_Name_Text));
      Modules.Set_Module_Version (The_Module, Ada.Strings.Unbounded.To_String (Module_Version_Text));
      Modules.Set_Flags (The_Module, Modules.Module_Flags (Module_Flags_Value));
      return True;
   end Parse_Header;

   function Parse_Instruction
     (Bytes : Byte_Sequence; Cursor : in out Natural; Item : out Instructions.Instruction; Code : out Errors.Error_Code)
      return Boolean
   is
      Word          : Interfaces.Unsigned_16;
      Opcode_Option : Opcodes.Opcode_Options.Option;
      Operand       : Interfaces.Unsigned_32 := 0;
   begin
      Item := (Operation => Opcodes.No_Operation);
      if not Read_U16 (Bytes, Cursor, Word) then
         Code := Errors.Truncated;
         return False;
      end if;
      Opcode_Option := Opcodes.From_Word (Word);
      if not Opcode_Option.Present then
         Code := Errors.Unknown_Opcode;
         return False;
      end if;
      if Opcode_Option.Value /= Opcodes.No_Operation and then not Read_U32 (Bytes, Cursor, Operand) then
         Code := Errors.Truncated;
         return False;
      end if;
      Item := Build_Instruction (Opcode_Option.Value, Operand);
      return True;
   end Parse_Instruction;

   function Parse_Instruction_Stream
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean
   is
      Instruction_Count : Interfaces.Unsigned_32;
      The_Instruction   : Instructions.Instruction;
   begin
      if not Read_U32 (Bytes, Cursor, Instruction_Count) then
         Code := Errors.Truncated;
         return False;
      end if;
      for Unused in 1 .. Natural (Instruction_Count) loop
         if not Parse_Instruction (Bytes, Cursor, The_Instruction, Code) then
            return False;
         end if;
         Subroutines.Append_Instruction (The_Subroutine, The_Instruction);
      end loop;
      return True;
   end Parse_Instruction_Stream;

   function Parse_Locals
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Locals : in out Types.Parameter_Sequence;
      Code   : out Errors.Error_Code) return Boolean
   is
      Local_Count : Interfaces.Unsigned_32;
   begin
      if not Read_U32 (Bytes, Cursor, Local_Count) then
         Code := Errors.Truncated;
         return False;
      end if;
      for Expected_Index in 1 .. Natural (Local_Count) loop
         declare
            Local_Index : Interfaces.Unsigned_32;
            Local_Name  : Ada.Strings.Unbounded.Unbounded_String;
            Local_Kind  : Types.Value_Type;
         begin
            if not Read_U32 (Bytes, Cursor, Local_Index) then
               Code := Errors.Truncated;
               return False;
            end if;
            if Natural (Local_Index) /= Expected_Index then
               Code := Errors.Invalid_Local_Index;
               return False;
            end if;
            if not Read_Typed_Name (Bytes, Cursor, Local_Name, Local_Kind, Code) then
               return False;
            end if;
            Types.Append (Locals, Ada.Strings.Unbounded.To_String (Local_Name), Local_Kind);
         end;
      end loop;
      return True;
   end Parse_Locals;

   function Parse_Magic_Version
     (Bytes : Byte_Sequence; Cursor : in out Natural; Code : out Errors.Error_Code) return Boolean
   is
      Magic : Magic_Array := [others => 0];
      Major : Interfaces.Unsigned_16;
      Minor : Interfaces.Unsigned_16;
   begin
      for Index in Magic'Range loop
         if not Read_Byte (Bytes, Cursor, Magic (Index)) then
            Code := Errors.Truncated;
            return False;
         end if;
      end loop;
      if Magic /= Magic_Bytes then
         Code := Errors.Invalid_Magic;
         return False;
      end if;
      if not Read_U16 (Bytes, Cursor, Major) or else not Read_U16 (Bytes, Cursor, Minor) then
         Code := Errors.Truncated;
         return False;
      end if;
      if Major /= Format_Major or else Minor /= Format_Minor then
         Code := Errors.Unsupported_Version;
         return False;
      end if;
      return True;
   end Parse_Magic_Version;
   function Parse_Module_Origin
     (Bytes : Byte_Sequence; Cursor : in out Natural; The_Module : in out Modules.Module; Code : out Errors.Error_Code)
      return Boolean
   is
      Presence      : Interfaces.Unsigned_8;
      Filename_Text : Ada.Strings.Unbounded.Unbounded_String;
      Filename      : Source.Filename_Option;
      Name_Span     : Source.Source_Span;
      Unit_Span     : Source.Source_Span;
   begin
      if not Read_Byte (Bytes, Cursor, Presence) then
         Code := Errors.Truncated;
         return False;
      end if;
      if Presence = Origin_Absent then
         return True;
      end if;
      if Presence /= Origin_Present then
         Code := Errors.Invalid_Presence;
         return False;
      end if;
      if not Read_String (Bytes, Cursor, Filename_Text) then
         Code := Errors.Truncated;
         return False;
      end if;
      if not Parse_Span (Bytes, Cursor, Name_Span) or else not Parse_Span (Bytes, Cursor, Unit_Span) then
         Code := Errors.Truncated;
         return False;
      end if;

      if Ada.Strings.Unbounded.Length (Filename_Text) = 0 then
         Filename := Source.Absent_Filename;
      else
         Filename := Source.Some_Filename (Source.From_Utf_8 (Ada.Strings.Unbounded.To_String (Filename_Text)));
      end if;

      Modules.Set_Origin (The_Module, (Name_Span => Name_Span, Span => Unit_Span, Filename => Filename));
      return True;
   end Parse_Module_Origin;

   function Parse_Parameters
     (Bytes      : Byte_Sequence;
      Cursor     : in out Natural;
      Parameters : in out Types.Parameter_Sequence;
      Code       : out Errors.Error_Code) return Boolean
   is
      Parameter_Count : Interfaces.Unsigned_32;
   begin
      if not Read_U32 (Bytes, Cursor, Parameter_Count) then
         Code := Errors.Truncated;
         return False;
      end if;
      for Unused in 1 .. Natural (Parameter_Count) loop
         declare
            Parameter_Name : Ada.Strings.Unbounded.Unbounded_String;
            Parameter_Kind : Types.Value_Type;
         begin
            if not Read_Typed_Name (Bytes, Cursor, Parameter_Name, Parameter_Kind, Code) then
               return False;
            end if;
            Types.Append (Parameters, Ada.Strings.Unbounded.To_String (Parameter_Name), Parameter_Kind);
         end;
      end loop;
      return True;
   end Parse_Parameters;

   function Parse_Position
     (Bytes : Byte_Sequence; Cursor : in out Natural; The_Position : out Source.Source_Position) return Boolean
   is
      Byte_Index_Value : Interfaces.Unsigned_32;
      Line_Value       : Interfaces.Unsigned_32;
      Column_Value     : Interfaces.Unsigned_32;
   begin
      if not Read_U32 (Bytes, Cursor, Byte_Index_Value)
        or else not Read_U32 (Bytes, Cursor, Line_Value)
        or else not Read_U32 (Bytes, Cursor, Column_Value)
      then
         return False;
      end if;
      if not Position_Fields_Ok (Byte_Index_Value, Line_Value, Column_Value) then
         return False;
      end if;
      The_Position :=
        (Byte_Index => Positive (Byte_Index_Value), Line => Positive (Line_Value), Column => Positive (Column_Value));
      return True;
   end Parse_Position;

   function Parse_Preamble
     (Bytes : Byte_Sequence; Cursor : in out Natural; Table : in out Preamble_Table; Code : out Errors.Error_Code)
      return Boolean
   is
      Subroutine_Total : Interfaces.Unsigned_32;
   begin
      if not Read_U32 (Bytes, Cursor, Subroutine_Total) then
         Code := Errors.Truncated;
         return False;
      end if;
      for Unused in 1 .. Natural (Subroutine_Total) loop
         declare
            Entry_Signature : Subroutines.Signature;
            Entry_Offset    : Interfaces.Unsigned_32;
         begin
            if not Read_Signature_Index (Bytes, Cursor, Entry_Signature, Code) then
               return False;
            end if;
            if not Read_U32 (Bytes, Cursor, Entry_Offset) then
               Code := Errors.Truncated;
               return False;
            end if;
            Table.Signatures.Append (Entry_Signature);
            Table.Offsets.Append (Entry_Offset);
         end;
      end loop;
      return True;
   end Parse_Preamble;

   function Parse_Signature
     (Bytes       : Byte_Sequence;
      Cursor      : in out Natural;
      Name_Text   : out Ada.Strings.Unbounded.Unbounded_String;
      Return_Kind : out Types.Value_Type;
      Parameters  : out Types.Parameter_Sequence;
      Code        : out Errors.Error_Code) return Boolean
   is
      Return_Code   : Interfaces.Unsigned_8;
      Return_Option : Types.Value_Type_Options.Option;
   begin
      Return_Kind := Types.Value_Type'First;
      Parameters := Types.Empty_Sequence;
      if not Read_String (Bytes, Cursor, Name_Text) or else not Read_Byte (Bytes, Cursor, Return_Code) then
         Code := Errors.Truncated;
         return False;
      end if;
      Return_Option := Types.From_Code (Return_Code);
      if not Return_Option.Present then
         Code := Errors.Unknown_Type;
         return False;
      end if;
      Return_Kind := Return_Option.Value;
      return Parse_Parameters (Bytes, Cursor, Parameters, Code);
   end Parse_Signature;

   function Parse_Span
     (Bytes : Byte_Sequence; Cursor : in out Natural; The_Span : out Source.Source_Span) return Boolean
   is
      First_Position : Source.Source_Position;
      Last_Position  : Source.Source_Position;
   begin
      if not Parse_Position (Bytes, Cursor, First_Position) or else not Parse_Position (Bytes, Cursor, Last_Position)
      then
         return False;
      end if;
      The_Span := (First => First_Position, Last => Last_Position);
      return True;
   end Parse_Span;

   function Parse_Subroutine
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean
   is
      Name_Text   : Ada.Strings.Unbounded.Unbounded_String;
      Return_Kind : Types.Value_Type;
      Flags_Value : Interfaces.Unsigned_32;
      Parameters  : Types.Parameter_Sequence := Types.Empty_Sequence;
      Locals      : Types.Parameter_Sequence := Types.Empty_Sequence;
   begin
      if not Parse_Signature (Bytes, Cursor, Name_Text, Return_Kind, Parameters, Code) then
         return False;
      end if;
      if not Parse_Locals (Bytes, Cursor, Locals, Code) then
         return False;
      end if;
      if not Read_U32 (Bytes, Cursor, Flags_Value) then
         Code := Errors.Truncated;
         return False;
      end if;

      The_Subroutine :=
        Subroutines.Create
          (The_Signature => (Name => Name_Text, Return_Type => Return_Kind, Parameters => Parameters),
           Flags         => Subroutines.Subroutine_Flags (Flags_Value));
      Append_Locals (The_Subroutine, Locals);

      if not Parse_Subroutine_Origin (Bytes, Cursor, The_Subroutine, Code) then
         return False;
      end if;
      if not Parse_Subroutine_From_Dependency (Bytes, Cursor, The_Subroutine, Code) then
         return False;
      end if;
      if not Parse_Subroutine_Native (Bytes, Cursor, The_Subroutine, Code) then
         return False;
      end if;

      return Parse_Instruction_Stream (Bytes, Cursor, The_Subroutine, Code);
   end Parse_Subroutine;

   function Parse_Subroutine_From_Dependency
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean
   is
      Presence : Interfaces.Unsigned_8;
      Dep_Text : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Read_Byte (Bytes, Cursor, Presence) then
         Code := Errors.Truncated;
         return False;
      end if;
      if Presence = Origin_Absent then
         return True;
      end if;
      if Presence /= Origin_Present then
         Code := Errors.Invalid_Presence;
         return False;
      end if;
      if not Read_String (Bytes, Cursor, Dep_Text) then
         Code := Errors.Truncated;
         return False;
      end if;

      Subroutines.Set_From_Dependency (The_Subroutine, Ada.Strings.Unbounded.To_String (Dep_Text));
      return True;
   end Parse_Subroutine_From_Dependency;

   function Parse_Subroutine_Native
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean
   is
      Presence    : Interfaces.Unsigned_8;
      Target_Text : Ada.Strings.Unbounded.Unbounded_String;
      Key_Text    : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Read_Byte (Bytes, Cursor, Presence) then
         Code := Errors.Truncated;
         return False;
      end if;
      if Presence = Origin_Absent then
         return True;
      end if;
      if Presence /= Origin_Present then
         Code := Errors.Invalid_Presence;
         return False;
      end if;
      if not Read_String (Bytes, Cursor, Target_Text) then
         Code := Errors.Truncated;
         return False;
      end if;
      if not Read_String (Bytes, Cursor, Key_Text) then
         Code := Errors.Truncated;
         return False;
      end if;

      Subroutines.Set_Native_Binding
        (The_Subroutine, Ada.Strings.Unbounded.To_String (Target_Text), Ada.Strings.Unbounded.To_String (Key_Text));
      return True;
   end Parse_Subroutine_Native;

   function Parse_Subroutine_Origin
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : in out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean
   is
      Presence      : Interfaces.Unsigned_8;
      Filename_Text : Ada.Strings.Unbounded.Unbounded_String;
      Filename      : Source.Filename_Option;
      Name_Span     : Source.Source_Span;
      Decl_Span     : Source.Source_Span;
   begin
      if not Read_Byte (Bytes, Cursor, Presence) then
         Code := Errors.Truncated;
         return False;
      end if;
      if Presence = Origin_Absent then
         return True;
      end if;
      if Presence /= Origin_Present then
         Code := Errors.Invalid_Presence;
         return False;
      end if;
      if not Read_String (Bytes, Cursor, Filename_Text) then
         Code := Errors.Truncated;
         return False;
      end if;
      if not Parse_Span (Bytes, Cursor, Name_Span) then
         Code := Errors.Truncated;
         return False;
      end if;
      if not Parse_Span (Bytes, Cursor, Decl_Span) then
         Code := Errors.Truncated;
         return False;
      end if;

      if Ada.Strings.Unbounded.Length (Filename_Text) = 0 then
         Filename := Source.Absent_Filename;
      else
         Filename := Source.Some_Filename (Source.From_Utf_8 (Ada.Strings.Unbounded.To_String (Filename_Text)));
      end if;

      Subroutines.Set_Origin (The_Subroutine, (Name_Span => Name_Span, Span => Decl_Span, Filename => Filename));
      return True;
   end Parse_Subroutine_Origin;

   procedure Patch_U32 (Buffer : in out Byte_Sequence; At_Index : Positive; Value : Interfaces.Unsigned_32) is
   begin
      Buffer.Items.Replace_Element (At_Index, Interfaces.Unsigned_8 (Value and 16#FF#));
      Buffer.Items.Replace_Element (At_Index + 1, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#));
      Buffer.Items.Replace_Element
        (At_Index + 2, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 16) and 16#FF#));
      Buffer.Items.Replace_Element
        (At_Index + 3, Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 24) and 16#FF#));
   end Patch_U32;

   function Position_Fields_Ok
     (Byte_Index_Value : Interfaces.Unsigned_32;
      Line_Value       : Interfaces.Unsigned_32;
      Column_Value     : Interfaces.Unsigned_32) return Boolean
   is
      Highest_Value : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Positive'Last);
   begin
      return
        Byte_Index_Value /= 0
        and then Line_Value /= 0
        and then Column_Value /= 0
        and then Byte_Index_Value <= Highest_Value
        and then Line_Value <= Highest_Value
        and then Column_Value <= Highest_Value;
   end Position_Fields_Ok;

   function Read (Path : String) return Decode_Result is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
      Sequence   : Byte_Sequence;
   begin
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return (Ok => False, Error => Errors.Io_Failure);
      end if;

      declare
         File_Size : constant Long_Integer := GNAT.OS_Lib.File_Length (Descriptor);
      begin
         if File_Size < 0 then
            GNAT.OS_Lib.Close (Descriptor);
            return (Ok => False, Error => Errors.Io_Failure);
         end if;

         declare
            Remaining_Bytes : Long_Integer := File_Size;
            Chunk           : Ada.Streams.Stream_Element_Array (1 .. 4096);
            Bytes_Read      : Integer;
         begin
            while Remaining_Bytes > 0 loop
               Bytes_Read :=
                 GNAT.OS_Lib.Read
                   (Descriptor,
                    Chunk'Address,
                    Integer (Long_Integer'Min (Remaining_Bytes, Long_Integer (Chunk'Length))));
               if Bytes_Read <= 0 then
                  GNAT.OS_Lib.Close (Descriptor);
                  return (Ok => False, Error => Errors.Io_Failure);
               end if;
               for Index in 1 .. Bytes_Read loop
                  Sequence.Items.Append (Interfaces.Unsigned_8 (Chunk (Ada.Streams.Stream_Element_Offset (Index))));
               end loop;
               Remaining_Bytes := Remaining_Bytes - Long_Integer (Bytes_Read);
            end loop;
         end;
      end;

      GNAT.OS_Lib.Close (Descriptor);
      return Decode (Sequence);
   end Read;

   function Read_Byte (Bytes : Byte_Sequence; Cursor : in out Natural; Value : out Interfaces.Unsigned_8) return Boolean
   is
   begin
      if Remaining (Bytes, Cursor) < 1 then
         return False;
      end if;
      Value := Element (Bytes, Cursor);
      Cursor := Cursor + 1;
      return True;
   end Read_Byte;

   function Read_Signature_Index
     (Bytes         : Byte_Sequence;
      Cursor        : in out Natural;
      The_Signature : out Subroutines.Signature;
      Code          : out Errors.Error_Code) return Boolean
   is
      Name_Text       : Ada.Strings.Unbounded.Unbounded_String;
      Return_Code     : Interfaces.Unsigned_8;
      Parameter_Count : Interfaces.Unsigned_32;
      Parameters      : Types.Parameter_Sequence := Types.Empty_Sequence;
      Return_Option   : Types.Value_Type_Options.Option;
   begin
      if not Read_String (Bytes, Cursor, Name_Text) or else not Read_Byte (Bytes, Cursor, Return_Code) then
         Code := Errors.Truncated;
         return False;
      end if;
      Return_Option := Types.From_Code (Return_Code);
      if not Return_Option.Present then
         Code := Errors.Unknown_Type;
         return False;
      end if;
      if not Read_U32 (Bytes, Cursor, Parameter_Count) then
         Code := Errors.Truncated;
         return False;
      end if;
      for Unused in 1 .. Natural (Parameter_Count) loop
         declare
            Parameter_Name : Ada.Strings.Unbounded.Unbounded_String;
            Parameter_Kind : Types.Value_Type;
         begin
            if not Read_Typed_Name (Bytes, Cursor, Parameter_Name, Parameter_Kind, Code) then
               return False;
            end if;
            Types.Append (Parameters, Ada.Strings.Unbounded.To_String (Parameter_Name), Parameter_Kind);
         end;
      end loop;
      The_Signature := (Name => Name_Text, Return_Type => Return_Option.Value, Parameters => Parameters);
      Code := Errors.Internal_Error;
      return True;
   end Read_Signature_Index;

   function Read_String
     (Bytes : Byte_Sequence; Cursor : in out Natural; Text : out Ada.Strings.Unbounded.Unbounded_String) return Boolean
   is
      Byte_Length : Interfaces.Unsigned_32;
   begin
      if not Read_U32 (Bytes, Cursor, Byte_Length) then
         return False;
      end if;
      if Remaining (Bytes, Cursor) < Natural (Byte_Length) then
         return False;
      end if;
      declare
         Slice : String (1 .. Natural (Byte_Length));
      begin
         for Index in Slice'Range loop
            Slice (Index) := Character'Val (Natural (Element (Bytes, Cursor)));
            Cursor := Cursor + 1;
         end loop;
         Text := Ada.Strings.Unbounded.To_Unbounded_String (Slice);
      end;
      return True;
   end Read_String;

   function Read_Typed_Name
     (Bytes      : Byte_Sequence;
      Cursor     : in out Natural;
      Name_Text  : out Ada.Strings.Unbounded.Unbounded_String;
      Value_Kind : out Types.Value_Type;
      Code       : out Errors.Error_Code) return Boolean
   is
      Type_Code   : Interfaces.Unsigned_8;
      Type_Option : Types.Value_Type_Options.Option;
   begin
      Value_Kind := Types.Value_Type'First;
      if not Read_String (Bytes, Cursor, Name_Text) or else not Read_Byte (Bytes, Cursor, Type_Code) then
         Code := Errors.Truncated;
         return False;
      end if;
      Type_Option := Types.From_Code (Type_Code);
      if not Type_Option.Present then
         Code := Errors.Unknown_Type;
         return False;
      end if;
      Value_Kind := Type_Option.Value;
      return True;
   end Read_Typed_Name;

   function Read_U16 (Bytes : Byte_Sequence; Cursor : in out Natural; Value : out Interfaces.Unsigned_16) return Boolean
   is
      Low  : Interfaces.Unsigned_8;
      High : Interfaces.Unsigned_8;
   begin
      if not Read_Byte (Bytes, Cursor, Low) or else not Read_Byte (Bytes, Cursor, High) then
         return False;
      end if;
      Value := Interfaces.Unsigned_16 (Low) or Interfaces.Shift_Left (Interfaces.Unsigned_16 (High), 8);
      return True;
   end Read_U16;

   function Read_U32 (Bytes : Byte_Sequence; Cursor : in out Natural; Value : out Interfaces.Unsigned_32) return Boolean
   is
      Byte_0 : Interfaces.Unsigned_8;
      Byte_1 : Interfaces.Unsigned_8;
      Byte_2 : Interfaces.Unsigned_8;
      Byte_3 : Interfaces.Unsigned_8;
   begin
      if not Read_Byte (Bytes, Cursor, Byte_0)
        or else not Read_Byte (Bytes, Cursor, Byte_1)
        or else not Read_Byte (Bytes, Cursor, Byte_2)
        or else not Read_Byte (Bytes, Cursor, Byte_3)
      then
         return False;
      end if;
      Value :=
        Interfaces.Unsigned_32 (Byte_0)
        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Byte_1), 8)
        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Byte_2), 16)
        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Byte_3), 24);
      return True;
   end Read_U32;

   function Remaining (Bytes : Byte_Sequence; Cursor : Natural) return Natural is
   begin
      if Cursor > Length (Bytes) then
         return 0;
      end if;
      return Length (Bytes) - Cursor + 1;
   end Remaining;

   function Signatures_Match (Left : Subroutines.Signature; Right : Subroutines.Signature) return Boolean is
   begin
      if Left.Name /= Right.Name
        or else Left.Return_Type /= Right.Return_Type
        or else Types.Length (Left.Parameters) /= Types.Length (Right.Parameters)
      then
         return False;
      end if;
      for Index in 1 .. Types.Length (Left.Parameters) loop
         declare
            Left_Param  : constant Types.Parameter := Types.Element (Left.Parameters, Index);
            Right_Param : constant Types.Parameter := Types.Element (Right.Parameters, Index);
         begin
            if Left_Param.Name /= Right_Param.Name or else Left_Param.The_Type /= Right_Param.The_Type then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Signatures_Match;

   function Write (The_Module : Modules.Module; Path : String) return Write_Result is
      Encoded : constant Encode_Result := Encode (The_Module);
   begin
      case Encoded.Ok is
         when False =>
            return (Ok => False, Error => Encoded.Error);

         when True  =>
            declare
               Descriptor : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
            begin
               if Descriptor = GNAT.OS_Lib.Invalid_FD then
                  return (Ok => False, Error => Errors.Io_Failure);
               end if;

               if Length (Encoded.Value) > 0 then
                  declare
                     Buffer  :
                       Ada.Streams.Stream_Element_Array
                         (1 .. Ada.Streams.Stream_Element_Offset (Length (Encoded.Value)));
                     Written : Integer;
                  begin
                     for Index in 1 .. Length (Encoded.Value) loop
                        Buffer (Ada.Streams.Stream_Element_Offset (Index)) :=
                          Ada.Streams.Stream_Element (Element (Encoded.Value, Index));
                     end loop;
                     Written := GNAT.OS_Lib.Write (Descriptor, Buffer'Address, Buffer'Length);
                     if Written /= Integer (Buffer'Length) then
                        GNAT.OS_Lib.Close (Descriptor);
                        return (Ok => False, Error => Errors.Io_Failure);
                     end if;
                  end;
               end if;

               GNAT.OS_Lib.Close (Descriptor);
               return (Ok => True);
            end;
      end case;
   end Write;

end Lovelace.Lir.Binary;
