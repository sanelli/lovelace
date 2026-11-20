with AUnit.Test_Suites;

--  AUnit suite for Lovelace.Main unit tests.

package Lovelace.Main.Tests.Suite is

   --  Build the CLI unit-test suite.
   --  @return Heap-allocated suite with all fixtures registered.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Lovelace.Main.Tests.Suite;
