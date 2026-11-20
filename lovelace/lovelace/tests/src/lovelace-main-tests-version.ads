with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Version.Product_Version.

package Lovelace.Main.Tests.Version is

   --  Fixture for version string tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Product_Version starts with the fixed release prefix.
   --  @param The_Test Unused fixture.
   procedure Test_Version_Prefix (The_Test : in out Fixture);

end Lovelace.Main.Tests.Version;
