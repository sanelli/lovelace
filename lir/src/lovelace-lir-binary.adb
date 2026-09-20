with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Binary is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Ada.Strings.Unbounded.Unbounded_String;

   Magic_0 : constant Interfaces.Unsigned_8 := 16#4C#;
   Magic_1 : constant Interfaces.Unsigned_8 := 16#49#;
   Magic_2 : constant Interfaces.Unsigned_8 := 16#52#;
   Magic_3 : constant Interfaces.Unsigned_8 := 16#00#;

   Format_Major : constant Interfaces.Unsigned_16 := 1;
   Format_Minor : constant Interfaces.Unsigned_16 := 0;

   procedure Append_Byte
     (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_8);
   procedure Append_Instruction
     (Buffer : in out Byte_Sequence; Item : Instructions.Instruction);
   procedure Append_String (Buffer : in out Byte_Sequence; Text : String);
   procedure Append_Subroutine
     (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine);
   procedure Append_U16
     (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_16);
   procedure Append_U32
     (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_32);
   function Parse_Subroutine
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean;
   procedure Patch_U32
     (Buffer   : in out Byte_Sequence;
      At_Index : Positive;
      Value    : Interfaces.Unsigned_32);
   function Read_Byte
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Value  : out Interfaces.Unsigned_8) return Boolean;
   function Read_String
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Text   : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   function Read_U16
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Value  : out Interfaces.Unsigned_16) return Boolean;
   function Read_U32
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Value  : out Interfaces.Unsigned_32) return Boolean;
   function Remaining (Bytes : Byte_Sequence; Cursor : Natural) return Natural;

   procedure Append_Byte
     (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_8) is
   begin
      Buffer.Items.Append (Value);
   end Append_Byte;

   procedure Append_Instruction
     (Buffer : in out Byte_Sequence; Item : Instructions.Instruction) is
   begin
      Append_U16 (Buffer, Opcodes.To_Word (Item.Operation));
   end Append_Instruction;

   procedure Append_String (Buffer : in out Byte_Sequence; Text : String) is
   begin
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Text'Length));
      for Index in Text'Range loop
         Append_Byte
           (Buffer, Interfaces.Unsigned_8 (Character'Pos (Text (Index))));
      end loop;
   end Append_String;

   procedure Append_Subroutine
     (Buffer : in out Byte_Sequence; The_Subroutine : Subroutines.Subroutine)
   is
      The_Signature : constant Subroutines.Signature :=
        Subroutines.Get_Signature (The_Subroutine);
      Params        : constant Types.Value_Type_Sequence :=
        The_Signature.Parameter_Types;
      Body_Instrs   : constant Instructions.Instruction_Sequence :=
        Subroutines.Get_Instructions (The_Subroutine);
   begin
      Append_String
        (Buffer, Ada.Strings.Unbounded.To_String (The_Signature.Name));
      Append_Byte (Buffer, Types.To_Code (The_Signature.Return_Type));
      Append_U32 (Buffer, Interfaces.Unsigned_32 (Types.Length (Params)));
      for Parameter_Index in 1 .. Types.Length (Params) loop
         Append_Byte
           (Buffer, Types.To_Code (Types.Element (Params, Parameter_Index)));
      end loop;
      Append_U32
        (Buffer,
         Interfaces.Unsigned_32 (Subroutines.Get_Flags (The_Subroutine)));
      Append_U32
        (Buffer, Interfaces.Unsigned_32 (Instructions.Length (Body_Instrs)));
      for Instruction_Index in 1 .. Instructions.Length (Body_Instrs) loop
         Append_Instruction
           (Buffer, Instructions.Element (Body_Instrs, Instruction_Index));
      end loop;
   end Append_Subroutine;

   procedure Append_U16
     (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_16) is
   begin
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Value and 16#FF#));
      Append_Byte
        (Buffer,
         Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#));
   end Append_U16;

   procedure Append_U32
     (Buffer : in out Byte_Sequence; Value : Interfaces.Unsigned_32) is
   begin
      Append_Byte (Buffer, Interfaces.Unsigned_8 (Value and 16#FF#));
      Append_Byte
        (Buffer,
         Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#));
      Append_Byte
        (Buffer,
         Interfaces.Unsigned_8
           (Interfaces.Shift_Right (Value, 16) and 16#FF#));
      Append_Byte
        (Buffer,
         Interfaces.Unsigned_8
           (Interfaces.Shift_Right (Value, 24) and 16#FF#));
   end Append_U32;

   function Decode (Bytes : Byte_Sequence) return Decode_Result is
      package Offset_Vectors is new
        Ada.Containers.Vectors
          (Index_Type   => Positive,
           Element_Type => Interfaces.Unsigned_32);

      package Name_Vectors is new
        Ada.Containers.Indefinite_Vectors
          (Index_Type   => Positive,
           Element_Type => Ada.Strings.Unbounded.Unbounded_String);

      Cursor             : Natural := 1;
      Byte_0             : Interfaces.Unsigned_8;
      Byte_1             : Interfaces.Unsigned_8;
      Byte_2             : Interfaces.Unsigned_8;
      Byte_3             : Interfaces.Unsigned_8;
      Major              : Interfaces.Unsigned_16;
      Minor              : Interfaces.Unsigned_16;
      Subroutine_Total   : Interfaces.Unsigned_32;
      Preamble_Names     : Name_Vectors.Vector;
      Preamble_Offsets   : Offset_Vectors.Vector;
      Module_Name_Text   : Ada.Strings.Unbounded.Unbounded_String;
      Module_Flags_Value : Interfaces.Unsigned_32;
      Dependency_Total   : Interfaces.Unsigned_32;
      The_Module         : Modules.Module;
      Previous_Offset    : Interfaces.Unsigned_32 := 0;
      First_Offset       : Boolean := True;
   begin
      if not Read_Byte (Bytes, Cursor, Byte_0)
        or else not Read_Byte (Bytes, Cursor, Byte_1)
        or else not Read_Byte (Bytes, Cursor, Byte_2)
        or else not Read_Byte (Bytes, Cursor, Byte_3)
      then
         return (Ok => False, Error => Errors.Truncated);
      end if;
      if Byte_0 /= Magic_0
        or else Byte_1 /= Magic_1
        or else Byte_2 /= Magic_2
        or else Byte_3 /= Magic_3
      then
         return (Ok => False, Error => Errors.Invalid_Magic);
      end if;
      if not Read_U16 (Bytes, Cursor, Major)
        or else not Read_U16 (Bytes, Cursor, Minor)
      then
         return (Ok => False, Error => Errors.Truncated);
      end if;
      if Major /= Format_Major or else Minor /= Format_Minor then
         return (Ok => False, Error => Errors.Unsupported_Version);
      end if;

      if not Read_String (Bytes, Cursor, Module_Name_Text) then
         return (Ok => False, Error => Errors.Truncated);
      end if;
      if not Read_U32 (Bytes, Cursor, Module_Flags_Value) then
         return (Ok => False, Error => Errors.Truncated);
      end if;
      if not Read_U32 (Bytes, Cursor, Dependency_Total) then
         return (Ok => False, Error => Errors.Truncated);
      end if;

      The_Module :=
        Modules.Create (Ada.Strings.Unbounded.To_String (Module_Name_Text));
      Modules.Set_Flags
        (The_Module, Modules.Module_Flags (Module_Flags_Value));

      for Unused in 1 .. Natural (Dependency_Total) loop
         declare
            Depend_Name : Ada.Strings.Unbounded.Unbounded_String;
         begin
            if not Read_String (Bytes, Cursor, Depend_Name) then
               return (Ok => False, Error => Errors.Truncated);
            end if;
            Modules.Append_Dependency
              (The_Module, Ada.Strings.Unbounded.To_String (Depend_Name));
         end;
      end loop;

      if not Read_U32 (Bytes, Cursor, Subroutine_Total) then
         return (Ok => False, Error => Errors.Truncated);
      end if;
      for Unused in 1 .. Natural (Subroutine_Total) loop
         declare
            Entry_Name   : Ada.Strings.Unbounded.Unbounded_String;
            Entry_Offset : Interfaces.Unsigned_32;
         begin
            if not Read_String (Bytes, Cursor, Entry_Name) then
               return (Ok => False, Error => Errors.Truncated);
            end if;
            if not Read_U32 (Bytes, Cursor, Entry_Offset) then
               return (Ok => False, Error => Errors.Truncated);
            end if;
            Preamble_Names.Append (Entry_Name);
            Preamble_Offsets.Append (Entry_Offset);
         end;
      end loop;

      for Subroutine_Index in 1 .. Natural (Subroutine_Total) loop
         declare
            Expected_Offset     : constant Interfaces.Unsigned_32 :=
              Preamble_Offsets.Element (Subroutine_Index);
            Current_File_Offset : constant Interfaces.Unsigned_32 :=
              Interfaces.Unsigned_32 (Cursor - 1);
            The_Subroutine      : Subroutines.Subroutine;
            Parse_Code          : Errors.Error_Code;
            Parsed_Name         : Ada.Strings.Unbounded.Unbounded_String;
         begin
            if Expected_Offset /= Current_File_Offset then
               return (Ok => False, Error => Errors.Invalid_Offset);
            end if;
            if not First_Offset and then Expected_Offset <= Previous_Offset
            then
               return (Ok => False, Error => Errors.Invalid_Offset);
            end if;
            First_Offset := False;
            Previous_Offset := Expected_Offset;

            if not Parse_Subroutine (Bytes, Cursor, The_Subroutine, Parse_Code)
            then
               return (Ok => False, Error => Parse_Code);
            end if;

            Parsed_Name := Subroutines.Get_Signature (The_Subroutine).Name;
            if Parsed_Name /= Preamble_Names.Element (Subroutine_Index) then
               return (Ok => False, Error => Errors.Invalid_Offset);
            end if;

            Modules.Append_Subroutine (The_Module, The_Subroutine);
         end;
      end loop;

      if Remaining (Bytes, Cursor) /= 0 then
         return (Ok => False, Error => Errors.Trailing_Bytes);
      end if;

      declare
         Validation : constant Errors.Validation_Results.Result :=
           Modules.Validate (The_Module);
      begin
         case Validation.Ok is
            when False =>
               return (Ok => False, Error => Validation.Error);

            when True  =>
               return (Ok => True, Value => The_Module);
         end case;
      end;
   end Decode;

   function Decode
     (Bytes : Ada.Streams.Stream_Element_Array) return Decode_Result
   is
      Sequence : Byte_Sequence;
   begin
      for Index in Bytes'Range loop
         Sequence.Items.Append (Interfaces.Unsigned_8 (Bytes (Index)));
      end loop;
      return Decode (Sequence);
   end Decode;

   function Element
     (Sequence : Byte_Sequence; Index : Positive) return Interfaces.Unsigned_8
   is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Encode (The_Module : Modules.Module) return Encode_Result is
      package Slot_Vectors is new
        Ada.Containers.Vectors
          (Index_Type   => Positive,
           Element_Type => Positive);

      Validation : constant Errors.Validation_Results.Result :=
        Modules.Validate (The_Module);
   begin
      case Validation.Ok is
         when False =>
            return (Ok => False, Error => Validation.Error);

         when True  =>
            null;
      end case;

      declare
         Buffer           : Byte_Sequence;
         Subroutine_Total : constant Natural :=
           Modules.Subroutine_Count (The_Module);
         Offset_Slots     : Slot_Vectors.Vector;
      begin
         Append_Byte (Buffer, Magic_0);
         Append_Byte (Buffer, Magic_1);
         Append_Byte (Buffer, Magic_2);
         Append_Byte (Buffer, Magic_3);
         Append_U16 (Buffer, Format_Major);
         Append_U16 (Buffer, Format_Minor);

         Append_String (Buffer, Modules.Name (The_Module));
         Append_U32
           (Buffer, Interfaces.Unsigned_32 (Modules.Flags (The_Module)));
         Append_U32
           (Buffer,
            Interfaces.Unsigned_32 (Modules.Dependency_Count (The_Module)));
         for Dependency_Index in 1 .. Modules.Dependency_Count (The_Module)
         loop
            Append_String
              (Buffer, Modules.Dependency_Name (The_Module, Dependency_Index));
         end loop;

         Append_U32 (Buffer, Interfaces.Unsigned_32 (Subroutine_Total));
         for Subroutine_Index in 1 .. Subroutine_Total loop
            declare
               The_Subroutine : constant Subroutines.Subroutine :=
                 Modules.Get_Subroutine (The_Module, Subroutine_Index);
               The_Signature  : constant Subroutines.Signature :=
                 Subroutines.Get_Signature (The_Subroutine);
            begin
               Append_String
                 (Buffer,
                  Ada.Strings.Unbounded.To_String (The_Signature.Name));
               Offset_Slots.Append (Length (Buffer) + 1);
               Append_U32 (Buffer, 0);
            end;
         end loop;

         for Subroutine_Index in 1 .. Subroutine_Total loop
            declare
               File_Offset : constant Interfaces.Unsigned_32 :=
                 Interfaces.Unsigned_32 (Length (Buffer));
            begin
               Patch_U32
                 (Buffer,
                  Offset_Slots.Element (Subroutine_Index),
                  File_Offset);
               Append_Subroutine
                 (Buffer,
                  Modules.Get_Subroutine (The_Module, Subroutine_Index));
            end;
         end loop;

         return (Ok => True, Value => Buffer);
      end;
   end Encode;

   function Length (Sequence : Byte_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Parse_Subroutine
     (Bytes          : Byte_Sequence;
      Cursor         : in out Natural;
      The_Subroutine : out Subroutines.Subroutine;
      Code           : out Errors.Error_Code) return Boolean
   is
      Name_Text         : Ada.Strings.Unbounded.Unbounded_String;
      Return_Code       : Interfaces.Unsigned_8;
      Parameter_Count   : Interfaces.Unsigned_32;
      Flags_Value       : Interfaces.Unsigned_32;
      Instruction_Count : Interfaces.Unsigned_32;
      Parameters        : Types.Value_Type_Sequence := Types.Empty_Sequence;
      Return_Option     : Types.Value_Type_Options.Option;
   begin
      if not Read_String (Bytes, Cursor, Name_Text) then
         Code := Errors.Truncated;
         return False;
      end if;
      if not Read_Byte (Bytes, Cursor, Return_Code) then
         Code := Errors.Truncated;
         return False;
      end if;
      Return_Option := Types.From_Code (Return_Code);
      case Return_Option.Present is
         when False =>
            Code := Errors.Unknown_Type;
            return False;

         when True  =>
            null;
      end case;
      if not Read_U32 (Bytes, Cursor, Parameter_Count) then
         Code := Errors.Truncated;
         return False;
      end if;
      for Unused in 1 .. Natural (Parameter_Count) loop
         declare
            Type_Code   : Interfaces.Unsigned_8;
            Type_Option : Types.Value_Type_Options.Option;
         begin
            if not Read_Byte (Bytes, Cursor, Type_Code) then
               Code := Errors.Truncated;
               return False;
            end if;
            Type_Option := Types.From_Code (Type_Code);
            case Type_Option.Present is
               when False =>
                  Code := Errors.Unknown_Type;
                  return False;

               when True  =>
                  Types.Append (Parameters, Type_Option.Value);
            end case;
         end;
      end loop;
      if not Read_U32 (Bytes, Cursor, Flags_Value) then
         Code := Errors.Truncated;
         return False;
      end if;
      if not Read_U32 (Bytes, Cursor, Instruction_Count) then
         Code := Errors.Truncated;
         return False;
      end if;

      The_Subroutine :=
        Subroutines.Create
          (The_Signature =>
             (Name            => Name_Text,
              Return_Type     => Return_Option.Value,
              Parameter_Types => Parameters),
           Flags         => Subroutines.Subroutine_Flags (Flags_Value));

      for Unused in 1 .. Natural (Instruction_Count) loop
         declare
            Word            : Interfaces.Unsigned_16;
            Opcode_Option   : Opcodes.Opcode_Options.Option;
            The_Instruction : Instructions.Instruction;
         begin
            if not Read_U16 (Bytes, Cursor, Word) then
               Code := Errors.Truncated;
               return False;
            end if;
            Opcode_Option := Opcodes.From_Word (Word);
            case Opcode_Option.Present is
               when False =>
                  Code := Errors.Unknown_Opcode;
                  return False;

               when True  =>
                  case Opcode_Option.Value is
                     when Opcodes.No_Operation =>
                        The_Instruction := (Operation => Opcodes.No_Operation);
                  end case;
                  Subroutines.Append_Instruction
                    (The_Subroutine, The_Instruction);
            end case;
         end;
      end loop;

      return True;
   end Parse_Subroutine;

   procedure Patch_U32
     (Buffer   : in out Byte_Sequence;
      At_Index : Positive;
      Value    : Interfaces.Unsigned_32) is
   begin
      Buffer.Items.Replace_Element
        (At_Index, Interfaces.Unsigned_8 (Value and 16#FF#));
      Buffer.Items.Replace_Element
        (At_Index + 1,
         Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#));
      Buffer.Items.Replace_Element
        (At_Index + 2,
         Interfaces.Unsigned_8
           (Interfaces.Shift_Right (Value, 16) and 16#FF#));
      Buffer.Items.Replace_Element
        (At_Index + 3,
         Interfaces.Unsigned_8
           (Interfaces.Shift_Right (Value, 24) and 16#FF#));
   end Patch_U32;

   function Read (Path : String) return Decode_Result is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
      Sequence   : Byte_Sequence;
   begin
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return (Ok => False, Error => Errors.Io_Failure);
      end if;

      declare
         File_Size : constant Long_Integer :=
           GNAT.OS_Lib.File_Length (Descriptor);
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
                    Integer
                      (Long_Integer'Min
                         (Remaining_Bytes, Long_Integer (Chunk'Length))));
               if Bytes_Read <= 0 then
                  GNAT.OS_Lib.Close (Descriptor);
                  return (Ok => False, Error => Errors.Io_Failure);
               end if;
               for Index in 1 .. Bytes_Read loop
                  Sequence.Items.Append
                    (Interfaces.Unsigned_8
                       (Chunk (Ada.Streams.Stream_Element_Offset (Index))));
               end loop;
               Remaining_Bytes := Remaining_Bytes - Long_Integer (Bytes_Read);
            end loop;
         end;
      end;

      GNAT.OS_Lib.Close (Descriptor);
      return Decode (Sequence);
   end Read;

   function Read_Byte
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Value  : out Interfaces.Unsigned_8) return Boolean is
   begin
      if Remaining (Bytes, Cursor) < 1 then
         return False;
      end if;
      Value := Element (Bytes, Cursor);
      Cursor := Cursor + 1;
      return True;
   end Read_Byte;

   function Read_String
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Text   : out Ada.Strings.Unbounded.Unbounded_String) return Boolean
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

   function Read_U16
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Value  : out Interfaces.Unsigned_16) return Boolean
   is
      Low  : Interfaces.Unsigned_8;
      High : Interfaces.Unsigned_8;
   begin
      if not Read_Byte (Bytes, Cursor, Low)
        or else not Read_Byte (Bytes, Cursor, High)
      then
         return False;
      end if;
      Value :=
        Interfaces.Unsigned_16 (Low)
        or Interfaces.Shift_Left (Interfaces.Unsigned_16 (High), 8);
      return True;
   end Read_U16;

   function Read_U32
     (Bytes  : Byte_Sequence;
      Cursor : in out Natural;
      Value  : out Interfaces.Unsigned_32) return Boolean
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

   function Remaining (Bytes : Byte_Sequence; Cursor : Natural) return Natural
   is
   begin
      if Cursor > Length (Bytes) then
         return 0;
      end if;
      return Length (Bytes) - Cursor + 1;
   end Remaining;

   function Write
     (The_Module : Modules.Module; Path : String) return Write_Result
   is
      Encoded : constant Encode_Result := Encode (The_Module);
   begin
      case Encoded.Ok is
         when False =>
            return (Ok => False, Error => Encoded.Error);

         when True  =>
            declare
               Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
                 GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
            begin
               if Descriptor = GNAT.OS_Lib.Invalid_FD then
                  return (Ok => False, Error => Errors.Io_Failure);
               end if;

               if Length (Encoded.Value) > 0 then
                  declare
                     Buffer  :
                       Ada.Streams.Stream_Element_Array
                         (1
                          .. Ada.Streams.Stream_Element_Offset
                               (Length (Encoded.Value)));
                     Written : Integer;
                  begin
                     for Index in 1 .. Length (Encoded.Value) loop
                        Buffer (Ada.Streams.Stream_Element_Offset (Index)) :=
                          Ada.Streams.Stream_Element
                            (Element (Encoded.Value, Index));
                     end loop;
                     Written :=
                       GNAT.OS_Lib.Write
                         (Descriptor, Buffer'Address, Buffer'Length);
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
