with AUnit.Test_Fixtures;

--  AUnit fixtures for Lovelace.Common.Option.

package Lovelace.Common.Tests.Option is

   --  Fixture for Option generic tests.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  From_Value sets Present True and stores Value.
   --  @param The_Test Unused fixture.
   procedure Test_From_Value (The_Test : in out Fixture);

   --  None sets Present False.
   --  @param The_Test Unused fixture.
   procedure Test_None (The_Test : in out Fixture);

   --  case on Present handles both arms without reading Value when absent.
   --  @param The_Test Unused fixture.
   procedure Test_Present_Discriminant (The_Test : in out Fixture);

end Lovelace.Common.Tests.Option;
