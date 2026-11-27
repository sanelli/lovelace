with AUnit.Assertions;

with Lovelace.Common.Internal_Error;

package body Lovelace.Common.Tests.Internal_Error is

   type Sample_Group is (Sample);

   package Sample_Errors is new Lovelace.Common.Internal_Error (Error_Group => Sample_Group);

   procedure Test_Make_Detail_Report (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Item : constant Sample_Errors.Lovelace_Internal_Error := Sample_Errors.Make (Sample, "boom");
   begin
      AUnit.Assertions.Assert (Sample_Errors.Detail (Item) = "boom", "detail");
      AUnit.Assertions.Assert
        (Sample_Errors.Report (Item) = "internal error: boom", "report");
   end Test_Make_Detail_Report;

end Lovelace.Common.Tests.Internal_Error;
