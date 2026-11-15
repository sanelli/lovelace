with AUnit.Test_Fixtures;

--  Build program samples, validate artifacts, and run entrypoints when tools exist.

package Lovelace.Main.Integration_Tests.Hello_Build is

   --  Fixture for program sample end-to-end checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build Hello.love; validate .wasm/.wat; run when wasmtime exists.
   --  @param The_Test Unused fixture.
   procedure Test_Build_Validate_And_Run (The_Test : in out Fixture);

   --  Build ImportDecl.love (leading import); validate and run like Hello.
   --  @param The_Test Unused fixture.
   procedure Test_Import_Decl_Build_Validate_And_Run (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Hello_Build;
