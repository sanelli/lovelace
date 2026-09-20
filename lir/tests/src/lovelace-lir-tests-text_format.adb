with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Text;
with Lovelace.Lir.Tests.Support;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Tests.Text_Format is

   use type GNAT.OS_Lib.File_Descriptor;
   use type Subroutines.Subroutine_Flags;

   procedure Test_Empty_Module_Golden (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("example");
      Rendered   : constant Ada.Strings.Unbounded.Unbounded_String :=
        Support.Must_To_Text (The_Module, "empty");
      Text       : constant String :=
        Ada.Strings.Unbounded.To_String (Rendered);
      Expected   : constant String :=
        "(module"
        & ASCII.LF
        & "  (version 1 0)"
        & ASCII.LF
        & "  (name ""example"")"
        & ASCII.LF
        & "  (flags 0)"
        & ASCII.LF
        & ")"
        & ASCII.LF;
   begin
      AUnit.Assertions.Assert (Text = Expected, "empty module golden");
      Support.Assert_Contains (Text, "(flags 0)", "flags");
      Support.Assert_Not_Contains (Text, "(depend", "no depend");
      Support.Assert_Not_Contains (Text, "(subroutine", "no subroutine");
   end Test_Empty_Module_Golden;

   procedure Test_Subroutine_Goldens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Params    : Types.Value_Type_Sequence := Types.Empty_Sequence;
      Unit_Only : Modules.Module := Modules.Create ("m");
      I32_Only  : Modules.Module := Modules.Create ("m");
      Param_Mod : Modules.Module := Modules.Create ("m");
      Flagged   : Modules.Module := Modules.Create ("m");
   begin
      Types.Append (Params, Types.I8);
      Types.Append (Params, Types.U8);
      Types.Append (Params, Types.F16);

      Modules.Append_Subroutine
        (Unit_Only, Support.Make_Subroutine ("P", Types.Unit));
      Modules.Append_Subroutine
        (I32_Only, Support.Make_Subroutine ("F", Types.I32));
      Modules.Append_Subroutine
        (Param_Mod,
         Support.Make_Subroutine ("G", Types.Unit, Parameter_Types => Params));
      Modules.Append_Subroutine
        (Flagged,
         Support.Make_Subroutine
           ("Main",
            Types.I32,
            Parameter_Types => Params,
            Flags           =>
              Subroutines.Export_Flag or Subroutines.Entrypoint_Flag,
            Noop_Count      => 1));

      declare
         Unit_Text  : constant String :=
           Ada.Strings.Unbounded.To_String
             (Support.Must_To_Text (Unit_Only, "unit"));
         I32_Text   : constant String :=
           Ada.Strings.Unbounded.To_String
             (Support.Must_To_Text (I32_Only, "i32"));
         Param_Text : constant String :=
           Ada.Strings.Unbounded.To_String
             (Support.Must_To_Text (Param_Mod, "param"));
         Flag_Text  : constant String :=
           Ada.Strings.Unbounded.To_String
             (Support.Must_To_Text (Flagged, "flags"));
      begin
         Support.Assert_Contains (Unit_Text, "(result unit)", "result unit");
         Support.Assert_Not_Contains (Unit_Text, "(param", "no param form");
         Support.Assert_Contains (I32_Text, "(result i32)", "result i32");
         Support.Assert_Contains
           (Param_Text, "(param i8 u8 f16)", "param list");
         Support.Assert_Contains (Param_Text, "(result unit)", "param result");
         Support.Assert_Contains (Flag_Text, "export", "export");
         Support.Assert_Contains (Flag_Text, "entrypoint", "entrypoint");
         Support.Assert_Contains (Flag_Text, "noop", "noop");
         Support.Assert_Contains (Flag_Text, "(body", "body");
      end;

      for The_Type in Types.Value_Type loop
         declare
            Token      : constant String :=
              (case The_Type is
                 when Types.Unit => "unit",
                 when Types.I8   => "i8",
                 when Types.I16  => "i16",
                 when Types.I32  => "i32",
                 when Types.I64  => "i64",
                 when Types.I128 => "i128",
                 when Types.U8   => "u8",
                 when Types.U16  => "u16",
                 when Types.U32  => "u32",
                 when Types.U64  => "u64",
                 when Types.U128 => "u128",
                 when Types.F16  => "f16",
                 when Types.F32  => "f32",
                 when Types.F64  => "f64");
            Lone_Param : Types.Value_Type_Sequence := Types.Empty_Sequence;
            As_Param   : Modules.Module := Modules.Create ("m");
            As_Result  : Modules.Module := Modules.Create ("m");
         begin
            Types.Append (Lone_Param, The_Type);
            Modules.Append_Subroutine
              (As_Param,
               Support.Make_Subroutine
                 ("P", Types.Unit, Parameter_Types => Lone_Param));
            Modules.Append_Subroutine
              (As_Result, Support.Make_Subroutine ("R", The_Type));
            Support.Assert_Contains
              (Ada.Strings.Unbounded.To_String
                 (Support.Must_To_Text (As_Param, "p")),
               "(param " & Token & ")",
               "param token " & Token);
            Support.Assert_Contains
              (Ada.Strings.Unbounded.To_String
                 (Support.Must_To_Text (As_Result, "r")),
               "(result " & Token & ")",
               "result token " & Token);
         end;
      end loop;
   end Test_Subroutine_Goldens;

   procedure Test_Write_Tlir (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("example");
      Path       : constant String := "obj/lir_test_roundtrip.tlir";
      Written    : Text.Write_Result;
      Deleted    : Boolean;
      Expected   : constant Ada.Strings.Unbounded.Unbounded_String :=
        Support.Must_To_Text (The_Module, "expected");
   begin
      Written := Text.Write (The_Module, Path);
      case Written.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False,
               "write failed " & Errors.Error_Code'Image (Written.Error));

         when True  =>
            declare
               Read_Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
                 GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
               File_Size       : Long_Integer;
            begin
               if Read_Descriptor = GNAT.OS_Lib.Invalid_FD then
                  AUnit.Assertions.Assert (False, "reopen failed");
               else
                  File_Size := GNAT.OS_Lib.File_Length (Read_Descriptor);
                  declare
                     Buffer     :
                       Ada.Streams.Stream_Element_Array
                         (1 .. Ada.Streams.Stream_Element_Offset (File_Size));
                     Got        : Integer;
                     Text_Bytes : String (1 .. Integer (File_Size));
                  begin
                     Got :=
                       GNAT.OS_Lib.Read
                         (Read_Descriptor, Buffer'Address, Buffer'Length);
                     GNAT.OS_Lib.Close (Read_Descriptor);
                     AUnit.Assertions.Assert
                       (Got = Integer (File_Size), "read size");
                     for Index in Text_Bytes'Range loop
                        Text_Bytes (Index) :=
                          Character'Val
                            (Natural
                               (Buffer
                                  (Ada.Streams.Stream_Element_Offset
                                     (Index))));
                     end loop;
                     AUnit.Assertions.Assert
                       (Text_Bytes
                        = Ada.Strings.Unbounded.To_String (Expected),
                        "tlir file matches To_Text");
                  end;
               end if;
            end;
      end case;
      GNAT.OS_Lib.Delete_File (Path, Deleted);
   end Test_Write_Tlir;

end Lovelace.Lir.Tests.Text_Format;
