with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Compile option helpers.

package Lovelace.Main.Tests.Compile is

   --  Fixture for compile option helper tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  --no-warnings accepts warning LV labels and rejects bad entries.

   --  @param The_Test Unused fixture.
   procedure Test_No_Warnings_Empty_Entry (The_Test : in out Fixture);

   --  @param The_Test Unused fixture.
   procedure Test_No_Warnings_List (The_Test : in out Fixture);

   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Invalid (The_Test : in out Fixture);

   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Values (The_Test : in out Fixture);

   --  @param The_Test Unused fixture.
   procedure Test_Warning_Policy_Cli (The_Test : in out Fixture);

end Lovelace.Main.Tests.Compile;
