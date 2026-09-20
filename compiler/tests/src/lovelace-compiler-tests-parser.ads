with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Parser.

package Lovelace.Compiler.Tests.Parser is

   --  Fixture for parser matrix tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Canonical multiline program Hello; begin end.
   --  @param The_Test Unused fixture.
   procedure Test_Canonical_Multiline (The_Test : in out Fixture);

   --  Glued and heavily spaced one-line forms parse the same.
   --  @param The_Test Unused fixture.
   procedure Test_Whitespace_Variants (The_Test : in out Fixture);

   --  Unicode and @-prefixed identifiers name module and subroutine.
   --  @param The_Test Unused fixture.
   procedure Test_Identifier_Names (The_Test : in out Fixture);

   --  end; after end is Unexpected_Token (Full_Stop required).
   --  @param The_Test Unused fixture.
   procedure Test_End_Semicolon (The_Test : in out Fixture);

   --  Wrong order and incomplete units fail.
   --  @param The_Test Unused fixture.
   procedure Test_Wrong_Order_And_Incomplete (The_Test : in out Fixture);

   --  Trailing tokens and Program (identifier) as keyword fail.
   --  @param The_Test Unused fixture.
   procedure Test_Trailing_And_Keyword_Case (The_Test : in out Fixture);

   --  Empty token list yields Unexpected_End_Of_Input.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Tokens (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Parser;
