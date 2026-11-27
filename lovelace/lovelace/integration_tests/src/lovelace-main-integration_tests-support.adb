with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Lovelace.Test_Status;

package body Lovelace.Main.Integration_Tests.Support is

   use type GNAT.OS_Lib.String_Access;

   function Discard_Stdio_Path return String;
   --  OS null device for discarding child stdout/stderr.

   function Read_Exact_File (Path : String) return String;
   --  Read entire file bytes as a String (no newline rewriting).

   function Read_Text_File (Path : String) return String;
   --  Read entire UTF-8 text file (Get_Line; appends LF per line).

   function Spawn_Capturing_Stdout
     (Program_Name : String;
      Args         : GNAT.OS_Lib.Argument_List;
      Output_Path  : String) return Integer;
   --  Spawn with stdout written to Output_Path; stderr kept separate
   --  (so Expected_Stdout capture is not mixed with diagnostics).

   function Spawn_Discarding_Stdio
     (Program_Name : String; Args : GNAT.OS_Lib.Argument_List) return Integer;
   --  Spawn with stdout and stderr discarded (quiet compile/validate/run).

   procedure Assert_Build_Artifacts
     (Output_Root : String; Unit_Name : String; Message : String)
   is
      Obj_Dir : constant String := Compose_Under (Output_Root, "obj");
      Bin_Dir : constant String := Compose_Under (Output_Root, "bin");
   begin
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Obj_Dir, Unit_Name & ".lir")),
         Message & ": " & Unit_Name & ".lir");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Bin_Dir, Unit_Name & ".wasm")),
         Message & ": " & Unit_Name & ".wasm");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Bin_Dir, Unit_Name & ".wat")),
         Message & ": " & Unit_Name & ".wat");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Compose_Under (Bin_Dir, Unit_Name & ".wit")),
         Message & ": " & Unit_Name & ".wit");
   end Assert_Build_Artifacts;

   procedure Assert_Lir_Contains
     (Output_Root : String;
      Unit_Name   : String;
      Fragment    : String;
      Message     : String)
   is
      Lir_Path : constant String :=
        Compose_Under (Compose_Under (Output_Root, "obj"), Unit_Name & ".lir");
      Contents : constant String := Read_Exact_File (Lir_Path);
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Contents, Fragment) > 0,
         Message & ": missing `" & Fragment & "` in .lir");
   end Assert_Lir_Contains;

   procedure Assert_Wat_Contains
     (Output_Root : String;
      Unit_Name   : String;
      Fragment    : String;
      Message     : String)
   is
      Wat_Path : constant String :=
        Compose_Under (Compose_Under (Output_Root, "bin"), Unit_Name & ".wat");
      Contents : constant String := Read_Text_File (Wat_Path);
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Contents, Fragment) > 0,
         Message & ": missing `" & Fragment & "`");
   end Assert_Wat_Contains;

   procedure Compile_Sample
     (Lovelace_Path : String;
      Sample_Path   : String;
      Output_Root   : String;
      Message       : String;
      Include_Path  : String := "")
   is
      Build_Args  : GNAT.OS_Lib.Argument_List_Access;
      Return_Code : Integer;
   begin
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Sample_Path), Message & ": sample present");

      if Include_Path'Length = 0 then
         Build_Args :=
           new GNAT.OS_Lib.Argument_List'
             (1 => new String'("--no-logo"),
              2 => new String'("compile"),
              3 => new String'(Sample_Path),
              4 => new String'("--output-format"),
              5 => new String'("wasm,wat"),
              6 => new String'("--output-folder"),
              7 => new String'(Output_Root),
              8 => new String'("--force"));
      else
         Build_Args :=
           new GNAT.OS_Lib.Argument_List'
             (1  => new String'("--no-logo"),
              2  => new String'("compile"),
              3  => new String'(Sample_Path),
              4  => new String'("--output-format"),
              5  => new String'("wasm,wat"),
              6  => new String'("--output-folder"),
              7  => new String'(Output_Root),
              8  => new String'("--force"),
              9  => new String'("-I"),
              10 => new String'(Include_Path));
      end if;

      Return_Code := Spawn_Discarding_Stdio (Lovelace_Path, Build_Args.all);
      GNAT.OS_Lib.Free (Build_Args);
      AUnit.Assertions.Assert (Return_Code = 0, Message & ": build exit 0");
   end Compile_Sample;

   function Compose_Under (Root, Relative : String) return String is
   begin
      return Ada.Directories.Compose (Root, Relative);
   end Compose_Under;

   function Discard_Stdio_Path return String is
   begin
      if Ada.Directories.Exists ("/dev/null") then
         return "/dev/null";
      end if;

      return "NUL";
   end Discard_Stdio_Path;

   function Locate_Lovelace return String is
      Relative : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Compose ("..", "bin"), "lovelace");
   begin
      if Ada.Directories.Exists (Relative) then
         return Relative;
      end if;

      return Locate_Tool ("lovelace");
   end Locate_Lovelace;

   function Locate_Output_Root (Subfolder : String := "") return String is
      Repository_Root : constant String := Locate_Repository_Root;
      Base            : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Compose (Repository_Root, ".tests"),
           "integration-tests");
   begin
      if Subfolder'Length = 0 then
         return Base;
      end if;

      return Ada.Directories.Compose (Base, Subfolder);
   end Locate_Output_Root;

   function Locate_Repository_Root return String is
   begin
      --  Crate cwd is lovelace/lovelace/integration_tests → repo root is ../../..
      return
        Ada.Directories.Full_Name
          (Ada.Directories.Compose
             (Ada.Directories.Compose
                (Ada.Directories.Compose
                   (Ada.Directories.Current_Directory, ".."),
                 ".."),
              ".."));
   end Locate_Repository_Root;

   function Locate_Sample (Feature_Folder, File_Name : String) return String is
   begin
      return
        Ada.Directories.Compose
          (Ada.Directories.Compose
             (Ada.Directories.Compose
                (Ada.Directories.Compose
                   (Ada.Directories.Compose ("..", ".."), ".."),
                 "samples"),
              Feature_Folder),
           File_Name);
   end Locate_Sample;

   function Locate_Tool (Name : String) return String is
      On_Path : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path (Name);
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
   end Locate_Tool;

   function Read_Exact_File (Path : String) return String is
      Size : constant Natural := Natural (Ada.Directories.Size (Path));
   begin
      if Size = 0 then
         return "";
      end if;

      declare
         File   : Ada.Streams.Stream_IO.File_Type;
         Stream : Ada.Streams.Stream_IO.Stream_Access;
         Buffer : String (1 .. Size);
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Path);
         Stream := Ada.Streams.Stream_IO.Stream (File);
         String'Read (Stream, Buffer);
         Ada.Streams.Stream_IO.Close (File);
         return Buffer;
      end;
   end Read_Exact_File;

   function Read_Text_File (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Strings.Unbounded.Append (Buffer, Ada.Text_IO.Get_Line (File));
         Ada.Strings.Unbounded.Append (Buffer, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end Read_Text_File;

   procedure Report_And_Require_Tools is
      Wasm_Tools_Path : constant String := Locate_Tool ("wasm-tools");
      Wasmtime_Path   : constant String := Locate_Tool ("wasmtime");
   begin
      if Wasm_Tools_Path'Length = 0 then
         Report_Test_Result ("tools: wasm-tools available", Fail);
      else
         Report_Test_Result ("tools: wasm-tools available", Ok);
      end if;

      if Wasmtime_Path'Length = 0 then
         Report_Test_Result ("tools: wasmtime available", Fail);
      else
         Report_Test_Result ("tools: wasmtime available", Ok);
      end if;

      AUnit.Assertions.Assert
        (Wasm_Tools_Path'Length > 0,
         "wasm-tools must be on PATH for integration tests");
      AUnit.Assertions.Assert
        (Wasmtime_Path'Length > 0,
         "wasmtime must be on PATH for integration tests");
   end Report_And_Require_Tools;

   procedure Report_Test_Result (Name : String; Outcome : Test_Outcome) is
      Status : Lovelace.Test_Status.Test_Outcome;
   begin
      case Outcome is
         when Ok           =>
            Status := Lovelace.Test_Status.Ok;

         when Fail         =>
            Status := Lovelace.Test_Status.Fail;

         when Inconclusive =>
            Status := Lovelace.Test_Status.Inconclusive;
      end case;

      Lovelace.Test_Status.Report_Test_Result (Name, Status);
   end Report_Test_Result;

   procedure Reset_Output_Root (Output_Root : String) is
   begin
      if Ada.Directories.Exists (Output_Root) then
         Ada.Directories.Delete_Tree (Output_Root);
      end if;
      Ada.Directories.Create_Path (Output_Root);
   end Reset_Output_Root;

   procedure Run_Entrypoint_Artifact
     (Path            : String;
      Message         : String;
      Status          : out Tool_Status;
      Expected_Stdout : String := "")
   is
      Wasmtime_Path : constant String := Locate_Tool ("wasmtime");
      Run_Args      : GNAT.OS_Lib.Argument_List_Access;
      Return_Code   : Integer;
      Capture_Path  : constant String := Path & ".stdout";
   begin
      if Wasmtime_Path'Length = 0 then
         Status := Missing;
         return;
      end if;

      --  Today: every entrypoint program is treated as WASI and run via wasmtime.
      --  Future host selection by Augusta flavor:
      --    wasi   -> wasmtime CLI
      --    native -> lovelace CLI (host embedder)
      --    web    -> headless Chrome or Node with JS glue libraries
      Run_Args :=
        new GNAT.OS_Lib.Argument_List'
          (1 => new String'("run"),
           2 => new String'("-Sp3"),
           3 => new String'("-W"),
           4 => new String'("component-model-async=y"),
           5 => new String'(Path));

      if Expected_Stdout'Length = 0 then
         Return_Code := Spawn_Discarding_Stdio (Wasmtime_Path, Run_Args.all);
      else
         Return_Code :=
           Spawn_Capturing_Stdout
             (Wasmtime_Path, Run_Args.all, Capture_Path);
      end if;

      GNAT.OS_Lib.Free (Run_Args);

      if Return_Code /= 0 then
         Status := Failed;
         AUnit.Assertions.Assert
           (False,
            Message & ": wasmtime run exit" & Integer'Image (Return_Code));
         return;
      end if;

      if Expected_Stdout'Length > 0 then
         declare
            Actual : constant String := Read_Exact_File (Capture_Path);
         begin
            AUnit.Assertions.Assert
              (Actual = Expected_Stdout,
               Message
               & ": stdout expected `"
               & Expected_Stdout
               & "` got `"
               & Actual
               & "`");
         end;
      end if;

      Status := Succeeded;
   end Run_Entrypoint_Artifact;

   procedure Run_Unit_Entrypoint
     (Output_Root     : String;
      Unit_Name       : String;
      Message         : String;
      Status          : out Tool_Status;
      Expected_Stdout : String := "")
   is
      Bin_Dir     : constant String := Compose_Under (Output_Root, "bin");
      Wasm_Path   : constant String :=
        Compose_Under (Bin_Dir, Unit_Name & ".wasm");
      Wat_Path    : constant String :=
        Compose_Under (Bin_Dir, Unit_Name & ".wat");
      Wasm_Status : Tool_Status;
      Wat_Status  : Tool_Status;
   begin
      if Locate_Tool ("wasmtime")'Length = 0 then
         Status := Missing;
         return;
      end if;

      Run_Entrypoint_Artifact
        (Path            => Wasm_Path,
         Message         => Message & " wasm",
         Status          => Wasm_Status,
         Expected_Stdout => Expected_Stdout);
      Run_Entrypoint_Artifact
        (Path            => Wat_Path,
         Message         => Message & " wat",
         Status          => Wat_Status,
         Expected_Stdout => Expected_Stdout);

      if Wasm_Status = Succeeded and then Wat_Status = Succeeded then
         Status := Succeeded;
      else
         Status := Failed;
      end if;
   end Run_Unit_Entrypoint;

   function Spawn_Capturing_Stdout
     (Program_Name : String;
      Args         : GNAT.OS_Lib.Argument_List;
      Output_Path  : String) return Integer
   is
      Success     : Boolean;
      Return_Code : Integer;
   begin
      GNAT.OS_Lib.Spawn
        (Program_Name => Program_Name,
         Args         => Args,
         Output_File  => Output_Path,
         Success      => Success,
         Return_Code  => Return_Code,
         Err_To_Out   => False);

      if not Success then
         return 1;
      end if;

      return Return_Code;
   end Spawn_Capturing_Stdout;

   function Spawn_Discarding_Stdio
     (Program_Name : String; Args : GNAT.OS_Lib.Argument_List) return Integer
   is
      Success     : Boolean;
      Return_Code : Integer;
   begin
      --  Err_To_Out merges stderr into the discarded stdout file (quiet [info]/[warning]/[err]).
      GNAT.OS_Lib.Spawn
        (Program_Name => Program_Name,
         Args         => Args,
         Output_File  => Discard_Stdio_Path,
         Success      => Success,
         Return_Code  => Return_Code,
         Err_To_Out   => True);

      if not Success then
         return 1;
      end if;

      return Return_Code;
   end Spawn_Discarding_Stdio;

   procedure Validate_Artifact
     (Path : String; Message : String; Status : out Tool_Status)
   is
      Wasm_Tools_Path : constant String := Locate_Tool ("wasm-tools");
      Validate_Args   : GNAT.OS_Lib.Argument_List_Access;
      Return_Code     : Integer;
   begin
      if Wasm_Tools_Path'Length = 0 then
         Status := Missing;
         return;
      end if;

      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Path), Message & ": artifact present");

      Validate_Args :=
        new GNAT.OS_Lib.Argument_List'
          (1 => new String'("validate"), 2 => new String'(Path));
      Return_Code :=
        Spawn_Discarding_Stdio (Wasm_Tools_Path, Validate_Args.all);
      GNAT.OS_Lib.Free (Validate_Args);

      if Return_Code = 0 then
         Status := Succeeded;
      else
         Status := Failed;
         AUnit.Assertions.Assert
           (False,
            Message
            & ": wasm-tools validate exit"
            & Integer'Image (Return_Code));
      end if;
   end Validate_Artifact;

   procedure Validate_Unit_Artifacts
     (Output_Root : String;
      Unit_Name   : String;
      Message     : String;
      Status      : out Tool_Status)
   is
      Bin_Dir     : constant String := Compose_Under (Output_Root, "bin");
      Wasm_Path   : constant String :=
        Compose_Under (Bin_Dir, Unit_Name & ".wasm");
      Wat_Path    : constant String :=
        Compose_Under (Bin_Dir, Unit_Name & ".wat");
      Wasm_Status : Tool_Status;
      Wat_Status  : Tool_Status;
   begin
      if Locate_Tool ("wasm-tools")'Length = 0 then
         Status := Missing;
         return;
      end if;

      Validate_Artifact (Wasm_Path, Message & " wasm", Wasm_Status);
      Validate_Artifact (Wat_Path, Message & " wat", Wat_Status);

      if Wasm_Status = Succeeded and then Wat_Status = Succeeded then
         Status := Succeeded;
      else
         Status := Failed;
      end if;
   end Validate_Unit_Artifacts;

end Lovelace.Main.Integration_Tests.Support;
