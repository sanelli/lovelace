with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Lir.Binary and related opcodes/types.

package Lovelace.Lir.Tests.Binary_Format is

   --  Fixture for binary codec and value-type stream tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Empty named module round-trips in memory.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module_Memory (The_Test : in out Fixture);

   --  Empty named module round-trips via temp .lir file.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module_File (The_Test : in out Fixture);

   --  Encode starts with LIR NUL magic and version 1.0.
   --  @param The_Test Unused fixture.
   procedure Test_Magic_And_Version (The_Test : in out Fixture);

   --  UTF-8 and emoji module/subroutine names round-trip.
   --  @param The_Test Unused fixture.
   procedure Test_Unicode_Names (The_Test : in out Fixture);

   --  Depends, empty body, noop, several noops, export, entrypoint.
   --  @param The_Test Unused fixture.
   procedure Test_Subroutines_And_Flags (The_Test : in out Fixture);

   --  Encoded noop is two 0x00 bytes; Encoded_Length is 2.
   --  @param The_Test Unused fixture.
   procedure Test_Noop_Encoding (The_Test : in out Fixture);

   --  Constant_I32 and Call round-trip; encoding sizes and words match.
   --  @param The_Test Unused fixture.
   procedure Test_Const_And_Call_Encoding (The_Test : in out Fixture);

   --  Each Value_Type as lone parameter and lone result round-trips.
   --  @param The_Test Unused fixture.
   procedure Test_All_Value_Types (The_Test : in out Fixture);

   --  Decode rejects bad magic, version 2.0, truncated, trailing, bad opcode/type/UTF-8.
   --  @param The_Test Unused fixture.
   procedure Test_Decode_Failures (The_Test : in out Fixture);

   --  Module and subroutine origins with an absent filename round-trip.
   --  @param The_Test Unused fixture.
   procedure Test_Absent_Filename_Origins (The_Test : in out Fixture);

   --  Body signature, locals, native binding, and from-dependency success and failure arms.
   --  @param The_Test Unused fixture.
   procedure Test_Body_Failures (The_Test : in out Fixture);

   --  Encode rejects a module that fails validation.
   --  @param The_Test Unused fixture.
   procedure Test_Encode_Failures (The_Test : in out Fixture);

   --  Read and Write report I/O and validation failures.
   --  @param The_Test Unused fixture.
   procedure Test_File_Failures (The_Test : in out Fixture);

   --  Hand-built image decodes and re-encodes to identical bytes.
   --  @param The_Test Unused fixture.
   procedure Test_Hand_Built_Baseline (The_Test : in out Fixture);

   --  Magic, version, and header field failures, including cut-off headers.
   --  @param The_Test Unused fixture.
   procedure Test_Header_Failures (The_Test : in out Fixture);

   --  Immediate extremes, invalid call and local operands, bad opcodes, cut-off instructions.
   --  @param The_Test Unused fixture.
   procedure Test_Instruction_Immediates (The_Test : in out Fixture);

   --  Invalid UTF-8, empty, self-dependency, and duplicate-dependency names.
   --  @param The_Test Unused fixture.
   procedure Test_Name_Failures (The_Test : in out Fixture);

   --  Dependencies, origins, locals, from-dependency, native binding, and all opcodes round-trip.
   --  @param The_Test Unused fixture.
   procedure Test_Optional_Sections_Round_Trip (The_Test : in out Fixture);

   --  Bad source positions and cut-off origin records, plus boundary positions.
   --  @param The_Test Unused fixture.
   procedure Test_Origin_Failures (The_Test : in out Fixture);

   --  Preamble type, offset, and signature-mismatch failures.
   --  @param The_Test Unused fixture.
   procedure Test_Preamble_Failures (The_Test : in out Fixture);

   --  Origin, from-dependency, and native presence bytes other than 0 or 1.
   --  @param The_Test Unused fixture.
   procedure Test_Presence_Failures (The_Test : in out Fixture);

   --  Every proper prefix of a complete image decodes as Truncated.
   --  @param The_Test Unused fixture.
   procedure Test_Truncation_Sweep (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Binary_Format;
