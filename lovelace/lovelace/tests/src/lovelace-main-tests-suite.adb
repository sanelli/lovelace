with AUnit.Test_Caller;

with Lovelace.Main.Tests.Arguments;
with Lovelace.Main.Tests.Compile;
with Lovelace.Main.Tests.Compile_Run;
with Lovelace.Main.Tests.Help;
with Lovelace.Main.Tests.Reporting;
with Lovelace.Main.Tests.Run;
with Lovelace.Main.Tests.Terminal;
with Lovelace.Main.Tests.Version;

package body Lovelace.Main.Tests.Suite is

   package Arguments_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Arguments.Fixture);
   package Build_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Compile.Fixture);
   package Compile_Run_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Compile_Run.Fixture);
   package Help_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Help.Fixture);
   package Reporting_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Reporting.Fixture);
   package Run_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Run.Fixture);
   package Terminal_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Terminal.Fixture);
   package Version_Caller is new AUnit.Test_Caller (Lovelace.Main.Tests.Version.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Arguments_Caller.Create ("arguments: commands", Lovelace.Main.Tests.Arguments.Test_Commands'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("arguments: globals before command", Lovelace.Main.Tests.Arguments.Test_Globals_Before_Command'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("arguments: global after command is argument",
            Lovelace.Main.Tests.Arguments.Test_Global_After_Command_Is_Argument'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("arguments: unknown global rejected", Lovelace.Main.Tests.Arguments.Test_Unknown_Global'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("arguments: unknown command rejected", Lovelace.Main.Tests.Arguments.Test_Unknown_Command'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("arguments: option as command rejected",
            Lovelace.Main.Tests.Arguments.Test_Unknown_Option_As_Command'Access));
      Result.Add_Test
        (Arguments_Caller.Create ("arguments: no command", Lovelace.Main.Tests.Arguments.Test_No_Command'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("arguments: process command line", Lovelace.Main.Tests.Arguments.Test_Process_Command_Line'Access));

      Result.Add_Test
        (Build_Caller.Create ("compile: no-warnings list", Lovelace.Main.Tests.Compile.Test_No_Warnings_List'Access));
      Result.Add_Test
        (Build_Caller.Create
           ("compile: no-warnings empty entry", Lovelace.Main.Tests.Compile.Test_No_Warnings_Empty_Entry'Access));
      Result.Add_Test
        (Build_Caller.Create
           ("compile: warning policy CLI", Lovelace.Main.Tests.Compile.Test_Warning_Policy_Cli'Access));
      Result.Add_Test
        (Build_Caller.Create
           ("compile: output format values", Lovelace.Main.Tests.Compile.Test_Output_Format_Values'Access));
      Result.Add_Test
        (Build_Caller.Create
           ("compile: output format invalid", Lovelace.Main.Tests.Compile.Test_Output_Format_Invalid'Access));

      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: success artifacts", Lovelace.Main.Tests.Compile_Run.Test_Success_Artifacts'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: up to date", Lovelace.Main.Tests.Compile_Run.Test_Up_To_Date'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create ("compile in-process: no-wit", Lovelace.Main.Tests.Compile_Run.Test_No_Wit'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: output format wat", Lovelace.Main.Tests.Compile_Run.Test_Output_Format_Wat'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: output format wasm,wat",
            Lovelace.Main.Tests.Compile_Run.Test_Output_Format_Both'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: generate-tlir", Lovelace.Main.Tests.Compile_Run.Test_Generate_Tlir'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: missing source file",
            Lovelace.Main.Tests.Compile_Run.Test_Missing_Source_File'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: no positional source",
            Lovelace.Main.Tests.Compile_Run.Test_No_Positional_Source'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: extra positional", Lovelace.Main.Tests.Compile_Run.Test_Extra_Positional'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: unknown option", Lovelace.Main.Tests.Compile_Run.Test_Unknown_Option'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: missing --output-folder value",
            Lovelace.Main.Tests.Compile_Run.Test_Missing_Output_Folder_Value'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: invalid --output-format",
            Lovelace.Main.Tests.Compile_Run.Test_Invalid_Output_Format'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: flavor option", Lovelace.Main.Tests.Compile_Run.Test_Flavor_Option'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: invalid --module-version",
            Lovelace.Main.Tests.Compile_Run.Test_Invalid_Module_Version'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: include path options",
            Lovelace.Main.Tests.Compile_Run.Test_Include_Path_Options'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: parse error", Lovelace.Main.Tests.Compile_Run.Test_Parse_Error'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: unit name mismatch", Lovelace.Main.Tests.Compile_Run.Test_Unit_Name_Mismatch'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: warning policy", Lovelace.Main.Tests.Compile_Run.Test_Warning_Policy'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: --no-warnings accepted",
            Lovelace.Main.Tests.Compile_Run.Test_No_Warnings_Accepted'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: bad --no-warnings", Lovelace.Main.Tests.Compile_Run.Test_Bad_No_Warnings'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: empty --no-warnings entry",
            Lovelace.Main.Tests.Compile_Run.Test_Empty_No_Warnings_Entry'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: --module-version accepted",
            Lovelace.Main.Tests.Compile_Run.Test_Module_Version_Accepted'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: missing value options",
            Lovelace.Main.Tests.Compile_Run.Test_Missing_Value_Options'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: tokenize error", Lovelace.Main.Tests.Compile_Run.Test_Tokenize_Error'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: load error", Lovelace.Main.Tests.Compile_Run.Test_Load_Error'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: loaded dependency", Lovelace.Main.Tests.Compile_Run.Test_Loaded_Dependency'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: semantic error", Lovelace.Main.Tests.Compile_Run.Test_Semantic_Error'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: backend emit failure",
            Lovelace.Main.Tests.Compile_Run.Test_Backend_Emit_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: wat emit failure",
            Lovelace.Main.Tests.Compile_Run.Test_Wat_Emit_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: corrupt lir", Lovelace.Main.Tests.Compile_Run.Test_Corrupt_Lir'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: wit refresh without wasm",
            Lovelace.Main.Tests.Compile_Run.Test_Wit_Refresh_Without_Wasm'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: wasm write failure", Lovelace.Main.Tests.Compile_Run.Test_Wasm_Write_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: lir write failure", Lovelace.Main.Tests.Compile_Run.Test_Lir_Write_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: generate error", Lovelace.Main.Tests.Compile_Run.Test_Generate_Error'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: flavor native/web", Lovelace.Main.Tests.Compile_Run.Test_Flavor_Native_Web'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: wit write failure", Lovelace.Main.Tests.Compile_Run.Test_Wit_Write_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: wat write failure", Lovelace.Main.Tests.Compile_Run.Test_Wat_Write_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: tlir write failure", Lovelace.Main.Tests.Compile_Run.Test_Tlir_Write_Failure'Access));
      Result.Add_Test
        (Compile_Run_Caller.Create
           ("compile in-process: empty source", Lovelace.Main.Tests.Compile_Run.Test_Empty_Source'Access));

      Result.Add_Test
        (Help_Caller.Create ("help: compile topic succeeds", Lovelace.Main.Tests.Help.Test_Help_Build_Topic'Access));
      Result.Add_Test
        (Help_Caller.Create
           ("help: CLI stdout mentions compile", Lovelace.Main.Tests.Help.Test_Help_Mentions_Build'Access));
      Result.Add_Test (Help_Caller.Create ("help: general usage", Lovelace.Main.Tests.Help.Test_Help_General'Access));
      Result.Add_Test
        (Help_Caller.Create ("help: topics and errors", Lovelace.Main.Tests.Help.Test_Help_Topics_And_Errors'Access));
      Result.Add_Test
        (Help_Caller.Create ("help: standard error stream", Lovelace.Main.Tests.Help.Test_Help_Standard_Error'Access));

      Result.Add_Test
        (Run_Caller.Create ("main run: none dispatch", Lovelace.Main.Tests.Run.Test_None_Dispatch'Access));
      Result.Add_Test
        (Run_Caller.Create
           ("main run: parse failure dispatch", Lovelace.Main.Tests.Run.Test_Parse_Failure_Dispatch'Access));
      Result.Add_Test
        (Run_Caller.Create ("main run: help dispatch", Lovelace.Main.Tests.Run.Test_Help_Dispatch'Access));
      Result.Add_Test
        (Run_Caller.Create ("main run: Main.Run wrapper", Lovelace.Main.Tests.Run.Test_Main_Run_Wrapper'Access));
      Result.Add_Test
        (Run_Caller.Create ("main run: version dispatch", Lovelace.Main.Tests.Run.Test_Version_Dispatch'Access));
      Result.Add_Test
        (Run_Caller.Create
           ("main run: compile failure dispatch", Lovelace.Main.Tests.Run.Test_Compile_Failure_Dispatch'Access));

      Result.Add_Test
        (Version_Caller.Create
           ("version: product version prefix", Lovelace.Main.Tests.Version.Test_Version_Prefix'Access));

      Result.Add_Test
        (Reporting_Caller.Create ("reporting: love basename", Lovelace.Main.Tests.Reporting.Test_Love_Basename'Access));

      Result.Add_Test
        (Terminal_Caller.Create ("terminal: colour flag", Lovelace.Main.Tests.Terminal.Test_Colour_Flag'Access));
      Result.Add_Test
        (Terminal_Caller.Create ("terminal: Put_Info plain", Lovelace.Main.Tests.Terminal.Test_Put_Info_Plain'Access));
      Result.Add_Test
        (Terminal_Caller.Create
           ("terminal: Put_Info coloured", Lovelace.Main.Tests.Terminal.Test_Put_Info_Coloured'Access));
      Result.Add_Test
        (Terminal_Caller.Create
           ("terminal: Put_Error_Text plain", Lovelace.Main.Tests.Terminal.Test_Put_Error_Text_Plain'Access));
      Result.Add_Test
        (Terminal_Caller.Create
           ("terminal: Put_Error_Text coloured", Lovelace.Main.Tests.Terminal.Test_Put_Error_Text_Coloured'Access));
      Result.Add_Test
        (Terminal_Caller.Create
           ("terminal: Put_Error_Text no trailing newline",
            Lovelace.Main.Tests.Terminal.Test_Put_Error_Text_No_Trailing_Newline'Access));
      Result.Add_Test
        (Terminal_Caller.Create ("terminal: Put_Logo", Lovelace.Main.Tests.Terminal.Test_Put_Logo'Access));
      Result.Add_Test
        (Terminal_Caller.Create ("terminal: Report_Error", Lovelace.Main.Tests.Terminal.Test_Report_Error'Access));

      return Result;
   end Suite;

end Lovelace.Main.Tests.Suite;
