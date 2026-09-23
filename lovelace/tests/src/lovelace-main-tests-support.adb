with Ada.Directories;
with GNAT.OS_Lib;

package body Lovelace.Main.Tests.Support is

   use type GNAT.OS_Lib.String_Access;

   function Locate_Lovelace_Executable return String is
      Relative : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Compose ("..", "bin"), "lovelace");
   begin
      if Ada.Directories.Exists (Relative) then
         return Relative;
      end if;

      declare
         On_Path : GNAT.OS_Lib.String_Access :=
           GNAT.OS_Lib.Locate_Exec_On_Path ("lovelace");
      begin
         if On_Path = null then
            return "";
         end if;

         declare
            Result : constant String := On_Path.all;
         begin
            GNAT.OS_Lib.Free (On_Path);
            return Result;
         end;
      end;
   end Locate_Lovelace_Executable;

end Lovelace.Main.Tests.Support;
