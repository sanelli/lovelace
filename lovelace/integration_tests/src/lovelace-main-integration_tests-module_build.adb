with Ada.Directories;
with AUnit.Assertions;
with GNAT.OS_Lib;

package body Lovelace.Main.Integration_Tests.Module_Build is

   use type GNAT.OS_Lib.String_Access;

   procedure Assert_Build_Artifacts (Output_Root : String; Unit_Name : String; Message : String);
   --  Assert obj/Unit_Name.lir and bin Unit_Name .wasm/.wat/.wit exist.

   procedure Build_Sample (Lovelace_Path : String; Sample_Path : String; Output_Root : String; Message : String);
   --  Run lovelace build --force for Sample_Path into Output_Root.

   function Compose_Under (Root, Relative : String) return String;
   --  Ada.Directories.Compose for Root / Relative.

   function Locate_Lovelace return String;
   --  Path to lovelace under ../bin or on PATH.

   function Locate_Output_Root return String;
   --  Repo .tests/integration-tests/modules output folder.

   function Locate_Sample (File_Name : String) return String;
   --  Path to samples/module/File_Name relative to this crate.

   procedure Assert_Build_Artifacts (Output_Root : String; Unit_Name : String; Message : String) is
      Obj_Dir : constant String := Compose_Under (Output_Root, "obj");
      Bin_Dir : constant String := Compose_Under (Output_Root, "bin");
   begin
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Obj_Dir, Unit_Name & ".lir")), Message & ": " & Unit_Name & ".lir");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Bin_Dir, Unit_Name & ".wasm")), Message & ": " & Unit_Name & ".wasm");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Bin_Dir, Unit_Name & ".wat")), Message & ": " & Unit_Name & ".wat");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Bin_Dir, Unit_Name & ".wit")), Message & ": " & Unit_Name & ".wit");
   end Assert_Build_Artifacts;

   procedure Build_Sample (Lovelace_Path : String; Sample_Path : String; Output_Root : String; Message : String) is
      Build_Args  : GNAT.OS_Lib.Argument_List_Access;
      Return_Code : Integer;
   begin
      AUnit.Assertions.Assert (Ada.Directories.Exists (Sample_Path), Message & ": sample present");

      Build_Args :=
        new GNAT.OS_Lib.Argument_List'
          (1 => new String'("--no-logo"),
           2 => new String'("build"),
           3 => new String'(Sample_Path),
           4 => new String'("--output-format"),
           5 => new String'("wasm,wat"),
           6 => new String'("--output-folder"),
           7 => new String'(Output_Root),
           8 => new String'("--force"));

      Return_Code := GNAT.OS_Lib.Spawn (Program_Name => Lovelace_Path, Args => Build_Args.all);
      GNAT.OS_Lib.Free (Build_Args);
      AUnit.Assertions.Assert (Return_Code = 0, Message & ": build exit 0");
   end Build_Sample;

   function Compose_Under (Root, Relative : String) return String is
   begin
      return Ada.Directories.Compose (Root, Relative);
   end Compose_Under;

   function Locate_Lovelace return String is
      Relative : constant String := Ada.Directories.Compose (Ada.Directories.Compose ("..", "bin"), "lovelace");
   begin
      if Ada.Directories.Exists (Relative) then
         return Relative;
      end if;

      declare
         On_Path : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("lovelace");
      begin
         if On_Path = null then
            return "";
         end if;

         declare
            Result : constant String := On_Path.all;
         begin
            GNAT.OS_Lib.Free (On_Path);
            return Result;
         end;
      end;
   end Locate_Lovelace;

   function Locate_Output_Root return String is
      Repository_Root : constant String :=
        Ada.Directories.Full_Name
          (Ada.Directories.Compose (Ada.Directories.Compose (Ada.Directories.Current_Directory, ".."), ".."));
   begin
      return
        Ada.Directories.Compose
          (Ada.Directories.Compose (Ada.Directories.Compose (Repository_Root, ".tests"), "integration-tests"),
           "modules");
   end Locate_Output_Root;

   function Locate_Sample (File_Name : String) return String is
   begin
      return
        Ada.Directories.Compose
          (Ada.Directories.Compose
             (Ada.Directories.Compose
                (Ada.Directories.Compose ("..", ".."), "samples"),
              "module"),
           File_Name);
   end Locate_Sample;

   procedure Test_Build_Module_Samples (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lovelace_Path : constant String := Locate_Lovelace;
      Output_Root   : constant String := Locate_Output_Root;
      Empty_Sample  : constant String := Locate_Sample ("Empty.love");
      Dotted_Sample : constant String := Locate_Sample ("Foo.Bar.love");
   begin
      AUnit.Assertions.Assert (Lovelace_Path'Length > 0, "lovelace executable present");

      if Ada.Directories.Exists (Output_Root) then
         Ada.Directories.Delete_Tree (Output_Root);
      end if;
      Ada.Directories.Create_Path (Output_Root);

      Build_Sample
        (Lovelace_Path => Lovelace_Path, Sample_Path => Empty_Sample, Output_Root => Output_Root, Message => "Empty");
      Assert_Build_Artifacts (Output_Root => Output_Root, Unit_Name => "Empty", Message => "Empty");

      Build_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Dotted_Sample,
         Output_Root   => Output_Root,
         Message       => "Foo.Bar");
      Assert_Build_Artifacts (Output_Root => Output_Root, Unit_Name => "Foo.Bar", Message => "Foo.Bar");
   end Test_Build_Module_Samples;

end Lovelace.Main.Integration_Tests.Module_Build;
