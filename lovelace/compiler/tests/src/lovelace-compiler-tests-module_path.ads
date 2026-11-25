with AUnit.Test_Fixtures;

--  AUnit fixtures for Module_Path candidate enumeration and resolve.

package Lovelace.Compiler.Tests.Module_Path is

   --  Fixture for module path tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Augusta_Root prefers AUGUSTA_HOME, else LOVELACE_HOME/lib/augusta/<version>,
   --  else ~/.lovelace/lib/augusta/<version>.
   --  @param The_Test Unused fixture.
   procedure Test_Augusta_Root_Slot (The_Test : in out Fixture);

   --  Default_Search_Roots includes file dir, cwd, -I paths, and an existing Augusta slot.
   --  @param The_Test Unused fixture.
   procedure Test_Default_Search_Roots (The_Test : in out Fixture);

   --  Augusta_Root and Default_Search_Roots fall back to USERPROFILE and to no
   --  Augusta slot when HOME and USERPROFILE are unset or empty.
   --  @param The_Test Unused fixture.
   procedure Test_Home_Fallbacks (The_Test : in out Fixture);

   --  Default_Search_Roots skips missing include directories, invalid paths, and
   --  duplicates; a root with no containing directory falls back to ".".
   --  @param The_Test Unused fixture.
   procedure Test_Search_Roots_Edge_Cases (The_Test : in out Fixture);

   --  Join_Root handles empty parts and every slash / backslash combination.
   --  @param The_Test Unused fixture.
   procedure Test_Join_Root (The_Test : in out Fixture);

   --  Module_To_Relative_Candidates handles empty names and empty segments.
   --  @param The_Test Unused fixture.
   procedure Test_Candidates_Empty_Segments (The_Test : in out Fixture);

   --  Resolve_Module_File deduplicates repeated roots and ignores invalid roots.
   --  @param The_Test Unused fixture.
   procedure Test_Resolve_Duplicate_And_Invalid_Roots
     (The_Test : in out Fixture);

   --  Module_To_Relative_Candidates enumerates mixed slash/dot forms stably.
   --  @param The_Test Unused fixture.
   procedure Test_Relative_Candidates (The_Test : in out Fixture);

   --  Resolve finds a unique file, reports not-found, and errors when ambiguous.
   --  @param The_Test Unused fixture.
   procedure Test_Resolve_Unique_Missing_Ambiguous (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Module_Path;
