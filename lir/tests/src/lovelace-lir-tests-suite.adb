package body Lovelace.Lir.Tests.Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      return Result;
   end Suite;

end Lovelace.Lir.Tests.Suite;
