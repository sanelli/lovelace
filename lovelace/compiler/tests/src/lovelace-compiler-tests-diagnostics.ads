with AUnit.Test_Fixtures;

--  AUnit fixtures for LV error labels, diagnostics formatting, and reporting maps.

package Lovelace.Compiler.Tests.Diagnostics is

   --  Fixture for diagnostics and reporting tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Error_Codes.Label returns the expected LV##### strings.
   --  @param The_Test Unused fixture.
   procedure Test_Error_Code_Labels (The_Test : in out Fixture);

   --  Format produces the required [error]/[warning] / line / caret / [LV] shape.
   --  @param The_Test Unused fixture.
   procedure Test_Format_Shape (The_Test : in out Fixture);

   --  Format extracts the right source line for LF, CRLF, CR, empty, invalid UTF-8,
   --  and past-the-end line numbers.
   --  @param The_Test Unused fixture.
   procedure Test_Format_Line_Endings (The_Test : in out Fixture);

   --  Format widens an inverted span to one caret.
   --  @param The_Test Unused fixture.
   procedure Test_Format_Inverted_Span (The_Test : in out Fixture);

   --  Format_Unbounded, Promote_Warnings, and repeated Suppress_Warning.
   --  @param The_Test Unused fixture.
   procedure Test_Policy_Accessors (The_Test : in out Fixture);

   --  Love_Basename strips directories and a final .love suffix (including dotted stems).
   --  @param The_Test Unused fixture.
   procedure Test_Love_Basename (The_Test : in out Fixture);

   --  Default_Severity, Effective_Severity, promote, and suppress policy.
   --  @param The_Test Unused fixture.
   procedure Test_Severity_Policy (The_Test : in out Fixture);

   --  To_Error_Code maps tokenizer and parser enums to LV kinds.
   --  @param The_Test Unused fixture.
   procedure Test_Stage_Mappings (The_Test : in out Fixture);

   --  Unit_Kind_Label returns program or module from Ast.Kind.
   --  @param The_Test Unused fixture.
   procedure Test_Unit_Kind_Label (The_Test : in out Fixture);

   --  Unit_Name_Matches_File compares the AST name to the path stem.
   --  @param The_Test Unused fixture.
   procedure Test_Unit_Name_Matches_File (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Diagnostics;
