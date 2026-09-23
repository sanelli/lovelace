with AUnit.Reporter.Text;
with AUnit.Run;

with Lovelace.Main.Integration_Tests.Suite;

--  AUnit harness for lovelace_integration_tests.

procedure Lovelace_Integration_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Main.Integration_Tests.Suite.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Runner (Reporter);
end Lovelace_Integration_Tests;
