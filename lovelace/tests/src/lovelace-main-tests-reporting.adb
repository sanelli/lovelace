with AUnit.Assertions;

with Lovelace.Compiler.Reporting;

package body Lovelace.Main.Tests.Reporting is

   package Compiler_Reporting renames Lovelace.Compiler.Reporting;

   procedure Test_Love_Basename (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Compiler_Reporting.Love_Basename ("Hello.love") = "Hello", "simple");
      AUnit.Assertions.Assert
        (Compiler_Reporting.Love_Basename ("samples/Hello.love") = "Hello",
         "dir");
      AUnit.Assertions.Assert
        (Compiler_Reporting.Love_Basename ("Hello") = "Hello", "no suffix");
   end Test_Love_Basename;

end Lovelace.Main.Tests.Reporting;
