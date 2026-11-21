with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;

with Lovelace.Main.Integration_Tests.Support;

package body Lovelace.Main.Integration_Tests.Support_Tests is

   package Helpers renames Lovelace.Main.Integration_Tests.Support;

   procedure Test_Locate_And_Compose (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name       : constant String :=
        "support: locate lovelace and compose paths";
      Sample_Path     : constant String :=
        Helpers.Locate_Sample ("program", "Hello.love");
      Using_Path      : constant String :=
        Helpers.Locate_Sample ("using", "UsingDecl.love");
      Using_Lib_Path  : constant String :=
        Helpers.Locate_Sample ("using", "UsingLib.love");
      Assignment_Path : constant String :=
        Helpers.Locate_Sample ("assignment", "Assignment.love");
      Nested_Call     : constant String :=
        Helpers.Locate_Sample ("nested-call", "NestedCall.love");
      Nested_Middle   : constant String :=
        Helpers.Locate_Sample ("nested-call", "Middle.love");
      Nested_Using    : constant String :=
        Helpers.Locate_Sample ("nested-using", "NestedUsing.love");
      Module_Path     : constant String :=
        Helpers.Locate_Sample ("module", "Empty.love");
      Comments_Path   : constant String :=
        Helpers.Locate_Sample ("comments", "Comments.love");
      Calls_Path      : constant String :=
        Helpers.Locate_Sample ("calls", "SameModuleCall.love");
      Overload_Path   : constant String :=
        Helpers.Locate_Sample ("overload", "Overload.love");
      Overload_Lib    : constant String :=
        Helpers.Locate_Sample ("overload", "OverloadLib.love");
      Overload_Caller : constant String :=
        Helpers.Locate_Sample ("overload", "OverloadCaller.love");
      Resolve_Caller  : constant String :=
        Helpers.Locate_Sample ("resolve", "Caller.love");
      Resolve_Lib     : constant String :=
        Helpers.Locate_Sample ("resolve", "Lib.love");
      Resolve_Util    : constant String :=
        Helpers.Compose_Under
          (Helpers.Locate_Sample ("resolve", "pkg"), "Util.love");
      Output_Root     : constant String := Helpers.Locate_Output_Root;
      Modules_Out     : constant String :=
        Helpers.Locate_Output_Root ("modules");
      Nested          : constant String :=
        Helpers.Compose_Under (Output_Root, "bin");
   begin
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Sample_Path), "program Hello.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Using_Path), "using UsingDecl.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Using_Lib_Path),
         "using UsingLib.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Assignment_Path),
         "assignment Assignment.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Nested_Call),
         "nested-call NestedCall.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Nested_Middle),
         "nested-call Middle.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Nested_Using),
         "nested-using NestedUsing.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Module_Path), "module Empty.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Comments_Path),
         "comments Comments.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Calls_Path),
         "calls SameModuleCall.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Overload_Path),
         "overload Overload.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Overload_Lib),
         "overload OverloadLib.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Overload_Caller),
         "overload OverloadCaller.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Resolve_Caller),
         "resolve Caller.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Resolve_Lib), "resolve Lib.love present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Resolve_Util),
         "resolve pkg/Util.love present");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Output_Root, "integration-tests") > 0,
         "output root segment");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Modules_Out, "modules") > 0,
         "modules output subfolder");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Nested, "bin") > 0, "compose under bin");
      AUnit.Assertions.Assert
        (Helpers.Locate_Tool ("definitely-not-a-real-tool-xyz") = "",
         "missing tool");
      Helpers.Report_Test_Result (Test_Name, Helpers.Ok);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Locate_And_Compose;

end Lovelace.Main.Integration_Tests.Support_Tests;
