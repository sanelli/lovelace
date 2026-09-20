with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Types;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Tests.Ir_Generator is

   package Source renames Lovelace.Common.Source;
   package Modules renames Lovelace.Lir.Modules;
   package Subroutines renames Lovelace.Lir.Subroutines;

   use type Lovelace.Lir.Types.Value_Type;
   use type Source.Source_Span;

   procedure Assert_Entrypoint_Lir
     (Lir_Module : Modules.Module; Expected_Name : String; Ast_Module : Ast.Module; Message : String);
   --  Assert LIR module/subroutine shape and origins match Expected_Name and Ast_Module.

   procedure Assert_Entrypoint_Lir
     (Lir_Module : Modules.Module; Expected_Name : String; Ast_Module : Ast.Module; Message : String)
   is
      Lir_Subroutine : constant Subroutines.Subroutine := Modules.Get_Subroutine (Lir_Module, 1);
      The_Signature  : constant Subroutines.Signature := Subroutines.Get_Signature (Lir_Subroutine);
      Flags          : constant Subroutines.Subroutine_Flags := Subroutines.Get_Flags (Lir_Subroutine);
      Instructions   : constant Lovelace.Lir.Instructions.Instruction_Sequence :=
        Subroutines.Get_Instructions (Lir_Subroutine);
      Module_Origin  : constant Modules.Origin_Option := Modules.Origin (Lir_Module);
      Sub_Origin     : constant Subroutines.Origin_Option := Subroutines.Origin (Lir_Subroutine);
      Ast_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (Ast_Module, 1);
   begin
      AUnit.Assertions.Assert (Modules.Name (Lir_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert (Modules.Subroutine_Count (Lir_Module) = 1, Message & ": one subroutine");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (The_Signature.Name) = Expected_Name, Message & ": subroutine name");
      AUnit.Assertions.Assert (The_Signature.Return_Type = Lovelace.Lir.Types.Unit, Message & ": return Unit");
      AUnit.Assertions.Assert (Lovelace.Lir.Types.Length (The_Signature.Parameter_Types) = 0, Message & ": no params");
      AUnit.Assertions.Assert (Subroutines.Has_Export (Flags), Message & ": export");
      AUnit.Assertions.Assert (Subroutines.Has_Entrypoint (Flags), Message & ": entrypoint");
      AUnit.Assertions.Assert (Lovelace.Lir.Instructions.Length (Instructions) = 0, Message & ": empty instructions");

      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (False, Message & ": module origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Module_Origin.Value.Name_Span = Ast.Name_Span (Ast_Module), Message & ": module name span");
            AUnit.Assertions.Assert (Module_Origin.Value.Span = Ast.Span (Ast_Module), Message & ": module unit span");
            AUnit.Assertions.Assert
              (Source.Same_Storage (Module_Origin.Value.Filename, Ast.Filename (Ast_Module)),
               Message & ": module filename");
      end case;

      case Sub_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (False, Message & ": subroutine origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Sub_Origin.Value.Name_Span = Ast.Name_Span (Ast_Subroutine), Message & ": subroutine name span");
            AUnit.Assertions.Assert
              (Source.Same_Storage (Sub_Origin.Value.Filename, Ast.Filename (Ast_Subroutine)),
               Message & ": subroutine filename");
      end case;
   end Assert_Entrypoint_Lir;

   procedure Test_Canonical_Multiline (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program Hello;" & ASCII.LF & "begin" & ASCII.LF & "end.";
      Ast_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "canonical");
      Lir_Module  : constant Modules.Module := Support.Must_Generate (Ast_Module, "canonical");
   begin
      Assert_Entrypoint_Lir (Lir_Module, "Hello", Ast_Module, "canonical");
   end Test_Canonical_Multiline;

   procedure Test_Export_Only_Flags (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Name_Span  : constant Source.Source_Span :=
        (First => (Byte_Index => 9, Line => 1, Column => 9), Last => (Byte_Index => 11, Line => 1, Column => 11));
      Unit_Span  : constant Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 20, Line => 1, Column => 20));
      Ast_Sub    : constant Ast.Subroutine :=
        Ast.Create_Subroutine
          (Name        => "Lib",
           Name_Span   => Name_Span,
           Filename    => Source.Absent_Filename,
           Flags       => Ast.Export_Flag,
           Return_Type => Types.Unit_Type,
           The_Body    => Ast.Empty_Body);
      Ast_Module : constant Ast.Module :=
        Ast.Create_Module
          (Name           => "Lib",
           Name_Span      => Name_Span,
           Filename       => Source.Absent_Filename,
           Span           => Unit_Span,
           The_Subroutine => Ast_Sub);
      Lir_Module : constant Modules.Module := Support.Must_Generate (Ast_Module, "export only");
      Lir_Sub    : constant Subroutines.Subroutine := Modules.Get_Subroutine (Lir_Module, 1);
      Flags      : constant Subroutines.Subroutine_Flags := Subroutines.Get_Flags (Lir_Sub);
   begin
      AUnit.Assertions.Assert (Subroutines.Has_Export (Flags), "export only: export");
      AUnit.Assertions.Assert (not Subroutines.Has_Entrypoint (Flags), "export only: no entrypoint");
      AUnit.Assertions.Assert (Modules.Origin (Lir_Module).Present, "export only: module origin");
      AUnit.Assertions.Assert (Subroutines.Origin (Lir_Sub).Present, "export only: subroutine origin");
   end Test_Export_Only_Flags;

   procedure Test_Filename_Shared (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text   : constant String := "program Hello; begin end.";
      Ast_Module    : constant Ast.Module := Support.Must_Parse (Source_Text, "unit.love", "filename shared");
      Lir_Module    : constant Modules.Module := Support.Must_Generate (Ast_Module, "filename shared");
      Module_Origin : constant Modules.Origin_Option := Modules.Origin (Lir_Module);
      Sub_Origin    : constant Subroutines.Origin_Option := Subroutines.Origin (Modules.Get_Subroutine (Lir_Module, 1));
   begin
      Assert_Entrypoint_Lir (Lir_Module, "Hello", Ast_Module, "filename shared");

      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (False, "filename shared: module origin");

         when True  =>
            AUnit.Assertions.Assert (Module_Origin.Value.Filename.Present, "filename shared: module has filename");

            case Sub_Origin.Present is
               when False =>
                  AUnit.Assertions.Assert (False, "filename shared: subroutine origin");

               when True  =>
                  AUnit.Assertions.Assert
                    (Source.Same_Storage (Module_Origin.Value.Filename, Sub_Origin.Value.Filename),
                     "filename shared: module and subroutine Same_Storage");
            end case;
      end case;
   end Test_Filename_Shared;

   procedure Test_Identifier_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe_Name   : constant String := "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Cafe_Source : constant String := "program " & Cafe_Name & "; begin end.";
      At_Source   : constant String := "program @foo; begin end.";
      Cafe_Ast    : constant Ast.Module := Support.Must_Parse (Cafe_Source, "unicode name");
      At_Ast      : constant Ast.Module := Support.Must_Parse (At_Source, "@foo name");
      Cafe_Lir    : constant Modules.Module := Support.Must_Generate (Cafe_Ast, "unicode name");
      At_Lir      : constant Modules.Module := Support.Must_Generate (At_Ast, "@foo name");
   begin
      Assert_Entrypoint_Lir (Cafe_Lir, Cafe_Name, Cafe_Ast, "unicode name");
      Assert_Entrypoint_Lir (At_Lir, "@foo", At_Ast, "@foo name");
   end Test_Identifier_Names;

end Lovelace.Compiler.Tests.Ir_Generator;
