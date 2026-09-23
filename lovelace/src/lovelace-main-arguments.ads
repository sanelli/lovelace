with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

--  Parse lovelace [globals...] <command> [command-parameters...].

package Lovelace.Main.Arguments is

   package String_Vectors is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => String);

   --  Recognized top-level commands.
   --  @enum Build Compile a .love file.
   --  @enum Help Show help text.
   --  @enum Version Print the product version string.
   --  @enum None No command was present on the command line.
   type Command_Kind is (Build, Help, Version, None);

   --  Parsed command line.
   --  @field Show_Logo True unless --no-logo was given before the command.
   --  @field Colour_Enabled True unless --no-colour was given before the command.
   --  @field Command Selected command, or None.
   --  @field Command_Arguments Remaining tokens after the command name.
   --  @field Ok True when parsing succeeded.
   --  @field Error_Message UTF-8 detail when Ok is False.
   type Parsed_Arguments (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Show_Logo         : Boolean := True;
            Colour_Enabled    : Boolean := True;
            Command           : Command_Kind := None;
            Command_Arguments : String_Vectors.Vector;

         when False =>
            Error_Message : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   --  Parse Tokens as if they were the process argv (no program name).
   --  @param Tokens Global options, command, and command arguments.
   --  @return Parsed arguments, or a failure with Error_Message.
   function Parse (Tokens : String_Vectors.Vector) return Parsed_Arguments;

   --  Parse Ada.Command_Line into globals, command, and command arguments.
   --  @return Parsed arguments, or a failure with Error_Message.
   function Parse return Parsed_Arguments;

end Lovelace.Main.Arguments;
