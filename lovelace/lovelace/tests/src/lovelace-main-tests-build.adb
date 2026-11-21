with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Lovelace.Compiler.Diagnostics;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Main.Build;
with Lovelace.Main.Tests.Support;

package body Lovelace.Main.Tests.Build is

   package Cli_Build renames Lovelace.Main.Build;
   package Diagnostics renames Lovelace.Compiler.Diagnostics;
   package Error_Codes renames Lovelace.Compiler.Error_Codes;

   use type Error_Codes.Error_Code;

   function Read_File (Path : String) return String;
   --  Read entire text file for Spawn capture assertions.

   function Spawn_Build
     (Lovelace_Path : String;
      Source_Path   : String;
      Output_Root   : String;
      Capture_Path  : String;
      Extra_1       : String := "";
      Extra_2       : String := "") return Integer;
   --  Spawn lovelace build with stderr merged into Capture_Path; return exit code.

   procedure Write_Unread_Local_Source (Path : String);
   --  Tiny program with one unread local (triggers LV00028).

   function Read_File (Path : String) return String is
      File     : Ada.Text_IO.File_Type;
      Contents : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Strings.Unbounded.Append
           (Contents, Ada.Text_IO.Get_Line (File) & ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Contents);
   end Read_File;

   function Spawn_Build
     (Lovelace_Path : String;
      Source_Path   : String;
      Output_Root   : String;
      Capture_Path  : String;
      Extra_1       : String := "";
      Extra_2       : String := "") return Integer
   is
      Args        : GNAT.OS_Lib.Argument_List_Access;
      Success     : Boolean;
      Return_Code : Integer;
   begin
      if Extra_1'Length = 0 then
         Args :=
           new GNAT.OS_Lib.Argument_List'
             (1 => new String'("--no-logo"),
              2 => new String'("--no-colour"),
              3 => new String'("build"),
              4 => new String'(Source_Path),
              5 => new String'("--force"),
              6 => new String'("--output-folder"),
              7 => new String'(Output_Root));
      elsif Extra_2'Length = 0 then
         Args :=
           new GNAT.OS_Lib.Argument_List'
             (1 => new String'("--no-logo"),
              2 => new String'("--no-colour"),
              3 => new String'("build"),
              4 => new String'(Source_Path),
              5 => new String'("--force"),
              6 => new String'("--output-folder"),
              7 => new String'(Output_Root),
              8 => new String'(Extra_1));
      else
         Args :=
           new GNAT.OS_Lib.Argument_List'
             (1 => new String'("--no-logo"),
              2 => new String'("--no-colour"),
              3 => new String'("build"),
              4 => new String'(Source_Path),
              5 => new String'("--force"),
              6 => new String'("--output-folder"),
              7 => new String'(Output_Root),
              8 => new String'(Extra_1),
              9 => new String'(Extra_2));
      end if;

      GNAT.OS_Lib.Spawn
        (Program_Name => Lovelace_Path,
         Args         => Args.all,
         Output_File  => Capture_Path,
         Success      => Success,
         Return_Code  => Return_Code,
         Err_To_Out   => True);
      GNAT.OS_Lib.Free (Args);
      AUnit.Assertions.Assert (Success, "spawn build");
      return Return_Code;
   end Spawn_Build;

   procedure Test_No_Warnings_List (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Policy : Diagnostics.Policy := Diagnostics.Default_Policy;
      Detail     : Ada.Strings.Unbounded.Unbounded_String;
      Code       : Error_Codes.Error_Code;
   begin
      AUnit.Assertions.Assert
        (Cli_Build.Try_Apply_No_Warnings
           ("LV00028,LV00029", The_Policy, Detail),
         "apply both warnings");
      AUnit.Assertions.Assert
        (Diagnostics.Is_Suppressed (The_Policy, Error_Codes.Unused_Variable),
         "LV00028 suppressed");
      AUnit.Assertions.Assert
        (Diagnostics.Is_Suppressed (The_Policy, Error_Codes.Unused_Assignment),
         "LV00029 suppressed");

      The_Policy := Diagnostics.Default_Policy;
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("", The_Policy, Detail),
         "reject empty");
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("LV99999", The_Policy, Detail),
         "reject unknown");
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("LV00027", The_Policy, Detail),
         "reject non-warning");
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("LV00028,", The_Policy, Detail),
         "reject trailing comma");

      AUnit.Assertions.Assert
        (Error_Codes.Try_From_Label ("LV00028", Code), "from label");
      AUnit.Assertions.Assert
        (Code = Error_Codes.Unused_Variable, "label maps to unused variable");
      declare
         Ignored  : Error_Codes.Error_Code;
         Rejected : constant Boolean :=
           not Error_Codes.Try_From_Label ("lv00028", Ignored);
      begin
         pragma Unreferenced (Ignored);
         AUnit.Assertions.Assert (Rejected, "case-sensitive");
      end;
   end Test_No_Warnings_List;

   procedure Test_Output_Format_Invalid (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Format_Set_A : Cli_Build.Output_Format_Set;
      Format_Set_B : Cli_Build.Output_Format_Set;
      Rejected_A   : constant Boolean :=
        not Cli_Build.Try_Parse_Output_Format ("wasmwat", Format_Set_A);
      Rejected_B   : constant Boolean :=
        not Cli_Build.Try_Parse_Output_Format ("", Format_Set_B);
   begin
      pragma Unreferenced (Format_Set_A, Format_Set_B);
      AUnit.Assertions.Assert (Rejected_A, "reject");
      AUnit.Assertions.Assert (Rejected_B, "empty");
   end Test_Output_Format_Invalid;

   procedure Test_Output_Format_Values (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Format_Set : Cli_Build.Output_Format_Set;
   begin
      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wasm", Format_Set), "wasm ok");
      AUnit.Assertions.Assert
        (Format_Set.Want_Wasm and then not Format_Set.Want_Wat, "wasm only");

      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wat", Format_Set), "wat ok");
      AUnit.Assertions.Assert
        (not Format_Set.Want_Wasm and then Format_Set.Want_Wat, "wat only");

      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wasm,wat", Format_Set),
         "wasm,wat ok");
      AUnit.Assertions.Assert
        (Format_Set.Want_Wasm and then Format_Set.Want_Wat, "both A");

      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wat,wasm", Format_Set),
         "wat,wasm ok");
      AUnit.Assertions.Assert
        (Format_Set.Want_Wasm and then Format_Set.Want_Wat, "both B");
   end Test_Output_Format_Values;

   procedure Test_Warning_Policy_Cli (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lovelace_Path : constant String := Support.Locate_Lovelace_Executable;
      Work_Dir      : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Current_Directory, "warning-policy-work");
      Source_Path   : constant String :=
        Ada.Directories.Compose (Work_Dir, "WarnUnused.love");
      Out_Default   : constant String :=
        Ada.Directories.Compose (Work_Dir, "out-default");
      Out_As_Errors : constant String :=
        Ada.Directories.Compose (Work_Dir, "out-as-errors");
      Out_Bad_Supp  : constant String :=
        Ada.Directories.Compose (Work_Dir, "out-bad-supp");
      Cap_Default   : constant String :=
        Ada.Directories.Compose (Work_Dir, "cap-default.txt");
      Cap_As_Errors : constant String :=
        Ada.Directories.Compose (Work_Dir, "cap-as-errors.txt");
      Cap_Bad_Supp  : constant String :=
        Ada.Directories.Compose (Work_Dir, "cap-bad-supp.txt");
      Code_Default  : Integer;
      Code_As_Err   : Integer;
      Code_Bad_Supp : Integer;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      if Ada.Directories.Exists (Work_Dir) then
         Ada.Directories.Delete_Tree (Work_Dir);
      end if;
      Ada.Directories.Create_Path (Work_Dir);
      Write_Unread_Local_Source (Source_Path);

      Code_Default :=
        Spawn_Build (Lovelace_Path, Source_Path, Out_Default, Cap_Default);
      AUnit.Assertions.Assert (Code_Default = 0, "warnings alone exit 0");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_File (Cap_Default), "LV00028") > 0,
         "default build surfaces LV00028");

      Code_As_Err :=
        Spawn_Build
          (Lovelace_Path,
           Source_Path,
           Out_As_Errors,
           Cap_As_Errors,
           "--warning-as-errors");
      AUnit.Assertions.Assert (Code_As_Err /= 0, "warning-as-errors fails");

      Code_Bad_Supp :=
        Spawn_Build
          (Lovelace_Path,
           Source_Path,
           Out_Bad_Supp,
           Cap_Bad_Supp,
           "--no-warnings",
           "LV00027");
      AUnit.Assertions.Assert (Code_Bad_Supp /= 0, "bad suppression fails");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Read_File (Cap_Bad_Supp), "LV00030") > 0,
         "bad suppression reports LV00030");

      if Ada.Directories.Exists (Work_Dir) then
         Ada.Directories.Delete_Tree (Work_Dir);
      end if;
   end Test_Warning_Policy_Cli;

   procedure Write_Unread_Local_Source (Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "program WarnUnused;");
      Ada.Text_IO.Put_Line (File, "declare");
      Ada.Text_IO.Put_Line (File, "   Unused : integer;");
      Ada.Text_IO.Put_Line (File, "begin");
      Ada.Text_IO.Put_Line (File, "end.");
      Ada.Text_IO.Close (File);
   end Write_Unread_Local_Source;

end Lovelace.Main.Tests.Build;
