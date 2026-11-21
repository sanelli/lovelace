with Ada.Directories;
with Ada.Exceptions;
with AUnit.Assertions;

with Lovelace.Main.Integration_Tests.Support;

package body Lovelace.Main.Integration_Tests.Hello_Compile is

   package Helpers renames Lovelace.Main.Integration_Tests.Support;

   use type Helpers.Tool_Status;

   procedure Test_Assignment_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program Assignment";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("assignment", "Assignment.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("assignment");
      Augusta_Root    : constant String :=
        Helpers.Compose_Under
          (Helpers.Compose_Under (Helpers.Locate_Repository_Root, "augusta"),
           "lovelace");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "Assignment",
         Include_Path  => Augusta_Root);
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Assignment",
         Message     => "Assignment");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Assignment",
         Message     => "Assignment",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root     => Output_Root,
         Unit_Name       => "Assignment",
         Message         => "Assignment",
         Status          => Run_Status,
         Expected_Stdout => "7");

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Assignment_Build_Validate_And_Run;

   procedure Test_Build_Validate_And_Run (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program Hello";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("program", "Hello.love");
      Output_Root     : constant String := Helpers.Locate_Output_Root;
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "Hello");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root, Unit_Name => "Hello", Message => "Hello");
      Helpers.Assert_Lir_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Hello",
         Fragment    => Ada.Directories.Full_Name (Sample_Path),
         Message     => "Hello absolute origin");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Hello",
         Message     => "Hello",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => "Hello",
         Message     => "Hello",
         Status      => Run_Status);

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Build_Validate_And_Run;

   procedure Test_Emoji_Program_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      --  U+1F680 ROCKET as UTF-8 (program / file stem).
      Rocket          : constant String :=
        [1 => Character'Val (16#F0#),
         2 => Character'Val (16#9F#),
         3 => Character'Val (16#9A#),
         4 => Character'Val (16#80#)];
      Test_Name       : constant String :=
        "compile: validate and run program emoji rocket";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("emoji", Rocket & ".love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("emoji");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "emoji program");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => Rocket,
         Message     => "emoji program");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => Rocket,
         Fragment    => "(local i32)",
         Message     => "emoji program local");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => Rocket,
         Message     => "emoji program",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => Rocket,
         Message     => "emoji program",
         Status      => Run_Status);

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Emoji_Program_Build_Validate_And_Run;

   procedure Test_Hello_Print_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program HelloPrint";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("io", "HelloPrint.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("io");
      Augusta_Root    : constant String :=
        Helpers.Compose_Under
          (Helpers.Compose_Under (Helpers.Locate_Repository_Root, "augusta"),
           "lovelace");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "HelloPrint",
         Include_Path  => Augusta_Root);
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "HelloPrint",
         Message     => "HelloPrint");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "HelloPrint",
         Fragment    => "wasi:cli/stdout@0.3.0",
         Message     => "HelloPrint stdout import");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "HelloPrint",
         Message     => "HelloPrint",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root     => Output_Root,
         Unit_Name       => "HelloPrint",
         Message         => "HelloPrint",
         Status          => Run_Status,
         Expected_Stdout => "42");

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Hello_Print_Build_Validate_And_Run;

   procedure Test_Nested_Call_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program NestedCall";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("nested-call", "NestedCall.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("nested-call");
      Augusta_Root    : constant String :=
        Helpers.Compose_Under
          (Helpers.Compose_Under (Helpers.Locate_Repository_Root, "augusta"),
           "lovelace");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "NestedCall",
         Include_Path  => Augusta_Root);
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "NestedCall",
         Message     => "NestedCall");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "NestedCall",
         Fragment    => "call $Middle_2ePass",
         Message     => "NestedCall calls Middle.Pass");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "NestedCall",
         Message     => "NestedCall",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root     => Output_Root,
         Unit_Name       => "NestedCall",
         Message         => "NestedCall",
         Status          => Run_Status,
         Expected_Stdout => "42");

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Nested_Call_Build_Validate_And_Run;

   procedure Test_Nested_Using_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program NestedUsing";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("nested-using", "NestedUsing.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("nested-using");
      Augusta_Root    : constant String :=
        Helpers.Compose_Under
          (Helpers.Compose_Under (Helpers.Locate_Repository_Root, "augusta"),
           "lovelace");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "NestedUsing",
         Include_Path  => Augusta_Root);
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "NestedUsing",
         Message     => "NestedUsing");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "NestedUsing",
         Message     => "NestedUsing",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root     => Output_Root,
         Unit_Name       => "NestedUsing",
         Message         => "NestedUsing",
         Status          => Run_Status,
         Expected_Stdout => "1");

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Nested_Using_Build_Validate_And_Run;

   procedure Test_Overload_Caller_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program OverloadCaller";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("overload", "OverloadCaller.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("overload");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "OverloadCaller");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "OverloadCaller",
         Message     => "OverloadCaller");
      --  LIR '.' → WAT _2e; shared name gets _<index>.
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "OverloadCaller",
         Fragment    => "call $OverloadLib_2eSink_2",
         Message     => "OverloadCaller integer overload");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "OverloadCaller",
         Fragment    => "call $OverloadLib_2eSink_3",
         Message     => "OverloadCaller boolean overload");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "OverloadCaller",
         Message     => "OverloadCaller",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => "OverloadCaller",
         Message     => "OverloadCaller",
         Status      => Run_Status);

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Overload_Caller_Build_Validate_And_Run;

   procedure Test_Resolve_Caller_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program Caller";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      --  Building samples/resolve/Caller.love: search root = file dir finds Lib
      --  and pkg/Util without -I. Once CLI has --include-path/-I, builds from
      --  other cwd layouts may need an explicit -I samples/resolve.
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("resolve", "Caller.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("resolve");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "Caller");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Caller",
         Message     => "Caller");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Caller",
         Message     => "Caller",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => "Caller",
         Message     => "Caller",
         Status      => Run_Status);

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Resolve_Caller_Build_Validate_And_Run;

   procedure Test_Using_Decl_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program UsingDecl";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("using", "UsingDecl.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("using");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "UsingDecl");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "UsingDecl",
         Message     => "UsingDecl");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "UsingDecl",
         Message     => "UsingDecl",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => "UsingDecl",
         Message     => "UsingDecl",
         Status      => Run_Status);

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Using_Decl_Build_Validate_And_Run;

   procedure Test_Variables_Build_Validate_And_Run (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "compile: validate and run program Variables";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("variables", "Variables.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("variables");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Compile_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "Variables");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Variables",
         Message     => "Variables");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Variables",
         Fragment    => "(local i32 i32 i32 f32)",
         Message     => "Variables flattened locals");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "Variables",
         Message     => "Variables",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => "Variables",
         Message     => "Variables",
         Status      => Run_Status);

      if Validate_Status = Helpers.Missing or else Run_Status = Helpers.Missing
      then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Variables_Build_Validate_And_Run;

end Lovelace.Main.Integration_Tests.Hello_Compile;
