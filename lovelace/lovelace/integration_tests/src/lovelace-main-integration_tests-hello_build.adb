with Ada.Exceptions;
with AUnit.Assertions;

with Lovelace.Main.Integration_Tests.Support;

package body Lovelace.Main.Integration_Tests.Hello_Build is

   package Helpers renames Lovelace.Main.Integration_Tests.Support;

   use type Helpers.Tool_Status;

   procedure Test_Build_Validate_And_Run (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "build: validate and run program Hello";
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
      Helpers.Build_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "Hello");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root, Unit_Name => "Hello", Message => "Hello");

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

   procedure Test_Hello_Print_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "build: validate and run program HelloPrint";
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
      Helpers.Build_Sample
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

   procedure Test_Import_Decl_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "build: validate and run program ImportDecl";
      Lovelace_Path   : constant String := Helpers.Locate_Lovelace;
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("import", "ImportDecl.love");
      Output_Root     : constant String :=
        Helpers.Locate_Output_Root ("import");
      Validate_Status : Helpers.Tool_Status;
      Run_Status      : Helpers.Tool_Status;
      Outcome         : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);
      Helpers.Build_Sample
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Sample_Path,
         Output_Root   => Output_Root,
         Message       => "ImportDecl");
      Helpers.Assert_Build_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "ImportDecl",
         Message     => "ImportDecl");

      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root,
         Unit_Name   => "ImportDecl",
         Message     => "ImportDecl",
         Status      => Validate_Status);
      Helpers.Run_Unit_Entrypoint
        (Output_Root => Output_Root,
         Unit_Name   => "ImportDecl",
         Message     => "ImportDecl",
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
   end Test_Import_Decl_Build_Validate_And_Run;

   procedure Test_Resolve_Caller_Build_Validate_And_Run
     (The_Test : in out Fixture)
   is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "build: validate and run program Caller";
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
      Helpers.Build_Sample
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

end Lovelace.Main.Integration_Tests.Hello_Build;
