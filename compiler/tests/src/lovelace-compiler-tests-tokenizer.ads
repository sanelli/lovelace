with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Tokenizer.

package Lovelace.Compiler.Tests.Tokenizer is

   --  Fixture for tokenizer matrix tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Empty source and whitespace-only source yield no tokens.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_And_Whitespace (The_Test : in out Fixture);

   --  program begin end. is three keywords and Full_Stop, with spans.
   --  @param The_Test Unused fixture.
   procedure Test_Program_Begin_End (The_Test : in out Fixture);

   --  Space, tab, LF, CR, and NBSP between tokens yield the same kinds.
   --  @param The_Test Unused fixture.
   procedure Test_Whitespace_Kinds (The_Test : in out Fixture);

   --  end; and end ; are the same two tokens.
   --  @param The_Test Unused fixture.
   procedure Test_Glued_Punctuation (The_Test : in out Fixture);

   --  Program and BEGIN are identifiers, not keywords.
   --  @param The_Test Unused fixture.
   procedure Test_Keyword_Case (The_Test : in out Fixture);

   --  programmer and programbegin are single identifiers.
   --  @param The_Test Unused fixture.
   procedure Test_Keyword_Reservation (The_Test : in out Fixture);

   --  ASCII identifiers name, foo_bar, _x, foo2.
   --  @param The_Test Unused fixture.
   procedure Test_Ascii_Identifiers (The_Test : in out Fixture);

   --  Leading ASCII digits are Unrecognized_Symbol.
   --  @param The_Test Unused fixture.
   procedure Test_Leading_Digits (The_Test : in out Fixture);

   --  café and emoji identifiers built via Utf_8.Encode.
   --  @param The_Test Unused fixture.
   procedure Test_Unicode_Identifiers (The_Test : in out Fixture);

   --  @foo is an identifier; @ alone and foo@bar report Unrecognized_Symbol.
   --  @param The_Test Unused fixture.
   procedure Test_At_Prefix (The_Test : in out Fixture);

   --  $ % ^ ~ ' ? are Unrecognized_Symbol.
   --  @param The_Test Unused fixture.
   procedure Test_Unrecognized_Identifier_Characters (The_Test : in out Fixture);

   --  Newline updates Line and Column.
   --  @param The_Test Unused fixture.
   procedure Test_Newline_Line_Column (The_Test : in out Fixture);

   --  Omitted filename is absent on every token.
   --  @param The_Test Unused fixture.
   procedure Test_Filename_Omitted (The_Test : in out Fixture);

   --  Provided filename is shared across every token.
   --  @param The_Test Unused fixture.
   procedure Test_Filename_Shared_On_Tokens (The_Test : in out Fixture);

   --  Provided filename is shared across every error.
   --  @param The_Test Unused fixture.
   procedure Test_Filename_Shared_On_Errors (The_Test : in out Fixture);

   --  +, comma, and quote are Unrecognized_Symbol.
   --  @param The_Test Unused fixture.
   procedure Test_Unrecognized_Symbols (The_Test : in out Fixture);

   --  program + begin $ end. reports two Unrecognized_Symbol errors.
   --  @param The_Test Unused fixture.
   procedure Test_Multi_Error (The_Test : in out Fixture);

   --  Invalid UTF-8 is reported and scanning continues.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Utf_8 (The_Test : in out Fixture);

   --  Clean begin succeeds (built-in patterns compile).
   --  @param The_Test Unused fixture.
   procedure Test_Clean_Begin (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Tokenizer;
