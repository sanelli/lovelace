with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Compiler.Literals.

package Lovelace.Compiler.Tests.Literals is

   --  Fixture for literal interpretation tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Decimal, 0b/0o/0x, signedness, and size suffixes interpret successfully.
   --  @param The_Test Unused fixture.
   procedure Test_Integer_Forms (The_Test : in out Fixture);

   --  Float lexemes with signs and exponents interpret successfully.
   --  @param The_Test Unused fixture.
   procedure Test_Float_Forms (The_Test : in out Fixture);

   --  Invalid digits for a base fail with Invalid_Literal.
   --  @param The_Test Unused fixture.
   procedure Test_Invalid_Integer (The_Test : in out Fixture);

   --  To_Integer_32 evaluates decimal/0x/negative forms; overflow fails.
   --  @param The_Test Unused fixture.
   procedure Test_To_Integer_32 (The_Test : in out Fixture);

end Lovelace.Compiler.Tests.Literals;
