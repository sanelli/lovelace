with AUnit.Test_Caller;

with Lovelace.Main.Integration_Tests.Hello_Compile;
with Lovelace.Main.Integration_Tests.Module_Compile;
with Lovelace.Main.Integration_Tests.Support_Tests;

package body Lovelace.Main.Integration_Tests.Suite is

   package Hello_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Hello_Compile.Fixture);
   package Module_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Integration_Tests.Module_Compile.Fixture);
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
           ("compile: validate and run program Hello",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program HelloPrint",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Hello_Print_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program NestedUsing",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Nested_Using_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program OverloadCaller",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Overload_Caller_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program UsingDecl",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Using_Decl_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program Assignment",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Assignment_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program Caller",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Resolve_Caller_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program Variables",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Variables_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Hello_Caller.Create
           ("compile: validate and run program emoji rocket",
            Lovelace
              .Main
              .Integration_Tests
              .Hello_Compile
              .Test_Emoji_Program_Build_Validate_And_Run'Access));
      Result.Add_Test
        (Module_Caller.Create
           ("compile: validate modules Empty and Foo.Bar",
            Lovelace
              .Main
              .Integration_Tests
              .Module_Compile
              .Test_Build_And_Validate'Access));
      return Result;
   end Suite;

end Lovelace.Main.Integration_Tests.Suite;
