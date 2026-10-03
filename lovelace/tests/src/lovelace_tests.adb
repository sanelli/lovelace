with AUnit.Run;

with Lovelace.Main.Tests.Suite;
with Lovelace.Test_Status;

--  AUnit harness for lovelace_tests.

procedure Lovelace_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Main.Tests.Suite.Suite);
   Reporter : Lovelace.Test_Status.Status_Reporter;
begin
   Lovelace.Test_Status.Report_Suite_Header ("lovelace");
   Runner (Reporter);
   Lovelace.Test_Status.Report_Suite_Footer;
end Lovelace_Tests;
