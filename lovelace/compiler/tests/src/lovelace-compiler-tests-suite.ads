with AUnit.Test_Suites;

--  Aggregate suite for lovelace_compiler AUnit tests.

package Lovelace.Compiler.Tests.Suite is

   --  Build the full test suite.
   --  @return Suite containing tokenizer fixtures.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Lovelace.Compiler.Tests.Suite;
