with AUnit.Test_Fixtures;

--  AUnit fixtures for optional LIR source origins.

package Lovelace.Lir.Tests.Origins is

   --  Fixture for module and subroutine origin tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Create leaves module and subroutine origins absent.
   --  @param The_Test Unused fixture.
   procedure Test_Create_Absent (The_Test : in out Fixture);

   --  Set_Origin stores spans and shared filename; Validate still succeeds.
   --  @param The_Test Unused fixture.
   procedure Test_Set_Origin (The_Test : in out Fixture);

   --  Encode/Decode round-trip preserves origins (v1.0 layouts store them).
   --  @param The_Test Unused fixture.
   procedure Test_Codecs_Preserve_Origins (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Origins;
