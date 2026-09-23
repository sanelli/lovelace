with Lovelace.Main.Arguments;

--  lovelace build: compile .love through LIR to WASM/WAT/WIT.

package Lovelace.Main.Build is

   --  Selected backend artifact kinds for --output-format.
   --  @field Want_Wasm True when .wasm should be written.
   --  @field Want_Wat True when .wat should be written.
   type Output_Format_Set is record
      Want_Wasm : Boolean := True;
      Want_Wat  : Boolean := False;
   end record;

   --  Parse a --output-format value into Format_Set.
   --  @param Text One of wasm, wat, wasm,wat, or wat,wasm.
   --  @param Format_Set Filled on success.
   --  @return True when Text is a recognized format set.
   function Try_Parse_Output_Format
     (Text : String; Format_Set : out Output_Format_Set) return Boolean;

   --  Run the build command with Command_Arguments.
   --  @param Command_Arguments Tokens after 'build'.
   --  @return True on success; False after reporting errors.
   function Run
     (Command_Arguments : Arguments.String_Vectors.Vector) return Boolean;

end Lovelace.Main.Build;
