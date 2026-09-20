with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Ir_Generator.

package Lovelace.Compiler.Tests.Ir_Generator is

   --  Fixture for IR Generator matrix tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Canonical program Hello; begin end. lowers to matching LIR structure and origins.
   --  @param The_Test Unused fixture.
   procedure Test_Canonical_Multiline (The_Test : in out Fixture);

   --  Tokenize+Parse with a filename label shares storage on LIR module and subroutine.
   --  @param The_Test Unused fixture.
   procedure Test_Filename_Shared (The_Test : in out Fixture);

   --  Unicode and @-prefixed identifiers preserve names into LIR.
   --  @param The_Test Unused fixture.
   procedure Test_Identifier_Names (The_Test : in out Fixture);

   --  Hand-built AST with export-only flags maps export without entrypoint.
   --  @param The_Test Unused fixture.
   procedure Test_Export_Only_Flags (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Ir_Generator;
