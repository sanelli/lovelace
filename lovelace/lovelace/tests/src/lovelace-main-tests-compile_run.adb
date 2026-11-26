with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;

with Lovelace.Main.Arguments;
with Lovelace.Main.Compile;
with Lovelace.Main.Terminal;
with Lovelace.Main.Tests.Support;

package body Lovelace.Main.Tests.Compile_Run is

   package Cli_Arguments renames Lovelace.Main.Arguments;
   package Cli_Compile renames Lovelace.Main.Compile;
   package Cli_Terminal renames Lovelace.Main.Terminal;

   Minimal_Name : constant String := "Minimal";

   type Run_Result is record
      Ok     : Boolean;
      Stdout : Ada.Strings.Unbounded.Unbounded_String;
      Stderr : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Work_Dir (Case_Name : String) return String;
   --  Fresh (deleted and recreated) directory under Current_Directory.

   function Out_Dir (Work : String) return String;
   --  Output folder passed with --output-folder.

   function Bin_File (Work : String; Name : String) return String;
   --  Path of Name under the output bin directory.

   function Obj_File (Work : String; Name : String) return String;
   --  Path of Name under the output obj directory.

   procedure Write_Source (Path : String; Lines : String);
   --  Write Lines (already containing LF separators) to Path.

   function Minimal_Source return String;
   --  program Minimal; begin end.

   procedure Write_Minimal (Work : String);
   --  Create Work/Minimal.love.

   function Source_Path (Work : String) return String;
   --  Path of Work/Minimal.love.

   function Make_Args
     (A1 : String := "";
      A2 : String := "";
      A3 : String := "";
      A4 : String := "";
      A5 : String := "";
      A6 : String := "";
      A7 : String := "";
      A8 : String := "") return Cli_Arguments.String_Vectors.Vector;
   --  Argument vector from the non-empty arguments, in order.

   function Run_Compile (Work : String; Args : Cli_Arguments.String_Vectors.Vector) return Run_Result;
   --  Call Compile.Run in-process with colour off and both streams captured.

   function Contains (Text : String; Pattern : String) return Boolean;

   procedure Remove (Work : String);

   procedure Write_Unread_Local (Work : String);
   --  Create Work/WarnUnused.love with one unread local (LV00028).

   function Bin_File (Work : String; Name : String) return String
   is (Ada.Directories.Compose (Ada.Directories.Compose (Out_Dir (Work), "bin"), Name));

   function Contains (Text : String; Pattern : String) return Boolean
   is (Ada.Strings.Fixed.Index (Text, Pattern) > 0);

   function Make_Args
     (A1 : String := "";
      A2 : String := "";
      A3 : String := "";
      A4 : String := "";
      A5 : String := "";
      A6 : String := "";
      A7 : String := "";
      A8 : String := "") return Cli_Arguments.String_Vectors.Vector
   is
      Result : Cli_Arguments.String_Vectors.Vector;

      procedure Add (Item : String);

      procedure Add (Item : String) is
      begin
         if Item'Length > 0 then
            Result.Append (Item);
         end if;
      end Add;
   begin
      Add (A1);
      Add (A2);
      Add (A3);
      Add (A4);
      Add (A5);
      Add (A6);
      Add (A7);
      Add (A8);
      return Result;
   end Make_Args;

   function Minimal_Source return String
   is ("program " & Minimal_Name & ";" & ASCII.LF & "begin" & ASCII.LF & "end." & ASCII.LF);

   function Obj_File (Work : String; Name : String) return String
   is (Ada.Directories.Compose (Ada.Directories.Compose (Out_Dir (Work), "obj"), Name));

   function Out_Dir (Work : String) return String
   is (Ada.Directories.Compose (Work, "out"));

   procedure Remove (Work : String) is
   begin
      if Ada.Directories.Exists (Work) then
         Ada.Directories.Delete_Tree (Work);
      end if;
   end Remove;

   function Run_Compile (Work : String; Args : Cli_Arguments.String_Vectors.Vector) return Run_Result is
      Out_Path : constant String := Ada.Directories.Compose (Work, "captured-stdout.txt");
      Err_Path : constant String := Ada.Directories.Compose (Work, "captured-stderr.txt");
      Saved    : constant Boolean := Cli_Terminal.Colour_Enabled;
      Ok       : Boolean := False;
   begin
      Cli_Terminal.Set_Colour_Enabled (False);
      Support.Start_Capture (Out_Path, Err_Path);
      begin
         Ok := Cli_Compile.Run (Args);
      exception
         when others =>
            Support.Stop_Capture;
            Cli_Terminal.Set_Colour_Enabled (Saved);
            raise;
      end;
      Support.Stop_Capture;
      Cli_Terminal.Set_Colour_Enabled (Saved);

      return
        (Ok     => Ok,
         Stdout => Ada.Strings.Unbounded.To_Unbounded_String (Support.Read_File (Out_Path)),
         Stderr => Ada.Strings.Unbounded.To_Unbounded_String (Support.Read_File (Err_Path)));
   end Run_Compile;

   function Source_Path (Work : String) return String
   is (Ada.Directories.Compose (Work, Minimal_Name & ".love"));

   procedure Test_Bad_No_Warnings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("no-warnings-bad");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work, Make_Args (Source_Path (Work), "--no-warnings", "LV00027", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "bad suppression fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "LV00030"), "reports LV00030");
      Remove (Work);
   end Test_Bad_No_Warnings;

   procedure Test_Corrupt_Lir (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("corrupt-lir");
      First  : Run_Result;
      Second : Run_Result;
      Lir    : constant String := Obj_File (Work, "Minimal.lir");
   begin
      Write_Minimal (Work);
      First := Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "first compile succeeds");
      Write_Source (Lir, "not a valid lir file");
      Second := Run_Compile (Work, Make_Args (Source_Path (Work), "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Second.Ok, "corrupt lir fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stderr), "failed to read LIR"), "reports lir read failure");
      Remove (Work);
   end Test_Corrupt_Lir;

   procedure Test_Empty_No_Warnings_Entry (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("no-warnings-empty");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--no-warnings", "LV00028,,LV00028", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "empty no-warnings entry fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "--no-warnings entry is empty"),
         "reports empty entry");
      Remove (Work);
   end Test_Empty_No_Warnings_Entry;

   procedure Test_Empty_Source (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("empty-source");
      Path   : constant String := Ada.Directories.Compose (Work, "Empty.love");
      Result : Run_Result;
   begin
      Write_Source (Path, "");
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "empty source fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "[LV"), "reports located diagnostic");
      Remove (Work);
   end Test_Empty_Source;

   procedure Test_Extra_Positional (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("extra-positional");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result := Run_Compile (Work, Make_Args (Source_Path (Work), "Other.love", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "extra argument fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "unexpected extra argument"),
         "reports extra argument");
      Remove (Work);
   end Test_Extra_Positional;

   procedure Test_Flavor_Native_Web (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("flavor-native-web");
      Native : Run_Result;
      Web    : Run_Result;
   begin
      Write_Minimal (Work);
      Native :=
        Run_Compile
          (Work,
           Make_Args
             (Source_Path (Work), "--force", "--flavor", "native", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Native.Ok, "native flavor succeeds: " & Ada.Strings.Unbounded.To_String (Native.Stderr));
      Web :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--flavor", "web", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Web.Ok, "web flavor succeeds: " & Ada.Strings.Unbounded.To_String (Web.Stderr));
      Remove (Work);
   end Test_Flavor_Native_Web;

   procedure Test_Flavor_Option (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work : constant String := Work_Dir ("flavor");
      Bad  : Run_Result;
      Good : Run_Result;
   begin
      Write_Minimal (Work);
      Bad := Run_Compile (Work, Make_Args (Source_Path (Work), "--flavor", "bogus", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Bad.Ok, "invalid flavor fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Bad.Stderr), "invalid --flavor"), "reports invalid flavor");

      Good :=
        Run_Compile
          (Work, Make_Args (Source_Path (Work), "--force", "--flavor", "wasi", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Good.Ok, "wasi flavor succeeds: " & Ada.Strings.Unbounded.To_String (Good.Stderr));
      Remove (Work);
   end Test_Flavor_Option;

   procedure Test_Generate_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("generate-error");
      Path   : constant String := Ada.Directories.Compose (Work, "Lib.love");
      Result : Run_Result;
   begin
      Write_Source
        (Path,
         "module Lib;"
         & ASCII.LF
         & "export @intrinsic procedure print(value : integer);"
         & ASCII.LF
         & "end."
         & ASCII.LF);
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "generate error fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "[LV"), "reports located diagnostic");
      Remove (Work);
   end Test_Generate_Error;

   procedure Test_Generate_Tlir (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("tlir");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--generate-tlir", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Result.Ok, "tlir compile succeeds: " & Ada.Strings.Unbounded.To_String (Result.Stderr));
      AUnit.Assertions.Assert (Ada.Directories.Exists (Obj_File (Work, "Minimal.tlir")), "tlir exists");
      Remove (Work);
   end Test_Generate_Tlir;

   procedure Test_Include_Path_Options (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("include-path");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args
             (Source_Path (Work), "-I", Work, "-I" & Work, "--include-path", Work, "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert
        (Result.Ok, "include path options accepted: " & Ada.Strings.Unbounded.To_String (Result.Stderr));
      Remove (Work);
   end Test_Include_Path_Options;

   procedure Test_Invalid_Module_Version (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("bad-module-version");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--module-version", "not-a-version", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "invalid module version fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "invalid --module-version"),
         "reports invalid module version");
      Remove (Work);
   end Test_Invalid_Module_Version;

   procedure Test_Invalid_Output_Format (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("bad-format");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work, Make_Args (Source_Path (Work), "--output-format", "bogus", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "invalid output format fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "invalid --output-format"),
         "reports invalid format");
      Remove (Work);
   end Test_Invalid_Output_Format;

   procedure Test_Lir_Write_Failure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("lir-write-fail");
      First  : Run_Result;
      Second : Run_Result;
      Lir    : constant String := Obj_File (Work, "Minimal.lir");
   begin
      Write_Minimal (Work);
      First :=
        Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "seed compile succeeds");
      Ada.Directories.Delete_File (Lir);
      Ada.Directories.Create_Directory (Lir);
      Second :=
        Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Second.Ok, "lir write failure fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stderr), "failed to write LIR"),
         "reports lir write failure");
      Remove (Work);
   end Test_Lir_Write_Failure;

   procedure Test_Load_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("load-error");
      Path   : constant String := Ada.Directories.Compose (Work, "LoadFail.love");
      Result : Run_Result;
   begin
      Write_Source
        (Path, "using Missing;" & ASCII.LF & "program LoadFail;" & ASCII.LF & "begin" & ASCII.LF & "end." & ASCII.LF);
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "load error fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "[LV"), "reports located diagnostic");
      Remove (Work);
   end Test_Load_Error;

   procedure Test_Missing_Output_Folder_Value (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("missing-value");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result := Run_Compile (Work, Make_Args (Source_Path (Work), "--output-folder"));
      AUnit.Assertions.Assert (not Result.Ok, "missing option value fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "--output-folder"), "names the option");
      Remove (Work);
   end Test_Missing_Output_Folder_Value;

   procedure Test_Missing_Source_File (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("missing-source");
      Result : Run_Result;
   begin
      Result :=
        Run_Compile (Work, Make_Args (Ada.Directories.Compose (Work, "Nope.love"), "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "missing source fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "cannot read source file"),
         "missing source reports read failure");
      Remove (Work);
   end Test_Missing_Source_File;

   procedure Test_Missing_Value_Options (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work : constant String := Work_Dir ("missing-values");
      Src  : constant String := Source_Path (Work);

      procedure Expect_Fail (Args : Cli_Arguments.String_Vectors.Vector; Needle : String; Label : String);

      procedure Expect_Fail (Args : Cli_Arguments.String_Vectors.Vector; Needle : String; Label : String) is
         Result : constant Run_Result := Run_Compile (Work, Args);
      begin
         AUnit.Assertions.Assert (not Result.Ok, Label & " fails");
         AUnit.Assertions.Assert
           (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), Needle), Label & " message");
      end Expect_Fail;
   begin
      Write_Minimal (Work);
      Expect_Fail (Make_Args (Src, "--no-warnings"), "comma-separated LV list", "missing --no-warnings");
      Expect_Fail (Make_Args (Src, "--flavor"), "requires a value", "missing --flavor");
      Expect_Fail (Make_Args (Src, "--module-version"), "requires a version", "missing --module-version");
      Expect_Fail (Make_Args (Src, "--output-format"), "requires a value", "missing --output-format");
      Expect_Fail (Make_Args (Src, "-I"), "requires a directory path", "missing -I");
      Expect_Fail (Make_Args (Src, "--include-path"), "requires a directory path", "missing --include-path");
      Remove (Work);
   end Test_Missing_Value_Options;

   procedure Test_Module_Version_Accepted (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("module-version-ok");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--module-version", "1.2.3", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert
        (Result.Ok, "module-version accepted: " & Ada.Strings.Unbounded.To_String (Result.Stderr));
      Remove (Work);
   end Test_Module_Version_Accepted;

   procedure Test_No_Positional_Source (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("no-positional");
      Result : Run_Result;
   begin
      Result := Run_Compile (Work, Make_Args ("--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "missing source argument fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "missing .love source"), "reports missing source");
      Remove (Work);
   end Test_No_Positional_Source;

   procedure Test_No_Warnings_Accepted (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("no-warnings-ok");
      Path   : constant String := Ada.Directories.Compose (Work, "WarnUnused.love");
      Result : Run_Result;
   begin
      Write_Unread_Local (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args
             (Path, "--force", "--no-warnings", "LV00028", "--warning-as-errors", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert
        (Result.Ok, "suppressed warning does not fail: " & Ada.Strings.Unbounded.To_String (Result.Stderr));
      Remove (Work);
   end Test_No_Warnings_Accepted;

   procedure Test_No_Wit (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("no-wit");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Result.Ok, "compile succeeds");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Bin_File (Work, "Minimal.wasm")), "wasm exists");
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Bin_File (Work, "Minimal.wit")), "wit skipped");
      Remove (Work);
   end Test_No_Wit;

   procedure Test_Output_Format_Both (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("format-both");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--output-format", "wasm,wat", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Result.Ok, "wasm,wat compile succeeds");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Bin_File (Work, "Minimal.wat")), "wat exists");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Bin_File (Work, "Minimal.wasm")), "wasm exists");
      Remove (Work);
   end Test_Output_Format_Both;

   procedure Test_Output_Format_Wat (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("format-wat");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--output-format", "wat", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Result.Ok, "wat compile succeeds: " & Ada.Strings.Unbounded.To_String (Result.Stderr));
      AUnit.Assertions.Assert (Ada.Directories.Exists (Bin_File (Work, "Minimal.wat")), "wat exists");
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Bin_File (Work, "Minimal.wasm")), "wasm not requested");
      Remove (Work);
   end Test_Output_Format_Wat;

   procedure Test_Parse_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("parse-error");
      Path   : constant String := Ada.Directories.Compose (Work, "BadParse.love");
      Result : Run_Result;
   begin
      Write_Source (Path, "program BadParse;" & ASCII.LF & "begin begin" & ASCII.LF);
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "parse error fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "[LV"), "reports located diagnostic");
      Remove (Work);
   end Test_Parse_Error;

   procedure Test_Semantic_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("semantic-error");
      Path   : constant String := Ada.Directories.Compose (Work, "TypeBad.love");
      Result : Run_Result;
   begin
      Write_Source
        (Path,
         "program TypeBad;"
         & ASCII.LF
         & "declare"
         & ASCII.LF
         & "   X : integer;"
         & ASCII.LF
         & "begin"
         & ASCII.LF
         & "   X := true;"
         & ASCII.LF
         & "end."
         & ASCII.LF);
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "semantic error fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "LV00027"), "reports type mismatch");
      Remove (Work);
   end Test_Semantic_Error;

   procedure Test_Success_Artifacts (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("success");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result := Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Result.Ok, "compile succeeds: " & Ada.Strings.Unbounded.To_String (Result.Stderr));
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stdout), "Compile succeeded"), "reports success");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Obj_File (Work, "Minimal.lir")), "lir exists");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Bin_File (Work, "Minimal.wasm")), "wasm exists");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Bin_File (Work, "Minimal.wit")), "wit exists");
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Bin_File (Work, "Minimal.wat")), "wat not requested");
      Remove (Work);
   end Test_Success_Artifacts;

   procedure Test_Tlir_Write_Failure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("tlir-write-fail");
      First  : Run_Result;
      Second : Run_Result;
      Tlir   : constant String := Obj_File (Work, "Minimal.tlir");
   begin
      Write_Minimal (Work);
      First :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--generate-tlir", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "seed compile succeeds");
      Ada.Directories.Delete_File (Tlir);
      Ada.Directories.Create_Directory (Tlir);
      Second :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--generate-tlir", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Second.Ok, "tlir write failure fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stderr), "failed to write textual LIR"),
         "reports tlir write failure");
      Remove (Work);
   end Test_Tlir_Write_Failure;

   procedure Test_Tokenize_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("tokenize-error");
      Path   : constant String := Ada.Directories.Compose (Work, "TokErr.love");
      Result : Run_Result;
   begin
      Write_Source (Path, "program TokErr;" & ASCII.LF & "begin" & ASCII.LF & "   $" & ASCII.LF & "end." & ASCII.LF);
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "tokenize error fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "[LV"), "reports located diagnostic");
      Remove (Work);
   end Test_Tokenize_Error;

   procedure Test_Unit_Name_Mismatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("name-mismatch");
      Path   : constant String := Ada.Directories.Compose (Work, "OtherName.love");
      Result : Run_Result;
   begin
      Write_Source (Path, Minimal_Source);
      Result := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "name mismatch fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "does not match file stem"),
         "reports name mismatch");
      Remove (Work);
   end Test_Unit_Name_Mismatch;

   procedure Test_Unknown_Option (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("unknown-option");
      Result : Run_Result;
   begin
      Write_Minimal (Work);
      Result := Run_Compile (Work, Make_Args (Source_Path (Work), "--bogus", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Result.Ok, "unknown option fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Result.Stderr), "unknown compile option '--bogus'"),
         "reports unknown option");
      Remove (Work);
   end Test_Unknown_Option;

   procedure Test_Up_To_Date (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("up-to-date");
      First  : Run_Result;
      Second : Run_Result;
   begin
      Write_Minimal (Work);
      First := Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "first compile succeeds");

      Second := Run_Compile (Work, Make_Args (Source_Path (Work), "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert
        (Second.Ok, "second compile succeeds: " & Ada.Strings.Unbounded.To_String (Second.Stderr));
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stdout), "up to date, skipping backend"),
         "second compile skips backend");
      Remove (Work);
   end Test_Up_To_Date;

   procedure Test_Warning_Policy (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work    : constant String := Work_Dir ("warning-policy");
      Path    : constant String := Ada.Directories.Compose (Work, "WarnUnused.love");
      Default : Run_Result;
      Strict  : Run_Result;
   begin
      Write_Unread_Local (Work);
      Default := Run_Compile (Work, Make_Args (Path, "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert
        (Default.Ok, "warning alone succeeds: " & Ada.Strings.Unbounded.To_String (Default.Stderr));
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Default.Stderr), "LV00028"), "default compile surfaces LV00028");

      Strict :=
        Run_Compile (Work, Make_Args (Path, "--force", "--warning-as-errors", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Strict.Ok, "warning-as-errors fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Strict.Stderr), "LV00028"), "strict compile reports LV00028");
      Remove (Work);
   end Test_Warning_Policy;

   procedure Test_Wasm_Write_Failure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("wasm-write-fail");
      First  : Run_Result;
      Second : Run_Result;
      Wasm   : constant String := Bin_File (Work, "Minimal.wasm");
   begin
      Write_Minimal (Work);
      First :=
        Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "seed compile succeeds");
      Ada.Directories.Delete_File (Wasm);
      Ada.Directories.Create_Directory (Wasm);
      Second :=
        Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Second.Ok, "wasm write failure fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stderr), "failed to write"), "reports write failure");
      Remove (Work);
   end Test_Wasm_Write_Failure;

   procedure Test_Wat_Write_Failure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("wat-write-fail");
      First  : Run_Result;
      Second : Run_Result;
      Wat    : constant String := Bin_File (Work, "Minimal.wat");
   begin
      Write_Minimal (Work);
      First :=
        Run_Compile
          (Work,
           Make_Args
             (Source_Path (Work), "--force", "--output-format", "wat", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "seed compile succeeds");
      Ada.Directories.Delete_File (Wat);
      Ada.Directories.Create_Directory (Wat);
      Second :=
        Run_Compile
          (Work,
           Make_Args
             (Source_Path (Work), "--force", "--output-format", "wat", "--no-wit", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Second.Ok, "wat write failure fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stderr), "failed to write"), "reports write failure");
      Remove (Work);
   end Test_Wat_Write_Failure;

   procedure Test_Wit_Refresh_Without_Wasm (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("wit-refresh");
      First  : Run_Result;
      Second : Run_Result;
      Wit    : constant String := Bin_File (Work, "Minimal.wit");
   begin
      Write_Minimal (Work);
      First :=
        Run_Compile
          (Work,
           Make_Args (Source_Path (Work), "--force", "--output-format", "wat", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "first wat compile succeeds");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Wit), "wit exists after first");
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Bin_File (Work, "Minimal.wasm")), "no wasm after first");
      Ada.Directories.Delete_File (Wit);
      Second :=
        Run_Compile (Work, Make_Args (Source_Path (Work), "--output-format", "wat", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (Second.Ok, "wit refresh succeeds: " & Ada.Strings.Unbounded.To_String (Second.Stderr));
      AUnit.Assertions.Assert (Ada.Directories.Exists (Wit), "wit restored");
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Bin_File (Work, "Minimal.wasm")), "still no wasm");
      Remove (Work);
   end Test_Wit_Refresh_Without_Wasm;

   procedure Test_Wit_Write_Failure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Work   : constant String := Work_Dir ("wit-write-fail");
      First  : Run_Result;
      Second : Run_Result;
      Wit    : constant String := Bin_File (Work, "Minimal.wit");
   begin
      Write_Minimal (Work);
      First := Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (First.Ok, "seed compile succeeds");
      Ada.Directories.Delete_File (Wit);
      Ada.Directories.Create_Directory (Wit);
      Second := Run_Compile (Work, Make_Args (Source_Path (Work), "--force", "--output-folder", Out_Dir (Work)));
      AUnit.Assertions.Assert (not Second.Ok, "wit write failure fails");
      AUnit.Assertions.Assert
        (Contains (Ada.Strings.Unbounded.To_String (Second.Stderr), "failed to write"), "reports write failure");
      Remove (Work);
   end Test_Wit_Write_Failure;

   function Work_Dir (Case_Name : String) return String is
      Path : constant String := Ada.Directories.Compose (Ada.Directories.Current_Directory, "compile-run-" & Case_Name);
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
      Ada.Directories.Create_Path (Path);
      return Path;
   end Work_Dir;

   procedure Write_Minimal (Work : String) is
   begin
      Write_Source (Source_Path (Work), Minimal_Source);
   end Write_Minimal;

   procedure Write_Source (Path : String; Lines : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Lines);
      Ada.Text_IO.Close (File);
   end Write_Source;

   procedure Write_Unread_Local (Work : String) is
   begin
      Write_Source
        (Ada.Directories.Compose (Work, "WarnUnused.love"),
         "program WarnUnused;"
         & ASCII.LF
         & "declare"
         & ASCII.LF
         & "   Unused : integer;"
         & ASCII.LF
         & "begin"
         & ASCII.LF
         & "end."
         & ASCII.LF);
   end Write_Unread_Local;

end Lovelace.Main.Tests.Compile_Run;
