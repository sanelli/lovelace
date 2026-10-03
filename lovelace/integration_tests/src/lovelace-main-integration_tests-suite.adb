with AUnit.Test_Caller;

with Lovelace.Main.Integration_Tests.Hello_Build;
with Lovelace.Main.Integration_Tests.Module_Build;
with Lovelace.Main.Integration_Tests.Support_Tests;

package body Lovelace.Main.Integration_Tests.Suite is

   package Hello_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Hello_Build.Fixture);
   package Module_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Module_Build.Fixture);
   package Support_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Support_Tests.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Support_Caller.Create
           ("support: locate lovelace and compose paths",
            Lovelace
              .Main
              .Integration_Tests
              .Support_Tests
              .Test_Locate_And_Compose'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("build: validate and run program Hello",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Build
              .Test_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Module_Caller.Create
           ("build: validate modules Empty and Foo.Bar",
            Lovelace
              .Main
              .Integration_Tests
              .Module_Build
              .Test_Build_And_Validate'Access));
      return Result;
   end Suite;

end Lovelace.Main.Integration_Tests.Suite;
