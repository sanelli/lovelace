with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Arguments.Parse.

package Lovelace.Main.Tests.Arguments is

   --  Fixture for argument-parser tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  A global-looking flag after the command stays in Command_Arguments.
   --  @param The_Test Unused fixture.
   procedure Test_Global_After_Command_Is_Argument (The_Test : in out Fixture);

   --  Globals before the command are accepted.
   --  @param The_Test Unused fixture.
   procedure Test_Globals_Before_Command (The_Test : in out Fixture);

   --  No tokens yields Command None.
   --  @param The_Test Unused fixture.
   procedure Test_No_Command (The_Test : in out Fixture);

   --  Unknown global before the command fails parse.
   --  @param The_Test Unused fixture.
   procedure Test_Unknown_Global (The_Test : in out Fixture);

end Lovelace.Main.Tests.Arguments;
