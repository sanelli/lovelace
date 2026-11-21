with AUnit.Test_Fixtures;

--  AUnit fixtures for Unit_Graph import closure loading.

package Lovelace.Compiler.Tests.Unit_Graph is

   --  Fixture for unit graph tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Loads a root plus a direct dependency (diamond-safe single load).
   --  @param The_Test Unused fixture.
   procedure Test_Load_Dependency (The_Test : in out Fixture);

   --  Unknown / ambiguous / circular / program-as-dependency failures.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Failures (The_Test : in out Fixture);

   --  Nested `using` inside beginâ¦end still loads the dependency module.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Nested_Using (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Unit_Graph;
