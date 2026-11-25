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
   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String);
   --  Put Name back to Value, or unset it when it was not set before.
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

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Env.Set (Name, Value);
      elsif Env.Exists (Name) then
         Env.Clear (Name);
      end if;
   end Restore_Env;

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
             (Paths.Join_Root
                (Paths.Join_Root (Lovelace_Home, "lib"), "augusta"),
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

   procedure Test_Candidates_Empty_Segments (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Empty    : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates ("");
      Trailing : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates ("a.");
      Double   : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates ("a..b");
      Lone_Dot : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates (".");
      Leading  : constant Paths.Path_Sequence :=
        Paths.Module_To_Relative_Candidates (".a");
   begin
      AUnit.Assertions.Assert
        (Natural (Empty.Length) = 0, "empty name has no candidates");

      AUnit.Assertions.Assert
        (Natural (Trailing.Length) = 2, "trailing dot count");
      AUnit.Assertions.Assert
        (Trailing.Element (1) = "a/.love", "trailing dot slash form");
      AUnit.Assertions.Assert
        (Trailing.Element (2) = "a..love", "trailing dot dot form");

      AUnit.Assertions.Assert
        (Natural (Double.Length) = 4, "double dot count");
      AUnit.Assertions.Assert
        (Double.Element (1) = "a//b.love", "double dot slash slash");
      AUnit.Assertions.Assert
        (Double.Element (4) = "a..b.love", "double dot dot dot");

      AUnit.Assertions.Assert
        (Natural (Lone_Dot.Length) = 2, "lone dot count");
      AUnit.Assertions.Assert
        (Lone_Dot.Element (1) = "/.love", "lone dot slash form");
      AUnit.Assertions.Assert
        (Natural (Leading.Length) = 2, "leading dot count");
      AUnit.Assertions.Assert
        (Leading.Element (1) = "/a.love", "leading dot slash form");
   end Test_Candidates_Empty_Segments;

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

   procedure Test_Home_Fallbacks (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Saved_Home_Set    : constant Boolean := Env.Exists ("HOME");
      Saved_Home        : constant String :=
        (if Saved_Home_Set then Env.Value ("HOME") else "");
      Saved_Profile_Set : constant Boolean := Env.Exists ("USERPROFILE");
      Saved_Profile     : constant String :=
        (if Saved_Profile_Set then Env.Value ("USERPROFILE") else "");
      Profile_Dir       : constant String := Temp_Dir ("userprofile");
      Work              : constant String := Temp_Dir ("no_home");
      Source            : constant String :=
        Paths.Join_Root (Work, "Caller.love");
      Includes          : Paths.Path_Sequence;
      Roots             : Paths.Path_Sequence;
      Version           : constant String := Lovelace.Common.Release.Version;
   begin
      Write_Text_File (Source, "program Caller; begin end.");
      Clear_Augusta_Env;

      begin
         --  Empty HOME is ignored; USERPROFILE supplies the home directory.
         Env.Set ("HOME", "");
         Env.Set ("USERPROFILE", Profile_Dir);
         AUnit.Assertions.Assert
           (Paths.Augusta_Root
            = Paths.Join_Root
                (Paths.Join_Root
                   (Paths.Join_Root
                      (Paths.Join_Root (Profile_Dir, ".lovelace"), "lib"),
                    "augusta"),
                 Version),
            "USERPROFILE fallback");

         --  Unset HOME is ignored the same way.
         Env.Clear ("HOME");
         AUnit.Assertions.Assert
           (Paths.Augusta_Root
            = Paths.Join_Root
                (Paths.Join_Root
                   (Paths.Join_Root
                      (Paths.Join_Root (Profile_Dir, ".lovelace"), "lib"),
                    "augusta"),
                 Version),
            "USERPROFILE fallback without HOME");

         --  Neither variable usable: no Augusta slot at all.
         Env.Set ("USERPROFILE", "");
         AUnit.Assertions.Assert
           (Paths.Augusta_Root = "", "no home gives empty Augusta root");
         Env.Clear ("USERPROFILE");
         AUnit.Assertions.Assert
           (Paths.Augusta_Root = "", "unset home gives empty Augusta root");

         Roots := Paths.Default_Search_Roots (Source, Includes);
         AUnit.Assertions.Assert
           (Natural (Roots.Length) >= 1
            and then Roots.Element (1) = Ada.Directories.Full_Name (Work),
            "source dir root without Augusta slot");
         for Index in 1 .. Natural (Roots.Length) loop
            AUnit.Assertions.Assert
              (Roots.Element (Index)
               /= Ada.Directories.Full_Name (Profile_Dir),
               "no Augusta root added");
         end loop;
      exception
         when others =>
            Restore_Env ("HOME", Saved_Home_Set, Saved_Home);
            Restore_Env ("USERPROFILE", Saved_Profile_Set, Saved_Profile);
            Clear_Augusta_Env;
            raise;
      end;
      Restore_Env ("HOME", Saved_Home_Set, Saved_Home);
      Restore_Env ("USERPROFILE", Saved_Profile_Set, Saved_Profile);
      Clear_Augusta_Env;
   end Test_Home_Fallbacks;

   procedure Test_Join_Root (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert (Paths.Join_Root ("", "x") = "x", "empty root");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r", "") = "r", "empty relative");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r", "x") = "r/x", "plain join");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r/", "x") = "r/x", "root slash");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r\", "x") = "r\x", "root backslash");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r/", "/x") = "r/x", "root slash, relative slash");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r/", "\x") = "r/x",
         "root slash, relative backslash");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r\", "/x") = "r\x",
         "root backslash, relative slash");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r", "/x") = "r/x", "relative slash");
      AUnit.Assertions.Assert
        (Paths.Join_Root ("r", "\x") = "r\x", "relative backslash");
   end Test_Join_Root;

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

   procedure Test_Resolve_Duplicate_And_Invalid_Roots
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Root     : constant String := Temp_Dir ("resolve_dup");
      Roots    : Paths.Path_Sequence;
      Result   : Paths.Resolve_Result;
      Mod_Path : constant String := Paths.Join_Root (Root, "Solo.love");
   begin
      Write_Text_File (Mod_Path, "module Solo; end.");
      Roots.Append (Paths.Join_Root (Root, "missing"));
      Roots.Append ("bad" & ASCII.NUL & "root");
      Roots.Append (Root);
      Roots.Append (Root & "/.");
      Roots.Append (Root);

      Result := Paths.Resolve_Module_File ("Solo", Roots);
      AUnit.Assertions.Assert
        (Result.Status = Paths.Unique,
         "same file through several roots is unique, got "
         & Paths.Resolve_Status'Image (Result.Status));
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Result.Path)
         = Ada.Directories.Full_Name (Mod_Path),
         "deduplicated path");

      --  A directory with the candidate name is not a module file.
      Ada.Directories.Create_Path (Paths.Join_Root (Root, "DirOnly.love"));
      Result := Paths.Resolve_Module_File ("DirOnly", Roots);
      AUnit.Assertions.Assert
        (Result.Status = Paths.Not_Found,
         "directory named like a module is not found");
   end Test_Resolve_Duplicate_And_Invalid_Roots;

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

   procedure Test_Search_Roots_Edge_Cases (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work       : constant String := Temp_Dir ("edge_roots");
      Include    : constant String := Paths.Join_Root (Work, "include");
      Plain_File : constant String := Paths.Join_Root (Work, "plain.txt");
      Bad_Path   : constant String := "bad" & ASCII.NUL & "path";
      Source     : constant String := Paths.Join_Root (Work, "Caller.love");
      Includes   : Paths.Path_Sequence;
      Roots      : Paths.Path_Sequence;
      Count      : Natural := 0;
   begin
      Ada.Directories.Create_Path (Include);
      Write_Text_File (Plain_File, "not a directory");
      Write_Text_File (Source, "program Caller; begin end.");
      Clear_Augusta_Env;
      Env.Set ("AUGUSTA_HOME", Paths.Join_Root (Work, "missing_augusta"));

      Includes.Append (Paths.Join_Root (Work, "missing_include"));
      Includes.Append (Plain_File);
      Includes.Append ("");
      Includes.Append (Bad_Path);
      Includes.Append (Include);
      Includes.Append (Include);
      Includes.Append (Work);
      Roots := Paths.Default_Search_Roots (Source, Includes);

      for Index in 1 .. Natural (Roots.Length) loop
         if Roots.Element (Index) = Ada.Directories.Full_Name (Include) then
            Count := Count + 1;
         end if;
         AUnit.Assertions.Assert
           (Roots.Element (Index) /= Ada.Directories.Full_Name (Plain_File),
            "file is not a root");
         AUnit.Assertions.Assert
           (Roots.Element (Index)
            /= Ada.Directories.Full_Name
                 (Paths.Join_Root (Work, "missing_include")),
            "missing directory is not a root");
         AUnit.Assertions.Assert
           (Roots.Element (Index)'Length > 0, "empty path is not a root");
      end loop;
      AUnit.Assertions.Assert (Count = 1, "duplicate include appears once");
      AUnit.Assertions.Assert
        (Roots.Element (1) = Ada.Directories.Full_Name (Work),
         "source dir first and deduplicated");

      --  A path with no containing directory falls back to the current directory.
      Includes.Clear;
      Roots := Paths.Default_Search_Roots ("/", Includes);
      AUnit.Assertions.Assert
        (Natural (Roots.Length) >= 1
         and then Roots.Element (1) = Ada.Directories.Current_Directory,
         "root path falls back to current directory");
      Clear_Augusta_Env;
   end Test_Search_Roots_Edge_Cases;

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
