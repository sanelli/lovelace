with Ada.Strings.Fixed;
with AUnit.Assertions;

with Lovelace.Main.Version;

package body Lovelace.Main.Tests.Version is

   package Cli_Version renames Lovelace.Main.Version;

   procedure Test_Version_Prefix (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Text : constant String := Cli_Version.Product_Version;
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Text, "0.0.1-alpha.1 @ ") = Text'First,
         "version prefix");
   end Test_Version_Prefix;

end Lovelace.Main.Tests.Version;
