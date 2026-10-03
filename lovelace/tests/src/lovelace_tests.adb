with AUnit.Run;

with Lovelace.Main.Tests.Suite;
with Lovelace.Test_Status;

--  AUnit harness for lovelace_tests.

procedure Lovelace_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Main.Tests.Suite.Suite);
   Reporter : Lovelace.Test_Status.Status_Reporter;
begin
   Runner (Reporter);
end Lovelace_Tests;
