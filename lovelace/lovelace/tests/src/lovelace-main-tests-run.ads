with AUnit.Test_Fixtures;

--  In-process tests for Lovelace.Main.Dispatch.Run.

package Lovelace.Main.Tests.Run is

   --  Fixture for top-level dispatch tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Compile with no source fails and sets Failure exit status.
   --  @param The_Test Unused fixture.
   procedure Test_Compile_Failure_Dispatch (The_Test : in out Fixture);

   --  help succeeds and sets Success exit status (logo suppressed).
   --  @param The_Test Unused fixture.
   procedure Test_Help_Dispatch (The_Test : in out Fixture);

   --  Parameterless Main.Run parses the process command line and dispatches.
   --  @param The_Test Unused fixture.
   procedure Test_Main_Run_Wrapper (The_Test : in out Fixture);

   --  No command prints help on stderr and sets Failure exit status.
   --  @param The_Test Unused fixture.
   procedure Test_None_Dispatch (The_Test : in out Fixture);

   --  A failed parse reports to stderr and sets Failure exit status.
   --  @param The_Test Unused fixture.
   procedure Test_Parse_Failure_Dispatch (The_Test : in out Fixture);

   --  version succeeds and sets Success exit status (logo suppressed).
   --  @param The_Test Unused fixture.
   procedure Test_Version_Dispatch (The_Test : in out Fixture);

end Lovelace.Main.Tests.Run;
