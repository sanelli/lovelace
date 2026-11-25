with Ada.Directories;
with Ada.Strings.Fixed;
with AUnit.Assertions;

with Lovelace.Main.Tests.Support;
with Lovelace.Main.Terminal;
with Lovelace.Main.Version;

package body Lovelace.Main.Tests.Terminal is

   package Cli_Terminal renames Lovelace.Main.Terminal;

   Esc   : constant Character := ASCII.ESC;
   Red   : constant String := Esc & "[31m";
   Green : constant String := Esc & "[32m";
   Reset : constant String := Esc & "[0m";

   type Stream_Kind is (Standard_Out, Standard_Err);

   type Output_Kind is (Info, Error_Text, Logo, Report);

   function Capture (Kind : Output_Kind; Text : String; Colour : Boolean; Stream : Stream_Kind) return String;
   --  Run one terminal call with colour forced to Colour and return what was
   --  written to Stream. Colour and stream redirection are always restored.

   function Capture (Kind : Output_Kind; Text : String; Colour : Boolean; Stream : Stream_Kind) return String is
      Out_Path : constant String := Ada.Directories.Compose (Ada.Directories.Current_Directory, "terminal-stdout.txt");
      Err_Path : constant String := Ada.Directories.Compose (Ada.Directories.Current_Directory, "terminal-stderr.txt");
      Saved    : constant Boolean := Cli_Terminal.Colour_Enabled;
   begin
      Cli_Terminal.Set_Colour_Enabled (Colour);
      Support.Start_Capture (Out_Path, Err_Path);
      begin
         case Kind is
            when Info       =>
               Cli_Terminal.Put_Info (Text);

            when Error_Text =>
               Cli_Terminal.Put_Error_Text (Text);

            when Logo       =>
               Cli_Terminal.Put_Logo;

            when Report     =>
               Report_Error ("ctx", Text);
         end case;
      exception
         when others =>
            Support.Stop_Capture;
            Cli_Terminal.Set_Colour_Enabled (Saved);
            raise;
      end;
      Support.Stop_Capture;
      Cli_Terminal.Set_Colour_Enabled (Saved);

      declare
         Result : constant String :=
           Support.Read_File
             (case Stream is
                when Standard_Out => Out_Path,
                when Standard_Err => Err_Path);
      begin
         Ada.Directories.Delete_File (Out_Path);
         Ada.Directories.Delete_File (Err_Path);
         return Result;
      end;
   end Capture;

   procedure Test_Colour_Flag (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Saved : constant Boolean := Cli_Terminal.Colour_Enabled;
   begin
      Cli_Terminal.Set_Colour_Enabled (False);
      AUnit.Assertions.Assert (not Cli_Terminal.Colour_Enabled, "colour disabled");
      Cli_Terminal.Set_Colour_Enabled (True);
      AUnit.Assertions.Assert (Cli_Terminal.Colour_Enabled, "colour enabled");
      Cli_Terminal.Set_Colour_Enabled (Saved);
   end Test_Colour_Flag;

   procedure Test_Put_Error_Text_Coloured (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Text     : constant String :=
        "[err] one" & ASCII.LF & "[LV00028] two" & ASCII.LF & "plain" & ASCII.LF & "[x] short" & ASCII.LF & ASCII.LF;
      Expected : constant String :=
        Red
        & "[err] one"
        & Reset
        & ASCII.LF
        & Red
        & "[LV00028] two"
        & Reset
        & ASCII.LF
        & "plain"
        & ASCII.LF
        & "[x] short"
        & ASCII.LF
        & ASCII.LF;
      Output   : constant String := Capture (Error_Text, Text, True, Standard_Err);
   begin
      AUnit.Assertions.Assert (Output = Expected, "only [err] and [LV red");
   end Test_Put_Error_Text_Coloured;

   procedure Test_Put_Error_Text_No_Trailing_Newline (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Coloured : constant String := Capture (Error_Text, "[err] tail", True, Standard_Err);
      Plain    : constant String := Capture (Error_Text, "tail", True, Standard_Err);
      Short    : constant String := Capture (Error_Text, "[L", True, Standard_Err);
      Empty    : constant String := Capture (Error_Text, "", True, Standard_Err);
   begin
      AUnit.Assertions.Assert
        (Coloured = Red & "[err] tail" & Reset & ASCII.LF, "last line coloured without trailing LF");
      AUnit.Assertions.Assert (Plain = "tail" & ASCII.LF, "last plain line without trailing LF");
      AUnit.Assertions.Assert (Short = "[L" & ASCII.LF, "too short for [LV prefix stays plain");
      AUnit.Assertions.Assert (Empty = "", "empty text writes nothing");
   end Test_Put_Error_Text_No_Trailing_Newline;

   procedure Test_Put_Error_Text_Plain (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Text   : constant String := "[err] one" & ASCII.LF & "[LV00028] two" & ASCII.LF & "plain" & ASCII.LF;
      Output : constant String := Capture (Error_Text, Text, False, Standard_Err);
   begin
      AUnit.Assertions.Assert (Output = Text, "plain error text unchanged");
   end Test_Put_Error_Text_Plain;

   procedure Test_Put_Info_Coloured (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Output : constant String := Capture (Info, "hello", True, Standard_Out);
   begin
      AUnit.Assertions.Assert (Output = Green & "[info]" & Reset & " hello" & ASCII.LF, "coloured info line");
   end Test_Put_Info_Coloured;

   procedure Test_Put_Info_Plain (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Output : constant String := Capture (Info, "hello", False, Standard_Out);
   begin
      AUnit.Assertions.Assert (Output = "[info] hello" & ASCII.LF, "plain info line: " & Output);
   end Test_Put_Info_Plain;

   procedure Test_Put_Logo (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Output : constant String := Capture (Logo, "", False, Standard_Out);
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Output, "Lovelace compiler toolchain " & Lovelace.Main.Version.Product_Version) > 0,
         "logo shows product version");
      AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Output, "|____|") > 0, "logo art present");
   end Test_Put_Logo;

   procedure Test_Report_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Plain    : constant String := Capture (Report, "boom", False, Standard_Err);
      Coloured : constant String := Capture (Report, "boom", True, Standard_Err);
   begin
      AUnit.Assertions.Assert
        (Plain = "[err] ctx" & ASCII.LF & ASCII.LF & ASCII.LF & "boom" & ASCII.LF, "plain Report_Error block");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Coloured, Red & "[err] ctx" & Reset) = 1, "coloured Report_Error header");
   end Test_Report_Error;

end Lovelace.Main.Tests.Terminal;
