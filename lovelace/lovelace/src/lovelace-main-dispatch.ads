with Lovelace.Main.Arguments;

--  Run a parsed CLI command (shared by Lovelace.Main.Run and AUnit).

package Lovelace.Main.Dispatch is

   --  Run the requested command from Parsed and set the process exit status.
   --  @param Parsed Globals, command, and command arguments from Arguments.Parse.
   procedure Run (Parsed : Arguments.Parsed_Arguments);

end Lovelace.Main.Dispatch;
