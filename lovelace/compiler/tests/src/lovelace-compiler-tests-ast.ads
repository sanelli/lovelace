with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Ast accessors.

package Lovelace.Compiler.Tests.Ast is

   --  Fixture for AST accessor edge cases.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Locals / Statements / Usings on a default (null) Block return empty sequences.
   --  @param The_Test Unused fixture.
   procedure Test_Null_Block_Accessors (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Ast;
