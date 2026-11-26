with AUnit.Test_Fixtures;

with Lovelace.Main.Arguments;

--  Tests for Lovelace.Main.Help.

package Lovelace.Main.Tests.Help is

   --  Fixture for help command tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  help compile succeeds (topic is known).
   --  @param The_Test Unused fixture.
   procedure Test_Help_Build_Topic (The_Test : in out Fixture);

   --  Empty help args print general usage and succeed.
   --  @param The_Test Unused fixture.
   procedure Test_Help_General (The_Test : in out Fixture);

   --  Spawned lovelace help stdout mentions compile.
   --  @param The_Test Unused fixture.
   procedure Test_Help_Mentions_Build (The_Test : in out Fixture);

   --  To_Standard_Error => True still succeeds for general help.
   --  @param The_Test Unused fixture.
   procedure Test_Help_Standard_Error (The_Test : in out Fixture);

   --  help help / help version succeed; unknown topic and extra args fail.
   --  @param The_Test Unused fixture.
   procedure Test_Help_Topics_And_Errors (The_Test : in out Fixture);

private

   package Cli_Arguments renames Lovelace.Main.Arguments;

   --  Run Help with stdout/stderr redirected to Path; return success.
   --  @param Tokens Help command arguments.
   --  @param Path Capture file path.
   --  @param To_Stderr When True, redirect Standard_Error.
   --  @return Whether Help.Run reported success.
   function Capture_Help
     (Tokens : Cli_Arguments.String_Vectors.Vector; Path : String; To_Stderr : Boolean := False) return Boolean;

   --  Read Path as text and delete the file.
   --  @param Path File to read.
   --  @return File contents.
   function Read_And_Delete (Path : String) return String;

end Lovelace.Main.Tests.Help;
