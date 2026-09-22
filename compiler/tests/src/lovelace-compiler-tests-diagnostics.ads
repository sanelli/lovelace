with AUnit.Test_Fixtures;

--  AUnit fixtures for LV error labels, diagnostics formatting, and reporting maps.

package Lovelace.Compiler.Tests.Diagnostics is

   --  Fixture for diagnostics and reporting tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Error_Codes.Label returns the expected LV##### strings.
   --  @param The_Test Unused fixture.
   procedure Test_Error_Code_Labels (The_Test : in out Fixture);

   --  Format produces the required [err] / line / caret / [LV] shape.
   --  @param The_Test Unused fixture.
   procedure Test_Format_Shape (The_Test : in out Fixture);

   --  Love_Basename strips directories and a final .love suffix.
   --  @param The_Test Unused fixture.
   procedure Test_Love_Basename (The_Test : in out Fixture);

   --  Program_Name_Matches_File compares the AST name to the path stem.
   --  @param The_Test Unused fixture.
   procedure Test_Program_Name_Matches_File (The_Test : in out Fixture);

   --  To_Error_Code maps tokenizer and parser enums to LV kinds.
   --  @param The_Test Unused fixture.
   procedure Test_Stage_Mappings (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Diagnostics;
