with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Backend.Wit and Backend.Wat.

package Lovelace.Compiler.Tests.Backend is

   --  Fixture for backend WIT / WAT emit tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Export-only Unit subroutine: WIT has named export, no run; WAT exports the name.
   --  @param The_Test Unused fixture.
   procedure Test_Export_Only (The_Test : in out Fixture);

   --  Export_Flag with parameters: core functype only; no WIT kebab export.
   --  @param The_Test Unused fixture.
   procedure Test_Export_With_Parameters (The_Test : in out Fixture);

   --  Entrypoint: WIT has run; WAT has $_start, i32.const 0, and export "run".
   --  @param The_Test Unused fixture.
   procedure Test_Entrypoint (The_Test : in out Fixture);

   --  Entrypoint plus Export_Flag on the same subroutine: both run and named export.
   --  @param The_Test Unused fixture.
   procedure Test_Entrypoint_And_Export (The_Test : in out Fixture);

   --  Two export-only subroutines, no entrypoint: two WIT/WAT exports; no _start or run.
   --  @param The_Test Unused fixture.
   procedure Test_Two_Exports (The_Test : in out Fixture);

   --  Noop body still emits a valid empty-ish function in WAT.
   --  @param The_Test Unused fixture.
   procedure Test_Noop_Body (The_Test : in out Fixture);

   --  Constant_I32 + Call lower to i32.const and call in WAT.
   --  @param The_Test Unused fixture.
   procedure Test_Const_And_Call_Body (The_Test : in out Fixture);

   --  LIR locals widen into WAT `(local ...)` after parameters.
   --  @param The_Test Unused fixture.
   procedure Test_Typed_Locals (The_Test : in out Fixture);

   --  Non-exported Unit procedure parameters widen into core WAT/WASM functypes.
   --  @param The_Test Unused fixture.
   procedure Test_Typed_Parameters (The_Test : in out Fixture);

   --  Unsupported I32 return, and entrypoint with parameters, yield Unsupported_Type.
   --  @param The_Test Unused fixture.
   procedure Test_Unsupported_Type (The_Test : in out Fixture);

   --  Empty module name fails Validate and yields Invalid_Module.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Module (The_Test : in out Fixture);

   --  Local_Get / Local_Set (1-based LIR) lower to 0-based local.get / local.set in WAT.
   --  @param The_Test Unused fixture.
   procedure Test_Local_Get_Set_Body (The_Test : in out Fixture);

   --  native-print-integer synthesizes stdout import + stream builtins in WAT/WIT.
   --  @param The_Test Unused fixture.
   procedure Test_Native_Print_Integer (The_Test : in out Fixture);

   --  Emit_Wasm and Emit_Wat produce identical companion WIT for the same module.
   --  @param The_Test Unused fixture.
   procedure Test_Wasm_Wit_Equality (The_Test : in out Fixture);

   --  Emit_Wasm component preamble is magic asm, version 0x0d, layer 1.
   --  @param The_Test Unused fixture.
   procedure Test_Wasm_Component_Preamble (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Backend;
