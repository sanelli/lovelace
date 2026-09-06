with AUnit.Test_Fixtures;

--  AUnit fixtures proving one regex per Lovelace token class.

package Lovelace.Common.Tests.Token_Classes is

   --  Identifier pattern shared by id and interpolation-hole tests.
   Identifier_Pattern : constant String := "[^0-9 \t\n\r\f+\-*/%;,.()\[\]<>""'{}][^ \t\n\r\f+\-*/%;,.()\[\]<>""'{}]*";

   --  Fixture for token-class pattern tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Block comments { ÃÂ¢ÃÂÃÂ¦ }.
   --  @param The_Test Unused fixture.
   procedure Test_Block_Comments (The_Test : in out Fixture);

   --  Character literals including emoji and \u{ÃÂ¢ÃÂÃÂ¦}.
   --  @param The_Test Unused fixture.
   procedure Test_Character_Literals (The_Test : in out Fixture);

   --  Combined $@"ÃÂ¢ÃÂÃÂ¦" multiline interpolated strings.
   --  @param The_Test Unused fixture.
   procedure Test_Combined_Strings (The_Test : in out Fixture);

   --  Identifiers including cafÃÂÃÂ© and emoji.
   --  @param The_Test Unused fixture.
   procedure Test_Identifiers (The_Test : in out Fixture);

   --  Interpolated $"ÃÂ¢ÃÂÃÂ¦" with {identifier} holes.
   --  @param The_Test Unused fixture.
   procedure Test_Interpolated_Strings (The_Test : in out Fixture);

   --  Keyword alternation.
   --  @param The_Test Unused fixture.
   procedure Test_Keywords (The_Test : in out Fixture);

   --  Multiline strings @"ÃÂ¢ÃÂÃÂ¦".
   --  @param The_Test Unused fixture.
   procedure Test_Multiline_Strings (The_Test : in out Fixture);

   --  Operators + - * / %, glued and spaced.
   --  @param The_Test Unused fixture.
   procedure Test_Operators (The_Test : in out Fixture);

   --  Parentheses and brackets.
   --  @param The_Test Unused fixture.
   procedure Test_Parentheses (The_Test : in out Fixture);

   --  Punctuation ; , .
   --  @param The_Test Unused fixture.
   procedure Test_Punctuation (The_Test : in out Fixture);

   --  Single-line strings with escapes; reject bare newline.
   --  @param The_Test Unused fixture.
   procedure Test_Single_Line_Strings (The_Test : in out Fixture);

end Lovelace.Common.Tests.Token_Classes;
