with AUnit.Test_Fixtures;

--  Build module samples and validate artifacts; no entrypoint run.

package Lovelace.Main.Integration_Tests.Module_Build is

   --  Fixture for module sample end-to-end build and validate checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build Empty, Foo.Bar, and Procedures; assert artifacts and validate.
   --  @param The_Test Unused fixture.
   procedure Test_Build_And_Validate (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Module_Build;
