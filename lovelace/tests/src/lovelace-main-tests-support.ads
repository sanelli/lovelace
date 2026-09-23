--  Shared helpers for CLI unit and integration tests.

package Lovelace.Main.Tests.Support is

   --  Path to the built lovelace executable, or "" if not found.
   --  @return Absolute or relative path usable with Spawn.
   function Locate_Lovelace_Executable return String;

end Lovelace.Main.Tests.Support;
