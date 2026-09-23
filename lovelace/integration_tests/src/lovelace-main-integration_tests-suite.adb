with AUnit.Test_Caller;

with Lovelace.Main.Integration_Tests.Hello_Build;

package body Lovelace.Main.Integration_Tests.Suite is

   package Hello_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Hello_Build.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Hello_Caller.Create
           ("build Hello and wasmtime",
            Hello_Build.Test_Build_And_Wasmtime'Access));
      return Result;
   end Suite;

end Lovelace.Main.Integration_Tests.Suite;
