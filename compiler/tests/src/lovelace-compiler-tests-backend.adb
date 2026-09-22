with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Compiler.Backend;
with Lovelace.Compiler.Backend.Wat;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Tests.Backend is

   package Modules renames Lovelace.Lir.Modules;
   package Subroutines renames Lovelace.Lir.Subroutines;
   package Types renames Lovelace.Lir.Types;
   package Wat_Backend renames Lovelace.Compiler.Backend.Wat;

   use type Lovelace.Compiler.Backend.Backend_Error_Code;
   use type Subroutines.Subroutine_Flags;

   procedure Assert_Contains (Text : String; Fragment : String; Message : String);
   --  Assert Text contains Fragment.

   procedure Assert_Not_Contains (Text : String; Fragment : String; Message : String);
   --  Assert Text does not contain Fragment.

   function Make_Unit_Subroutine
     (Name : String; Flags : Subroutines.Subroutine_Flags; Noop_Count : Natural := 0) return Subroutines.Subroutine;
   --  Build a Unit/no-params subroutine with optional noop instructions.

   function Must_Emit_Wat
     (The_Module : Modules.Module; Message : String) return Lovelace.Compiler.Backend.Wat_Emit_Result;
   --  Require Emit_Wat success.

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
        (Name            => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Return_Type     => Types.Unit,
         Parameter_Types => Types.Empty_Sequence);
      Result        : Subroutines.Subroutine := Subroutines.Create (The_Signature => The_Signature, Flags => Flags);
   begin
      for Index in 1 .. Noop_Count loop
         pragma Unreferenced (Index);
         Subroutines.Append_Instruction (Result, (Operation => Lovelace.Lir.Opcodes.No_Operation));
      end loop;

      return Result;
   end Make_Unit_Subroutine;

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

   procedure Test_Entrypoint (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Hello");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Hello", Subroutines.Entrypoint_Flag));
      Emitted := Must_Emit_Wat (The_Module, "entrypoint");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export run: func() -> result;", "entrypoint wit run");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export Hello:", "entrypoint wit named");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$_start", "entrypoint wat start");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "i32.const 0", "entrypoint wat success");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""run""", "entrypoint wat run");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "call $Hello", "entrypoint wat call");
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
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export Hello: func();", "both flags wit Hello");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export run: func() -> result;", "both flags wit run");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""Hello""", "both flags wat Hello");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""run""", "both flags wat run");
   end Test_Entrypoint_And_Export;

   procedure Test_Export_Only (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
      Wit_Text   : Ada.Strings.Unbounded.Unbounded_String;
      Wat_Text   : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "export only");
      Wit_Text := Emitted.Wit_Text;
      Wat_Text := Emitted.Wat_Text;

      Assert_Contains (Ada.Strings.Unbounded.To_String (Wit_Text), "package love:lib@0.1.0;", "export only wit");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wit_Text), "export Helper: func();", "export only wit helper");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Wit_Text), "export run:", "export only wit run");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "(export ""Helper""", "export only wat helper");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "$_start", "export only wat start");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Wat_Text), "(export ""run""", "export only wat run");
   end Test_Export_Only;

   procedure Test_Invalid_Module (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("");
      Emitted    : constant Lovelace.Compiler.Backend.Wat_Emit_Result := Wat_Backend.Emit_Wat (The_Module);
   begin
      case Emitted.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "invalid module: expected failure");

         when False =>
            AUnit.Assertions.Assert
              (Emitted.Error.Code = Lovelace.Compiler.Backend.Invalid_Module, "invalid module: code");
      end case;
   end Test_Invalid_Module;

   procedure Test_Noop_Body (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Helper", Subroutines.Export_Flag, Noop_Count => 2));
      Emitted := Must_Emit_Wat (The_Module, "noop body");

      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(func $Helper", "noop body wat func");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export Helper: func();", "noop body wit");
   end Test_Noop_Body;

   procedure Test_Two_Exports (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("Lib");
      Emitted    : Lovelace.Compiler.Backend.Wat_Emit_Result;
   begin
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Alpha", Subroutines.Export_Flag));
      Modules.Append_Subroutine (The_Module, Make_Unit_Subroutine ("Beta", Subroutines.Export_Flag));
      Emitted := Must_Emit_Wat (The_Module, "two exports");

      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export Alpha: func();", "two exports wit Alpha");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export Beta: func();", "two exports wit Beta");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wit_Text), "export run:", "two exports wit run");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""Alpha""", "two exports wat Alpha");
      Assert_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "(export ""Beta""", "two exports wat Beta");
      Assert_Not_Contains (Ada.Strings.Unbounded.To_String (Emitted.Wat_Text), "$_start", "two exports wat start");
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
        (The_Module, Subroutines.Create (The_Signature => The_Signature, Flags => Subroutines.Export_Flag));

      declare
         Emitted : constant Lovelace.Compiler.Backend.Wat_Emit_Result := Wat_Backend.Emit_Wat (The_Module);
      begin
         case Emitted.Ok is
            when True  =>
               AUnit.Assertions.Assert (False, "unsupported type: expected failure");

            when False =>
               AUnit.Assertions.Assert
                 (Emitted.Error.Code = Lovelace.Compiler.Backend.Unsupported_Type, "unsupported type: code");
         end case;
      end;
   end Test_Unsupported_Type;

end Lovelace.Compiler.Tests.Backend;
