with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Lir.Text.

package Lovelace.Lir.Tests.Text_Format is

   --  Fixture for .tlir writer tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Empty module golden: flags 0, no dependency or subroutine forms.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module_Golden (The_Test : in out Fixture);

   --  Print writes To_Text to standard output.
   --  @param The_Test Unused fixture.
   procedure Test_Print (The_Test : in out Fixture);

   --  Print of an invalid module fails without writing.
   --  @param The_Test Unused fixture.
   procedure Test_Print_Invalid (The_Test : in out Fixture);

   --  Quoted names escape ", \, LF, CR, tab, and other controls.
   --  @param The_Test Unused fixture.
   procedure Test_Quoted_Escapes (The_Test : in out Fixture);

   --  Signature and flag golden fragments for representative subroutines.
   --  @param The_Test Unused fixture.
   procedure Test_Subroutine_Goldens (The_Test : in out Fixture);

   --  To_Text of an invalid module returns the validation Error_Code.
   --  @param The_Test Unused fixture.
   procedure Test_To_Text_Invalid (The_Test : in out Fixture);

   --  Write to a missing directory fails.
   --  @param The_Test Unused fixture.
   procedure Test_Write_Invalid_Path (The_Test : in out Fixture);

   --  Write to a temp .tlir matches To_Text.
   --  @param The_Test Unused fixture.
   procedure Test_Write_Tlir (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Text_Format;
