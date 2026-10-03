with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Literals.

package Lovelace.Compiler.Tests.Literals is

   --  Fixture for literal interpretation tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Decimal, based, signedness, and size suffixes interpret successfully.
   --  @param The_Test Unused fixture.
   procedure Test_Integer_Forms (The_Test : in out Fixture);

   --  Float lexemes with signs and exponents interpret successfully.
   --  @param The_Test Unused fixture.
   procedure Test_Float_Forms (The_Test : in out Fixture);

   --  Invalid digits for a base fail with Invalid_Literal.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Integer (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Literals;
