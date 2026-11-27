with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Main.Arguments;
with Lovelace.Main.Dispatch;
with Lovelace.Main.Terminal;
with Lovelace.Main.Tests.Support;

package body Lovelace.Main.Tests.Run is

   package Cli_Arguments renames Lovelace.Main.Arguments;
   package Cli_Dispatch renames Lovelace.Main.Dispatch;
   package Cli_Terminal renames Lovelace.Main.Terminal;

   type Capture_Result is record
      Stdout : Ada.Strings.Unbounded.Unbounded_String;
      Stderr : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Capture_Run (Parsed : Cli_Arguments.Parsed_Arguments) return Capture_Result;
   --  Call Dispatch.Run with streams captured; restore colour and clear Failure
   --  exit status so AUnit itself is not reported as failed.

   function Capture_Run (Parsed : Cli_Arguments.Parsed_Arguments) return Capture_Result is
      Out_Path     : constant String :=
        Ada.Directories.Compose (Ada.Directories.Current_Directory, "main-run-stdout.txt");
      Err_Path     : constant String :=
        Ada.Directories.Compose (Ada.Directories.Current_Directory, "main-run-stderr.txt");
      Saved_Colour : constant Boolean := Cli_Terminal.Colour_Enabled;
   begin
      Cli_Terminal.Set_Colour_Enabled (False);
      Support.Start_Capture (Out_Path, Err_Path);
      begin
         Cli_Dispatch.Run (Parsed);
      exception
         when others =>
            Support.Stop_Capture;
            Cli_Terminal.Set_Colour_Enabled (Saved_Colour);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
            raise;
      end;
      Support.Stop_Capture;
      Cli_Terminal.Set_Colour_Enabled (Saved_Colour);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);

      declare
         Result : constant Capture_Result :=
           (Stdout => Ada.Strings.Unbounded.To_Unbounded_String (Support.Read_File (Out_Path)),
            Stderr => Ada.Strings.Unbounded.To_Unbounded_String (Support.Read_File (Err_Path)));
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         if Ada.Directories.Exists (Err_Path) then
            Ada.Directories.Delete_File (Err_Path);
         end if;
         return Result;
      end;
   end Capture_Run;

   procedure Test_Compile_Failure_Dispatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed   : Cli_Arguments.Parsed_Arguments;
      Captured : Capture_Result;
   begin
      Parsed :=
        (Ok                => True,
         Show_Logo         => False,
         Colour_Enabled    => False,
         Command           => Cli_Arguments.Compile,
         Command_Arguments => Cli_Arguments.String_Vectors.Empty_Vector);
      Captured := Capture_Run (Parsed);
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Captured.Stderr), "missing .love source") > 0,
         "compile failure message");
   end Test_Compile_Failure_Dispatch;

   procedure Test_Help_Dispatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed   : Cli_Arguments.Parsed_Arguments;
      Captured : Capture_Result;
   begin
      Parsed :=
        (Ok                => True,
         Show_Logo         => False,
         Colour_Enabled    => False,
         Command           => Cli_Arguments.Help,
         Command_Arguments => Cli_Arguments.String_Vectors.Empty_Vector);
      Captured := Capture_Run (Parsed);
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Captured.Stdout), "Commands:") > 0,
         "help lists commands");
   end Test_Help_Dispatch;

   procedure Test_Main_Run_Wrapper (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Out_Path     : constant String :=
        Ada.Directories.Compose (Ada.Directories.Current_Directory, "main-run-wrapper-out.txt");
      Err_Path     : constant String :=
        Ada.Directories.Compose (Ada.Directories.Current_Directory, "main-run-wrapper-err.txt");
      Saved_Colour : constant Boolean := Cli_Terminal.Colour_Enabled;
      Stderr       : Ada.Strings.Unbounded.Unbounded_String;
   begin
      --  Under AUnit, Argument_Count is typically 0 so Parse yields Command None.
      Cli_Terminal.Set_Colour_Enabled (False);
      Support.Start_Capture (Out_Path, Err_Path);
      begin
         Lovelace.Main.Run;
      exception
         when others =>
            Support.Stop_Capture;
            Cli_Terminal.Set_Colour_Enabled (Saved_Colour);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
            raise;
      end;
      Support.Stop_Capture;
      Cli_Terminal.Set_Colour_Enabled (Saved_Colour);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
      Stderr := Ada.Strings.Unbounded.To_Unbounded_String (Support.Read_File (Err_Path));
      if Ada.Directories.Exists (Out_Path) then
         Ada.Directories.Delete_File (Out_Path);
      end if;
      if Ada.Directories.Exists (Err_Path) then
         Ada.Directories.Delete_File (Err_Path);
      end if;
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Stderr), "Commands:") > 0
         or else Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Stderr), "[err]") > 0,
         "main run wrapper dispatched");
   end Test_Main_Run_Wrapper;

   procedure Test_None_Dispatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed   : Cli_Arguments.Parsed_Arguments;
      Captured : Capture_Result;
   begin
      Parsed :=
        (Ok                => True,
         Show_Logo         => True,
         Colour_Enabled    => False,
         Command           => Cli_Arguments.None,
         Command_Arguments => Cli_Arguments.String_Vectors.Empty_Vector);
      Captured := Capture_Run (Parsed);
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Captured.Stdout), "Lovelace") > 0
         or else Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Captured.Stderr), "Commands:") > 0,
         "none shows logo or help");
   end Test_None_Dispatch;

   procedure Test_Parse_Failure_Dispatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed   : Cli_Arguments.Parsed_Arguments;
      Captured : Capture_Result;
   begin
      Parsed := (Ok => False, Error_Message => Ada.Strings.Unbounded.To_Unbounded_String ("unknown command 'nope'"));
      Captured := Capture_Run (Parsed);
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Captured.Stderr), "unknown command") > 0,
         "parse failure message");
   end Test_Parse_Failure_Dispatch;

   procedure Test_Version_Dispatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parsed   : Cli_Arguments.Parsed_Arguments;
      Captured : Capture_Result;
   begin
      Parsed :=
        (Ok                => True,
         Show_Logo         => False,
         Colour_Enabled    => False,
         Command           => Cli_Arguments.Version,
         Command_Arguments => Cli_Arguments.String_Vectors.Empty_Vector);
      Captured := Capture_Run (Parsed);
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Captured.Stdout), "0.0.1-alpha.1") > 0,
         "version text");
   end Test_Version_Dispatch;

end Lovelace.Main.Tests.Run;
