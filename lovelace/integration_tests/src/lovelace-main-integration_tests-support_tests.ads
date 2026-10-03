with AUnit.Test_Fixtures;

--  Unit checks for Integration_Tests.Support locate/compose helpers.

package Lovelace.Main.Integration_Tests.Support_Tests is

   --  Fixture for Support helper unit tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Locate_Sample / Locate_Output_Root / Compose_Under return usable paths.
   --  @param The_Test Unused fixture.
   procedure Test_Locate_And_Compose (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Support_Tests;
