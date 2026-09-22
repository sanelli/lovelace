with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Backend.Wit and Backend.Wat.

package Lovelace.Compiler.Tests.Backend is

   --  Fixture for backend WIT / WAT emit tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Export-only Unit subroutine: WIT has named export, no run; WAT exports the name.
   --  @param The_Test Unused fixture.
   procedure Test_Export_Only (The_Test : in out Fixture);

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

   --  Unsupported I32 return type yields Unsupported_Type.
   --  @param The_Test Unused fixture.
   procedure Test_Unsupported_Type (The_Test : in out Fixture);

   --  Empty module name fails Validate and yields Invalid_Module.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Module (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Backend;
