with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Backend.Wit and Backend.Wat.

package Lovelace.Compiler.Tests.Backend is

   --  Fixture for backend WIT / WAT emit tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Constant_I32 + Call lower to i32.const and call in WAT.
   --  @param The_Test Unused fixture.
   procedure Test_Const_And_Call_Body (The_Test : in out Fixture);

   --  Two Entrypoint_Flag subroutines fail LIR Validate (duplicate entrypoint).
   --  @param The_Test Unused fixture.
   procedure Test_Duplicate_Entrypoint (The_Test : in out Fixture);

   --  Entrypoint: WIT has run; WAT has $_start, i32.const 0, and export "run".
   --  @param The_Test Unused fixture.
   procedure Test_Entrypoint (The_Test : in out Fixture);

   --  Entrypoint plus Export_Flag on the same subroutine: both run and named export.
   --  @param The_Test Unused fixture.
   procedure Test_Entrypoint_And_Export (The_Test : in out Fixture);

   --  Export-only Unit subroutine: WIT has named export, no run; WAT exports the name.
   --  @param The_Test Unused fixture.
   procedure Test_Export_Only (The_Test : in out Fixture);

   --  Export_Flag with parameters: core functype only; no WIT kebab export.
   --  @param The_Test Unused fixture.
   procedure Test_Export_With_Parameters (The_Test : in out Fixture);

   --  @intrinsic with no table match yields Internal_Error.
   --  @param The_Test Unused fixture.
   procedure Test_Intrinsic_Table_Miss (The_Test : in out Fixture);

   --  Empty module name fails Validate and yields Invalid_Module.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Module (The_Test : in out Fixture);

   --  Export names with leading/trailing/consecutive non-alnum kebab to "export" / collapsed dashes.
   --  @param The_Test Unused fixture.
   procedure Test_Kebab_Export_Dash_Collapse (The_Test : in out Fixture);

   --  Local_Get / Local_Set (1-based LIR) lower to 0-based local.get / local.set in WAT.
   --  @param The_Test Unused fixture.
   procedure Test_Local_Get_Set_Body (The_Test : in out Fixture);

   --  Module dependency is copied into the lowered model / WAT identity.
   --  @param The_Test Unused fixture.
   procedure Test_Module_Dependency (The_Test : in out Fixture);

   --  Backend.Names: empty / dotted / digit / non-ASCII segments and dash trim fallbacks.
   --  @param The_Test Unused fixture.
   procedure Test_Names_Sanitize_Edges (The_Test : in out Fixture);

   --  @native stub (Set_Native_Binding) lowers to an empty body.
   --  @param The_Test Unused fixture.
   procedure Test_Native_Empty_Body (The_Test : in out Fixture);

   --  native-print-integer synthesizes stdout import + stream builtins in WAT/WIT.
   --  @param The_Test Unused fixture.
   procedure Test_Native_Print_Integer (The_Test : in out Fixture);

   --  Intrinsic print with non-I32 parameter fails Match (table miss / signature path).
   --  @param The_Test Unused fixture.
   procedure Test_Native_Print_Signature_Mismatch (The_Test : in out Fixture);

   --  Noop body still emits a valid empty-ish function in WAT.
   --  @param The_Test Unused fixture.
   procedure Test_Noop_Body (The_Test : in out Fixture);

   --  Two export-only subroutines, no entrypoint: two WIT/WAT exports; no _start or run.
   --  @param The_Test Unused fixture.
   procedure Test_Two_Exports (The_Test : in out Fixture);

   --  LIR locals widen into WAT `(local ...)` after parameters.
   --  @param The_Test Unused fixture.
   procedure Test_Typed_Locals (The_Test : in out Fixture);

   --  Non-exported Unit procedure parameters widen into core WAT/WASM functypes.
   --  @param The_Test Unused fixture.
   procedure Test_Typed_Parameters (The_Test : in out Fixture);

   --  Unsupported I32 return, and entrypoint with parameters, yield Unsupported_Type.
   --  @param The_Test Unused fixture.
   procedure Test_Unsupported_Type (The_Test : in out Fixture);

   --  Unit local type fails Map_Locals with Unsupported_Type.
   --  @param The_Test Unused fixture.
   procedure Test_Unsupported_Unit_Local (The_Test : in out Fixture);

   --  Unit parameter type fails Map_Parameters with Unsupported_Type.
   --  @param The_Test Unused fixture.
   procedure Test_Unsupported_Unit_Parameter (The_Test : in out Fixture);

   --  Emit_Wasm component preamble is magic asm, version 0x0d, layer 1.
   --  @param The_Test Unused fixture.
   procedure Test_Wasm_Component_Preamble (The_Test : in out Fixture);

   --  Emit_Wasm and Emit_Wat produce identical companion WIT for the same module.
   --  @param The_Test Unused fixture.
   procedure Test_Wasm_Wit_Equality (The_Test : in out Fixture);

   --  Call with Target_Index 0 fails LIR Validate (Invalid_Module before lowering).
   --  @param The_Test Unused fixture.
   procedure Test_Zero_Call_Target (The_Test : in out Fixture);

   --  Local_Get / Local_Set with Local_Index 0 fail LIR Validate (Invalid_Module).
   --  @param The_Test Unused fixture.
   procedure Test_Zero_Local_Index (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Backend;
