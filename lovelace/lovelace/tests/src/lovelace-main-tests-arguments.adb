with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Main.Arguments;

package body Lovelace.Main.Tests.Arguments is

   package Cli_Arguments renames Lovelace.Main.Arguments;

   use type Cli_Arguments.Command_Kind;

   procedure Test_Commands (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Help_Tokens    : Cli_Arguments.String_Vectors.Vector;
      Version_Tokens : Cli_Arguments.String_Vectors.Vector;
      Help_Parsed    : Cli_Arguments.Parsed_Arguments;
      Version_Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Help_Tokens.Append ("help");
      Help_Tokens.Append ("compile");
      Help_Parsed := Cli_Arguments.Parse (Help_Tokens);
      case Help_Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "help parse should succeed");

         when True  =>
            AUnit.Assertions.Assert (Help_Parsed.Command = Cli_Arguments.Help, "help");
            AUnit.Assertions.Assert (Natural (Help_Parsed.Command_Arguments.Length) = 1, "help topic");
            AUnit.Assertions.Assert (Help_Parsed.Command_Arguments.Element (1) = "compile", "compile topic");
      end case;

      Version_Tokens.Append ("--no-logo");
      Version_Tokens.Append ("version");
      Version_Parsed := Cli_Arguments.Parse (Version_Tokens);
      case Version_Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "version parse should succeed");

         when True  =>
            AUnit.Assertions.Assert (not Version_Parsed.Show_Logo, "no logo");
            AUnit.Assertions.Assert (Version_Parsed.Command = Cli_Arguments.Version, "version");
      end case;
   end Test_Commands;

   procedure Test_Global_After_Command_Is_Argument (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("compile");
      Tokens.Append ("--no-logo");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "parse should succeed");

         when True  =>
            AUnit.Assertions.Assert (Parsed.Show_Logo, "logo still default");
            AUnit.Assertions.Assert (Parsed.Command = Cli_Arguments.Compile, "compile");
            AUnit.Assertions.Assert (Parsed.Command_Arguments.Element (1) = "--no-logo", "arg kept");
      end case;
   end Test_Global_After_Command_Is_Argument;

   procedure Test_Globals_Before_Command (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("--no-logo");
      Tokens.Append ("--no-colour");
      Tokens.Append ("compile");
      Tokens.Append ("Hello.love");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "parse should succeed");

         when True  =>
            AUnit.Assertions.Assert (not Parsed.Show_Logo, "no logo");
            AUnit.Assertions.Assert (not Parsed.Colour_Enabled, "no colour");
            AUnit.Assertions.Assert (Parsed.Command = Cli_Arguments.Compile, "compile");
            AUnit.Assertions.Assert (Natural (Parsed.Command_Arguments.Length) = 1, "one arg");
            AUnit.Assertions.Assert (Parsed.Command_Arguments.Element (1) = "Hello.love", "path");
      end case;
   end Test_Globals_Before_Command;

   procedure Test_No_Command (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed : constant Cli_Arguments.Parsed_Arguments :=
        Cli_Arguments.Parse (Cli_Arguments.String_Vectors.Empty_Vector);
   begin
      case Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "empty should succeed");

         when True  =>
            AUnit.Assertions.Assert (Parsed.Command = Cli_Arguments.None, "none");
      end case;
   end Test_No_Command;

   procedure Test_Process_Command_Line (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed : constant Cli_Arguments.Parsed_Arguments := Cli_Arguments.Parse;
   begin
      case Parsed.Ok is
         when False =>
            --  AUnit may pass harness flags; a failed parse is still exercised.
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.Length (Parsed.Error_Message) > 0, "command-line parse error");

         when True  =>
            AUnit.Assertions.Assert
              (Parsed.Command = Cli_Arguments.None
               or else Parsed.Command = Cli_Arguments.Help
               or else Parsed.Command = Cli_Arguments.Version
               or else Parsed.Command = Cli_Arguments.Compile,
               "command-line parse ok");
      end case;
   end Test_Process_Command_Line;

   procedure Test_Unknown_Command (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("frobnicate");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "parse should fail");

         when False =>
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.Index (Parsed.Error_Message, "unknown command") > 0,
               "error mentions unknown command");
      end case;
   end Test_Unknown_Command;

   procedure Test_Unknown_Global (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("--no-color");
      Tokens.Append ("compile");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "parse should fail");

         when False =>
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.Index (Parsed.Error_Message, "unknown global") > 0,
               "error mentions unknown global");
      end case;
   end Test_Unknown_Global;

   procedure Test_Unknown_Option_As_Command (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      --  Leading "--" tokens are globals; an unknown one fails before command
      --  selection (so "--no-logo --force" is "unknown global", not "expected a
      --  command").
      Tokens.Append ("--no-logo");
      Tokens.Append ("--force");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "parse should fail");

         when False =>
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.Index (Parsed.Error_Message, "unknown global") > 0,
               "error mentions unknown global");
      end case;
   end Test_Unknown_Option_As_Command;

end Lovelace.Main.Tests.Arguments;
