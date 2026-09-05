with AUnit.Test_Suites;

--  Aggregate suite for lovelace_common AUnit tests.

package Lovelace.Common.Tests.Suite is

   --  Build the full test suite.
   --  @return Suite containing engine and token-class fixtures.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Lovelace.Common.Tests.Suite;
