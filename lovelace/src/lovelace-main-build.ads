with Lovelace.Main.Arguments;

--  lovelace build: compile .love through LIR to WASM/WAT/WIT.

package Lovelace.Main.Build is

   --  Run the build command with Command_Arguments.
   --  @param Command_Arguments Tokens after 'build'.
   --  @return True on success; False after reporting errors.
   function Run (Command_Arguments : Arguments.String_Vectors.Vector) return Boolean;

end Lovelace.Main.Build;
