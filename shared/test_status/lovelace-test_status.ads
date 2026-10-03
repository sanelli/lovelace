with AUnit.Options;
with AUnit.Reporter;
with AUnit.Test_Results;

--  Shared AUnit status lines: "NAME  [OK|FAIL|INCONCLUSIVE]" with ANSI colors.

package Lovelace.Test_Status is

   --  Printed status for one test case.
   --  @enum Ok Test completed successfully.
   --  @enum Fail Test hit a failing assertion or unexpected error.
   --  @enum Inconclusive Optional tool or precondition missing.
   type Test_Outcome is (Ok, Fail, Inconclusive);

   --  Print "NAME  [OK|FAIL|INCONCLUSIVE]" with colored status.
   --  @param Name Test display name.
   --  @param Outcome Result to print.
   procedure Report_Test_Result (Name : String; Outcome : Test_Outcome);

   --  AUnit reporter that prints one colored status line per test (no totals).
   type Status_Reporter is new AUnit.Reporter.Reporter with null record;

   --  Report each success/failure/error as a status line.
   --  @param Engine Unused reporter state.
   --  @param R Collected AUnit results.
   --  @param Options Ignored (successes are always printed).
   overriding
   procedure Report
     (Engine  : Status_Reporter;
      R       : in out AUnit.Test_Results.Result'Class;
      Options : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options);

   --  AUnit reporter that prints nothing (use with manual Report_Test_Result).
   type Silent_Reporter is new AUnit.Reporter.Reporter with null record;

   --  No output.
   --  @param Engine Unused.
   --  @param R Unused.
   --  @param Options Unused.
   overriding
   procedure Report
     (Engine  : Silent_Reporter;
      R       : in out AUnit.Test_Results.Result'Class;
      Options : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options);

end Lovelace.Test_Status;
