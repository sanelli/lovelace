with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Lovelace.Main.Arguments;
with Lovelace.Main.Help;
with Lovelace.Main.Tests.Support;

package body Lovelace.Main.Tests.Help is

   package Cli_Arguments renames Lovelace.Main.Arguments;
   package Cli_Help renames Lovelace.Main.Help;

   procedure Test_Help_Build_Topic (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Tokens       : Cli_Arguments.String_Vectors.Vector;
      Discard_Path : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Current_Directory, "help-build-out.txt");
      Discard_File : Ada.Text_IO.File_Type;
      Succeeded    : Boolean;
   begin
      Tokens.Append ("build");

      Ada.Text_IO.Create (Discard_File, Ada.Text_IO.Out_File, Discard_Path);
      Ada.Text_IO.Set_Output (Discard_File);
      Succeeded := Cli_Help.Run (Tokens);
      Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output.all);
      Ada.Text_IO.Close (Discard_File);

      if Ada.Directories.Exists (Discard_Path) then
         Ada.Directories.Delete_File (Discard_Path);
      end if;

      AUnit.Assertions.Assert (Succeeded, "help build");
   end Test_Help_Build_Topic;

   procedure Test_Help_Mentions_Build (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lovelace_Path : constant String := Support.Locate_Lovelace_Executable;
      Output_Path   : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Current_Directory, "help-out.txt");
      Args          : GNAT.OS_Lib.Argument_List_Access;
      Success       : Boolean;
      Return_Code   : Integer;
      Contents      : Ada.Strings.Unbounded.Unbounded_String;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Args :=
        new GNAT.OS_Lib.Argument_List'
          (1 => new String'("--no-logo"), 2 => new String'("help"));
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
            Ada.Strings.Unbounded.Append
              (Contents, Ada.Text_IO.Get_Line (File) & ASCII.LF);
         end loop;
         Ada.Text_IO.Close (File);
      end;

      if Ada.Directories.Exists (Output_Path) then
         Ada.Directories.Delete_File (Output_Path);
      end if;

      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index
           (Ada.Strings.Unbounded.To_String (Contents), "build")
         > 0,
         "help mentions build");
   end Test_Help_Mentions_Build;

end Lovelace.Main.Tests.Help;
