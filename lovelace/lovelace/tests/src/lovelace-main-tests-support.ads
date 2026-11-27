--  Shared helpers for CLI unit and integration tests.

package Lovelace.Main.Tests.Support is

   --  Path to the built lovelace executable, or "" if not found.
   --  @return Absolute or relative path usable with Spawn.
   function Locate_Lovelace_Executable return String;

   --  Read an entire text file; LF after each line.
   --  @param Path File to read.
   --  @return Contents, or "" when the file is missing.
   function Read_File (Path : String) return String;

   --  Redirect standard output (Ada current output) and standard error
   --  (file descriptor 2) to the given files until Stop_Capture.
   --  @param Stdout_Path File receiving Put_Line output.
   --  @param Stderr_Path File receiving Standard_Error output.
   procedure Start_Capture (Stdout_Path : String; Stderr_Path : String);

   --  Undo Start_Capture. Safe to call when no capture is active.
   procedure Stop_Capture;

end Lovelace.Main.Tests.Support;
