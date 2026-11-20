--  Lovelace command-line interface: entry point and shared error reporting.

package Lovelace.Main is

   --  Parse the process command line, run the requested command, and set the
   --  process exit status (success when the command succeeded).
   procedure Run;

   --  Print an unlocated CLI diagnostic block to standard error, in the shape
   --  "[err] Context" followed by blank lines and Description (no LV code).
   --  @param Context UTF-8 context shown after the [err] label (path or command).
   --  @param Description UTF-8 message body.
   procedure Report_Error (Context : String; Description : String);

end Lovelace.Main;
