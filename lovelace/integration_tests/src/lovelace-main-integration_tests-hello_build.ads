with AUnit.Test_Fixtures;

--  Build Hello.love, validate artifacts, and run entrypoint when tools exist.

package Lovelace.Main.Integration_Tests.Hello_Build is

   --  Fixture for Hello sample end-to-end checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build the program sample; validate .wasm/.wat; run when wasmtime exists.
   --  @param The_Test Unused fixture.
   procedure Test_Build_Validate_And_Run (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Hello_Build;
