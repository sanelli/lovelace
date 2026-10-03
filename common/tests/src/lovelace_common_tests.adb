with AUnit.Run;

with Lovelace.Common.Tests.Suite;
with Lovelace.Test_Status;

--  AUnit harness for lovelace_common_tests.

procedure Lovelace_Common_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Common.Tests.Suite.Suite);
   Reporter : Lovelace.Test_Status.Status_Reporter;
begin
   Runner (Reporter);
end Lovelace_Common_Tests;
