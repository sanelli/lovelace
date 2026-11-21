with AUnit.Test_Fixtures;

--  Compile module samples and validate artifacts; no entrypoint run.

package Lovelace.Main.Integration_Tests.Module_Compile is

   --  Fixture for module sample end-to-end build and validate checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Compile Empty, Foo.Bar, Procedures, ExportProcedures, SameModuleCall,
   --  Overload, and emoji-module; validate.
   --  @param The_Test Unused fixture.
   procedure Test_Build_And_Validate (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Module_Compile;
