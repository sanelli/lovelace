with AUnit.Test_Fixtures;

--  Build program samples, validate artifacts, and run entrypoints when tools exist.

package Lovelace.Main.Integration_Tests.Hello_Build is

   --  Fixture for program sample end-to-end checks.
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Build samples/assignment/Assignment.love with -I Augusta; assert stdout "7".
   --  @param The_Test Unused fixture.
   procedure Test_Assignment_Build_Validate_And_Run (The_Test : in out Fixture);

   --  Build Hello.love; validate .wasm/.wat; run when wasmtime exists.
   --  @param The_Test Unused fixture.
   procedure Test_Build_Validate_And_Run (The_Test : in out Fixture);

   --  Build samples/emoji/🚀.love (emoji program + local); validate and run.
   --  @param The_Test Unused fixture.
   procedure Test_Emoji_Program_Build_Validate_And_Run
     (The_Test : in out Fixture);

   --  Build samples/io/HelloPrint.love with -I <repo>/augusta/lovelace so augusta.std.io
   --  resolves; validate stdout import in WAT; run and assert stdout is "42".
   --  @param The_Test Unused fixture.
   procedure Test_Hello_Print_Build_Validate_And_Run
     (The_Test : in out Fixture);

   --  Build samples/nested-using/NestedUsing.love with -I Augusta; assert stdout "1".
   --  @param The_Test Unused fixture.
   procedure Test_Nested_Using_Build_Validate_And_Run
     (The_Test : in out Fixture);

   --  Build overload/OverloadCaller.love (cross-module Sink overloads via OverloadLib).
   --  @param The_Test Unused fixture.
   procedure Test_Overload_Caller_Build_Validate_And_Run
     (The_Test : in out Fixture);

   --  Build resolve/Caller.love (multi-unit usings). File-dir search root finds
   --  Lib.love and pkg/Util.love beside Caller; -I may be needed once CLI exposes
   --  include paths for builds from other working directories.
   --  @param The_Test Unused fixture.
   procedure Test_Resolve_Caller_Build_Validate_And_Run
     (The_Test : in out Fixture);

   --  Build UsingDecl.love (resolves same-folder UsingLib); validate and run like Hello.
   --  @param The_Test Unused fixture.
   procedure Test_Using_Decl_Build_Validate_And_Run
     (The_Test : in out Fixture);

   --  Build samples/variables/Variables.love (nested declare); assert flattened
   --  Wasm locals in WAT; validate and run.
   --  @param The_Test Unused fixture.
   procedure Test_Variables_Build_Validate_And_Run (The_Test : in out Fixture);

end Lovelace.Main.Integration_Tests.Hello_Build;
