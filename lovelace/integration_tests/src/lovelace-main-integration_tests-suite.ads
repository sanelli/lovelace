with AUnit.Test_Suites;

--  AUnit suite for optional CLI + wasmtime integration tests.

package Lovelace.Main.Integration_Tests.Suite is

   --  Build the integration-test suite.
   --  @return Heap-allocated suite.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Lovelace.Main.Integration_Tests.Suite;
