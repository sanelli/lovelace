with AUnit.Test_Caller;

with Lovelace.Main.Integration_Tests.Hello_Build;
with Lovelace.Main.Integration_Tests.Module_Build;

package body Lovelace.Main.Integration_Tests.Suite is

   package Hello_Caller is new AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Hello_Build.Fixture);

   package Module_Caller is new AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Module_Build.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (Hello_Caller.Create ("build Hello and wasmtime", Hello_Build.Test_Build_And_Wasmtime'Access));
      Result.Add_Test (Module_Caller.Create ("build module samples", Module_Build.Test_Build_Module_Samples'Access));
      return Result;
   end Suite;

end Lovelace.Main.Integration_Tests.Suite;
