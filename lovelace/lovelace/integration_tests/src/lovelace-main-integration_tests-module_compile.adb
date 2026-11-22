with Ada.Exceptions;
with AUnit.Assertions;

with Lovelace.Main.Integration_Tests.Support;

package body Lovelace.Main.Integration_Tests.Module_Compile is

   package Helpers renames Lovelace.Main.Integration_Tests.Support;

   use type Helpers.Tool_Status;

   procedure Compile_Validate_Unit
     (Lovelace_Path : String;
      Sample_Path   : String;
      Output_Root   : String;
      Unit_Name     : String;
      Message       : String;
      Status        : in out Helpers.Tool_Status);
   --  Compile Sample_Path, assert artifacts, and validate .wasm/.wat.
   --  Status becomes Missing if any validate step is Missing; Failed if any Failed.

   procedure Compile_Validate_Unit
     (Lovelace_Path : String;
      Sample_Path   : String;
      Output_Root   : String;
      Unit_Name     : String;
      Message       : String;
      Status        : in out Helpers.Tool_Status)
   is
      Validate_Status : Helpers.Tool_Status;
   begin
      Helpers.Compile_Sample
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
   end Compile_Validate_Unit;

   procedure Test_Build_And_Validate (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Test_Name         : constant String :=
        "compile: validate modules Empty, Foo.Bar, Procedures, ExportProcedures, SameModuleCall, Overload, emoji";
      Lovelace_Path     : constant String := Helpers.Locate_Lovelace;
      Output_Root       : constant String := Helpers.Locate_Output_Root ("modules");
      Empty_Sample      : constant String := Helpers.Locate_Sample ("module", "Empty.love");
      Dotted_Sample     : constant String := Helpers.Locate_Sample ("module", "Foo.Bar.love");
      Procedures_Sample : constant String := Helpers.Locate_Sample ("module", "Procedures.love");
      Export_Sample     : constant String := Helpers.Locate_Sample ("module", "ExportProcedures.love");
      Calls_Sample      : constant String := Helpers.Locate_Sample ("calls", "SameModuleCall.love");
      Overload_Sample   : constant String := Helpers.Locate_Sample ("overload", "Overload.love");
      --  U+1F6F8 FLYING SAUCER as UTF-8 (emoji module stem; distinct from program 🚀).
      Saucer            : constant String :=
        [1 => Character'Val (16#F0#),
         2 => Character'Val (16#9F#),
         3 => Character'Val (16#9B#),
         4 => Character'Val (16#B8#)];
      Emoji_Sample      : constant String :=
        Helpers.Locate_Sample ("emoji-module", Saucer & ".love");
      Aggregate_Status  : Helpers.Tool_Status := Helpers.Succeeded;
      Outcome           : Helpers.Test_Outcome := Helpers.Ok;
   begin
      AUnit.Assertions.Assert (Lovelace_Path'Length > 0, "lovelace executable present");

      Helpers.Reset_Output_Root (Output_Root);

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Empty_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Empty",
         Message       => "Empty",
         Status        => Aggregate_Status);

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Dotted_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Foo.Bar",
         Message       => "Foo.Bar",
         Status        => Aggregate_Status);

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Procedures_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Procedures",
         Message       => "Procedures",
         Status        => Aggregate_Status);
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Procedures",
         Fragment    => "(func $Procedures_2eWhatever (param i32 f32 f32)",
         Message     => "Procedures");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Procedures",
         Fragment    => "(func $Procedures_2eSized (param i32 i64 f64)",
         Message     => "Procedures sized");

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Export_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "ExportProcedures",
         Message       => "ExportProcedures",
         Status        => Aggregate_Status);
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "ExportProcedures",
         Fragment    => "(func $ExportProcedures_2ePrint (param i32)",
         Message     => "ExportProcedures Print");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "ExportProcedures",
         Fragment    => "(func $ExportProcedures_2eInternalHelper (param i32)",
         Message     => "ExportProcedures InternalHelper");

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Calls_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "SameModuleCall",
         Message       => "SameModuleCall",
         Status        => Aggregate_Status);
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "SameModuleCall",
         Fragment    => "i32.const 42",
         Message     => "SameModuleCall const");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "SameModuleCall",
         Fragment    => "call $SameModuleCall_2eSink",
         Message     => "SameModuleCall call");

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Overload_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => "Overload",
         Message       => "Overload",
         Status        => Aggregate_Status);
      --  Shared LIR name "Sink" → WAT $Sink_<1-based index>.
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Overload",
         Fragment    => "call $Overload_2eSink_1",
         Message     => "Overload integer call");
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => "Overload",
         Fragment    => "call $Overload_2eSink_2",
         Message     => "Overload boolean call");

      Compile_Validate_Unit
        (Lovelace_Path => Lovelace_Path,
         Sample_Path   => Emoji_Sample,
         Output_Root   => Output_Root,
         Unit_Name     => Saucer,
         Message       => "emoji module",
         Status        => Aggregate_Status);
      Helpers.Assert_Wat_Contains
        (Output_Root => Output_Root,
         Unit_Name   => Saucer,
         Fragment    => "(local i32)",
         Message     => "emoji module local");

      if Aggregate_Status = Helpers.Missing then
         Outcome := Helpers.Inconclusive;
      end if;

      Helpers.Report_Test_Result (Test_Name, Outcome);
   exception
      when Error : others =>
         Helpers.Report_Test_Result (Test_Name, Helpers.Fail);
         Ada.Exceptions.Reraise_Occurrence (Error);
   end Test_Build_And_Validate;

end Lovelace.Main.Integration_Tests.Module_Compile;
