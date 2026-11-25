with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces.C;

package body Lovelace.Main.Tests.Support is

   use type GNAT.OS_Lib.String_Access;
   use type Interfaces.C.int;

   function C_Dup (Old_Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Dup, "dup");

   function C_Dup2 (Old_Fd : Interfaces.C.int; New_Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Dup2, "dup2");

   function C_Close (Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   Stderr_Fd : constant Interfaces.C.int := 2;

   Capture_Active : Boolean := False;
   Saved_Stderr   : Interfaces.C.int := -1;
   Stderr_Target  : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Stdout_File    : Ada.Text_IO.File_Type;

   function Locate_Lovelace_Executable return String is
      Relative : constant String := Ada.Directories.Compose (Ada.Directories.Compose ("..", "bin"), "lovelace");
   begin
      if Ada.Directories.Exists (Relative) then
         return Relative;
      end if;

      declare
         On_Path : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("lovelace");
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

   function Read_File (Path : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      declare
         Length   : constant Natural := Natural (Ada.Streams.Stream_IO.Size (File));
         Contents : String (1 .. Length);
      begin
         String'Read (Ada.Streams.Stream_IO.Stream (File), Contents);
         Ada.Streams.Stream_IO.Close (File);
         return Contents;
      end;
   end Read_File;

   procedure Start_Capture (Stdout_Path : String; Stderr_Path : String) is
      Ignored : Interfaces.C.int;
      pragma Unreferenced (Ignored);
   begin
      Stop_Capture;
      Ada.Text_IO.Create (Stdout_File, Ada.Text_IO.Out_File, Stdout_Path);
      Ada.Text_IO.Set_Output (Stdout_File);

      Stderr_Target := GNAT.OS_Lib.Create_File (Stderr_Path, GNAT.OS_Lib.Text);
      Saved_Stderr := C_Dup (Stderr_Fd);
      Ignored := C_Dup2 (Interfaces.C.int (Stderr_Target), Stderr_Fd);
      Capture_Active := True;
   end Start_Capture;

   procedure Stop_Capture is
      Ignored : Interfaces.C.int;
      pragma Unreferenced (Ignored);
   begin
      if not Capture_Active then
         return;
      end if;
      Capture_Active := False;

      Ada.Text_IO.Flush (Ada.Text_IO.Standard_Error.all);
      Ignored := C_Dup2 (Saved_Stderr, Stderr_Fd);
      Ignored := C_Close (Saved_Stderr);
      GNAT.OS_Lib.Close (Stderr_Target);
      Stderr_Target := GNAT.OS_Lib.Invalid_FD;

      Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output.all);
      if Ada.Text_IO.Is_Open (Stdout_File) then
         Ada.Text_IO.Close (Stdout_File);
      end if;
   end Stop_Capture;

end Lovelace.Main.Tests.Support;
