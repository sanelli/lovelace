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

   --  Nested `using` inside begin ... end still loads the dependency module.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Nested_Using (The_Test : in out Fixture);

   --  Resolved versions: @version, .loveversion, CLI fallback, invalid .loveversion.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Versions (The_Test : in out Fixture);

   --  A module reached twice (diamond) loads once; usings inside dependency and
   --  subroutine bodies load transitively.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Shared_And_Transitive (The_Test : in out Fixture);

   --  Dependency name mismatch, tokenizer/parser errors, transitive failures,
   --  and unreadable dependency files.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Dependency_Failures (The_Test : in out Fixture);

   --  Invalid or unreadable .loveversion for a dependency or for the root.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Version_Failures (The_Test : in out Fixture);

   --  A dependency larger than one read chunk loads completely.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Large_Dependency (The_Test : in out Fixture);

   --  A root path that cannot be normalized is kept as written.
   --  @param The_Test Unused fixture.
   procedure Test_Load_Invalid_Root_Path (The_Test : in out Fixture);

   --  Surface_Error_Code maps every Unit_Graph_Error_Code.
   --  @param The_Test Unused fixture.
   procedure Test_Surface_Error_Codes (The_Test : in out Fixture);

   --  Versioning.Is_Valid_Version accepts and rejects the documented shapes.
   --  @param The_Test Unused fixture.
   procedure Test_Version_Syntax (The_Test : in out Fixture);

   --  Versioning.Library_Root_For picks the longest matching root.
   --  @param The_Test Unused fixture.
   procedure Test_Library_Root_For (The_Test : in out Fixture);

   --  Versioning.Try_Read_Loveversion success and failure paths.
   --  @param The_Test Unused fixture.
   procedure Test_Try_Read_Loveversion (The_Test : in out Fixture);

   --  Versioning.Resolve_Version priority: file, .loveversion, CLI, default.
   --  @param The_Test Unused fixture.
   procedure Test_Resolve_Version_Priority (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Unit_Graph;
