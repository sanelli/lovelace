with AUnit.Assertions;

with Lovelace.Compiler.Ast;

package body Lovelace.Compiler.Tests.Ast is

   package Ast renames Lovelace.Compiler.Ast;

   procedure Test_Null_Block_Accessors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Null_Block : Ast.Block;
   begin
      AUnit.Assertions.Assert
        (Ast.Length (Ast.Locals (Null_Block)) = 0, "null locals empty");
      AUnit.Assertions.Assert
        (Ast.Length (Ast.Statements (Null_Block)) = 0, "null statements empty");
      AUnit.Assertions.Assert
        (Ast.Length (Ast.Usings (Null_Block)) = 0, "null usings empty");
   end Test_Null_Block_Accessors;

end Lovelace.Compiler.Tests.Ast;
