with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Lir.Types and Opcodes helpers.

package Lovelace.Lir.Tests.Type_Codes is

   --  Fixture for type codes and opcode sizes.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  To_Code / From_Code for every Value_Type; unknown code is absent.
   --  @param The_Test Unused fixture.
   procedure Test_Type_Codes (The_Test : in out Fixture);

   --  Encoded_Length (No_Operation) is 2.
   --  @param The_Test Unused fixture.
   procedure Test_Encoded_Length (The_Test : in out Fixture);

end Lovelace.Lir.Tests.Type_Codes;
