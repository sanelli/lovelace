with Ada.Containers.Vectors;
with Ada.Streams;
with Interfaces;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;

--  Versioned binary .lir encode, decode, and file I/O.
--  Layout: magic and version, module metadata, subroutine preamble
--  (name + absolute offset per subroutine), then subroutine records.

package Lovelace.Lir.Binary is

   --  Encoded .lir bytes. File offsets are 0-based from the first magic byte.
   type Byte_Sequence is private;

   --  Encode outcome: Byte_Sequence or Error_Code.
   --  @disc Ok True when Value is present; False when Error is.
   --  @field Value Encoded bytes when Ok is True.
   --  @field Error Failure code when Ok is False.
   type Encode_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Value : Byte_Sequence;

         when False =>
            Error : Errors.Error_Code;
      end case;
   end record;

   --  Decode outcome: Module or Error_Code.
   --  @disc Ok True when Value is present; False when Error is.
   --  @field Value Decoded module when Ok is True.
   --  @field Error Failure code when Ok is False.
   type Decode_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Value : Modules.Module;

         when False =>
            Error : Errors.Error_Code;
      end case;
   end record;

   --  Write-to-file outcome.
   --  @disc Ok True on success; False when Error is.
   --  @field Error Failure code when Ok is False.
   type Write_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            null;

         when False =>
            Error : Errors.Error_Code;
      end case;
   end record;

   --  Number of bytes in Sequence.
   --  @param Sequence Byte sequence.
   --  @return Byte count.
   function Length (Sequence : Byte_Sequence) return Natural;

   --  Byte at Index (1 .. Length (Sequence)).
   --  @param Sequence Byte sequence.
   --  @param Index 1-based index.
   --  @return Byte at Index.
   function Element
     (Sequence : Byte_Sequence; Index : Positive) return Interfaces.Unsigned_8;

   --  Encode The_Module as a versioned .lir image after Validate.
   --  @param The_Module Module to encode.
   --  @return Byte sequence, or a format/validation Error_Code.
   function Encode (The_Module : Modules.Module) return Encode_Result;

   --  Decode Bytes as a .lir module (Validate applied).
   --  @param Bytes Encoded image.
   --  @return Module, or a format/validation Error_Code.
   function Decode (Bytes : Byte_Sequence) return Decode_Result;

   --  Decode a Stream_Element_Array as a .lir module.
   --  @param Bytes Encoded image.
   --  @return Module, or a format/validation Error_Code.
   function Decode
     (Bytes : Ada.Streams.Stream_Element_Array) return Decode_Result;

   --  Encode The_Module and write Path (conventionally .lir).
   --  @param The_Module Module to write.
   --  @param Path Destination filesystem path.
   --  @return Success, or Error_Code.
   function Write
     (The_Module : Modules.Module; Path : String) return Write_Result;

   --  Read Path and Decode.
   --  @param Path Source filesystem path.
   --  @return Module, or Error_Code.
   function Read (Path : String) return Decode_Result;

private

   use type Interfaces.Unsigned_8;

   package Byte_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Interfaces.Unsigned_8);

   type Byte_Sequence is record
      Items : Byte_Vectors.Vector;
   end record;

end Lovelace.Lir.Binary;
