with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Build option helpers.

package Lovelace.Main.Tests.Build is

   --  Fixture for build option helper tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  --no-warnings accepts warning LV labels and rejects bad entries.
   --  @param The_Test Unused fixture.
   procedure Test_No_Warnings_List (The_Test : in out Fixture);

   --  Unknown format text is rejected.
   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Invalid (The_Test : in out Fixture);

   --  Recognized --output-format values.
   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Values (The_Test : in out Fixture);

   --  Spawned build: unread local surfaces LV00028 (exit 0); --warning-as-errors
   --  fails; --no-warnings LV00027 fails with LV00030.
   --  @param The_Test Unused fixture.
   procedure Test_Warning_Policy_Cli (The_Test : in out Fixture);

end Lovelace.Main.Tests.Build;
