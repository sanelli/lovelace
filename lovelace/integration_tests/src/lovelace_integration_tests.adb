with AUnit.Options;
with AUnit.Run;

with Lovelace.Main.Integration_Tests.Suite;
with Lovelace.Main.Integration_Tests.Support;
with Lovelace.Test_Status;

--  AUnit harness for lovelace_integration_tests.

procedure Lovelace_Integration_Tests is
   procedure Runner is new
     AUnit.Run.Test_Runner (Lovelace.Main.Integration_Tests.Suite.Suite);

   Reporter : Lovelace.Test_Status.Silent_Reporter;
   Options  : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options;
begin
   Lovelace.Test_Status.Report_Suite_Header ("lovelace integration tests");
   Lovelace.Main.Integration_Tests.Support.Report_And_Require_Tools;

   --  Per-test lines come from Support.Report_Test_Result.
   Options.Report_Successes := False;
   Runner (Reporter, Options);
   Lovelace.Test_Status.Report_Suite_Footer;
end Lovelace_Integration_Tests;
