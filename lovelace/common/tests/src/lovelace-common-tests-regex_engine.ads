with AUnit.Test_Fixtures;

--  AUnit fixtures for Thompson NFA engine mechanics.

package Lovelace.Common.Tests.Regex_Engine is

   --  Fixture for regex engine mechanic tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Alternation prefers a successful branch.
   --  @param The_Test Unused fixture.
   procedure Test_Alternation (The_Test : in out Fixture);

   --  Dot matches any scalar.
   --  @param The_Test Unused fixture.
   procedure Test_Any (The_Test : in out Fixture);

   --  Character class and negation.
   --  @param The_Test Unused fixture.
   procedure Test_Classes (The_Test : in out Fixture);

   --  Concatenation of literals.
   --  @param The_Test Unused fixture.
   procedure Test_Concatenation (The_Test : in out Fixture);

   --  Invalid patterns fail Compile.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Patterns (The_Test : in out Fixture);

   --  Literal ASCII match.
   --  @param The_Test Unused fixture.
   procedure Test_Literal (The_Test : in out Fixture);

   --  Match_Prefix From offset.
   --  @param The_Test Unused fixture.
   procedure Test_Offsets (The_Test : in out Fixture);

   --  Star, plus, and question quantifiers.
   --  @param The_Test Unused fixture.
   procedure Test_Quantifiers (The_Test : in out Fixture);

   --  Multi-byte UTF-8 literals and \u{ÃÂ¢ÃÂÃÂ¦}.
   --  @param The_Test Unused fixture.
   procedure Test_Utf_8_Literals (The_Test : in out Fixture);

end Lovelace.Common.Tests.Regex_Engine;
