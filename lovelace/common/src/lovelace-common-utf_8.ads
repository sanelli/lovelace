with Ada.Strings.Unbounded;
with Lovelace.Common.Internal_Error;
with Lovelace.Common.Result;

--  UTF-8 byte sequences and Unicode scalar values.

package Lovelace.Common.Utf_8 is

   --  One Unicode scalar stored in four bytes. Surrogates and values
   --  above U+10FFFF are rejected by Encode.
   subtype Code_Point is Wide_Wide_Character;

   --  Why UTF-8 decode or encode failed (implementers only).
   --  @enum Invalid_Code_Point Encode rejected a surrogate or a value
   --  above U+10FFFF.
   --  @enum Invalid_Sequence Decode rejected bytes that are not UTF-8.
   type Utf_8_Error_Group is (Invalid_Code_Point, Invalid_Sequence);

   --  Internal_Error instantiated with Utf_8_Error_Group.
   package Internal_Errors is new Lovelace.Common.Internal_Error (Error_Group => Utf_8_Error_Group);

   --  Internal UTF-8 failure: group plus detail string.
   type Utf_8_Error is new Internal_Errors.Lovelace_Internal_Error;

   --  Decode outcome: a Code_Point or a Utf_8_Error.
   package Decode_Results is new Lovelace.Common.Result (Success_Type => Code_Point, Error_Type => Utf_8_Error);

   --  Encode outcome: UTF-8 bytes or a Utf_8_Error.
   package Encode_Results is new
     Lovelace.Common.Result (Success_Type => Ada.Strings.Unbounded.Unbounded_String, Error_Type => Utf_8_Error);

   --  Byte length of the UTF-8 sequence at Index.
   --  Returns 0 if Index is not in Source'Range or the sequence is
   --  invalid.
   --  @param Source UTF-8 byte string.
   --  @param Index First byte of the sequence.
   --  @return Sequence length in bytes, or 0.
   function Sequence_Length (Source : String; Index : Positive) return Natural;

   --  Decode the scalar at Index. Failure is Invalid_Sequence.
   --  @param Source UTF-8 byte string.
   --  @param Index First byte of the sequence.
   --  @return Code_Point on success, or Utf_8_Error.
   function Decode (Source : String; Index : Positive) return Decode_Results.Result;

   --  Decode the scalar at Index. Valid is False (and Length is 0)
   --  when Index is out of range or the sequence is not valid UTF-8.
   --  @param Source UTF-8 byte string.
   --  @param Index First byte of the sequence.
   --  @param Point Decoded scalar when Valid is True.
   --  @param Length Byte length when Valid is True; otherwise 0.
   --  @param Valid True iff the sequence at Index is valid UTF-8.
   procedure Decode
     (Source : String; Index : Positive; Point : out Code_Point; Length : out Natural; Valid : out Boolean);

   --  Encode Point as UTF-8 bytes. Failure is Invalid_Code_Point.
   --  @param Point Unicode scalar to encode.
   --  @return UTF-8 bytes on success, or Utf_8_Error.
   function Encode (Point : Code_Point) return Encode_Results.Result;

end Lovelace.Common.Utf_8;
