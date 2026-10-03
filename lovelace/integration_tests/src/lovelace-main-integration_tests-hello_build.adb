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

end Lovelace.Main.Integration_Tests.Hello_Build;
