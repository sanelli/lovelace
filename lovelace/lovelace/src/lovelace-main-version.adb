with Ada.Text_IO;

with Lovelace.Common.Release;
with Lovelace.Main.Git_Hash;

package body Lovelace.Main.Version is

   function Product_Version return String is
   begin
      return Lovelace.Common.Release.Version & " @ " & Git_Hash.Git_Hash;
   end Product_Version;

   procedure Run is
   begin
      Ada.Text_IO.Put_Line (Product_Version);
   end Run;

end Lovelace.Main.Version;
