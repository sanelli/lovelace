with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with AUnit.Assertions;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Flavor;
with Lovelace.Compiler.Module_Path;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Unit_Graph;
with Lovelace.Compiler.Versioning;

package body Lovelace.Compiler.Tests.Unit_Graph is

   package Paths renames Lovelace.Compiler.Module_Path;
   package Graph renames Lovelace.Compiler.Unit_Graph;
   package Versioning renames Lovelace.Compiler.Versioning;

   use type Error_Codes.Error_Code;
   use type Graph.Unit_Graph_Error_Code;

   function Temp_Dir (Leaf : String) return String;
   procedure Write_Text_File (Path : String; Contents : String);

   function Temp_Dir (Leaf : String) return String is
      Base : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Compose (".tests", "unit_graph"), Leaf);
   begin
      if Ada.Directories.Exists (Base) then
         Ada.Directories.Delete_Tree (Base);
      end if;
      Ada.Directories.Create_Path (Base);
      return Ada.Directories.Full_Name (Base);
   end Temp_Dir;

   procedure Test_Load_Dependency (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Root_Dir   : constant String := Temp_Dir ("ok");
      Lib_Path   : constant String := Paths.Join_Root (Root_Dir, "Lib.love");
      Caller_Src : constant String :=
        "using Lib;"
        & ASCII.LF
        & "program Caller;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end.";
      Caller     : constant Ast.Module :=
        Support.Must_Parse (Caller_Src, "parse caller");
      Roots      : Paths.Path_Sequence;
      Result     : Graph.Load_Result;
   begin
      Write_Text_File (Lib_Path, "module Lib;" & ASCII.LF & "end.");
      Roots.Append (Root_Dir);
      Result :=
        Graph.Load
          (Root_Module      => Caller,
           Root_Source_Path => Paths.Join_Root (Root_Dir, "Caller.love"),
           Root_Source_Text => Caller_Src,
           Search_Roots     => Roots,
           Active_Flavor    => Flavor.Default,
           Cli_Version      => (Present => False));

      AUnit.Assertions.Assert (Result.Ok, "load ok");
      AUnit.Assertions.Assert
        (Natural (Result.Units.Length) = 2, "root + lib");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (1).The_Module) = "Caller",
         "root first");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (2).The_Module) = "Lib", "lib second");
   end Test_Load_Dependency;

   procedure Test_Load_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Root_Dir : constant String := Temp_Dir ("fail");
      Roots    : Paths.Path_Sequence;
   begin
      Roots.Append (Root_Dir);

      declare
         Src    : constant String :=
           "using Missing;"
           & ASCII.LF
           & "program P;"
           & ASCII.LF
           & "begin end.";
         Root   : constant Ast.Module :=
           Support.Must_Parse (Src, "parse missing");
         Result : constant Graph.Load_Result :=
           Graph.Load
             (Root,
              Paths.Join_Root (Root_Dir, "P.love"),
              Src,
              Roots,
              Flavor.Default,
              (Present => False));
      begin
         AUnit.Assertions.Assert (not Result.Ok, "missing fails");
         AUnit.Assertions.Assert
           (Result.Error.Code = Graph.Unknown_Module, "missing code");
         AUnit.Assertions.Assert
           (Graph.Surface_Error_Code (Result.Error)
            = Error_Codes.Unknown_Module,
            "missing LV");
      end;

      declare
         Slash  : constant String :=
           Paths.Join_Root (Root_Dir, "pkg/Util.love");
         Dot    : constant String :=
           Paths.Join_Root (Root_Dir, "pkg.Util.love");
         Src    : constant String :=
           "using pkg.Util;"
           & ASCII.LF
           & "program Amb;"
           & ASCII.LF
           & "begin end.";
         Root   : constant Ast.Module := Support.Must_Parse (Src, "parse amb");
         Result : Graph.Load_Result;
      begin
         Write_Text_File (Slash, "module pkg.Util;" & ASCII.LF & "end.");
         Write_Text_File (Dot, "module pkg.Util;" & ASCII.LF & "end.");
         Result :=
           Graph.Load
             (Root,
              Paths.Join_Root (Root_Dir, "Amb.love"),
              Src,
              Roots,
              Flavor.Default,
              (Present => False));
         AUnit.Assertions.Assert (not Result.Ok, "ambiguous fails");
         AUnit.Assertions.Assert
           (Result.Error.Code = Graph.Ambiguous_Module_Path, "ambiguous code");
         AUnit.Assertions.Assert
           (Graph.Surface_Error_Code (Result.Error)
            = Error_Codes.Ambiguous_Module_Path,
            "ambiguous LV");
      end;

      declare
         A_Path : constant String := Paths.Join_Root (Root_Dir, "CycleA.love");
         B_Path : constant String := Paths.Join_Root (Root_Dir, "CycleB.love");
         Src    : constant String :=
           "using CycleA;"
           & ASCII.LF
           & "program CycleRoot;"
           & ASCII.LF
           & "begin end.";
         Root   : constant Ast.Module :=
           Support.Must_Parse (Src, "parse cycle root");
         Result : Graph.Load_Result;
      begin
         Write_Text_File
           (A_Path,
            "using CycleB;" & ASCII.LF & "module CycleA;" & ASCII.LF & "end.");
         Write_Text_File
           (B_Path,
            "using CycleA;" & ASCII.LF & "module CycleB;" & ASCII.LF & "end.");
         Result :=
           Graph.Load
             (Root,
              Paths.Join_Root (Root_Dir, "CycleRoot.love"),
              Src,
              Roots,
              Flavor.Default,
              (Present => False));
         AUnit.Assertions.Assert (not Result.Ok, "cycle fails");
         AUnit.Assertions.Assert
           (Result.Error.Code = Graph.Circular_Import, "cycle code");
         AUnit.Assertions.Assert
           (Graph.Surface_Error_Code (Result.Error)
            = Error_Codes.Circular_Import,
            "cycle LV");
      end;

      declare
         Prog_Path : constant String :=
           Paths.Join_Root (Root_Dir, "NotMod.love");
         Src       : constant String :=
           "using NotMod;"
           & ASCII.LF
           & "program ProgImp;"
           & ASCII.LF
           & "begin end.";
         Root      : constant Ast.Module :=
           Support.Must_Parse (Src, "parse prog import");
         Result    : Graph.Load_Result;
      begin
         Write_Text_File
           (Prog_Path, "program NotMod;" & ASCII.LF & "begin end.");
         Result :=
           Graph.Load
             (Root,
              Paths.Join_Root (Root_Dir, "ProgImp.love"),
              Src,
              Roots,
              Flavor.Default,
              (Present => False));
         AUnit.Assertions.Assert (not Result.Ok, "program dep fails");
         AUnit.Assertions.Assert
           (Result.Error.Code = Graph.Not_A_Module, "program dep code");
         AUnit.Assertions.Assert
           (Graph.Surface_Error_Code (Result.Error)
            = Error_Codes.Invalid_Module,
            "program dep LV");
      end;
   end Test_Load_Failures;

   procedure Test_Load_Nested_Using (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Root_Dir   : constant String := Temp_Dir ("nested");
      Lib_Path   : constant String :=
        Paths.Join_Root (Root_Dir, "SomeMod.love");
      Caller_Src : constant String :=
        "program Caller;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "   using SomeMod;"
        & ASCII.LF
        & "   begin"
        & ASCII.LF
        & "   end;"
        & ASCII.LF
        & "end.";
      Caller     : constant Ast.Module :=
        Support.Must_Parse (Caller_Src, "parse nested using");
      Roots      : Paths.Path_Sequence;
      Result     : Graph.Load_Result;
   begin
      Write_Text_File (Lib_Path, "module SomeMod;" & ASCII.LF & "end.");
      Roots.Append (Root_Dir);
      Result :=
        Graph.Load
          (Root_Module      => Caller,
           Root_Source_Path => Paths.Join_Root (Root_Dir, "Caller.love"),
           Root_Source_Text => Caller_Src,
           Search_Roots     => Roots,
           Active_Flavor    => Flavor.Default,
           Cli_Version      => (Present => False));

      AUnit.Assertions.Assert (Result.Ok, "nested using load ok");
      AUnit.Assertions.Assert
        (Natural (Result.Units.Length) = 2, "root + SomeMod");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (1).The_Module) = "Caller",
         "root first");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (2).The_Module) = "SomeMod",
         "SomeMod second");
   end Test_Load_Nested_Using;

   procedure Test_Load_Versions (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lib_Dir    : constant String := Temp_Dir ("versions_lib");
      Cli_Dir    : constant String := Temp_Dir ("versions_cli");
      Bad_Dir    : constant String := Temp_Dir ("versions_bad");
      Caller_Src : constant String :=
        "using Lib;"
        & ASCII.LF
        & "using Pinned;"
        & ASCII.LF
        & "program Caller;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end.";
      Caller     : constant Ast.Module :=
        Support.Must_Parse (Caller_Src, "parse versions caller");
      Cli        : constant Versioning.Version_Option :=
        (Present => True,
         Value   => Ada.Strings.Unbounded.To_Unbounded_String ("9.9.9"));
      Roots      : Paths.Path_Sequence;
      Result     : Graph.Load_Result;
   begin
      --  .loveversion beats the CLI value; @version beats .loveversion.
      Write_Text_File
        (Paths.Join_Root (Lib_Dir, Versioning.Loveversion_Filename),
         "@version(""2.0.0"")");
      Write_Text_File
        (Paths.Join_Root (Lib_Dir, "Lib.love"), "module Lib;" & ASCII.LF & "end.");
      Write_Text_File
        (Paths.Join_Root (Lib_Dir, "Pinned.love"),
         "@version(""3.1.4-beta.2"")" & ASCII.LF & "module Pinned;" & ASCII.LF & "end.");
      Roots.Append (Lib_Dir);
      Result :=
        Graph.Load
          (Root_Module      => Caller,
           Root_Source_Path => Paths.Join_Root (Lib_Dir, "Caller.love"),
           Root_Source_Text => Caller_Src,
           Search_Roots     => Roots,
           Active_Flavor    => Flavor.Default,
           Cli_Version      => Cli);
      AUnit.Assertions.Assert (Result.Ok, "versions load ok");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Result.Units.Element (1).Version)
         = "2.0.0",
         "root uses .loveversion");

      declare
         Lib_Index    : Natural := 0;
         Pinned_Index : Natural := 0;
      begin
         for Index in 1 .. Natural (Result.Units.Length) loop
            if Ast.Name (Result.Units.Element (Index).The_Module) = "Lib" then
               Lib_Index := Index;
            elsif Ast.Name (Result.Units.Element (Index).The_Module)
              = "Pinned"
            then
               Pinned_Index := Index;
            end if;
         end loop;
         AUnit.Assertions.Assert
           (Lib_Index > 0 and then Pinned_Index > 0, "versions units found");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String
              (Result.Units.Element (Lib_Index).Version)
            = "2.0.0",
            "dependency uses .loveversion");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String
              (Result.Units.Element (Pinned_Index).Version)
            = "3.1.4-beta.2",
            "dependency @version wins");
      end;

      --  No attribute and no .loveversion: CLI value, else the default.
      declare
         Plain_Src : constant String :=
           "program Plain;" & ASCII.LF & "begin" & ASCII.LF & "end.";
         Plain     : constant Ast.Module :=
           Support.Must_Parse (Plain_Src, "parse versions plain");
         Cli_Roots : Paths.Path_Sequence;
         With_Cli  : Graph.Load_Result;
         No_Cli    : Graph.Load_Result;
      begin
         Cli_Roots.Append (Cli_Dir);
         With_Cli :=
           Graph.Load
             (Plain,
              Paths.Join_Root (Cli_Dir, "Plain.love"),
              Plain_Src,
              Cli_Roots,
              Flavor.Default,
              Cli);
         No_Cli :=
           Graph.Load
             (Plain,
              Paths.Join_Root (Cli_Dir, "Plain.love"),
              Plain_Src,
              Cli_Roots,
              Flavor.Default,
              (Present => False));
         AUnit.Assertions.Assert (With_Cli.Ok and then No_Cli.Ok, "plain ok");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String
              (With_Cli.Units.Element (1).Version)
            = "9.9.9",
            "CLI version fallback");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (No_Cli.Units.Element (1).Version)
            = Versioning.Default_Version,
            "default version");
      end;

      --  Invalid .loveversion fails with LV00034.
      declare
         Bad_Src   : constant String :=
           "program Bad;" & ASCII.LF & "begin" & ASCII.LF & "end.";
         Bad       : constant Ast.Module :=
           Support.Must_Parse (Bad_Src, "parse versions bad");
         Bad_Roots : Paths.Path_Sequence;
         Bad_Load  : Graph.Load_Result;
      begin
         Write_Text_File
           (Paths.Join_Root (Bad_Dir, Versioning.Loveversion_Filename),
            "@version(""1.0"")");
         Bad_Roots.Append (Bad_Dir);
         Bad_Load :=
           Graph.Load
             (Bad,
              Paths.Join_Root (Bad_Dir, "Bad.love"),
              Bad_Src,
              Bad_Roots,
              Flavor.Default,
              (Present => False));
         AUnit.Assertions.Assert (not Bad_Load.Ok, "bad .loveversion fails");
         AUnit.Assertions.Assert
           (Graph.Surface_Error_Code (Bad_Load.Error)
            = Error_Codes.Invalid_Module_Version,
            "bad .loveversion code");
      end;
   end Test_Load_Versions;

   procedure Write_Text_File (Path : String; Contents : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Contents);
      Ada.Text_IO.Close (File);
   end Write_Text_File;

end Lovelace.Compiler.Tests.Unit_Graph;
