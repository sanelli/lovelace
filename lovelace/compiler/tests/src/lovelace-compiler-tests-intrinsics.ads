with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Intrinsics table matching and name split.

package Lovelace.Compiler.Tests.Intrinsics is

   --  Fixture for intrinsic closed-table tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  AST Match_Intrinsic rejects print when the sole formal is not default integer.
   --  @param The_Test Unused fixture.
   procedure Test_Ast_Non_Default_Integer (The_Test : in out Fixture);

   --  LIR Match_Intrinsic rejects print when the return type is not Unit.
   --  @param The_Test Unused fixture.
   procedure Test_Lir_Non_Unit_Return (The_Test : in out Fixture);

   --  Split_Lir_Subroutine_Name handles dotted and undotted LIR names.
   --  @param The_Test Unused fixture.
   procedure Test_Split_Lir_Name (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Intrinsics;
