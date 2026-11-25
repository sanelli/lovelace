with AUnit.Assertions;

with Lovelace.Common.Utf_8;

package body Lovelace.Common.Tests.Utf_8 is

   function Decodes_As
     (Source : String; Index : Positive; Scalar_Value : Natural; Expected_Length : Natural) return Boolean;
   function Is_Rejected (Source : String; Index : Positive) return Boolean;

   --  Decode Source at Index and report whether it is valid with the expected scalar and length.
   function Decodes_As
     (Source : String; Index : Positive; Scalar_Value : Natural; Expected_Length : Natural) return Boolean
   is
      Point  : Lovelace.Common.Utf_8.Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      Lovelace.Common.Utf_8.Decode (Source, Index, Point, Length, Valid);
      return Valid and then Length = Expected_Length and then Wide_Wide_Character'Pos (Point) = Scalar_Value;
   end Decodes_As;

   --  True iff Decode rejects Source at Index with Length 0.
   function Is_Rejected (Source : String; Index : Positive) return Boolean is
      Point  : Lovelace.Common.Utf_8.Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      Lovelace.Common.Utf_8.Decode (Source, Index, Point, Length, Valid);
      return not Valid and then Length = 0 and then Lovelace.Common.Utf_8.Sequence_Length (Source, Index) = 0;
   end Is_Rejected;

   procedure Test_Decode_Boundaries (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Is_Rejected ([Character'Val (16#E0#), Character'Val (16#9F#), Character'Val (16#80#)], 1), "overlong 3-byte");
      AUnit.Assertions.Assert
        (Is_Rejected ([Character'Val (16#ED#), Character'Val (16#A0#), Character'Val (16#80#)], 1), "surrogate");
      AUnit.Assertions.Assert
        (Is_Rejected
           ([Character'Val (16#F0#), Character'Val (16#8F#), Character'Val (16#80#), Character'Val (16#80#)], 1),
         "overlong 4-byte");
      AUnit.Assertions.Assert
        (Is_Rejected
           ([Character'Val (16#F4#), Character'Val (16#90#), Character'Val (16#80#), Character'Val (16#80#)], 1),
         "above U+10FFFF");
      AUnit.Assertions.Assert (Is_Rejected ([Character'Val (16#C3#)], 1), "truncated 2-byte");
      AUnit.Assertions.Assert (Is_Rejected ([Character'Val (16#E2#), Character'Val (16#82#)], 1), "truncated 3-byte");
      AUnit.Assertions.Assert
        (Is_Rejected ([Character'Val (16#F0#), Character'Val (16#9F#), Character'Val (16#98#)], 1), "truncated 4-byte");
      AUnit.Assertions.Assert
        (Decodes_As ([Character'Val (16#ED#), Character'Val (16#9F#), Character'Val (16#BF#)], 1, 16#D7FF#, 3),
         "U+D7FF");
      AUnit.Assertions.Assert
        (Decodes_As
           ([Character'Val (16#F4#), Character'Val (16#8F#), Character'Val (16#BF#), Character'Val (16#BF#)],
            1,
            16#10FFFF#,
            4),
         "U+10FFFF");
   end Test_Decode_Boundaries;

   procedure Test_Decode_Malformed (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert (Is_Rejected ("abc", 4), "index past end");
      AUnit.Assertions.Assert (Is_Rejected ([Character'Val (16#80#)], 1), "stray continuation byte");
      AUnit.Assertions.Assert (Is_Rejected ([Character'Val (16#C0#), Character'Val (16#80#)], 1), "overlong lead C0");
      AUnit.Assertions.Assert
        (Is_Rejected
           ([Character'Val (16#F5#), Character'Val (16#80#), Character'Val (16#80#), Character'Val (16#80#)], 1),
         "lead F5");
      AUnit.Assertions.Assert (Is_Rejected ([Character'Val (16#C3#), 'A'], 1), "bad 2-byte continuation");
      AUnit.Assertions.Assert
        (Is_Rejected ([Character'Val (16#E2#), Character'Val (16#82#), 'A'], 1), "bad 3-byte continuation");
      AUnit.Assertions.Assert
        (Is_Rejected ([Character'Val (16#F0#), Character'Val (16#9F#), 'A', Character'Val (16#80#)], 1),
         "bad 4-byte continuation");
   end Test_Decode_Malformed;

   procedure Test_Decode_Valid (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert (Decodes_As ("A", 1, 16#41#, 1), "ASCII");
      AUnit.Assertions.Assert (Decodes_As ([Character'Val (16#C3#), Character'Val (16#A9#)], 1, 16#E9#, 2), "U+00E9");
      AUnit.Assertions.Assert
        (Decodes_As ([Character'Val (16#E2#), Character'Val (16#82#), Character'Val (16#AC#)], 1, 16#20AC#, 3),
         "U+20AC");
      AUnit.Assertions.Assert
        (Decodes_As
           ([Character'Val (16#F0#), Character'Val (16#9F#), Character'Val (16#98#), Character'Val (16#80#)],
            1,
            16#1F600#,
            4),
         "U+1F600");
      AUnit.Assertions.Assert
        (Decodes_As ("x" & Character'Val (16#C3#) & Character'Val (16#A9#), 2, 16#E9#, 2), "non-initial index");
   end Test_Decode_Valid;

end Lovelace.Common.Tests.Utf_8;
