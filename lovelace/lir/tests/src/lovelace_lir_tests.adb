with AUnit.Run;

with Lovelace.Lir.Tests.Suite;
with Lovelace.Test_Status;

--  AUnit harness for lovelace_lir_tests.

procedure Lovelace_Lir_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Lir.Tests.Suite.Suite);
   Reporter : Lovelace.Test_Status.Status_Reporter;
begin
   Lovelace.Test_Status.Report_Suite_Header ("lir");
   Runner (Reporter);
   Lovelace.Test_Status.Report_Suite_Footer;
end Lovelace_Lir_Tests;
