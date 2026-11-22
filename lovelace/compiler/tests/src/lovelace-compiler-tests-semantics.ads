with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Semantics (environment, DA, types, unused, call resolve).

package Lovelace.Compiler.Tests.Semantics is

   --  Fixture for semantics matrix tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Definite assignment: read of an unassigned local fails; assigned, parameter, and nested reads pass.
   --  @param The_Test Unused fixture.
   procedure Test_Definite_Assignment (The_Test : in out Fixture);

   --  Scope stack: innermost-first lookup, kind filtering, and pop.
   --  @param The_Test Unused fixture.
   procedure Test_Environment_Scopes (The_Test : in out Fixture);

   --  Missing callees (LV00014), non-exported callees (LV00018), and missing using (LV00017).
   --  @param The_Test Unused fixture.
   procedure Test_Missing_And_Not_Exported_Callees (The_Test : in out Fixture);

   --  Overload resolve by parameter types; Ambiguous_Call; export visibility of overloads.
   --  @param The_Test Unused fixture.
   procedure Test_Overload_Resolve (The_Test : in out Fixture);

   --  Semantic codes map to the stable LV labels and severities.
   --  @param The_Test Unused fixture.
   procedure Test_Reporting_Mapping (The_Test : in out Fixture);

   --  Using visibility follows the scope at the call site (unit, procedure, nested block, siblings).
   --  @param The_Test Unused fixture.
   procedure Test_Scoped_Using_Visibility (The_Test : in out Fixture);

   --  Type mismatch on `:=` and on call actuals vs formals, plus arity and literal ranges.
   --  @param The_Test Unused fixture.
   procedure Test_Type_Mismatch (The_Test : in out Fixture);

   --  Lovelace_Type assignability API shared by assignment and call checking.
   --  @param The_Test Unused fixture.
   procedure Test_Typecheck_Api (The_Test : in out Fixture);

   --  Unused_Variable vs Unused_Assignment priority, parameters, and nested scopes.
   --  @param The_Test Unused fixture.
   procedure Test_Unused_Priority (The_Test : in out Fixture);

   --  Unused_Using for unit and block usings; independence from Unused_Variable.
   --  @param The_Test Unused fixture.
   procedure Test_Unused_Using (The_Test : in out Fixture);

   --  Warnings never fail Analyze; errors in a dependency carry that unit's index.
   --  @param The_Test Unused fixture.
   procedure Test_Warnings_Do_Not_Fail (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Semantics;
