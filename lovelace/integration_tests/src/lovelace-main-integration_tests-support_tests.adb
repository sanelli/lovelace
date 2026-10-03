with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;

with Lovelace.Main.Integration_Tests.Support;

package body Lovelace.Main.Integration_Tests.Support_Tests is

   package Helpers renames Lovelace.Main.Integration_Tests.Support;

   procedure Test_Locate_And_Compose (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name   : constant String := "support locate and compose";
      Sample_Path : constant String := Helpers.Locate_Sample ("program", "Hello.love");
      Module_Path : constant String := Helpers.Locate_Sample ("module", "Empty.love");
      Output_Root : constant String := Helpers.Locate_Output_Root;
      Modules_Out : constant String := Helpers.Locate_Output_Root ("modules");
      Nested      : constant String := Helpers.Compose_Under (Output_Root, "bin");
   begin
      AUnit.Assertions.Assert (Ada.Directories.Exists (Sample_Path), "program Hello.love present");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Module_Path), "module Empty.love present");
      AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Output_Root, "integration-tests") > 0, "output root segment");
      AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Modules_Out, "modules") > 0, "modules output subfolder");
      AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Nested, "bin") > 0, "compose under bin");
      AUnit.Assertions.Assert (Helpers.Locate_Tool ("definitely-not-a-real-tool-xyz") = "", "missing tool");
      Helpers.Report_Test_Result (Test_Name, Helpers.Ok);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Locate_And_Compose;

end Lovelace.Main.Integration_Tests.Support_Tests;
