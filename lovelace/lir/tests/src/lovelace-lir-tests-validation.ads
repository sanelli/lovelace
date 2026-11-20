with AUnit.Test_Fixtures;

--  AUnit fixtures for Modules.Validate failures.

package Lovelace.Lir.Tests.Validation is

   --  Fixture for validation error cases.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Empty names, duplicate subroutines, two entrypoints, self-depend.
   --  @param The_Test Unused fixture.
   procedure Test_Validate_Failures (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Validation;
