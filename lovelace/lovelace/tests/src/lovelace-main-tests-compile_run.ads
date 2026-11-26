with AUnit.Test_Fixtures;

--  In-process tests for Lovelace.Main.Compile.Run (no Spawn of lovelace).

package Lovelace.Main.Tests.Compile_Run is

   --  Fixture for in-process compile command tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Valid .lir that fails backend emit is reported via Report_Backend_Error.
   --  @param The_Test Unused fixture.
   procedure Test_Backend_Emit_Failure (The_Test : in out Fixture);

   --  --no-warnings with a non-warning code fails with LV00030.
   --  @param The_Test Unused fixture.
   procedure Test_Bad_No_Warnings (The_Test : in out Fixture);

   --  Corrupt .lir with frontend up to date fails Read_Lir.
   --  @param The_Test Unused fixture.
   procedure Test_Corrupt_Lir (The_Test : in out Fixture);

   --  --no-warnings with an empty list entry fails.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_No_Warnings_Entry (The_Test : in out Fixture);

   --  Empty source fails parse with absent filename (falls back to path).
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Source (The_Test : in out Fixture);

   --  A second positional argument fails.
   --  @param The_Test Unused fixture.
   procedure Test_Extra_Positional (The_Test : in out Fixture);

   --  --flavor native and web succeed.
   --  @param The_Test Unused fixture.
   procedure Test_Flavor_Native_Web (The_Test : in out Fixture);

   --  Invalid --flavor value fails; a valid one succeeds.
   --  @param The_Test Unused fixture.
   procedure Test_Flavor_Option (The_Test : in out Fixture);

   --  IR generation failure (unknown intrinsic) is reported.
   --  @param The_Test Unused fixture.
   procedure Test_Generate_Error (The_Test : in out Fixture);

   --  --generate-tlir writes a .tlir file.
   --  @param The_Test Unused fixture.
   procedure Test_Generate_Tlir (The_Test : in out Fixture);

   --  Include paths (-I separate and attached, --include-path) are accepted.
   --  @param The_Test Unused fixture.
   procedure Test_Include_Path_Options (The_Test : in out Fixture);

   --  Invalid --module-version value fails.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Module_Version (The_Test : in out Fixture);

   --  Invalid --output-format value fails.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Output_Format (The_Test : in out Fixture);

   --  LIR path that cannot be written fails.
   --  @param The_Test Unused fixture.
   procedure Test_Lir_Write_Failure (The_Test : in out Fixture);

   --  Missing using dependency fails at load.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Error (The_Test : in out Fixture);

   --  A resolved using dependency logs Loaded for the secondary unit.
   --  @param The_Test Unused fixture.
   procedure Test_Loaded_Dependency (The_Test : in out Fixture);

   --  --output-folder without a value fails.
   --  @param The_Test Unused fixture.
   procedure Test_Missing_Output_Folder_Value (The_Test : in out Fixture);

   --  A source path that does not exist fails.
   --  @param The_Test Unused fixture.
   procedure Test_Missing_Source_File (The_Test : in out Fixture);

   --  Value options without a following token fail (Report_Missing_Value).
   --  @param The_Test Unused fixture.
   procedure Test_Missing_Value_Options (The_Test : in out Fixture);

   --  Valid --module-version is accepted.
   --  @param The_Test Unused fixture.
   procedure Test_Module_Version_Accepted (The_Test : in out Fixture);

   --  No positional source argument fails.
   --  @param The_Test Unused fixture.
   procedure Test_No_Positional_Source (The_Test : in out Fixture);

   --  --no-warnings accepts a warning label.
   --  @param The_Test Unused fixture.
   procedure Test_No_Warnings_Accepted (The_Test : in out Fixture);

   --  --no-wit skips the .wit artifact.
   --  @param The_Test Unused fixture.
   procedure Test_No_Wit (The_Test : in out Fixture);

   --  --output-format wasm,wat writes both artifacts.
   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Both (The_Test : in out Fixture);

   --  --output-format wat writes .wat and no .wasm.
   --  @param The_Test Unused fixture.
   procedure Test_Output_Format_Wat (The_Test : in out Fixture);

   --  A source with a syntax error fails.
   --  @param The_Test Unused fixture.
   procedure Test_Parse_Error (The_Test : in out Fixture);

   --  Type mismatch fails at semantics.
   --  @param The_Test Unused fixture.
   procedure Test_Semantic_Error (The_Test : in out Fixture);

   --  Minimal program compiles; .lir, .wasm and .wit artifacts exist.
   --  @param The_Test Unused fixture.
   procedure Test_Success_Artifacts (The_Test : in out Fixture);

   --  TLIR path that cannot be written fails.
   --  @param The_Test Unused fixture.
   procedure Test_Tlir_Write_Failure (The_Test : in out Fixture);

   --  Unrecognized token fails at tokenize.
   --  @param The_Test Unused fixture.
   procedure Test_Tokenize_Error (The_Test : in out Fixture);

   --  Unit name that differs from the file stem fails.
   --  @param The_Test Unused fixture.
   procedure Test_Unit_Name_Mismatch (The_Test : in out Fixture);

   --  An unknown --option fails.
   --  @param The_Test Unused fixture.
   procedure Test_Unknown_Option (The_Test : in out Fixture);

   --  A second run without --force reports artifacts up to date.
   --  @param The_Test Unused fixture.
   procedure Test_Up_To_Date (The_Test : in out Fixture);

   --  Unread local succeeds with LV00028; --warning-as-errors fails.
   --  @param The_Test Unused fixture.
   procedure Test_Warning_Policy (The_Test : in out Fixture);

   --  WASM path that cannot be written fails.
   --  @param The_Test Unused fixture.
   procedure Test_Wasm_Write_Failure (The_Test : in out Fixture);

   --  Valid .lir that fails WAT emit is reported via Report_Backend_Error.
   --  @param The_Test Unused fixture.
   procedure Test_Wat_Emit_Failure (The_Test : in out Fixture);

   --  WAT path that cannot be written fails.
   --  @param The_Test Unused fixture.
   procedure Test_Wat_Write_Failure (The_Test : in out Fixture);

   --  Stale WIT with wat-only format refreshes WIT without writing WASM.
   --  @param The_Test Unused fixture.
   procedure Test_Wit_Refresh_Without_Wasm (The_Test : in out Fixture);

   --  WIT path that cannot be written fails.
   --  @param The_Test Unused fixture.
   procedure Test_Wit_Write_Failure (The_Test : in out Fixture);

end Lovelace.Main.Tests.Compile_Run;
