with AUnit.Test_Suites;

--  Aggregate suite for lovelace_lir AUnit tests.

package Lovelace.Lir.Tests.Suite is

   --  Build the full test suite.
   --  @return Suite containing Binary_Format, Text_Format, Type_Codes, and
   --  Validation fixtures.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Lovelace.Lir.Tests.Suite;
