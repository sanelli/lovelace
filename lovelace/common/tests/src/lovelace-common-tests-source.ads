with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Common.Source.

package Lovelace.Common.Tests.Source is

   --  Fixture for source position and shared-filename tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Source_Span stores First and Last positions as constructed.
   --  @param The_Test Unused fixture.
   procedure Test_Source_Span_Fields (The_Test : in out Fixture);

   --  Absent_Filename has Present False.
   --  @param The_Test Unused fixture.
   procedure Test_Absent_Filename (The_Test : in out Fixture);

   --  Clear_Filename_Pool drops interned text; a new From_Utf_8 still works.
   --  @param The_Test Unused fixture.
   procedure Test_Clear_Filename_Pool (The_Test : in out Fixture);

   --  From_Utf_8 interns: equal text shares one pool index; different text does not.
   --  @param The_Test Unused fixture.
   procedure Test_Same_Storage_Shared_Filename (The_Test : in out Fixture);

   --  Filename_Option Same_Storage covers absent/present and interned cases.
   --  @param The_Test Unused fixture.
   procedure Test_Same_Storage_Filename_Option (The_Test : in out Fixture);

   --  To_Utf_8 returns the stored path; absent options yield the empty string.
   --  @param The_Test Unused fixture.
   procedure Test_To_Utf_8 (The_Test : in out Fixture);

end Lovelace.Common.Tests.Source;
