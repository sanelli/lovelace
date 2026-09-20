with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Lir.Binary and related opcodes/types.

package Lovelace.Lir.Tests.Binary_Format is

   --  Fixture for binary codec and value-type stream tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Empty named module round-trips in memory.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module_Memory (The_Test : in out Fixture);

   --  Empty named module round-trips via temp .lir file.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module_File (The_Test : in out Fixture);

   --  Encode starts with LIR NUL magic and version 1.0.
   --  @param The_Test Unused fixture.
   procedure Test_Magic_And_Version (The_Test : in out Fixture);

   --  UTF-8 and emoji module/subroutine names round-trip.
   --  @param The_Test Unused fixture.
   procedure Test_Unicode_Names (The_Test : in out Fixture);

   --  Depends, empty body, noop, several noops, export, entrypoint.
   --  @param The_Test Unused fixture.
   procedure Test_Subroutines_And_Flags (The_Test : in out Fixture);

   --  Encoded noop is two 0x00 bytes; Encoded_Length is 2.
   --  @param The_Test Unused fixture.
   procedure Test_Noop_Encoding (The_Test : in out Fixture);

   --  Each Value_Type as lone parameter and lone result round-trips.
   --  @param The_Test Unused fixture.
   procedure Test_All_Value_Types (The_Test : in out Fixture);

   --  Decode rejects bad magic, version 2.0, truncated, trailing, bad opcode/type/UTF-8.
   --  @param The_Test Unused fixture.
   procedure Test_Decode_Failures (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Binary_Format;
