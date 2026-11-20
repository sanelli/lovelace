with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with AUnit.Assertions;

with Lovelace.Common.Release;
with Lovelace.Compiler.Module_Path;

package body Lovelace.Compiler.Tests.Module_Path is

   package Env renames Ada.Environment_Variables;
   package Paths renames Lovelace.Compiler.Module_Path;

   use type Paths.Resolve_Status;

   procedure Clear_Augusta_Env;
   function Temp_Dir (Leaf : String) return String;
   procedure Write_Text_File (Path : String; Contents : String);

   procedure Clear_Augusta_Env is
   begin
      if Env.Exists ("AUGUSTA_HOME") then
         Env.Clear ("AUGUSTA_HOME");
      end if;
      if Env.Exists ("LOVELACE_HOME") then
         Env.Clear ("LOVELACE_HOME");
      end if;
   end Clear_Augusta_Env;

   function Temp_Dir (Leaf : String) return String is
      Base : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Compose (".tests", "module_path"), Leaf);
   begin
      if Ada.Directories.Exists (Base) then
         Ada.Directories.Delete_Tree (Base);
      end if;
      Ada.Directories.Create_Path (Base);
      return Ada.Directories.Full_Name (Base);
   end Temp_Dir;

   procedure Test_Augusta_Root_Slot (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Augusta       : constant String := Temp_Dir ("augusta_home");
      Lovelace_Home : constant String := Temp_Dir ("lovelace_home");
   begin
      Clear_Augusta_Env;
      Env.Set ("AUGUSTA_HOME", Augusta);
      Env.Set ("LOVELACE_HOME", Lovelace_Home);
      AUnit.Assertions.Assert
        (Paths.Augusta_Root = Augusta, "AUGUSTA_HOME wins");

      Env.Clear ("AUGUSTA_HOME");
      AUnit.Assertions.Assert
        (Paths.Augusta_Root
         = Paths.Join_Root
             (Paths.Join_Root (Paths.Join_Root (Lovelace_Home, "lib"), "augusta"),
              Lovelace.Common.Release.Version),
         "LOVELACE_HOME fallback");

      Env.Clear ("LOVELACE_HOME");
      declare
         Home : constant String :=
           (if Env.Exists ("HOME") then Env.Value ("HOME") else "");
      begin
         if Home'Length > 0 then
            AUnit.Assertions.Assert
              (Paths.Augusta_Root
               = Paths.Join_Root
                   (Paths.Join_Root
                      (Paths.Join_Root
                         (Paths.Join_Root (Home, ".lovelace"), "lib"),
                       "augusta"),
                    Lovelace.Common.Release.Version),
               "default ~/.lovelace/lib/augusta/<version>");
         end if;
      end;
   end Test_Augusta_Root_Slot;

   procedure Test_Default_Search_Roots (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work       : constant String := Temp_Dir ("defaults");
      Source_Dir : constant String := Paths.Join_Root (Work, "src");
      Include    : constant String := Paths.Join_Root (Work, "include");
      Augusta    : constant String := Temp_Dir ("defaults_augusta");
      Source     : constant String :=
        Paths.Join_Root (Source_Dir, "Caller.love");
      Includes   : Paths.Path_Sequence;
      Roots      : Paths.Path_Sequence;
      Found_Src  : Boolean := False;
      Found_Inc  : Boolean := False;
      Found_Aug  : Boolean := False;
   begin
      Ada.Directories.Create_Path (Source_Dir);
      Ada.Directories.Create_Path (Include);
      Write_Text_File (Source, "program Caller; begin end.");

      Clear_Augusta_Env;
      Env.Set ("AUGUSTA_HOME", Augusta);
      Includes.Append (Include);
      Roots := Paths.Default_Search_Roots (Source, Includes);

      for Index in 1 .. Natural (Roots.Length) loop
         declare
            Root : constant String := Roots.Element (Index);
         begin
            if Root = Ada.Directories.Full_Name (Source_Dir) then
               Found_Src := True;
            elsif Root = Ada.Directories.Full_Name (Include) then
               Found_Inc := True;
            elsif Root = Ada.Directories.Full_Name (Augusta) then
               Found_Aug := True;
            end if;
         end;
      end loop;

      AUnit.Assertions.Assert (Found_Src, "source dir root");
      AUnit.Assertions.Assert (Found_Inc, "include root");
      AUnit.Assertions.Assert (Found_Aug, "augusta root");
      Clear_Augusta_Env;
   end Test_Default_Search_Roots;

   procedure Test_Relative_Candidates (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Single : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates ("Lib");
      Triple : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates ("a.b.c");
   begin
      AUnit.Assertions.Assert (Natural (Single.Length) = 1, "single count");
      AUnit.Assertions.Assert (Single.Element (1) = "Lib.love", "single form");

      AUnit.Assertions.Assert (Natural (Triple.Length) = 4, "triple count");
      AUnit.Assertions.Assert (Triple.Element (1) = "a/b/c.love", "all slash");
      AUnit.Assertions.Assert
        (Triple.Element (2) = "a/b.c.love", "slash then dot");
      AUnit.Assertions.Assert
        (Triple.Element (3) = "a.b/c.love", "dot then slash");
      AUnit.Assertions.Assert (Triple.Element (4) = "a.b.c.love", "all dot");
   end Test_Relative_Candidates;

   procedure Test_Resolve_Unique_Missing_Ambiguous (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Root       : constant String := Temp_Dir ("resolve");
      Roots      : Paths.Path_Sequence;
      Missing    : Paths.Resolve_Result;
      Unique     : Paths.Resolve_Result;
      Ambiguous  : Paths.Resolve_Result;
      Slash_Path : constant String := Paths.Join_Root (Root, "a/b/c.love");
      Dot_Path   : constant String := Paths.Join_Root (Root, "a.b.c.love");
   begin
      Roots.Append (Root);

      Missing := Paths.Resolve_Module_File ("missing.mod", Roots);
      AUnit.Assertions.Assert (Missing.Status = Paths.Not_Found, "missing");

      Write_Text_File (Slash_Path, "module a.b.c; end.");
      Unique := Paths.Resolve_Module_File ("a.b.c", Roots);
      AUnit.Assertions.Assert
        (Unique.Status = Paths.Unique,
         "unique status got " & Paths.Resolve_Status'Image (Unique.Status));
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Unique.Path) = Slash_Path,
         "unique path");

      Write_Text_File (Dot_Path, "module a.b.c; end.");
      Ambiguous := Paths.Resolve_Module_File ("a.b.c", Roots);
      AUnit.Assertions.Assert
        (Ambiguous.Status = Paths.Ambiguous, "ambiguous status");
      AUnit.Assertions.Assert
        (Natural (Ambiguous.Matches.Length) = 2, "ambiguous count");
   end Test_Resolve_Unique_Missing_Ambiguous;

   procedure Write_Text_File (Path : String; Contents : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Contents);
      Ada.Text_IO.Close (File);
   end Write_Text_File;

end Lovelace.Compiler.Tests.Module_Path;
