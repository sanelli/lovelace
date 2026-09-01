--  UTF-8 byte sequences and Unicode scalar values.
with Ada.Strings.Unbounded;
with Lovelace.Common.Internal_Error;
with Lovelace.Common.Result;

package Lovelace.Common.Utf_8 is

   --  One Unicode scalar stored in four bytes. Surrogates and values
   --  above U+10FFFF are rejected by Encode.
   subtype Code_Point is Wide_Wide_Character;

   --  Why UTF-8 decode or encode failed (implementers only).
   type Utf_8_Error_Group is (Invalid_Code_Point, Invalid_Sequence);

   package Internal_Errors is new Lovelace.Common.Internal_Error
     (Error_Group => Utf_8_Error_Group);

   --  Internal UTF-8 failure: group plus detail string.
   type Utf_8_Error is new Internal_Errors.Lovelace_Internal_Error;

   package Decode_Results is new Lovelace.Common.Result
     (T_Success => Code_Point,
      T_Error   => Utf_8_Error);

   package Encode_Results is new Lovelace.Common.Result
     (T_Success => Ada.Strings.Unbounded.Unbounded_String,
      T_Error   => Utf_8_Error);

   --  Byte length of the UTF-8 sequence at Index.
   --  Returns 0 if Index is not in Source'Range or the sequence is
   --  invalid.
   function Sequence_Length
     (Source : String;
      Index  : Positive) return Natural;

   --  Decode the scalar at Index. Failure is Invalid_Sequence.
   function Decode
     (Source : String;
      Index  : Positive) return Decode_Results.Result;

   --  Decode the scalar at Index. Valid is False (and Length is 0)
   --  when Index is out of range or the sequence is not valid UTF-8.
   procedure Decode
     (Source : String;
      Index  : Positive;
      Point  : out Code_Point;
      Length : out Natural;
      Valid  : out Boolean);

   --  Encode Point as UTF-8 bytes. Failure is Invalid_Code_Point.
   function Encode
     (Point : Code_Point) return Encode_Results.Result;

end Lovelace.Common.Utf_8;
