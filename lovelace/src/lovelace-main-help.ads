with Lovelace.Main.Arguments;

--  Help text for the Lovelace CLI.

package Lovelace.Main.Help is

   --  Print help for the whole tool or for a named command.
   --  @param Command_Arguments Optional command name (e.g. build).
   --  @param To_Standard_Error When True, write help to standard error.
   --  @return True on success; False when the topic is unknown.
   function Run
     (Command_Arguments : Arguments.String_Vectors.Vector;
      To_Standard_Error : Boolean := False) return Boolean;

end Lovelace.Main.Help;
