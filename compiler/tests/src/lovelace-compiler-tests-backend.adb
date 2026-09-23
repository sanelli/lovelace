with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Interfaces;

with Lovelace.Compiler.Backend;
with Lovelace.Compiler.Backend.Wasm;
with Lovelace.Compiler.Backend.Wat;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Tests.Backend is

   package Modules renames Lovelace.Lir.Modules;
   package Subroutines renames Lovelace.Lir.Subroutines;
   package Types renames Lovelace.Lir.Types;
   package Wasm_Backend renames Lovelace.Compiler.Backend.Wasm;
   package Wat_Backend renames Lovelace.Compiler.Backend.Wat;

   use type Lovelace.Compiler.Backend.Backend_Error_Code;
   use type Interfaces.Unsigned_8;
   use type Subroutines.Subroutine_Flags;

   procedure Assert_Bytes_Contain
     (Bytes    : Lovelace.Compiler.Backend.Byte_Sequence;
      Fragment : String;
      Message  : String);
   --  Assert Fragment UTF-8 bytes appear contiguously in Bytes.

   procedure Assert_Component_Preamble
     (Bytes : Lovelace.Compiler.Backend.Byte_Sequence; Message : String);
   --  Assert component magic, version 0x0d, layer 1.

   procedure Assert_Contains
     (Text : String; Fragment : String; Message : String);
   --  Assert Text contains Fragment.

   procedure Assert_Not_Contains
     (Text : String; Fragment : String; Message : String);
   --  Assert Text does not contain Fragment.

   function Make_Unit_Subroutine
     (Name       : String;
      Flags      : Subroutines.Subroutine_Flags;
      Noop_Count : Natural := 0) return Subroutines.Subroutine;
   --  Build a Unit/no-params subroutine with optional noop instructions.

   function Must_Emit_Wasm
     (The_Module : Modules.Module; Message : String)
      return Lovelace.Compiler.Backend.Wasm_Emit_Result;
   --  Require Emit_Wasm success.

   function Must_Emit_Wat
     (The_Module : Modules.Module; Message : String)
      return Lovelace.Compiler.Backend.Wat_Emit_Result;
   --  Require Emit_Wat success.

   procedure Assert_Bytes_Contain
     (Bytes    : Lovelace.Compiler.Backend.Byte_Sequence;
      Fragment : String;
      Message  : String)
   is
      package Backend renames Lovelace.Compiler.Backend;
      Found : Boolean := False;
   begin
      if Fragment'Length = 0 then
         AUnit.Assertions.Assert (False, Message & ": empty fragment");
         return;
      end if;

      if Backend.Length (Bytes) >= Fragment'Length then
         for Start in 1 .. Backend.Length (Bytes) - Fragment'Length + 1 loop
            declare
               Match : Boolean := True;
            begin
               for Offset in 0 .. Fragment'Length - 1 loop
                  if Backend.Element (Bytes, Start + Offset)
                    /= Interfaces.Unsigned_8
                         (Character'Pos (Fragment (Fragment'First + Offset)))
                  then
                     Match := False;
                     exit;
                  end if;
               end loop;

               if Match then
                  Found := True;
                  exit;
               end if;
            end;
         end loop;
      end if;

      AUnit.Assertions.Assert
        (Found, Message & ": missing bytes `" & Fragment & "`");
   end Assert_Bytes_Contain;

   procedure Assert_Component_Preamble
     (Bytes : Lovelace.Compiler.Backend.Byte_Sequence; Message : String)
   is
      package Backend renames Lovelace.Compiler.Backend;
   begin
      AUnit.Assertions.Assert
        (Backend.Length (Bytes) >= 8, Message & ": preamble length");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 1) = 16#00#, Message & ": magic 0");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 2) = 16#61#, Message & ": magic a");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 3) = 16#73#, Message & ": magic s");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 4) = 16#6D#, Message & ": magic m");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 5) = 16#0D#, Message & ": version 0x0d");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 6) = 16#00#, Message & ": version low");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 7) = 16#01#, Message & ": layer 1");
      AUnit.Assertions.Assert
        (Backend.Element (Bytes, 8) = 16#00#, Message & ": layer high");
   end Assert_Component_Preamble;

   procedure Assert_Contains
     (Text : String; Fragment : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Text, Fragment) > 0,
         Message & ": missing `" & Fragment & "`");
   end Assert_Contains;

   procedure Assert_Not_Contains
     (Text : String; Fragment : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Text, Fragment) = 0,
         Message & ": unexpected `" & Fragment & "`");
   end Assert_Not_Contains;

   function Make_Unit_Subroutine
     (Name       : String;
      Flags      : Subroutines.Subroutine_Flags;
      Noop_Count : Natural := 0) return Subroutines.Subroutine
   is
      The_Signature : constant Subroutines.Signature :=
        (Name            => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Return_Type     => Types.Unit,
         Parameter_Types => Types.Empty_Sequence);
      Result        : Subroutines.Subroutine :=
        Subroutines.Create (The_Signature => The_Signature, Flags => Flags);
   begin
      for Index in 1 .. Noop_Count loop
         pragma Unreferenced (Index);
         Subroutines.Append_Instruction
           (Result, (Operation => Lovelace.Lir.Opcodes.No_Operation));
      end loop;

      return Result;
   end Make_Unit_Subroutine;

   function Must_Emit_Wasm
     (The_Module : Modules.Module; Message : String)
      return Lovelace.Compiler.Backend.Wasm_Emit_Result
   is
      Emitted : constant Lovelace.Compiler.Backend.Wasm_Emit_Result :=
        Wasm_Backend.Emit_Wasm (The_Module);
   begin
      case Emitted.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False,
               Message
               & ": Emit_Wasm failed: "
               & Ada.Strings.Unbounded.To_String (Emitted.Error.Detail));
            return Emitted;

         when True  =>
            return Emitted;
      end case;
   end Must_Emit_Wasm;

   function Must_Emit_Wat
     (The_Module : Modules.Module; Message : String)
      return Lovelace.Compiler.Backend.Wat_Emit_Result
   is
      Emitted : constant Lovelace.Compiler.Backend.Wat_Emit_Result :=
        Wat_Backend.Emit_Wat (The_Module);
   begin
      case Emitted.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False,
               Message
               & ": Emit_Wat failed: "
               & Ada.Strings.Unbounded.To_String (Emitted.Error.Detail));
            return Emitted;

         when True  =>
            return Emitted;
      end case;
   end Must_Emit_Wat;

   procedure Test_Entrypoint (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Hello");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine
        (The_Module,
         Make_Unit_Subroutine ("Hello", Subroutines.Entrypoint_Flag));
      Wat_Emitted := Must_Emit_Wat (The_Module, "entrypoint wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "entrypoint wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text),
         "export wasi:cli/run@0.3.0;",
         "entrypoint wit run");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text),
         "export Hello:",
         "entrypoint wit named");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "$_start",
         "entrypoint wat start");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "i32.const 0",
         "entrypoint wat success");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(export ""wasi:cli/run@0.3.0""",
         "entrypoint wat run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(instance (export ""run""",
         "entrypoint wat run instance");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "call $Hello",
         "entrypoint wat call");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "entrypoint wasm");
      Assert_Bytes_Contain
        (Wasm_Emitted.Wasm_Bytes,
         "wasi:cli/run@0.3.0",
         "entrypoint wasm run");
      Assert_Bytes_Contain
        (Wasm_Emitted.Wasm_Bytes, "_start", "entrypoint wasm start");
   end Test_Entrypoint;

   procedure Test_Entrypoint_And_Export (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Hello");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Flags      : constant Subroutines.Subroutine_Flags :=
        Subroutines.Export_Flag or Subroutines.Entrypoint_Flag;
   begin
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine ("Hello", Flags));
      Emitted := Must_Emit_Wat (The_Module, "both flags");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text),
         "export hello: func();",
         "both flags wit Hello");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text),
         "export wasi:cli/run@0.3.0;",
         "both flags wit run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(export ""hello""",
         "both flags wat Hello");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(export ""wasi:cli/run@0.3.0""",
         "both flags wat run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(instance (export ""run""",
         "both flags wat run instance");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(func (type",
         "both flags wat canon func");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(type (result))",
         "both flags wat result type");
   end Test_Entrypoint_And_Export;

   procedure Test_Export_Only (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Lib");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag));
      Wat_Emitted := Must_Emit_Wat (The_Module, "export only wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "export only wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text),
         "package love:lib@0.1.0;",
         "export only wit");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text),
         "export helper: func();",
         "export only wit helper");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text),
         "wasi:cli/run",
         "export only wit run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(export ""helper""",
         "export only wat helper");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "$_start",
         "export only wat start");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "wasi:cli/run",
         "export only wat run");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "export only wasm");
      Assert_Bytes_Contain
        (Wasm_Emitted.Wasm_Bytes, "helper", "export only wasm helper");
   end Test_Export_Only;

   procedure Test_Invalid_Module (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("");
      Wat_Out    : constant Lovelace.Compiler.Backend.Wat_Emit_Result :=
        Wat_Backend.Emit_Wat (The_Module);
      Wasm_Out   : constant Lovelace.Compiler.Backend.Wasm_Emit_Result :=
        Wasm_Backend.Emit_Wasm (The_Module);
   begin
      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, "invalid module wat: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module,
               "invalid module wat: code");
      end case;

      case Wasm_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, "invalid module wasm: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wasm_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module,
               "invalid module wasm: code");
      end case;
   end Test_Invalid_Module;

   procedure Test_Noop_Body (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine
        (The_Module,
         Make_Unit_Subroutine
           ("Helper", Subroutines.Export_Flag, Noop_Count => 2));
      Emitted := Must_Emit_Wat (The_Module, "noop body");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(func $Helper",
         "noop body wat func");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text),
         "export helper: func();",
         "noop body wit");
   end Test_Noop_Body;

   procedure Test_Two_Exports (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine ("Alpha", Subroutines.Export_Flag));
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine ("Beta", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "two exports");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text),
         "export alpha: func();",
         "two exports wit Alpha");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text),
         "export beta: func();",
         "two exports wit Beta");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text),
         "wasi:cli/run",
         "two exports wit run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(export ""alpha""",
         "two exports wat Alpha");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(export ""beta""",
         "two exports wat Beta");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "$_start",
         "two exports wat start");
   end Test_Two_Exports;

   procedure Test_Unsupported_Type (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module    : Modules.Module := Modules.Create ("Lib");
      The_Signature : constant Subroutines.Signature :=
        (Name            => Ada.Strings.Unbounded.To_Unbounded_String ("Get"),
         Return_Type     => Types.I32,
         Parameter_Types => Types.Empty_Sequence);
   begin
      Modules.Append_Subroutine
        (The_Module,
         Subroutines.Create
           (The_Signature => The_Signature, Flags => Subroutines.Export_Flag));

      declare
         Wat_Out  : constant Lovelace.Compiler.Backend.Wat_Emit_Result :=
           Wat_Backend.Emit_Wat (The_Module);
         Wasm_Out : constant Lovelace.Compiler.Backend.Wasm_Emit_Result :=
           Wasm_Backend.Emit_Wasm (The_Module);
      begin
         case Wat_Out.Ok is
            when True  =>
               AUnit.Assertions.Assert
                 (False, "unsupported type wat: expected failure");

            when False =>
               AUnit.Assertions.Assert
                 (Wat_Out.Error.Code
                  = Lovelace.Compiler.Backend.Unsupported_Type,
                  "unsupported type wat: code");
         end case;

         case Wasm_Out.Ok is
            when True  =>
               AUnit.Assertions.Assert
                 (False, "unsupported type wasm: expected failure");

            when False =>
               AUnit.Assertions.Assert
                 (Wasm_Out.Error.Code
                  = Lovelace.Compiler.Backend.Unsupported_Type,
                  "unsupported type wasm: code");
         end case;
      end;
   end Test_Unsupported_Type;

   procedure Test_Wasm_Component_Preamble (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wasm (The_Module, "preamble");
      Assert_Component_Preamble (Emitted.Wasm_Bytes, "preamble");
   end Test_Wasm_Component_Preamble;

   procedure Test_Wasm_Wit_Equality (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Hello");
      Flags        : constant Subroutines.Subroutine_Flags :=
        Subroutines.Export_Flag or Subroutines.Entrypoint_Flag;
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine ("Hello", Flags));
      Wat_Emitted := Must_Emit_Wat (The_Module, "wit eq wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "wit eq wasm");

      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded."="
           (Wat_Emitted.Wit_Text, Wasm_Emitted.Wit_Text),
         "wit equality");
   end Test_Wasm_Wit_Equality;

end Lovelace.Compiler.Tests.Backend;
