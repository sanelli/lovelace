with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Lovelace.Main.Help;
with Lovelace.Main.Tests.Support;

package body Lovelace.Main.Tests.Help is

   package Cli_Help renames Lovelace.Main.Help;

   function Capture_Help
     (Tokens : Cli_Arguments.String_Vectors.Vector; Path : String; To_Stderr : Boolean := False) return Boolean
   is
      File      : Ada.Text_IO.File_Type;
      Succeeded : Boolean;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      if To_Stderr then
         Ada.Text_IO.Set_Error (File);
         Succeeded := Cli_Help.Run (Tokens, To_Standard_Error => True);
         Ada.Text_IO.Set_Error (Ada.Text_IO.Standard_Error.all);
      else
         Ada.Text_IO.Set_Output (File);
         Succeeded := Cli_Help.Run (Tokens);
         Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output.all);
      end if;
      Ada.Text_IO.Close (File);
      return Succeeded;
   end Capture_Help;

   function Read_And_Delete (Path : String) return String is
      File     : Ada.Text_IO.File_Type;
      Contents : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Strings.Unbounded.Append (Contents, Ada.Text_IO.Get_Line (File) & ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
      return Ada.Strings.Unbounded.To_String (Contents);
   end Read_And_Delete;

   procedure Test_Help_Build_Topic (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens       : Cli_Arguments.String_Vectors.Vector;
      Discard_Path : constant String :=
        Ada.Directories.Compose (Ada.Directories.Current_Directory, "help-compile-out.txt");
      Discard_File : Ada.Text_IO.File_Type;
      Succeeded    : Boolean;
      Contents     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Tokens.Append ("compile");

      Ada.Text_IO.Create (Discard_File, Ada.Text_IO.Out_File, Discard_Path);
      Ada.Text_IO.Set_Output (Discard_File);
      Succeeded := Cli_Help.Run (Tokens);
      Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output.all);
      Ada.Text_IO.Close (Discard_File);

      AUnit.Assertions.Assert (Succeeded, "help compile");

      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Discard_Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Strings.Unbounded.Append (Contents, Ada.Text_IO.Get_Line (File) & ASCII.LF);
         end loop;
         Ada.Text_IO.Close (File);
      end;

      if Ada.Directories.Exists (Discard_Path) then
         Ada.Directories.Delete_File (Discard_Path);
      end if;

      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Contents), "--generate-tlir") > 0,
         "help compile mentions --generate-tlir");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Contents), "--warning-as-errors") > 0,
         "help compile mentions --warning-as-errors");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Contents), "--no-warnings") > 0,
         "help compile mentions --no-warnings");
   end Test_Help_Build_Topic;

   procedure Test_Help_General (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Path   : constant String := Ada.Directories.Compose (Ada.Directories.Current_Directory, "help-general-out.txt");
   begin
      AUnit.Assertions.Assert (Capture_Help (Tokens, Path), "empty help succeeds");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_And_Delete (Path), "Commands:") > 0, "general help lists commands");
   end Test_Help_General;

   procedure Test_Help_Mentions_Build (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lovelace_Path : constant String := Support.Locate_Lovelace_Executable;
      Output_Path   : constant String := Ada.Directories.Compose (Ada.Directories.Current_Directory, "help-out.txt");
      Args          : GNAT.OS_Lib.Argument_List_Access;
      Success       : Boolean;
      Return_Code   : Integer;
      Contents      : Ada.Strings.Unbounded.Unbounded_String;
   begin
      AUnit.Assertions.Assert (Lovelace_Path'Length > 0, "lovelace executable present");

      Args := new GNAT.OS_Lib.Argument_List'(1 => new String'("--no-logo"), 2 => new String'("help"));
      GNAT.OS_Lib.Spawn
        (Program_Name => Lovelace_Path,
         Args         => Args.all,
         Output_File  => Output_Path,
         Success      => Success,
         Return_Code  => Return_Code);
      GNAT.OS_Lib.Free (Args);

      AUnit.Assertions.Assert (Success, "spawn help");
      AUnit.Assertions.Assert (Return_Code = 0, "help exit 0");

      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Output_Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Strings.Unbounded.Append (Contents, Ada.Text_IO.Get_Line (File) & ASCII.LF);
         end loop;
         Ada.Text_IO.Close (File);
      end;

      if Ada.Directories.Exists (Output_Path) then
         Ada.Directories.Delete_File (Output_Path);
      end if;

      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Contents), "compile") > 0, "help mentions compile");
   end Test_Help_Mentions_Build;

   procedure Test_Help_Standard_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens : Cli_Arguments.String_Vectors.Vector;
      Path   : constant String := Ada.Directories.Compose (Ada.Directories.Current_Directory, "help-stderr-out.txt");
   begin
      AUnit.Assertions.Assert (Capture_Help (Tokens, Path, To_Stderr => True), "stderr general help");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_And_Delete (Path), "Commands:") > 0, "stderr has general help");
   end Test_Help_Standard_Error;

   procedure Test_Help_Topics_And_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Help_Topic    : Cli_Arguments.String_Vectors.Vector;
      Version_Topic : Cli_Arguments.String_Vectors.Vector;
      Unknown       : Cli_Arguments.String_Vectors.Vector;
      Extra         : Cli_Arguments.String_Vectors.Vector;
      Path          : constant String :=
        Ada.Directories.Compose (Ada.Directories.Current_Directory, "help-topics-out.txt");
   begin
      Help_Topic.Append ("help");
      AUnit.Assertions.Assert (Capture_Help (Help_Topic, Path), "help help");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_And_Delete (Path), "lovelace help") > 0, "help topic text");

      Version_Topic.Append ("version");
      AUnit.Assertions.Assert (Capture_Help (Version_Topic, Path), "help version");
      AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Read_And_Delete (Path), "version") > 0, "version topic text");

      Unknown.Append ("not-a-command");
      AUnit.Assertions.Assert (not Capture_Help (Unknown, Path), "unknown topic fails");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_And_Delete (Path), "Unknown help topic") > 0, "unknown message");

      Extra.Append ("compile");
      Extra.Append ("extra");
      AUnit.Assertions.Assert (not Capture_Help (Extra, Path), "extra args fail");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_And_Delete (Path), "Usage: lovelace help") > 0, "usage on extra");
   end Test_Help_Topics_And_Errors;

end Lovelace.Main.Tests.Help;
