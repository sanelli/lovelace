with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Build.Try_Parse_Output_Format.

package Lovelace.Main.Tests.Build is

   --  Fixture for build option helper tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Unknown format text is rejected.
   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Invalid (The_Test : in out Fixture);

   --  Recognized --output-format values.
   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Values (The_Test : in out Fixture);

end Lovelace.Main.Tests.Build;
