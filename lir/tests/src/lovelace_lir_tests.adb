with AUnit.Reporter.Text;
with AUnit.Run;

with Lovelace.Lir.Tests.Suite;

--  AUnit harness for lovelace_lir_tests.

procedure Lovelace_Lir_Tests is
   procedure Runner is new AUnit.Run.Test_Runner (Lovelace.Lir.Tests.Suite.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Runner (Reporter);
end Lovelace_Lir_Tests;
