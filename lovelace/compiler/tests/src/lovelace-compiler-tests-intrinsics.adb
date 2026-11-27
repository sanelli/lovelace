with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Intrinsics;
with Lovelace.Compiler.Types;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Tests.Intrinsics is

   package Intrinsics renames Lovelace.Compiler.Intrinsics;
   package Lir_Types renames Lovelace.Lir.Types;
   package Source renames Lovelace.Common.Source;

   Origin : constant Source.Source_Span :=
     (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1));

   procedure Test_Ast_Non_Default_Integer (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Formals : Ast.Parameter_Sequence := Ast.Empty_Parameter_Sequence;
      Sub     : Ast.Subroutine;
      Matched : Intrinsics.Intrinsic_Kind_Option;
   begin
      Ast.Append
        (Formals,
         (Parameter_Name => Ada.Strings.Unbounded.To_Unbounded_String ("value"),
          Name_Span      => Origin,
          Filename       => Source.Absent_Filename,
          Parameter_Type => Types.Integer_Type (Types.Unsigned, Types.Bits_32)));
      Sub :=
        Ast.Create_Subroutine
          (Name        => "print",
           Module_Name => "augusta.std.io",
           Name_Span   => Origin,
           Filename    => Source.Absent_Filename,
           Span        => Origin,
           Flags       => Ast.Intrinsic_Flag,
           Return_Type => Types.Unit_Type,
           Parameters  => Formals,
           The_Body    => Ast.Empty_Block,
           Native      => (Present => False));
      Matched := Intrinsics.Match_Intrinsic ("augusta.std.io", Sub);
      AUnit.Assertions.Assert (not Matched.Present, "unsigned formal is not default integer");
   end Test_Ast_Non_Default_Integer;

   procedure Test_Lir_Non_Unit_Return (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Params  : Lir_Types.Parameter_Sequence := Lir_Types.Empty_Sequence;
      Matched : Intrinsics.Intrinsic_Kind_Option;
   begin
      Lir_Types.Append (Params, "value", Lir_Types.I32);
      Matched :=
        Intrinsics.Match_Intrinsic
          (Module_Name     => "augusta.std.io",
           Subroutine_Name => "print",
           Return_Type     => Lir_Types.I32,
           Parameters      => Params);
      AUnit.Assertions.Assert (not Matched.Present, "non-Unit return is not print intrinsic");
   end Test_Lir_Non_Unit_Return;

   procedure Test_Split_Lir_Name (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Module_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Subroutine_Name : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Intrinsics.Split_Lir_Subroutine_Name
        (Root_Module_Name => "Root",
         Lir_Name         => "augusta.std.io.print",
         Module_Name      => Module_Name,
         Subroutine_Name  => Subroutine_Name);
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Module_Name) = "augusta.std.io", "dotted module");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Subroutine_Name) = "print", "dotted subroutine");

      Intrinsics.Split_Lir_Subroutine_Name
        (Root_Module_Name => "Root",
         Lir_Name         => "print",
         Module_Name      => Module_Name,
         Subroutine_Name  => Subroutine_Name);
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Module_Name) = "Root", "undotted module is root");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Subroutine_Name) = "print", "undotted subroutine");
   end Test_Split_Lir_Name;

end Lovelace.Compiler.Tests.Intrinsics;
