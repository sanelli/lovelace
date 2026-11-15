with AUnit.Test_Fixtures;

--  AUnit fixtures for Module_Path candidate enumeration and resolve.

package Lovelace.Compiler.Tests.Module_Path is

   --  Fixture for module path tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Augusta_Root prefers AUGUSTA_HOME, else LOVELACE_HOME/lib/augusta, else ~/.lovelace/lib/augusta.
   --  @param The_Test Unused fixture.
   procedure Test_Augusta_Root_Slot (The_Test : in out Fixture);

   --  Default_Search_Roots includes file dir, cwd, -I paths, and an existing Augusta slot.
   --  @param The_Test Unused fixture.
   procedure Test_Default_Search_Roots (The_Test : in out Fixture);

   --  Module_To_Relative_Candidates enumerates mixed slash/dot forms stably.
   --  @param The_Test Unused fixture.
   procedure Test_Relative_Candidates (The_Test : in out Fixture);

   --  Resolve finds a unique file, reports not-found, and errors when ambiguous.
   --  @param The_Test Unused fixture.
   procedure Test_Resolve_Unique_Missing_Ambiguous (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Module_Path;
