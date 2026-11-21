with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Interfaces;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
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
        & "  (lir-version 1 0)"
        & ASCII.LF
        & "  (module-version ""0.0.1"")"
        & ASCII.LF
        & "  (name ""example"")"
        & ASCII.LF
        & ")"
        & ASCII.LF;
   begin
      AUnit.Assertions.Assert (Text = Expected, "empty module golden");
      Support.Assert_Not_Contains (Text, "(flags", "no zero flags");
      Support.Assert_Not_Contains (Text, "(dependency", "no dependency");
      Support.Assert_Not_Contains (Text, "(subroutine", "no subroutine");
   end Test_Empty_Module_Golden;

   procedure Test_Subroutine_Goldens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Params    : Types.Parameter_Sequence := Types.Empty_Sequence;
      Unit_Only : Modules.Module := Modules.Create ("m");
      I32_Only  : Modules.Module := Modules.Create ("m");
      Param_Mod : Modules.Module := Modules.Create ("m");
      Flagged   : Modules.Module := Modules.Create ("m");
   begin
      Types.Append (Params, "a", Types.I8);
      Types.Append (Params, "b", Types.U8);
      Types.Append (Params, "c", Types.F32);

      Modules.Append_Subroutine
        (Unit_Only, Support.Make_Subroutine ("P", Types.Unit));
      Modules.Append_Subroutine
        (I32_Only, Support.Make_Subroutine ("F", Types.I32));
      Modules.Append_Subroutine
        (Param_Mod,
         Support.Make_Subroutine ("G", Types.Unit, Parameters => Params));
      Modules.Append_Subroutine
        (Flagged,
         Support.Make_Subroutine
           ("Main",
            Types.I32,
            Parameters => Params,
            Flags      =>
              Subroutines.Export_Flag or Subroutines.Entrypoint_Flag,
            Noop_Count => 1));

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
         Support.Assert_Contains
           (Unit_Text, "(index" & ASCII.LF & "    (1 ""P"" (result unit))", "unit index");
         Support.Assert_Not_Contains (Unit_Text, "(param", "no param form");
         Support.Assert_Contains (I32_Text, "(result i32)", "result i32");
         Support.Assert_Contains
           (I32_Text, "(1 ""F"" (result i32))", "i32 index entry");
         Support.Assert_Contains
           (Param_Text,
            "(locals (1 ""a"" i8 param) (2 ""b"" u8 param) (3 ""c"" f32 param))",
            "params in locals");
         Support.Assert_Contains (Param_Text, "(result unit)", "param result");
         Support.Assert_Contains
           (Param_Text,
            "(1 ""G"" (param ""a"" i8 ""b"" u8 ""c"" f32) (result unit))",
            "param index entry");
         Support.Assert_Contains
           (Flag_Text, "(flags export entrypoint)", "flags form");
         Support.Assert_Contains (Flag_Text, "(noop)", "noop");
         Support.Assert_Contains (Flag_Text, "(body", "body");
      end;

      declare
         Local_Mod  : Modules.Module := Modules.Create ("m");
         Local_Sub  : Subroutines.Subroutine :=
           Support.Make_Subroutine ("P", Types.Unit);
         Local_Text : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Subroutines.Append_Local (Local_Sub, "tmp", Types.I32);
         Subroutines.Append_Local (Local_Sub, "flag", Types.I32);
         Modules.Append_Subroutine (Local_Mod, Local_Sub);
         Local_Text := Support.Must_To_Text (Local_Mod, "locals");
         Support.Assert_Contains
           (Ada.Strings.Unbounded.To_String (Local_Text),
            "(locals (1 ""tmp"" i32) (2 ""flag"" i32))",
            "locals list");
         --  With a parameter first, slots stay local.get order and params tag.
         declare
            Mixed_Mod : Modules.Module := Modules.Create ("m");
            Mixed_Params : Types.Parameter_Sequence := Types.Empty_Sequence;
            Mixed_Sub : Subroutines.Subroutine;
         begin
            Types.Append (Mixed_Params, "V", Types.I32);
            Mixed_Sub :=
              Support.Make_Subroutine
                ("P", Types.Unit, Parameters => Mixed_Params);
            Subroutines.Append_Local (Mixed_Sub, "tmp", Types.I32);
            Modules.Append_Subroutine (Mixed_Mod, Mixed_Sub);
            Support.Assert_Contains
              (Ada.Strings.Unbounded.To_String
                 (Support.Must_To_Text (Mixed_Mod, "mixed")),
               "(locals (1 ""V"" i32 param) (2 ""tmp"" i32))",
               "param+local slots");
         end;
         Support.Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Local_Text),
            "(body",
            "empty body omitted");
         Support.Assert_Binary_Round_Trip (Local_Mod, "locals round-trip");
      end;

      declare
         Native_Module : Modules.Module := Modules.Create ("io");
         Print_Sub     : Subroutines.Subroutine :=
           Support.Make_Subroutine
             ("print", Types.Unit, Flags => Subroutines.Export_Flag);
      begin
         Subroutines.Set_Native_Binding
           (Print_Sub, "wasi", "native-print-integer");
         Modules.Append_Subroutine (Native_Module, Print_Sub);
         declare
            Text : constant String :=
              Ada.Strings.Unbounded.To_String
                (Support.Must_To_Text (Native_Module, "native"));
         begin
            Support.Assert_Contains
              (Text, "(flags export native)", "native flags");
            Support.Assert_Contains
              (Text,
               "(native ""wasi"" ""native-print-integer"")",
               "native binding");
            Support.Assert_Not_Contains (Text, "(body", "native empty body");
         end;
      end;

      declare
         Intrinsic_Module : Modules.Module := Modules.Create ("io");
         Print_Sub        : Subroutines.Subroutine :=
           Support.Make_Subroutine
             ("print", Types.Unit, Flags => Subroutines.Export_Flag);
      begin
         Subroutines.Set_Intrinsic (Print_Sub);
         Modules.Append_Subroutine (Intrinsic_Module, Print_Sub);
         declare
            Text : constant String :=
              Ada.Strings.Unbounded.To_String
                (Support.Must_To_Text (Intrinsic_Module, "intrinsic"));
         begin
            Support.Assert_Contains
              (Text, "(flags export intrinsic)", "intrinsic flags");
            Support.Assert_Not_Contains
              (Text, "(body", "intrinsic empty body");
         end;
      end;

      declare
         Call_Module : Modules.Module := Modules.Create ("m");
         Sink        : constant Subroutines.Subroutine :=
           Support.Make_Subroutine ("Sink", Types.Unit);
         Caller      : Subroutines.Subroutine :=
           Support.Make_Subroutine ("Caller", Types.Unit);
         Call_Text   : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Subroutines.Append_Local (Caller, "x", Types.I32);
         Subroutines.Append_Instruction
           (Caller,
            (Operation     => Opcodes.Constant_I32,
             Immediate_I32 => Interfaces.Integer_32'(42)));
         Subroutines.Append_Instruction
           (Caller, (Operation => Opcodes.Local_Set, Local_Index => 1));
         Subroutines.Append_Instruction
           (Caller, (Operation => Opcodes.Local_Get, Local_Index => 1));
         Subroutines.Append_Instruction
           (Caller, (Operation => Opcodes.Call, Target_Index => 1));
         Modules.Append_Subroutine (Call_Module, Sink);
         Modules.Append_Subroutine (Call_Module, Caller);
         Call_Text := Support.Must_To_Text (Call_Module, "call text");
         Support.Assert_Contains
           (Ada.Strings.Unbounded.To_String (Call_Text),
            "(i32.const 42)",
            "i32.const");
         Support.Assert_Contains
           (Ada.Strings.Unbounded.To_String (Call_Text),
            "(local.set 1)",
            "local.set");
         Support.Assert_Contains
           (Ada.Strings.Unbounded.To_String (Call_Text),
            "(local.get 1)",
            "local.get");
         Support.Assert_Contains
           (Ada.Strings.Unbounded.To_String (Call_Text),
            "(call 1)",
            "call index");
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
                 when Types.U8   => "u8",
                 when Types.U16  => "u16",
                 when Types.U32  => "u32",
                 when Types.U64  => "u64",
                 when Types.F32  => "f32",
                 when Types.F64  => "f64");
            Lone_Param : Types.Parameter_Sequence := Types.Empty_Sequence;
            As_Param   : Modules.Module := Modules.Create ("m");
            As_Result  : Modules.Module := Modules.Create ("m");
         begin
            Types.Append (Lone_Param, "p", The_Type);
            Modules.Append_Subroutine
              (As_Param,
               Support.Make_Subroutine
                 ("P", Types.Unit, Parameters => Lone_Param));
            Modules.Append_Subroutine
              (As_Result, Support.Make_Subroutine ("R", The_Type));
            Support.Assert_Contains
              (Ada.Strings.Unbounded.To_String
                 (Support.Must_To_Text (As_Param, "p")),
               "(locals (1 ""p"" " & Token & " param))",
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
