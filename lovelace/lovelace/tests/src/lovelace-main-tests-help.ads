with AUnit.Test_Fixtures;

--  Tests for Lovelace.Main.Help.

package Lovelace.Main.Tests.Help is

   --  Fixture for help command tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  help compile succeeds (topic is known).
   --  @param The_Test Unused fixture.
   procedure Test_Help_Build_Topic (The_Test : in out Fixture);

   --  Spawned lovelace help stdout mentions compile.
   --  @param The_Test Unused fixture.
   procedure Test_Help_Mentions_Build (The_Test : in out Fixture);

end Lovelace.Main.Tests.Help;
