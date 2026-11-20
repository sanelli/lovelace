with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Main.Arguments;

package body Lovelace.Main.Tests.Arguments is

   package Cli_Arguments renames Lovelace.Main.Arguments;

   use type Cli_Arguments.Command_Kind;

   procedure Test_Global_After_Command_Is_Argument (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("build");
      Tokens.Append ("--no-logo");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "parse should succeed");

         when True  =>
            AUnit.Assertions.Assert (Parsed.Show_Logo, "logo still default");
            AUnit.Assertions.Assert
              (Parsed.Command = Cli_Arguments.Build, "build");
            AUnit.Assertions.Assert
              (Parsed.Command_Arguments.Element (1) = "--no-logo", "arg kept");
      end case;
   end Test_Global_After_Command_Is_Argument;

   procedure Test_Globals_Before_Command (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("--no-logo");
      Tokens.Append ("--no-colour");
      Tokens.Append ("build");
      Tokens.Append ("Hello.love");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "parse should succeed");

         when True  =>
            AUnit.Assertions.Assert (not Parsed.Show_Logo, "no logo");
            AUnit.Assertions.Assert (not Parsed.Colour_Enabled, "no colour");
            AUnit.Assertions.Assert
              (Parsed.Command = Cli_Arguments.Build, "build");
            AUnit.Assertions.Assert
              (Natural (Parsed.Command_Arguments.Length) = 1, "one arg");
            AUnit.Assertions.Assert
              (Parsed.Command_Arguments.Element (1) = "Hello.love", "path");
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
            AUnit.Assertions.Assert
              (Parsed.Command = Cli_Arguments.None, "none");
      end case;
   end Test_No_Command;

   procedure Test_Unknown_Global (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Parsed : Cli_Arguments.Parsed_Arguments;
   begin
      Tokens.Append ("--no-color");
      Tokens.Append ("build");
      Parsed := Cli_Arguments.Parse (Tokens);
      case Parsed.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "parse should fail");

         when False =>
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.Index
                 (Parsed.Error_Message, "unknown global")
               > 0,
               "error mentions unknown global");
      end case;
   end Test_Unknown_Global;

end Lovelace.Main.Tests.Arguments;
