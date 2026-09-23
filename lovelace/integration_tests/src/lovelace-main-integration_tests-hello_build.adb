with Ada.Directories;
with Ada.Text_IO;
with AUnit.Assertions;
with GNAT.OS_Lib;

package body Lovelace.Main.Integration_Tests.Hello_Build is

   use type GNAT.OS_Lib.String_Access;

   function Compose_Under (Root, Relative : String) return String;
   --  Ada.Directories.Compose chained for Root / Relative path segments.

   function Locate_Lovelace return String;
   --  Path to lovelace under ../bin or on PATH.

   function Locate_Sample return String;
   --  Path to samples/Hello.love relative to this crate.

   function Compose_Under (Root, Relative : String) return String is
   begin
      return Ada.Directories.Compose (Root, Relative);
   end Compose_Under;

   function Locate_Lovelace return String is
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
   end Locate_Lovelace;

   function Locate_Sample return String is
      Relative : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Compose
             (Ada.Directories.Compose ("..", ".."), "samples"),
           "Hello.love");
   begin
      return Relative;
   end Locate_Sample;

   procedure Test_Build_And_Wasmtime (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lovelace_Path : constant String := Locate_Lovelace;
      Sample_Path   : constant String := Locate_Sample;
      Wasmtime_Path : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("wasmtime");
      Output_Root   : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Current_Directory, "integration-output");
      Success       : Boolean;
      Return_Code   : Integer;
      Build_Args    : GNAT.OS_Lib.Argument_List_Access;
      Run_Args      : GNAT.OS_Lib.Argument_List_Access;
   begin
      AUnit.Assertions.Assert
        (Lovelace_Path'Length > 0, "lovelace executable present");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Sample_Path), "Hello.love present");

      if Wasmtime_Path = null then
         Ada.Text_IO.Put_Line ("INCONCLUSIVE: wasmtime not found");
         return;
      end if;

      if Ada.Directories.Exists (Output_Root) then
         Ada.Directories.Delete_Tree (Output_Root);
      end if;
      Ada.Directories.Create_Path (Output_Root);

      Build_Args :=
        new GNAT.OS_Lib.Argument_List'
          (1 => new String'("--no-logo"),
           2 => new String'("build"),
           3 => new String'(Sample_Path),
           4 => new String'("--output-format"),
           5 => new String'("wasm,wat"),
           6 => new String'("--output-folder"),
           7 => new String'(Output_Root),
           8 => new String'("--force"));

      Return_Code :=
        GNAT.OS_Lib.Spawn
          (Program_Name => Lovelace_Path, Args => Build_Args.all);
      GNAT.OS_Lib.Free (Build_Args);
      AUnit.Assertions.Assert (Return_Code = 0, "lovelace build exit 0");

      AUnit.Assertions.Assert
        (Ada.Directories.Exists
           (Compose_Under (Compose_Under (Output_Root, "obj"), "Hello.lir")),
         "Hello.lir");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists
           (Compose_Under (Compose_Under (Output_Root, "bin"), "Hello.wasm")),
         "Hello.wasm");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists
           (Compose_Under (Compose_Under (Output_Root, "bin"), "Hello.wat")),
         "Hello.wat");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists
           (Compose_Under (Compose_Under (Output_Root, "bin"), "Hello.wit")),
         "Hello.wit");

      declare
         Wasm_Path : constant String :=
           Compose_Under (Compose_Under (Output_Root, "bin"), "Hello.wasm");
         Wat_Path  : constant String :=
           Compose_Under (Compose_Under (Output_Root, "bin"), "Hello.wat");
      begin
         Run_Args :=
           new GNAT.OS_Lib.Argument_List'
             (1 => new String'("run"),
              2 => new String'("-Sp3"),
              3 => new String'("-W"),
              4 => new String'("component-model-async=y"),
              5 => new String'(Wasm_Path));
         GNAT.OS_Lib.Spawn
           (Program_Name => Wasmtime_Path.all,
            Args         => Run_Args.all,
            Success      => Success);
         GNAT.OS_Lib.Free (Run_Args);
         AUnit.Assertions.Assert (Success, "wasmtime Hello.wasm");

         Run_Args :=
           new GNAT.OS_Lib.Argument_List'
             (1 => new String'("run"),
              2 => new String'("-Sp3"),
              3 => new String'("-W"),
              4 => new String'("component-model-async=y"),
              5 => new String'(Wat_Path));
         GNAT.OS_Lib.Spawn
           (Program_Name => Wasmtime_Path.all,
            Args         => Run_Args.all,
            Success      => Success);
         GNAT.OS_Lib.Free (Run_Args);
         AUnit.Assertions.Assert (Success, "wasmtime Hello.wat");
      end;

      GNAT.OS_Lib.Free (Wasmtime_Path);
   end Test_Build_And_Wasmtime;

end Lovelace.Main.Integration_Tests.Hello_Build;
