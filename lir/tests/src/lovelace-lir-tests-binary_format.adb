with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Lovelace.Lir.Binary;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Tests.Support;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Tests.Binary_Format is

   use type Ada.Streams.Stream_Element_Offset;
   use type Subroutines.Subroutine_Flags;

   procedure Test_All_Value_Types (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      for The_Type in Types.Value_Type loop
         declare
            Params           : Types.Value_Type_Sequence :=
              Types.Empty_Sequence;
            As_Param_Module  : Modules.Module := Modules.Create ("m");
            As_Result_Module : Modules.Module := Modules.Create ("m");
         begin
            Types.Append (Params, The_Type);
            Modules.Append_Subroutine
              (As_Param_Module,
               Support.Make_Subroutine
                 (Name            => "P",
                  Return_Type     => Types.Unit,
                  Parameter_Types => Params));
            Modules.Append_Subroutine
              (As_Result_Module,
               Support.Make_Subroutine (Name => "R", Return_Type => The_Type));
            Support.Assert_Binary_Round_Trip
              (As_Param_Module, "param " & Types.Value_Type'Image (The_Type));
            Support.Assert_Binary_Round_Trip
              (As_Result_Module,
               "result " & Types.Value_Type'Image (The_Type));
         end;
      end loop;
   end Test_All_Value_Types;

   procedure Test_Decode_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Base_Module : constant Modules.Module := Modules.Create ("m");
      With_Noop   : Modules.Module := Modules.Create ("m");
      Base        : constant Ada.Streams.Stream_Element_Array :=
        Support.Must_Encode (Base_Module, "base");
   begin
      Modules.Append_Subroutine
        (With_Noop,
         Support.Make_Subroutine ("S", Types.Unit, Noop_Count => 1));

      declare
         Noop_Bytes : constant Ada.Streams.Stream_Element_Array :=
           Support.Must_Encode (With_Noop, "noop module");
      begin
         Support.Assert_Decode_Error
           (Support.Replace_Byte (Base, Base'First, 16#00#),
            Errors.Invalid_Magic,
            "bad magic");

         Support.Assert_Decode_Error
           (Support.Replace_Byte (Base, Base'First + 4, 16#02#),
            Errors.Unsupported_Version,
            "version 2.0");

         Support.Assert_Decode_Error
           (Support.Truncate (Base, Base'Length - 1),
            Errors.Truncated,
            "truncated");

         Support.Assert_Decode_Error
           (Support.Append_Byte (Base, 16#FF#),
            Errors.Trailing_Bytes,
            "trailing");

         Support.Assert_Decode_Error
           (Support.Replace_Byte (Noop_Bytes, Noop_Bytes'Last - 1, 16#01#),
            Errors.Unknown_Opcode,
            "unknown opcode");
      end;

      declare
         Typed : Modules.Module := Modules.Create ("m");
      begin
         Modules.Append_Subroutine
           (Typed, Support.Make_Subroutine ("S", Types.I32));
         declare
            Typed_Bytes : constant Ada.Streams.Stream_Element_Array :=
              Support.Must_Encode (Typed, "typed");
         begin
            --  Return type is 13 bytes before end: param_count+flags+origin+instr_count.
            Support.Assert_Decode_Error
              (Support.Replace_Byte
                 (Typed_Bytes, Typed_Bytes'Last - 13, 16#FF#),
               Errors.Unknown_Type,
               "unknown type");
         end;
      end;

      Support.Assert_Decode_Error
        (Support.Replace_Byte (Base, Base'First + 12, 16#FF#),
         Errors.Invalid_Utf_8,
         "invalid utf-8 name");
   end Test_Decode_Failures;

   procedure Test_Empty_Module_File (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("example");
      Path       : constant String := "obj/lir_test_roundtrip.lir";
      Written    : Binary.Write_Result;
      Loaded     : Binary.Decode_Result;
      Deleted    : Boolean;
   begin
      Written := Binary.Write (The_Module, Path);
      case Written.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False,
               "write failed " & Errors.Error_Code'Image (Written.Error));

         when True  =>
            Loaded := Binary.Read (Path);
            case Loaded.Ok is
               when False =>
                  AUnit.Assertions.Assert
                    (False,
                     "read failed " & Errors.Error_Code'Image (Loaded.Error));

               when True  =>
                  declare
                     Before :
                       constant Ada.Strings.Unbounded.Unbounded_String :=
                         Support.Must_To_Text (The_Module, "before");
                     After  :
                       constant Ada.Strings.Unbounded.Unbounded_String :=
                         Support.Must_To_Text (Loaded.Value, "after");
                  begin
                     AUnit.Assertions.Assert
                       (Ada.Strings.Unbounded."=" (Before, After),
                        "file round-trip To_Text");
                  end;
            end case;
      end case;
      GNAT.OS_Lib.Delete_File (Path, Deleted);
   end Test_Empty_Module_File;

   procedure Test_Empty_Module_Memory (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("example");
   begin
      Support.Assert_Binary_Round_Trip (The_Module, "empty module");
   end Test_Empty_Module_Memory;

   procedure Test_Magic_And_Version (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Bytes : constant Ada.Streams.Stream_Element_Array :=
        Support.Must_Encode (Modules.Create ("m"), "magic");
   begin
      Support.Assert_Byte_Count (Bytes, Natural (Bytes'Length), "non-empty");
      AUnit.Assertions.Assert (Bytes'Length >= 8, "header length");
      Support.Assert_Byte (Bytes, Bytes'First + 0, 16#4C#, "L");
      Support.Assert_Byte (Bytes, Bytes'First + 1, 16#49#, "I");
      Support.Assert_Byte (Bytes, Bytes'First + 2, 16#52#, "R");
      Support.Assert_Byte (Bytes, Bytes'First + 3, 16#00#, "NUL");
      Support.Assert_Byte (Bytes, Bytes'First + 4, 16#01#, "major low");
      Support.Assert_Byte (Bytes, Bytes'First + 5, 16#00#, "major high");
      Support.Assert_Byte (Bytes, Bytes'First + 6, 16#00#, "minor low");
      Support.Assert_Byte (Bytes, Bytes'First + 7, 16#00#, "minor high");
   end Test_Magic_And_Version;

   procedure Test_Noop_Encoding (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("m");
   begin
      AUnit.Assertions.Assert
        (Opcodes.Encoded_Length (Opcodes.No_Operation) = 2, "Encoded_Length");
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine ("S", Types.Unit, Noop_Count => 1));
      declare
         Bytes : constant Ada.Streams.Stream_Element_Array :=
           Support.Must_Encode (The_Module, "noop");
      begin
         Support.Assert_Byte (Bytes, Bytes'Last - 1, 16#00#, "noop low");
         Support.Assert_Byte (Bytes, Bytes'Last, 16#00#, "noop high");
      end;
   end Test_Noop_Encoding;

   procedure Test_Subroutines_And_Flags (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("mod");
      Params     : Types.Value_Type_Sequence := Types.Empty_Sequence;
   begin
      Modules.Append_Dependency (The_Module, "other");
      Types.Append (Params, Types.I8);
      Types.Append (Params, Types.U8);
      Types.Append (Params, Types.F16);

      Modules.Append_Subroutine
        (The_Module, Support.Make_Subroutine ("Empty", Types.Unit));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine ("One", Types.I32, Noop_Count => 1));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine ("Many", Types.Unit, Noop_Count => 3));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine
           ("Exp",
            Types.Unit,
            Flags      => Subroutines.Export_Flag,
            Noop_Count => 0));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine
           ("Entry",
            Types.Unit,
            Flags      => Subroutines.Entrypoint_Flag,
            Noop_Count => 0));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine
           ("Both",
            Types.Unit,
            Parameter_Types => Params,
            Flags           =>
              Subroutines.Export_Flag or Subroutines.Entrypoint_Flag,
            Noop_Count      => 1));

      --  Duplicate entrypoint would fail Validate; replace Entry with non-entry
      --  before the Both that also has entrypoint â Both alone is one entrypoint.
      --  Rebuild without two entrypoints:
      declare
         Clean : Modules.Module := Modules.Create ("mod");
      begin
         Modules.Append_Dependency (Clean, "other");
         Modules.Append_Subroutine
           (Clean, Support.Make_Subroutine ("Empty", Types.Unit));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine ("One", Types.I32, Noop_Count => 1));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine ("Many", Types.Unit, Noop_Count => 3));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine
              ("Exp", Types.Unit, Flags => Subroutines.Export_Flag));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine
              ("Both",
               Types.Unit,
               Parameter_Types => Params,
               Flags           =>
                 Subroutines.Export_Flag or Subroutines.Entrypoint_Flag,
               Noop_Count      => 1));
         Support.Assert_Binary_Round_Trip (Clean, "subroutines and flags");
      end;
   end Test_Subroutines_And_Flags;

   procedure Test_Unicode_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe       : constant String :=
        "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Rocket     : constant String :=
        Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#));
      The_Module : Modules.Module := Modules.Create (Cafe);
   begin
      Modules.Append_Subroutine
        (The_Module, Support.Make_Subroutine (Rocket, Types.Unit));
      Support.Assert_Binary_Round_Trip (The_Module, "unicode names");
   end Test_Unicode_Names;

end Lovelace.Lir.Tests.Binary_Format;
