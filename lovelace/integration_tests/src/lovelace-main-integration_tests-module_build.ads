with AUnit.Test_Fixtures;

--  Build empty, dotted, and procedure module samples; no wasmtime run (no entrypoint).

package Lovelace.Main.Integration_Tests.Module_Build is

   --  Fixture for module sample end-to-end build checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build Empty.love, Foo.Bar.love, and Procedures.love; assert artifacts.
   --  @param The_Test Unused fixture.
   procedure Test_Build_Module_Samples (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Module_Build;
