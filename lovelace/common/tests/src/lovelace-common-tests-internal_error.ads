with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Common.Internal_Error.

package Lovelace.Common.Tests.Internal_Error is

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Make / Detail / Report round-trip the message text.
   --  @param The_Test Unused fixture.
   procedure Test_Make_Detail_Report (The_Test : in out Fixture);

end Lovelace.Common.Tests.Internal_Error;
