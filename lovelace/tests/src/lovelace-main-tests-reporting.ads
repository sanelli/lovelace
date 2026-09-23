with AUnit.Test_Fixtures;

--  Tests for program-name vs .love basename (Reporting helpers).

package Lovelace.Main.Tests.Reporting is

   --  Fixture for Reporting mismatch helpers.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Love_Basename strips directories and .love.
   --  @param The_Test Unused fixture.
   procedure Test_Love_Basename (The_Test : in out Fixture);

end Lovelace.Main.Tests.Reporting;
