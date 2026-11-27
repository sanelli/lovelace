with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

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

   procedure Assert_Failed
     (Result  : Graph.Load_Result;
      Code    : Graph.Unit_Graph_Error_Code;
      Surface : Error_Codes.Error_Code;
      Message : String);
   --  Require a failed load with the given stage code and surface LV code.
   procedure Check_Version (Text : String; Expected : Boolean);
   --  Assert Versioning.Is_Valid_Version (Text) = Expected.
   function Detail_Starts_With
     (Detail : Ada.Strings.Unbounded.Unbounded_String; Prefix : String)
      return Boolean;
   function Load_Using
     (Dir : String; Roots : Paths.Path_Sequence; Module_Name : String)
      return Graph.Load_Result;
   --  Load a program Host (at Dir/Host.love) that imports Module_Name.
   procedure Read_Loveversion_Text
     (Dir      : String;
      Contents : String;
      Version  : out Versioning.Version_Option;
      Ok       : out Boolean;
      Detail   : out Ada.Strings.Unbounded.Unbounded_String);
   --  Write Contents as Dir/.loveversion and read it back.

   function Surface
     (Code     : Graph.Unit_Graph_Error_Code;
      Frontend : Error_Codes.Error_Code := Error_Codes.Internal_Error)
      return Error_Codes.Error_Code;
   --  Surface_Error_Code of a synthetic error with Code and Frontend.
   function Temp_Dir (Leaf : String) return String;
   procedure Write_Text_File (Path : String; Contents : String);

   procedure Assert_Failed
     (Result  : Graph.Load_Result;
      Code    : Graph.Unit_Graph_Error_Code;
      Surface : Error_Codes.Error_Code;
      Message : String) is
   begin
      AUnit.Assertions.Assert (not Result.Ok, Message & ": fails");
      if not Result.Ok then
         AUnit.Assertions.Assert
           (Result.Error.Code = Code, Message & ": stage code");
         AUnit.Assertions.Assert
           (Graph.Surface_Error_Code (Result.Error) = Surface,
            Message & ": LV code");
      end if;
   end Assert_Failed;

   procedure Check_Version (Text : String; Expected : Boolean) is
   begin
      AUnit.Assertions.Assert
        (Versioning.Is_Valid_Version (Text) = Expected,
         "version '" & Text & "' expected " & Boolean'Image (Expected));
   end Check_Version;

   function Detail_Starts_With
     (Detail : Ada.Strings.Unbounded.Unbounded_String; Prefix : String)
      return Boolean
   is
      Text : constant String := Ada.Strings.Unbounded.To_String (Detail);
   begin
      return
        Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Detail_Starts_With;

   function Load_Using
     (Dir : String; Roots : Paths.Path_Sequence; Module_Name : String)
      return Graph.Load_Result
   is
      Src  : constant String :=
        "using "
        & Module_Name
        & ";"
        & ASCII.LF
        & "program Host;"
        & ASCII.LF
        & "begin end.";
      Host : constant Ast.Module := Support.Must_Parse (Src, "parse host");
   begin
      return
        Graph.Load
          (Host,
           Paths.Join_Root (Dir, "Host.love"),
           Src,
           Roots,
           Flavor.Default,
           (Present => False));
   end Load_Using;

   procedure Read_Loveversion_Text
     (Dir      : String;
      Contents : String;
      Version  : out Versioning.Version_Option;
      Ok       : out Boolean;
      Detail   : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Write_Text_File
        (Paths.Join_Root (Dir, Versioning.Loveversion_Filename), Contents);
      Versioning.Try_Read_Loveversion (Dir, Version, Ok, Detail);
   end Read_Loveversion_Text;

   function Surface
     (Code     : Graph.Unit_Graph_Error_Code;
      Frontend : Error_Codes.Error_Code := Error_Codes.Internal_Error)
      return Error_Codes.Error_Code
   is
      Origin : constant Graph.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 1, Line => 1, Column => 1));
   begin
      return
        Graph.Surface_Error_Code
          ((Code          => Code,
            Span          => Origin,
            Detail        => Ada.Strings.Unbounded.Null_Unbounded_String,
            Filename      => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text   => Ada.Strings.Unbounded.Null_Unbounded_String,
            Frontend_Code => Frontend));
   end Surface;

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

   procedure Test_Library_Root_For (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Base      : constant String := Temp_Dir ("library_root");
      Outer     : constant String := Paths.Join_Root (Base, "lib");
      Inner     : constant String := Paths.Join_Root (Outer, "sub");
      Sibling   : constant String := Paths.Join_Root (Base, "libx");
      Back_Root : constant String := Paths.Join_Root (Base, "back");
      Roots     : Paths.Path_Sequence;
      Bad_Roots : Paths.Path_Sequence;
   begin
      Ada.Directories.Create_Path (Inner);
      Ada.Directories.Create_Path (Sibling);
      Ada.Directories.Create_Path (Back_Root);
      Roots.Append (Sibling);
      Roots.Append (Inner);
      Roots.Append (Outer);
      Roots.Append (Back_Root);

      AUnit.Assertions.Assert
        (Versioning.Library_Root_For (Paths.Join_Root (Inner, "X.love"), Roots)
         = Inner,
         "longest root wins");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For (Paths.Join_Root (Outer, "Y.love"), Roots)
         = Outer,
         "outer root");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For (Inner, Roots) = Inner,
         "source equal to root");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For
           (Paths.Join_Root (Sibling, "Z.love"), Roots)
         = Sibling,
         "sibling with common prefix does not match the shorter root");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For (Back_Root & "\file.love", Roots)
         = Back_Root,
         "backslash separator");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For
           (Paths.Join_Root (Base, "Other.love"), Roots)
         = "",
         "no matching root");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For
           (Paths.Join_Root (Base, "libraryX.love"), Roots)
         = "",
         "prefix without separator");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For
           (Paths.Join_Root (Base, "Q.love"), Bad_Roots)
         = "",
         "no roots");

      Bad_Roots.Append ("bad" & ASCII.NUL & "root");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For
           (Paths.Join_Root (Inner, "X.love"), Bad_Roots)
         = "",
         "invalid root name");
      AUnit.Assertions.Assert
        (Versioning.Library_Root_For ("bad" & ASCII.NUL & ".love", Roots) = "",
         "invalid source name");
   end Test_Library_Root_For;

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

   procedure Test_Load_Dependency_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Dir   : constant String := Temp_Dir ("dep_fail");
      Roots : Paths.Path_Sequence;
   begin
      Roots.Append (Dir);

      Write_Text_File
        (Paths.Join_Root (Dir, "Wrong.love"),
         "module Other;" & ASCII.LF & "end.");
      Assert_Failed
        (Load_Using (Dir, Roots, "Wrong"),
         Graph.Unit_Name_Mismatch,
         Error_Codes.Program_Name_Filename_Mismatch,
         "name mismatch");

      Write_Text_File
        (Paths.Join_Root (Dir, "TokBad.love"),
         "module TokBad;" & ASCII.LF & "x := ""open" & ASCII.LF);
      Assert_Failed
        (Load_Using (Dir, Roots, "TokBad"),
         Graph.Frontend_Error,
         Error_Codes.Unterminated_String_Literal,
         "tokenizer failure");

      Write_Text_File
        (Paths.Join_Root (Dir, "ParseBad.love"),
         "module ParseBad;" & ASCII.LF & "end");
      declare
         Result : constant Graph.Load_Result :=
           Load_Using (Dir, Roots, "ParseBad");
      begin
         AUnit.Assertions.Assert (not Result.Ok, "parser failure fails");
         if not Result.Ok then
            AUnit.Assertions.Assert
              (Result.Error.Code = Graph.Frontend_Error,
               "parser failure code");
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.To_String (Result.Error.Filename)
               = Paths.Join_Root (Dir, "ParseBad.love"),
               "parser failure names the dependency file");
         end if;
      end;

      Write_Text_File
        (Paths.Join_Root (Dir, "Mid.love"),
         "using Gone;" & ASCII.LF & "module Mid;" & ASCII.LF & "end.");
      Assert_Failed
        (Load_Using (Dir, Roots, "Mid"),
         Graph.Unknown_Module,
         Error_Codes.Unknown_Module,
         "transitive failure");

      Write_Text_File
        (Paths.Join_Root (Dir, "Hidden.love"),
         "module Hidden;" & ASCII.LF & "end.");
      GNAT.OS_Lib.Set_Non_Readable (Paths.Join_Root (Dir, "Hidden.love"));
      if not GNAT.OS_Lib.Is_Readable_File
               (Paths.Join_Root (Dir, "Hidden.love"))
      then
         Assert_Failed
           (Load_Using (Dir, Roots, "Hidden"),
            Graph.Source_File_Io,
            Error_Codes.Source_File_Io,
            "unreadable dependency");
      end if;
      GNAT.OS_Lib.Set_Readable (Paths.Join_Root (Dir, "Hidden.love"));
   end Test_Load_Dependency_Failures;

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

   procedure Test_Load_Invalid_Root_Path (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Src    : constant String := "program Odd;" & ASCII.LF & "begin end.";
      Odd    : constant Ast.Module := Support.Must_Parse (Src, "parse odd");
      Roots  : Paths.Path_Sequence;
      Path   : constant String := "odd" & ASCII.NUL & ".love";
      Result : Graph.Load_Result;
   begin
      Result :=
        Graph.Load (Odd, Path, Src, Roots, Flavor.Default, (Present => False));
      AUnit.Assertions.Assert
        (Result.Ok, "unnormalizable root path still loads");
      if Result.Ok then
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String
              (Result.Units.Element (1).Source_Path)
            = Path,
            "root path kept as written");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Result.Units.Element (1).Version)
            = Versioning.Default_Version,
            "default version without library root");
      end if;
   end Test_Load_Invalid_Root_Path;

   procedure Test_Load_Large_Dependency (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Dir     : constant String := Temp_Dir ("large");
      Padding : constant String (1 .. 9000) := [others => ' '];
      Roots   : Paths.Path_Sequence;
      Result  : Graph.Load_Result;
   begin
      Roots.Append (Dir);
      Write_Text_File
        (Paths.Join_Root (Dir, "Big.love"),
         "module Big;" & ASCII.LF & Padding & ASCII.LF & "end.");
      Result := Load_Using (Dir, Roots, "Big");
      AUnit.Assertions.Assert (Result.Ok, "large dependency loads");
      if Result.Ok then
         AUnit.Assertions.Assert
           (Natural (Result.Units.Length) = 2, "host + Big");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.Length (Result.Units.Element (2).Source_Text)
            >= 11 + 1 + 9000 + 1 + 4,
            "whole file read");
      end if;
   end Test_Load_Large_Dependency;

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

   procedure Test_Load_Shared_And_Transitive (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Dir    : constant String := Temp_Dir ("shared");
      Roots  : Paths.Path_Sequence;
      Result : Graph.Load_Result;
      Src    : constant String :=
        "using A;"
        & ASCII.LF
        & "module Host;"
        & ASCII.LF
        & "procedure Run();"
        & ASCII.LF
        & "using B;"
        & ASCII.LF
        & "declare x : integer;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "   x := 1;"
        & ASCII.LF
        & "   using C;"
        & ASCII.LF
        & "   declare y : integer;"
        & ASCII.LF
        & "   begin"
        & ASCII.LF
        & "      y := 2;"
        & ASCII.LF
        & "   end;"
        & ASCII.LF
        & "end;"
        & ASCII.LF
        & "end.";
      Host   : constant Ast.Module :=
        Support.Must_Parse (Src, "parse shared host");
   begin
      Write_Text_File
        (Paths.Join_Root (Dir, "A.love"),
         "using Shared;" & ASCII.LF & "module A;" & ASCII.LF & "end.");
      Write_Text_File
        (Paths.Join_Root (Dir, "B.love"),
         "using Shared;" & ASCII.LF & "module B;" & ASCII.LF & "end.");
      Write_Text_File
        (Paths.Join_Root (Dir, "C.love"),
         "using Shared;" & ASCII.LF & "module C;" & ASCII.LF & "end.");
      Write_Text_File
        (Paths.Join_Root (Dir, "Shared.love"),
         "module Shared;" & ASCII.LF & "end.");
      Roots.Append (Dir);

      Result :=
        Graph.Load
          (Host,
           Paths.Join_Root (Dir, "Host.love"),
           Src,
           Roots,
           Flavor.Default,
           (Present => False));
      AUnit.Assertions.Assert (Result.Ok, "shared load ok");
      AUnit.Assertions.Assert
        (Natural (Result.Units.Length) = 5, "host + A + B + C + Shared once");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (1).The_Module) = "Host",
         "host first");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (2).The_Module) = "Shared",
         "transitive dep first");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (3).The_Module) = "A",
         "A after Shared");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (4).The_Module) = "B", "B after A");
      AUnit.Assertions.Assert
        (Ast.Name (Result.Units.Element (5).The_Module) = "C", "C last");
   end Test_Load_Shared_And_Transitive;

   procedure Test_Load_Version_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Root_Dir  : constant String := Temp_Dir ("ver_fail_root");
      Dep_Dir   : constant String := Temp_Dir ("ver_fail_dep");
      Roots     : Paths.Path_Sequence;
      Love_Path : constant String :=
        Paths.Join_Root (Dep_Dir, Versioning.Loveversion_Filename);
   begin
      Roots.Append (Root_Dir);
      Roots.Append (Dep_Dir);
      Write_Text_File
        (Paths.Join_Root (Dep_Dir, "Lib.love"),
         "module Lib;" & ASCII.LF & "end.");

      Write_Text_File (Love_Path, "@version(""1.0"")");
      Assert_Failed
        (Load_Using (Root_Dir, Roots, "Lib"),
         Graph.Frontend_Error,
         Error_Codes.Invalid_Module_Version,
         "dependency bad .loveversion");

      GNAT.OS_Lib.Set_Non_Readable (Love_Path);
      if not GNAT.OS_Lib.Is_Readable_File (Love_Path) then
         Assert_Failed
           (Load_Using (Root_Dir, Roots, "Lib"),
            Graph.Frontend_Error,
            Error_Codes.Source_File_Io,
            "dependency unreadable .loveversion");

         --  The root unit hits the same failure when it lives under that library root.
         declare
            Src       : constant String :=
              "program Solo;" & ASCII.LF & "begin end.";
            Solo      : constant Ast.Module :=
              Support.Must_Parse (Src, "parse solo");
            Dep_Roots : Paths.Path_Sequence;
         begin
            Dep_Roots.Append (Dep_Dir);
            Assert_Failed
              (Graph.Load
                 (Solo,
                  Paths.Join_Root (Dep_Dir, "Solo.love"),
                  Src,
                  Dep_Roots,
                  Flavor.Default,
                  (Present => False)),
               Graph.Frontend_Error,
               Error_Codes.Source_File_Io,
               "root unreadable .loveversion");
         end;
      end if;
      GNAT.OS_Lib.Set_Readable (Love_Path);
   end Test_Load_Version_Failures;

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
        (Paths.Join_Root (Lib_Dir, "Lib.love"),
         "module Lib;" & ASCII.LF & "end.");
      Write_Text_File
        (Paths.Join_Root (Lib_Dir, "Pinned.love"),
         "@version(""3.1.4-beta.2"")"
         & ASCII.LF
         & "module Pinned;"
         & ASCII.LF
         & "end.");
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
            elsif Ast.Name (Result.Units.Element (Index).The_Module) = "Pinned"
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

   procedure Test_Resolve_Version_Priority (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Dir      : constant String := Temp_Dir ("resolve_priority");
      Empty    : constant String := Temp_Dir ("resolve_priority_empty");
      File_Ver : constant Versioning.Version_Option :=
        (Present => True,
         Value   => Ada.Strings.Unbounded.To_Unbounded_String ("5.0.0"));
      Cli_Ver  : constant Versioning.Version_Option :=
        (Present => True,
         Value   => Ada.Strings.Unbounded.To_Unbounded_String ("7.0.0"));
      None     : constant Versioning.Version_Option := (Present => False);
      Version  : Ada.Strings.Unbounded.Unbounded_String;
      Ok       : Boolean;
      Detail   : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Write_Text_File
        (Paths.Join_Root (Dir, Versioning.Loveversion_Filename),
         "@version(""6.0.0"")");

      Versioning.Resolve_Version (File_Ver, Dir, Cli_Ver, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then Ada.Strings.Unbounded.To_String (Version) = "5.0.0",
         "file version wins");

      Versioning.Resolve_Version (None, Dir, Cli_Ver, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then Ada.Strings.Unbounded.To_String (Version) = "6.0.0",
         ".loveversion beats CLI");

      Versioning.Resolve_Version (None, Empty, Cli_Ver, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then Ada.Strings.Unbounded.To_String (Version) = "7.0.0",
         "CLI fallback");

      Versioning.Resolve_Version (None, "", None, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok
         and then Ada.Strings.Unbounded.To_String (Version)
                  = Versioning.Default_Version,
         "default fallback");

      Write_Text_File
        (Paths.Join_Root (Empty, Versioning.Loveversion_Filename),
         "@version(""bad"")");
      Versioning.Resolve_Version (None, Empty, Cli_Ver, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Ada.Strings.Unbounded.Length (Version) = 0
         and then Ada.Strings.Unbounded.Length (Detail) > 0,
         "invalid .loveversion fails resolution");

      Versioning.Resolve_Version
        (File_Ver, Empty, Cli_Ver, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then Ada.Strings.Unbounded.To_String (Version) = "5.0.0",
         "file version ignores invalid .loveversion");
   end Test_Resolve_Version_Priority;

   procedure Test_Surface_Error_Codes (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Surface (Graph.Internal_Error) = Error_Codes.Internal_Error,
         "internal");
      AUnit.Assertions.Assert
        (Surface (Graph.Unknown_Module) = Error_Codes.Unknown_Module,
         "unknown module");
      AUnit.Assertions.Assert
        (Surface (Graph.Ambiguous_Module_Path)
         = Error_Codes.Ambiguous_Module_Path,
         "ambiguous");
      AUnit.Assertions.Assert
        (Surface (Graph.Circular_Import) = Error_Codes.Circular_Import,
         "circular");
      AUnit.Assertions.Assert
        (Surface (Graph.Not_A_Module) = Error_Codes.Invalid_Module,
         "not a module");
      AUnit.Assertions.Assert
        (Surface (Graph.Unit_Name_Mismatch)
         = Error_Codes.Program_Name_Filename_Mismatch,
         "name mismatch");
      AUnit.Assertions.Assert
        (Surface (Graph.Source_File_Io) = Error_Codes.Source_File_Io,
         "source io");
      AUnit.Assertions.Assert
        (Surface (Graph.Frontend_Error, Error_Codes.Unexpected_Token)
         = Error_Codes.Unexpected_Token,
         "frontend code passes through");
   end Test_Surface_Error_Codes;

   procedure Test_Try_Read_Loveversion (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Dir     : constant String := Temp_Dir ("try_read");
      Love    : constant String :=
        Paths.Join_Root (Dir, Versioning.Loveversion_Filename);
      Version : Versioning.Version_Option;
      Ok      : Boolean;
      Detail  : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Versioning.Try_Read_Loveversion ("", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then not Version.Present, "empty root is absent");

      Versioning.Try_Read_Loveversion (Dir, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then not Version.Present, "missing file is absent");

      Ada.Directories.Create_Path (Love);
      Versioning.Try_Read_Loveversion (Dir, Version, Ok, Detail);
      AUnit.Assertions.Assert
        (Ok and then not Version.Present,
         "directory is not a .loveversion file");
      Ada.Directories.Delete_Tree (Love);

      Read_Loveversion_Text
        (Dir, "@version(""4.5.6-rc.1"")", Version, Ok, Detail);
      AUnit.Assertions.Assert (Ok and then Version.Present, "valid file read");
      if Version.Present then
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Version.Value) = "4.5.6-rc.1",
            "valid file value");
      end if;

      Read_Loveversion_Text (Dir, "@version(""4.5.6"" ", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok and then not Version.Present, "unterminated call fails");

      Read_Loveversion_Text (Dir, "@version(""4.5.6);", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With (Detail, "invalid .loveversion at "),
         "tokenizer failure detail");

      Read_Loveversion_Text (Dir, "", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With (Detail, ".loveversion must be exactly"),
         "empty file shape");

      Read_Loveversion_Text
        (Dir, "@version(""1.0.0"") extra", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With (Detail, ".loveversion must be exactly"),
         "extra tokens shape");

      Read_Loveversion_Text (Dir, "version(""1.0.0"")", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With (Detail, ".loveversion must be exactly"),
         "wrong attribute name");

      Read_Loveversion_Text (Dir, "@version[""1.0.0""]", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok and then not Version.Present, "wrong brackets");

      Read_Loveversion_Text (Dir, "@version(1)", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With (Detail, ".loveversion must be exactly"),
         "non-string argument");

      Read_Loveversion_Text (Dir, "@version(""1.0.0"";", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With (Detail, ".loveversion must be exactly"),
         "wrong closer");

      Read_Loveversion_Text (Dir, "@version(""01.0.0"")", Version, Ok, Detail);
      AUnit.Assertions.Assert
        (not Ok
         and then Detail_Starts_With
                    (Detail, "invalid module version '01.0.0'"),
         "invalid version text");

      Write_Text_File (Love, "@version(""1.0.0"")");
      GNAT.OS_Lib.Set_Non_Readable (Love);
      if not GNAT.OS_Lib.Is_Readable_File (Love) then
         Versioning.Try_Read_Loveversion (Dir, Version, Ok, Detail);
         AUnit.Assertions.Assert
           (not Ok and then Detail_Starts_With (Detail, "cannot read "),
            "unreadable file");
      end if;
      GNAT.OS_Lib.Set_Readable (Love);
   end Test_Try_Read_Loveversion;

   procedure Test_Version_Syntax (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Check_Version ("0.0.1", True);
      Check_Version ("1.2.3", True);
      Check_Version ("10.20.300", True);
      Check_Version ("1.2.3-beta", True);
      Check_Version ("1.2.3-beta.4", True);
      Check_Version ("1.2.3-a-b-9.0", True);
      Check_Version ("1.2.3-beta.10", True);

      Check_Version ("", False);
      Check_Version ("1", False);
      Check_Version ("1.2", False);
      Check_Version ("1.2.", False);
      Check_Version ("1..3", False);
      Check_Version ("a.b.c", False);
      Check_Version ("01.2.3", False);
      Check_Version ("1.02.3", False);
      Check_Version ("1.2.03", False);
      Check_Version ("00.1.2", False);
      Check_Version ("1.2.3x", False);
      Check_Version ("1.2.3 ", False);
      Check_Version ("1.2.3-", False);
      Check_Version ("1.2.3-!", False);
      Check_Version ("1.2.3-beta!", False);
      Check_Version ("1.2.3-beta.", False);
      Check_Version ("1.2.3-beta.x", False);
      Check_Version ("1.2.3-beta.01", False);
      Check_Version ("1.2.3-beta.4.5", False);
      Check_Version ("1.2.3-beta.4x", False);
   end Test_Version_Syntax;

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
