with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Common.Utf_8 decoding.

package Lovelace.Common.Tests.Utf_8 is

   --  Fixture for UTF-8 Decode tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  One-, two-, three- and four-byte sequences decode to the expected scalar and length.
   --  @param The_Test Unused fixture.
   procedure Test_Decode_Valid (The_Test : in out Fixture);

   --  Out-of-range index, bad lead bytes and bad continuation bytes are rejected.
   --  @param The_Test Unused fixture.
   procedure Test_Decode_Malformed (The_Test : in out Fixture);

   --  Overlong forms, surrogates, values above U+10FFFF and truncated sequences are rejected.
   --  @param The_Test Unused fixture.
   procedure Test_Decode_Boundaries (The_Test : in out Fixture);

   --  Encode covers ASCII, 2-byte, and invalid surrogate code points.
   --  @param The_Test Unused fixture.
   procedure Test_Encode (The_Test : in out Fixture);

end Lovelace.Common.Tests.Utf_8;
