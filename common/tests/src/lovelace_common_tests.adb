with AUnit.Reporter.Text;
with AUnit.Run;

with Lovelace.Common.Tests.Suite;

--  AUnit harness for lovelace_common_tests.

procedure Lovelace_Common_Tests is
   procedure Runner is new AUnit.Run.Test_Runner (Lovelace.Common.Tests.Suite.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Runner (Reporter);
end Lovelace_Common_Tests;
