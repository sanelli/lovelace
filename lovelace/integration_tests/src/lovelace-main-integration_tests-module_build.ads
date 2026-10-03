with AUnit.Test_Fixtures;

--  Build empty and dotted module samples; no wasmtime run (no entrypoint).

package Lovelace.Main.Integration_Tests.Module_Build is

   --  Fixture for module sample end-to-end build checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build Empty.love and Foo.Bar.love; assert LIR/WASM/WAT/WIT artifacts.
   --  @param The_Test Unused fixture.
   procedure Test_Build_Module_Samples (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Module_Build;
