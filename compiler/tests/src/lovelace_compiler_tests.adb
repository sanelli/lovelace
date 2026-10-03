with AUnit.Run;

with Lovelace.Compiler.Tests.Suite;
with Lovelace.Test_Status;

--  AUnit harness for lovelace_compiler_tests.

procedure Lovelace_Compiler_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Compiler.Tests.Suite.Suite);
   Reporter : Lovelace.Test_Status.Status_Reporter;
begin
   Runner (Reporter);
end Lovelace_Compiler_Tests;
