--  Version command for the Lovelace CLI.

package Lovelace.Main.Version is

   --  Canonical product version string: 0.0.1-alpha.1 @ <githash>.
   --  @return UTF-8 version line used by version and the startup logo.
   function Product_Version return String;

   --  Print the product version string to standard output.
   procedure Run;

end Lovelace.Main.Version;
