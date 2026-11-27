with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Terminal and Lovelace.Main.Report_Error.

package Lovelace.Main.Tests.Terminal is

   --  Fixture for terminal output tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Set_Colour_Enabled is reflected by Colour_Enabled.
   --  @param The_Test Unused fixture.
   procedure Test_Colour_Flag (The_Test : in out Fixture);

   --  Put_Info without colour writes a plain [info] line.
   --  @param The_Test Unused fixture.
   procedure Test_Put_Info_Plain (The_Test : in out Fixture);

   --  Put_Info with colour wraps [info] in green escapes.
   --  @param The_Test Unused fixture.
   procedure Test_Put_Info_Coloured (The_Test : in out Fixture);

   --  Put_Error_Text without colour leaves all lines plain.
   --  @param The_Test Unused fixture.
   procedure Test_Put_Error_Text_Plain (The_Test : in out Fixture);

   --  Put_Error_Text with colour reddens [err] and [LV lines only.
   --  @param The_Test Unused fixture.
   procedure Test_Put_Error_Text_Coloured (The_Test : in out Fixture);

   --  Put_Error_Text handles text without a trailing newline and empty text.
   --  @param The_Test Unused fixture.
   procedure Test_Put_Error_Text_No_Trailing_Newline (The_Test : in out Fixture);

   --  Put_Logo prints the product banner.
   --  @param The_Test Unused fixture.
   procedure Test_Put_Logo (The_Test : in out Fixture);

   --  Main.Report_Error writes the [err] block to standard error.
   --  @param The_Test Unused fixture.
   procedure Test_Report_Error (The_Test : in out Fixture);

end Lovelace.Main.Tests.Terminal;
