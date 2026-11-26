with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Interfaces;

with Lovelace.Compiler.Backend;
with Lovelace.Compiler.Backend.Names;
with Lovelace.Compiler.Backend.Wasm;
with Lovelace.Compiler.Backend.Wat;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Tests.Backend is

   package Modules renames Lovelace.Lir.Modules;
   package Names renames Lovelace.Compiler.Backend.Names;
   package Subroutines renames Lovelace.Lir.Subroutines;
   package Types renames Lovelace.Lir.Types;
   package Wasm_Backend renames Lovelace.Compiler.Backend.Wasm;
   package Wat_Backend renames Lovelace.Compiler.Backend.Wat;

   use type Lovelace.Compiler.Backend.Backend_Error_Code;
   use type Interfaces.Unsigned_8;
   use type Subroutines.Subroutine_Flags;

   procedure Assert_Bytes_Contain
     (Bytes : Lovelace.Compiler.Backend.Byte_Sequence; Fragment : String; Message : String);
   --  Assert Fragment UTF-8 bytes appear contiguously in Bytes.

   procedure Assert_Component_Preamble (Bytes : Lovelace.Compiler.Backend.Byte_Sequence; Message : String);
   --  Assert component magic, version 0x0d, layer 1.

   procedure Assert_Contains (Text : String; Fragment : String; Message : String);
   --  Assert Text contains Fragment.

   procedure Assert_Not_Contains (Text : String; Fragment : String; Message : String);
   --  Assert Text does not contain Fragment.

   function Make_Unit_Subroutine
     (Name : String; Flags : Subroutines.Subroutine_Flags; Noop_Count : Natural := 0) return Subroutines.Subroutine;
   --  Build a Unit/no-params subroutine with optional noop instructions.

   function Make_Unit_Subroutine_With_Parameters
     (Name : String; Flags : Subroutines.Subroutine_Flags; Parameters : Types.Parameter_Sequence)
      return Subroutines.Subroutine;
   --  Build a Unit-return subroutine with Parameters.

   function Must_Emit_Wasm
     (The_Module : Modules.Module; Message : String) return Lovelace.Compiler.Backend.Wasm_Emit_Result;
   --  Require Emit_Wasm success.

   function Must_Emit_Wat
     (The_Module : Modules.Module; Message : String) return Lovelace.Compiler.Backend.Wat_Emit_Result;
   --  Require Emit_Wat success.

   procedure Assert_Bytes_Contain (Bytes : Lovelace.Compiler.Backend.Byte_Sequence; Fragment : String; Message : String)
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
                    /= Interfaces.Unsigned_8 (Character'Pos (Fragment (Fragment'First + Offset)))
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

      AUnit.Assertions.Assert (Found, Message & ": missing bytes `" & Fragment & "`");
   end Assert_Bytes_Contain;

   procedure Assert_Component_Preamble (Bytes : Lovelace.Compiler.Backend.Byte_Sequence; Message : String) is
      package Backend renames Lovelace.Compiler.Backend;
   begin
      AUnit.Assertions.Assert (Backend.Length (Bytes) >= 8, Message & ": preamble length");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 1) = 16#00#, Message & ": magic 0");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 2) = 16#61#, Message & ": magic a");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 3) = 16#73#, Message & ": magic s");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 4) = 16#6D#, Message & ": magic m");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 5) = 16#0D#, Message & ": version 0x0d");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 6) = 16#00#, Message & ": version low");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 7) = 16#01#, Message & ": layer 1");
      AUnit.Assertions.Assert (Backend.Element (Bytes, 8) = 16#00#, Message & ": layer high");
   end Assert_Component_Preamble;

   procedure Assert_Contains (Text : String; Fragment : String; Message : String) is
   begin
      AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Text, Fragment) > 0, Message & ": missing `" & Fragment & "`");
   end Assert_Contains;

   procedure Assert_Not_Contains (Text : String; Fragment : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Text, Fragment) = 0, Message & ": unexpected `" & Fragment & "`");
   end Assert_Not_Contains;

   function Make_Unit_Subroutine
     (Name : String; Flags : Subroutines.Subroutine_Flags; Noop_Count : Natural := 0) return Subroutines.Subroutine
   is
      The_Signature : constant Subroutines.Signature :=
        (Name        => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Return_Type => Types.Unit,
         Parameters  => Types.Empty_Sequence);
      Result        : Subroutines.Subroutine := Subroutines.Create (The_Signature => The_Signature, Flags => Flags);
   begin
      for Index in 1 .. Noop_Count loop
         pragma Unreferenced (Index);
         Subroutines.Append_Instruction (Result, (Operation => Lovelace.Lir.Opcodes.No_Operation));
      end loop;

      return Result;
   end Make_Unit_Subroutine;

   function Make_Unit_Subroutine_With_Parameters
     (Name : String; Flags : Subroutines.Subroutine_Flags; Parameters : Types.Parameter_Sequence)
      return Subroutines.Subroutine
   is
      The_Signature : constant Subroutines.Signature :=
        (Name => Ada.Strings.Unbounded.To_Unbounded_String (Name), Return_Type => Types.Unit, Parameters => Parameters);
   begin
      return Subroutines.Create (The_Signature => The_Signature, Flags => Flags);
   end Make_Unit_Subroutine_With_Parameters;

   function Must_Emit_Wasm
     (The_Module : Modules.Module; Message : String) return Lovelace.Compiler.Backend.Wasm_Emit_Result
   is
      Emitted : constant Lovelace.Compiler.Backend.Wasm_Emit_Result := Wasm_Backend.Emit_Wasm (The_Module);
   begin
      case Emitted.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False, Message & ": Emit_Wasm failed: " & Ada.Strings.Unbounded.To_String (Emitted.Error.Detail));
            return Emitted;

         when True  =>
            return Emitted;
      end case;
   end Must_Emit_Wasm;

   function Must_Emit_Wat
     (The_Module : Modules.Module; Message : String) return Lovelace.Compiler.Backend.Wat_Emit_Result
   is
      Emitted : constant Lovelace.Compiler.Backend.Wat_Emit_Result := Wat_Backend.Emit_Wat (The_Module);
   begin
      case Emitted.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False, Message & ": Emit_Wat failed: " & Ada.Strings.Unbounded.To_String (Emitted.Error.Detail));
            return Emitted;

         when True  =>
            return Emitted;
      end case;
   end Must_Emit_Wat;

   procedure Test_Const_And_Call_Body (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Calls");
      Params     : Types.Parameter_Sequence := Types.Empty_Sequence;
      Sink       : Subroutines.Subroutine;
      Caller     : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", 0);
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Types.Append (Params, "Value", Types.I32);
      Sink := Make_Unit_Subroutine_With_Parameters ("Sink", 0, Params);
      Subroutines.Append_Instruction
        (Caller, (Operation => Lovelace.Lir.Opcodes.Constant_I32, Immediate_I32 => Interfaces.Integer_32'(42)));
      Subroutines.Append_Instruction (Caller, (Operation => Lovelace.Lir.Opcodes.Call, Target_Index => 1));
      Modules.Append_Subroutine (The_Module, Sink);
      Modules.Append_Subroutine (The_Module, Caller);
      Emitted := Must_Emit_Wat (The_Module, "const and call");

      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "i32.const 42", "i32.const");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "call $Sink", "call Sink");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(func $Run", "Run func");
   end Test_Const_And_Call_Body;

   procedure Test_Dollar_Name_Edges (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Digit_Mod : Modules.Module := Modules.Create ("Lib");
      Weird_Mod : Modules.Module := Modules.Create ("Lib");
      Emitted   : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      --  Non-export keeps the LIR name (export path kebab-cases first).
      Modules.Append_Subroutine (Digit_Mod, Make_Unit_Subroutine ("1bad", 0));
      Emitted := Must_Emit_Wat (Digit_Mod, "digit name");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$n_1bad", "digit prefix guard");

      Modules.Append_Subroutine (Weird_Mod, Make_Unit_Subroutine ("a b", 0));
      Emitted := Must_Emit_Wat (Weird_Mod, "space name");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$a_20b", "space escaped in id");
   end Test_Dollar_Name_Edges;

   procedure Test_Duplicate_Entrypoint (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Wat_Out    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("First", Subroutines.Entrypoint_Flag));
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Second", Subroutines.Entrypoint_Flag));
      Wat_Out := Wat_Backend.Emit_Wat (The_Module);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "duplicate entrypoint: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "duplicate entrypoint: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail),
               "Validate failed",
               "duplicate entrypoint: detail");
      end case;
   end Test_Duplicate_Entrypoint;

   procedure Test_Duplicate_Func_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      --  Both exports so lowering kebab-cases both to the same "same" core name.
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Same", Subroutines.Export_Flag));
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Same", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "dup names");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$same_1", "dup name first");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$same_2", "dup name second");
   end Test_Duplicate_Func_Names;

   procedure Test_Empty_Module_Emit (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : constant Modules.Module := Modules.Create ("Empty");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Wat_Emitted := Must_Emit_Wat (The_Module, "empty wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "empty wasm");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "(component", "empty wat component");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "empty wasm");
   end Test_Empty_Module_Emit;

   procedure Test_Entrypoint (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Hello");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Hello", Subroutines.Entrypoint_Flag));
      Wat_Emitted := Must_Emit_Wat (The_Module, "entrypoint wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "entrypoint wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "export wasi:cli/run@0.3.0;", "entrypoint wit run");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "export Hello:", "entrypoint wit named");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "$_start", "entrypoint wat start");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "i32.const 0", "entrypoint wat success");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(export ""wasi:cli/run@0.3.0""",
         "entrypoint wat run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(instance (export ""run""",
         "entrypoint wat run instance");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "call $Hello", "entrypoint wat call");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "entrypoint wasm");
      Assert_Bytes_Contain (Wasm_Emitted.Wasm_Bytes, "wasi:cli/run@0.3.0", "entrypoint wasm run");
      Assert_Bytes_Contain (Wasm_Emitted.Wasm_Bytes, "_start", "entrypoint wasm start");
   end Test_Entrypoint;

   procedure Test_Entrypoint_And_Export (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Hello");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Flags      : constant Subroutines.Subroutine_Flags := Subroutines.Export_Flag or Subroutines.Entrypoint_Flag;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Hello", Flags));
      Emitted := Must_Emit_Wat (The_Module, "both flags");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export hello: func();", "both flags wit Hello");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export wasi:cli/run@0.3.0;", "both flags wit run");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""hello""", "both flags wat Hello");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""wasi:cli/run@0.3.0""", "both flags wat run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text),
         "(instance (export ""run""",
         "both flags wat run instance");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(func (type", "both flags wat canon func");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(type (result))", "both flags wat result type");
   end Test_Entrypoint_And_Export;

   procedure Test_Export_Only (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Lib");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag));
      Wat_Emitted := Must_Emit_Wat (The_Module, "export only wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "export only wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "package lovelace:lib@0.0.1;", "export only wit");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "export helper: func();", "export only wit helper");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "wasi:cli/run", "export only wit run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "(export ""helper""", "export only wat helper");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "$_start", "export only wat start");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text), "wasi:cli/run", "export only wat run");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "export only wasm");
      Assert_Bytes_Contain (Wasm_Emitted.Wasm_Bytes, "helper", "export only wasm helper");
   end Test_Export_Only;

   procedure Test_Export_With_Parameters (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parameters   : Types.Parameter_Sequence := Types.Empty_Sequence;
      The_Module   : Modules.Module := Modules.Create ("Lib");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Types.Append (Parameters, "Value", Types.I32);
      Modules.Append_Subroutine
        (The_Module, Make_Unit_Subroutine_With_Parameters ("Print", Subroutines.Export_Flag, Parameters));
      Wat_Emitted := Must_Emit_Wat (The_Module, "export params wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "export params wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(func $Print (param i32)",
         "export params wat functype");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "export print:", "export params wit no kebab");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(export ""Print""",
         "export params wat no core export");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "export params wasm");
   end Test_Export_With_Parameters;

   procedure Test_Intrinsic_Table_Miss (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Bad_Sub    : Subroutines.Subroutine := Make_Unit_Subroutine ("Unknown", 0);
      Wat_Out    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Set_Intrinsic (Bad_Sub);
      Modules.Append_Subroutine (The_Module, Bad_Sub);
      Wat_Out := Wat_Backend.Emit_Wat (The_Module);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "intrinsic miss: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Internal_Error, "intrinsic miss: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail),
               "intrinsic table miss",
               "intrinsic miss: detail");
      end case;
   end Test_Intrinsic_Table_Miss;

   procedure Test_Invalid_Module (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("");
      Wat_Out    : constant Lovelace.Compiler.Backend.Wat_Emit_Result := Wat_Backend.Emit_Wat (The_Module);
      Wasm_Out   : constant Lovelace.Compiler.Backend.Wasm_Emit_Result := Wasm_Backend.Emit_Wasm (The_Module);
   begin
      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "invalid module wat: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "invalid module wat: code");
      end case;

      case Wasm_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "invalid module wasm: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wasm_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "invalid module wasm: code");
      end case;
   end Test_Invalid_Module;

   procedure Test_Kebab_Export_Dash_Collapse (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("A..B", Subroutines.Export_Flag));
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("...Foo...", Subroutines.Export_Flag));
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("___", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "kebab collapse");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export a-b: func();", "kebab collapse consecutive");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export foo: func();", "kebab collapse trim");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export export: func();", "kebab collapse empty fallback");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""a-b""", "kebab collapse wat a-b");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""foo""", "kebab collapse wat foo");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""export""", "kebab collapse wat export");
   end Test_Kebab_Export_Dash_Collapse;

   procedure Test_Local_Get_Set_Body (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Locals");
      The_Sub    : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", Subroutines.Entrypoint_Flag);
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Append_Local (The_Sub, "Foo", Types.I32);
      Subroutines.Append_Instruction
        (The_Sub, (Operation => Lovelace.Lir.Opcodes.Constant_I32, Immediate_I32 => Interfaces.Integer_32'(1)));
      Subroutines.Append_Instruction (The_Sub, (Operation => Lovelace.Lir.Opcodes.Local_Set, Local_Index => 1));
      Subroutines.Append_Instruction (The_Sub, (Operation => Lovelace.Lir.Opcodes.Local_Get, Local_Index => 1));
      Modules.Append_Subroutine (The_Module, The_Sub);
      Emitted := Must_Emit_Wat (The_Module, "local get set");

      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "i32.const 1", "local get set const");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "local.set 0", "local.set 0-based");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "local.get 0", "local.get 0-based");
   end Test_Local_Get_Set_Body;

   procedure Test_Module_Dependency (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Host");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Dependency (The_Module, "Lib", "1.2.3");
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Run", Subroutines.Entrypoint_Flag));
      Emitted := Must_Emit_Wat (The_Module, "dependency");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "lovelace:lib@1.2.3", "dependency wat identity");
   end Test_Module_Dependency;

   procedure Test_Names_Sanitize_Edges (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe       : constant String := "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      The_Module : Modules.Module := Modules.Create ("lib2." & Cafe);
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      AUnit.Assertions.Assert (Names.Sanitize_Segment ("") = "module", "sanitize empty");
      AUnit.Assertions.Assert (Names.Sanitize_Segment ("---") = "module", "sanitize dashes");
      AUnit.Assertions.Assert (Names.Sanitize_Segment ("!Foo!") = "foo", "sanitize trim");
      AUnit.Assertions.Assert (Names.Sanitize_Segment ("A!!B") = "a-b", "sanitize collapse");
      AUnit.Assertions.Assert (Names.Sanitize_Segment ("x9") = "x9", "sanitize digit");
      AUnit.Assertions.Assert
        (Names.Component_Identity ("", "0.0.1") = "lovelace:module@0.0.1", "component empty name");
      AUnit.Assertions.Assert
        (Names.Component_Identity (".a..b.", "1.0.0") = "lovelace:module/a/module/b/module@1.0.0",
         "component empty dotted segments");
      AUnit.Assertions.Assert
        (Names.Wit_Package_Identity ("a..b", "2.0.0") = "lovelace:a-module-b@2.0.0", "wit empty middle segment");
      AUnit.Assertions.Assert
        (Names.Wit_Package_Identity (Cafe, "0.0.1") = "lovelace:caf@0.0.1", "wit non-ascii segment");

      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Go", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "names emit");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "package lovelace:lib2-caf@", "names emit wit package");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "lovelace:lib2/caf@", "names emit wat component");
   end Test_Names_Sanitize_Edges;

   procedure Test_Native_Empty_Body (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Native_Sub : Subroutines.Subroutine := Make_Unit_Subroutine ("Foreign", Subroutines.Export_Flag);
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Set_Native_Binding (Native_Sub, "wasi", "foreign");
      Modules.Append_Subroutine (The_Module, Native_Sub);
      Emitted := Must_Emit_Wat (The_Module, "native empty");

      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(func $foreign", "native empty wat func");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export foreign: func();", "native empty wit");
   end Test_Native_Empty_Body;

   procedure Test_Native_Print_Integer (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("augusta.std.io");
      Params       : Types.Parameter_Sequence := Types.Empty_Sequence;
      Print_Sub    : Subroutines.Subroutine;
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
      Wat_Text     : Ada.Strings.Unbounded.Unbounded_String;
      Wit_Text     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Types.Append (Params, "value", Types.I32);
      Print_Sub := Make_Unit_Subroutine_With_Parameters ("print", Subroutines.Export_Flag, Params);
      Subroutines.Set_Intrinsic (Print_Sub);
      Modules.Append_Subroutine (The_Module, Print_Sub);

      Wat_Emitted := Must_Emit_Wat (The_Module, "native print wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "native print wasm");
      Wat_Text := Wat_Emitted.Wat_Text;
      Wit_Text := Wat_Emitted.Wit_Text;

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wit_Text), "import wasi:cli/stdout@0.3.0;", "wit stdout import");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "wasi:cli/stdout@0.3.0", "wat stdout import");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "canon stream.new", "wat stream.new");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "write-via-stream", "wat write-via-stream");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "(func $print", "wat print func");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Text), "(core module $guest", "wat guest module with stdout");
      Assert_Bytes_Contain (Wasm_Emitted.Wasm_Bytes, "wasi:cli/stdout@0.3.0", "wasm stdout");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded."=" (Wat_Emitted.Wit_Text, Wasm_Emitted.Wit_Text), "native print wit equality");
   end Test_Native_Print_Integer;

   procedure Test_Native_Print_Signature_Mismatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Params_F64   : Types.Parameter_Sequence := Types.Empty_Sequence;
      Params_Two   : Types.Parameter_Sequence := Types.Empty_Sequence;
      Module_F64   : Modules.Module := Modules.Create ("augusta.std.io");
      Module_Arity : Modules.Module := Modules.Create ("augusta.std.io");
      Module_Empty : Modules.Module := Modules.Create ("augusta.std.io");
      Print_F64    : Subroutines.Subroutine;
      Print_Two    : Subroutines.Subroutine;
      Print_Empty  : Subroutines.Subroutine;
      Wat_Out      : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Types.Append (Params_F64, "value", Types.F64);
      Print_F64 := Make_Unit_Subroutine_With_Parameters ("print", 0, Params_F64);
      Subroutines.Set_Intrinsic (Print_F64);
      Modules.Append_Subroutine (Module_F64, Print_F64);
      Wat_Out := Wat_Backend.Emit_Wat (Module_F64);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "print f64 mismatch: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Internal_Error, "print f64 mismatch: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail),
               "intrinsic table miss",
               "print f64 mismatch: detail");
      end case;

      Types.Append (Params_Two, "a", Types.I32);
      Types.Append (Params_Two, "b", Types.I32);
      Print_Two := Make_Unit_Subroutine_With_Parameters ("print", 0, Params_Two);
      Subroutines.Set_Intrinsic (Print_Two);
      Modules.Append_Subroutine (Module_Arity, Print_Two);
      Wat_Out := Wat_Backend.Emit_Wat (Module_Arity);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "print arity mismatch: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Internal_Error, "print arity mismatch: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail),
               "intrinsic table miss",
               "print arity mismatch: detail");
      end case;

      Print_Empty := Make_Unit_Subroutine ("print", 0);
      Subroutines.Set_Intrinsic (Print_Empty);
      Modules.Append_Subroutine (Module_Empty, Print_Empty);
      Wat_Out := Wat_Backend.Emit_Wat (Module_Empty);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "print empty mismatch: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Internal_Error, "print empty mismatch: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail),
               "intrinsic table miss",
               "print empty mismatch: detail");
      end case;
   end Test_Native_Print_Signature_Mismatch;

   procedure Test_Noop_Body (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag, Noop_Count => 2));
      Emitted := Must_Emit_Wat (The_Module, "noop body");

      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(func $helper", "noop body wat func");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export helper: func();", "noop body wit");
   end Test_Noop_Body;

   procedure Test_Two_Exports (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Lib");
      Emitted      : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Alpha", Subroutines.Export_Flag));
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Beta", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "two exports");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "two exports wasm");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "two exports wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export alpha: func();", "two exports wit Alpha");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export beta: func();", "two exports wit Beta");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "wasi:cli/run", "two exports wit run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""alpha""", "two exports wat Alpha");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""beta""", "two exports wat Beta");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$_start", "two exports wat start");
   end Test_Two_Exports;

   procedure Test_Typed_Locals (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module  : Modules.Module := Modules.Create ("Locals");
      The_Sub     : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", Subroutines.Entrypoint_Flag);
      Wat_Emitted : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Append_Local (The_Sub, "a", Types.I32);
      Subroutines.Append_Local (The_Sub, "b", Types.F64);
      Subroutines.Append_Local (The_Sub, "c", Types.U8);
      Modules.Append_Subroutine (The_Module, The_Sub);
      Wat_Emitted := Must_Emit_Wat (The_Module, "typed locals wat");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(local i32 f64 i32)",
         "typed locals wat local section");
   end Test_Typed_Locals;

   procedure Test_Typed_Parameters (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parameters   : Types.Parameter_Sequence := Types.Empty_Sequence;
      The_Module   : Modules.Module := Modules.Create ("Types");
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Types.Append (Parameters, "i8", Types.I8);
      Types.Append (Parameters, "i16", Types.I16);
      Types.Append (Parameters, "i32", Types.I32);
      Types.Append (Parameters, "i64", Types.I64);
      Types.Append (Parameters, "u8", Types.U8);
      Types.Append (Parameters, "u16", Types.U16);
      Types.Append (Parameters, "u32", Types.U32);
      Types.Append (Parameters, "u64", Types.U64);
      Types.Append (Parameters, "f32", Types.F32);
      Types.Append (Parameters, "f64", Types.F64);
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine_With_Parameters ("Map", 0, Parameters));
      Wat_Emitted := Must_Emit_Wat (The_Module, "typed parameters wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "typed parameters wasm");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wat_Text),
         "(func $Map (param i32 i32 i32 i64 i32 i32 i32 i64 f32 f64)",
         "typed parameters wat functype");
      Assert_Not_Contains
        (Ada.Strings.Unbounded.To_String (Wat_Emitted.Wit_Text), "export map:", "typed parameters wit no export");
      Assert_Component_Preamble (Wasm_Emitted.Wasm_Bytes, "typed parameters wasm");
      --  Core functype: 0x60, 10 params, i32 i32 i32 i64 i32 i32 i32 i64 f32 f64, 0 results.
      Assert_Bytes_Contain
        (Wasm_Emitted.Wasm_Bytes,
         Character'Val (16#60#)
         & Character'Val (16#0A#)
         & Character'Val (16#7F#)
         & Character'Val (16#7F#)
         & Character'Val (16#7F#)
         & Character'Val (16#7E#)
         & Character'Val (16#7F#)
         & Character'Val (16#7F#)
         & Character'Val (16#7F#)
         & Character'Val (16#7E#)
         & Character'Val (16#7D#)
         & Character'Val (16#7C#)
         & Character'Val (16#00#),
         "typed parameters wasm functype");
   end Test_Typed_Parameters;

   procedure Test_Unsupported_Type (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module        : Modules.Module := Modules.Create ("Lib");
      The_Signature     : constant Subroutines.Signature :=
        (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("Get"),
         Return_Type => Types.I32,
         Parameters  => Types.Empty_Sequence);
      Entrypoint_Params : Types.Parameter_Sequence := Types.Empty_Sequence;
      Entrypoint_Module : Modules.Module := Modules.Create ("Lib");
   begin
      Modules.Append_Subroutine
        (The_Module, Subroutines.Create (The_Signature => The_Signature, Flags => Subroutines.Export_Flag));

      declare
         Wat_Out  : constant Lovelace.Compiler.Backend.Wat_Emit_Result := Wat_Backend.Emit_Wat (The_Module);
         Wasm_Out : constant Lovelace.Compiler.Backend.Wasm_Emit_Result := Wasm_Backend.Emit_Wasm (The_Module);
      begin
         case Wat_Out.Ok is
            when True  =>
               AUnit.Assertions.Assert (False, "unsupported type wat: expected failure");

            when False =>
               AUnit.Assertions.Assert
                 (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Unsupported_Type, "unsupported type wat: code");
         end case;

         case Wasm_Out.Ok is
            when True  =>
               AUnit.Assertions.Assert (False, "unsupported type wasm: expected failure");

            when False =>
               AUnit.Assertions.Assert
                 (Wasm_Out.Error.Code = Lovelace.Compiler.Backend.Unsupported_Type, "unsupported type wasm: code");
         end case;
      end;

      Types.Append (Entrypoint_Params, "x", Types.I32);
      Modules.Append_Subroutine
        (Entrypoint_Module,
         Make_Unit_Subroutine_With_Parameters ("Main", Subroutines.Entrypoint_Flag, Entrypoint_Params));

      declare
         Wat_Out : constant Lovelace.Compiler.Backend.Wat_Emit_Result := Wat_Backend.Emit_Wat (Entrypoint_Module);
      begin
         case Wat_Out.Ok is
            when True  =>
               AUnit.Assertions.Assert (False, "entrypoint params wat: expected failure");

            when False =>
               AUnit.Assertions.Assert
                 (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Unsupported_Type, "entrypoint params wat: code");
         end case;
      end;
   end Test_Unsupported_Type;

   procedure Test_Unsupported_Unit_Local (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      The_Sub    : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", 0);
      Wat_Out    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Append_Local (The_Sub, "Ghost", Types.Unit);
      Modules.Append_Subroutine (The_Module, The_Sub);
      Wat_Out := Wat_Backend.Emit_Wat (The_Module);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "unit local: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Unsupported_Type, "unit local: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail), "unsupported local type", "unit local: detail");
      end case;
   end Test_Unsupported_Unit_Local;

   procedure Test_Unsupported_Unit_Parameter (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Parameters : Types.Parameter_Sequence := Types.Empty_Sequence;
      The_Module : Modules.Module := Modules.Create ("Lib");
      Wat_Out    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Types.Append (Parameters, "Voidish", Types.Unit);
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine_With_Parameters ("TakesUnit", 0, Parameters));
      Wat_Out := Wat_Backend.Emit_Wat (The_Module);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "unit parameter: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Unsupported_Type, "unit parameter: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail),
               "unsupported parameter type",
               "unit parameter: detail");
      end case;
   end Test_Unsupported_Unit_Parameter;

   procedure Test_Wasm_Component_Preamble (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wasm (The_Module, "preamble");
      Assert_Component_Preamble (Emitted.Wasm_Bytes, "preamble");
   end Test_Wasm_Component_Preamble;

   procedure Test_Wasm_Wit_Equality (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module   : Modules.Module := Modules.Create ("Hello");
      Flags        : constant Subroutines.Subroutine_Flags := Subroutines.Export_Flag or Subroutines.Entrypoint_Flag;
      Wat_Emitted  : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wasm_Emitted : Lovelace.Compiler.Backend.Wasm_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Hello", Flags));
      Wat_Emitted := Must_Emit_Wat (The_Module, "wit eq wat");
      Wasm_Emitted := Must_Emit_Wasm (The_Module, "wit eq wasm");

      AUnit.Assertions.Assert (Ada.Strings.Unbounded."=" (Wat_Emitted.Wit_Text, Wasm_Emitted.Wit_Text), "wit equality");
   end Test_Wasm_Wit_Equality;

   procedure Test_Zero_Call_Target (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Calls");
      Caller     : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", 0);
      Wat_Out    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Append_Instruction (Caller, (Operation => Lovelace.Lir.Opcodes.Call, Target_Index => 0));
      Modules.Append_Subroutine (The_Module, Caller);
      Wat_Out := Wat_Backend.Emit_Wat (The_Module);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "zero call target: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "zero call target: code");
            Assert_Contains
              (Ada.Strings.Unbounded.To_String (Wat_Out.Error.Detail), "Validate failed", "zero call target: detail");
      end case;
   end Test_Zero_Call_Target;

   procedure Test_Zero_Local_Index (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Module_Get : Modules.Module := Modules.Create ("Locals");
      Module_Set : Modules.Module := Modules.Create ("Locals");
      Sub_Get    : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", 0);
      Sub_Set    : Subroutines.Subroutine := Make_Unit_Subroutine ("Run", 0);
      Wat_Out    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Subroutines.Append_Local (Sub_Get, "Foo", Types.I32);
      Subroutines.Append_Instruction (Sub_Get, (Operation => Lovelace.Lir.Opcodes.Local_Get, Local_Index => 0));
      Modules.Append_Subroutine (Module_Get, Sub_Get);
      Wat_Out := Wat_Backend.Emit_Wat (Module_Get);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "zero local get: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "zero local get: code");
      end case;

      Subroutines.Append_Local (Sub_Set, "Foo", Types.I32);
      Subroutines.Append_Instruction
        (Sub_Set, (Operation => Lovelace.Lir.Opcodes.Constant_I32, Immediate_I32 => Interfaces.Integer_32'(1)));
      Subroutines.Append_Instruction (Sub_Set, (Operation => Lovelace.Lir.Opcodes.Local_Set, Local_Index => 0));
      Modules.Append_Subroutine (Module_Set, Sub_Set);
      Wat_Out := Wat_Backend.Emit_Wat (Module_Set);

      case Wat_Out.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "zero local set: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Wat_Out.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "zero local set: code");
      end case;
   end Test_Zero_Local_Index;

end Lovelace.Compiler.Tests.Backend;
