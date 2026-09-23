with AUnit.Reporter.Text;
with AUnit.Run;

with Lovelace.Main.Tests.Suite;

--  AUnit harness for lovelace_tests.

procedure Lovelace_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Main.Tests.Suite.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Runner (Reporter);
end Lovelace_Tests;
