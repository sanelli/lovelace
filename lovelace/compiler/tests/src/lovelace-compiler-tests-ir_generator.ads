with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Ir_Generator.

package Lovelace.Compiler.Tests.Ir_Generator is

   --  Fixture for IR Generator matrix tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Assignment + identifier read + call with identifier arg emit Local_Set/Get/Constant/Call.
   --  @param The_Test Unused fixture.
   procedure Test_Assignment_And_Local_Access (The_Test : in out Fixture);

   --  Canonical program Hello; begin end. lowers to matching LIR structure and origins.
   --  @param The_Test Unused fixture.
   procedure Test_Canonical_Multiline (The_Test : in out Fixture);

   --  Multi-unit flatten lowers resolved exported calls to the flat callee index.
   --  @param The_Test Unused fixture.
   procedure Test_Cross_Module_Calls (The_Test : in out Fixture);

   --  Dotted module name is preserved on the LIR module with zero subroutines.
   --  @param The_Test Unused fixture.
   procedure Test_Dotted_Module_Name (The_Test : in out Fixture);

   --  Empty module Empty; end. lowers to a LIR module with no subroutines.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module (The_Test : in out Fixture);

   --  Hand-built AST with export-only flags maps export without entrypoint.
   --  @param The_Test Unused fixture.
   procedure Test_Export_Only_Flags (The_Test : in out Fixture);

   --  export procedure with parameters maps Export_Flag and LIR parameters.
   --  @param The_Test Unused fixture.
   procedure Test_Export_Procedure_Parameters (The_Test : in out Fixture);

   --  Tokenize+Parse with a filename label shares storage on LIR module and subroutine.
   --  @param The_Test Unused fixture.
   procedure Test_Filename_Shared (The_Test : in out Fixture);

   --  Nested declare locals flatten into ordered LIR local slots with mapped types.
   --  @param The_Test Unused fixture.
   procedure Test_Flattened_Locals (The_Test : in out Fixture);

   --  Unicode and @-prefixed identifiers preserve names into LIR.
   --  @param The_Test Unused fixture.
   procedure Test_Identifier_Names (The_Test : in out Fixture);

   --  Leading and nested usings lower to unique LIR Dependencies; empty stay zero.
   --  @param The_Test Unused fixture.
   procedure Test_Import_Dependencies (The_Test : in out Fixture);

   --  Hand-built AST / empty compilation set edges: Find_Local miss, Split_Callee, arity,
   --  native/intrinsic flag conflicts, version attribute, and duplicate usings.
   --  @param The_Test Unused fixture.
   procedure Test_Internal_Edges (The_Test : in out Fixture);

   --  Module procedure parameters lower to named LIR signature entries with mapped types.
   --  @param The_Test Unused fixture.
   procedure Test_Module_Procedure_Parameters (The_Test : in out Fixture);

   --  native("wasi", "native-print-integer") lowers to LIR Native_Flag + binding; unknown keys fail.
   --  @param The_Test Unused fixture.
   procedure Test_Native_Binding (The_Test : in out Fixture);

   --  Overloads select distinct Call targets; LIR names stay the source name.
   --  @param The_Test Unused fixture.
   procedure Test_Overload_Calls (The_Test : in out Fixture);

   --  Integer/float/boolean formals map to matching LIR Value_Type (boolean -> I32).
   --  @param The_Test Unused fixture.
   procedure Test_Parameter_Type_Mapping (The_Test : in out Fixture);

   --  Same-unit calls (integer + boolean literals) lower; unresolved calls are not an IR decision (Internal_Error).
   --  @param The_Test Unused fixture.
   procedure Test_Same_Unit_Calls (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Ir_Generator;
