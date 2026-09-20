with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Lir.Text.

package Lovelace.Lir.Tests.Text_Format is

   --  Fixture for .tlir writer tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Empty module golden: flags 0, no depend or subroutine forms.
   --  @param The_Test Unused fixture.
   procedure Test_Empty_Module_Golden (The_Test : in out Fixture);

   --  Signature and flag golden fragments for representative subroutines.
   --  @param The_Test Unused fixture.
   procedure Test_Subroutine_Goldens (The_Test : in out Fixture);

   --  Write to a temp .tlir matches To_Text.
   --  @param The_Test Unused fixture.
   procedure Test_Write_Tlir (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Text_Format;
