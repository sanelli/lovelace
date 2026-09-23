with AUnit.Test_Fixtures;

--  Build Hello.love and run wasmtime on .wasm and .wat when available.

package Lovelace.Main.Integration_Tests.Hello_Build is

   --  Fixture for Hello sample end-to-end checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build the sample and run wasmtime on both artifacts (or inconclusive).
   --  @param The_Test Unused fixture.
   procedure Test_Build_And_Wasmtime (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Hello_Build;
