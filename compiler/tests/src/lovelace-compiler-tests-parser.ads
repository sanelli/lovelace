with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Parser.

package Lovelace.Compiler.Tests.Parser is

   --  Fixture for parser matrix tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Canonical module Empty; end.
   --  @param The_Test Unused fixture.
   procedure Test_Canonical_Module (The_Test : in out Fixture);

   --  Canonical multiline program Hello; begin end.
   --  @param The_Test Unused fixture.
   procedure Test_Canonical_Multiline (The_Test : in out Fixture);

   --  Dotted module name Foo.Bar is one qualified identifier.
   --  @param The_Test Unused fixture.
   procedure Test_Dotted_Module_Name (The_Test : in out Fixture);

   --  Empty token list yields Unexpected_End_Of_Input.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Tokens (The_Test : in out Fixture);

   --  end; after end is Unexpected_Token (Full_Stop required).
   --  @param The_Test Unused fixture.
   procedure Test_End_Semicolon (The_Test : in out Fixture);

   --  Unicode and @-prefixed identifiers name module and subroutine.
   --  @param The_Test Unused fixture.
   procedure Test_Identifier_Names (The_Test : in out Fixture);

   --  module with begin is Unexpected_Token (no begin in module_unit).
   --  @param The_Test Unused fixture.
   procedure Test_Module_Begin_Rejected (The_Test : in out Fixture);

   --  Module (identifier) as first keyword fails.
   --  @param The_Test Unused fixture.
   procedure Test_Module_Keyword_Case (The_Test : in out Fixture);

   --  Trailing dot in a qualified name is Unexpected_Token or end of input.
   --  @param The_Test Unused fixture.
   procedure Test_Module_Trailing_Dot (The_Test : in out Fixture);

   --  Spaced module forms parse the same empty Module_Unit.
   --  @param The_Test Unused fixture.
   procedure Test_Module_Whitespace (The_Test : in out Fixture);

   --  Trailing tokens and Program (identifier) as keyword fail.
   --  @param The_Test Unused fixture.
   procedure Test_Trailing_And_Keyword_Case (The_Test : in out Fixture);

   --  Glued and heavily spaced one-line program forms parse the same.
   --  @param The_Test Unused fixture.
   procedure Test_Whitespace_Variants (The_Test : in out Fixture);

   --  Wrong order and incomplete units fail.
   --  @param The_Test Unused fixture.
   procedure Test_Wrong_Order_And_Incomplete (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Parser;
