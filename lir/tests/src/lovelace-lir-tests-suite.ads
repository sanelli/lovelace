with AUnit.Test_Suites;

--  Aggregate suite for lovelace_lir AUnit tests.

package Lovelace.Lir.Tests.Suite is

   --  Build the full test suite.
   --  @return Suite containing LIR fixtures (none until step 9).
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Lovelace.Lir.Tests.Suite;
