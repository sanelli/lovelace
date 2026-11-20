--  Colour-aware terminal output for the Lovelace CLI.

package Lovelace.Main.Terminal is

   --  Enable or disable ANSI colour on subsequent writes.
   --  @param Enabled True to colour [info]/[err]/[LV prefixes.
   procedure Set_Colour_Enabled (Enabled : Boolean);

   --  True when colour escapes are currently enabled.
   --  @return Colour flag.
   function Colour_Enabled return Boolean;

   --  Write the Lovelace startup logo to standard output.
   procedure Put_Logo;

   --  Write one informational line: green [info] prefix then Message.
   --  @param Message UTF-8 text after the prefix.
   procedure Put_Info (Message : String);

   --  Write Text to standard error; colour [err] and [LV lines when enabled.
   --  @param Text Multi-line UTF-8 diagnostic text.
   procedure Put_Error_Text (Text : String);

end Lovelace.Main.Terminal;
