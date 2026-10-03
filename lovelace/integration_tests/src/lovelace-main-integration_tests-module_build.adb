with Ada.Exceptions;
with AUnit.Assertions;

with Lovelace.Main.Integration_Tests.Support;

package body Lovelace.Main.Integration_Tests.Module_Build is

   package Helpers renames Lovelace.Main.Integration_Tests.Support;

   use type Helpers.Tool_Status;

   procedure Build_Validate_Unit
     (Lovelace_Path : String;
      Sample_Path   : String;
      Output_Root   : String;
      Unit_Name     : String;
      Message       : String;
      Status        : in out Helpers.Tool_Status);
   --  Build Sample_Path, assert artifacts, and validate .wasm/.wat.
   --  Status becomes Missing if any validate step is Missing; Failed if any Failed.

   procedure Build_Validate_Unit
     (Lovelace_Path : String;
      Sample_Path   : String;
      Output_Root   : String;
      Unit_Name     : String;
      Message       : String;
      Status        : in out Helpers.Tool_Status)
   is
      Validate_Status : Helpers.Tool_Status;
   begin
      Helpers.Build_Sample
        (Lovelace_Path => Lovelace_Path, Sample_Path => Sample_Path, Output_Root => Output_Root, Message => Message);
      Helpers.Assert_Build_Artifacts (Output_Root => Output_Root, Unit_Name => Unit_Name, Message => Message);
      Helpers.Validate_Unit_Artifacts
        (Output_Root => Output_Root, Unit_Name => Unit_Name, Message => Message, Status => Validate_Status);

      case Validate_Status is
         when Helpers.Missing   =>
            Status := Helpers.Missing;

         when Helpers.Failed    =>
            Status := Helpers.Failed;

         when Helpers.Succeeded =>
            null;
      end case;
   end Build_Validate_Unit;

   procedure Test_Build_And_Validate (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name         : constant String := "build and validate modules";
      Lovelace_Path     : constant String := Helpers.Locate_Lovelace;
      Output_Root       : constant String := Helpers.Locate_Output_Root ("modules");
      Empty_Sample      : constant String := Helpers.Locate_Sample ("module", "Empty.love");
      Dotted_Sample     : constant String := Helpers.Locate_Sample ("module", "Foo.Bar.love");
      Procedures_Sample : constant String := Helpers.Locate_Sample ("module", "Procedures.love");
      Aggregate_Status  : Helpers.Tool_Status := Helpers.Succeeded;
      Outcome           : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);

      Build_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Empty_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Empty",
         Message       => "Empty",
         Status        => Aggregate_Status);

      Build_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Dotted_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Foo.Bar",
         Message       => "Foo.Bar",
         Status        => Aggregate_Status);

      Build_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Procedures_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Procedures",
         Message       => "Procedures",
         Status        => Aggregate_Status);
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Procedures",
         Fragment    => "(func $Whatever (param i32 f32 f32)",
         Message     => "Procedures");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Procedures",
         Fragment    => "(func $Sized (param i32 i64 f64)",
         Message     => "Procedures sized");

      if Aggregate_Status = Helpers.Missing then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Build_And_Validate;

end Lovelace.Main.Integration_Tests.Module_Build;
