with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Intrinsics is

   use type Lovelace.Compiler.Types.Integer_Size;
   use type Lovelace.Compiler.Types.Signedness;
   use type Lovelace.Compiler.Types.Type_Kind;
   use type Lovelace.Lir.Types.Value_Type;

   package Ast renames Lovelace.Compiler.Ast;
   package Compiler_Types renames Lovelace.Compiler.Types;
   package Lir_Types renames Lovelace.Lir.Types;

   --  Simple-name renames so gnatcov can instrument call coverage (no dotted callees).
   function Lir_Element
     (Sequence : Lir_Types.Parameter_Sequence; Index : Positive) return Lir_Types.Parameter
     renames Lir_Types.Element;
   function Lir_Length (Sequence : Lir_Types.Parameter_Sequence) return Natural renames Lir_Types.Length;
   function Ast_Name (The_Subroutine : Ast.Subroutine) return String renames Ast.Name;
   function Ast_Return_Type
     (The_Subroutine : Ast.Subroutine) return Compiler_Types.Type_Expression
     renames Ast.Return_Type;
   function Ast_Parameters
     (The_Subroutine : Ast.Subroutine) return Ast.Parameter_Sequence
     renames Ast.Parameters;
   function Ast_Length (Sequence : Ast.Parameter_Sequence) return Natural renames Ast.Length;
   function Ast_Element
     (Sequence : Ast.Parameter_Sequence; Index : Positive) return Ast.Parameter
     renames Ast.Element;

   function Is_Default_Integer (The_Type : Lovelace.Compiler.Types.Type_Expression) return Boolean;
   --  True for signed integer / integer (Bits_32).

   function Is_Print_Integer_Stdout
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence) return Boolean;
   --  Closed-table check for augusta.std.io.print(integer) -> Unit.

   function Is_Default_Integer (The_Type : Lovelace.Compiler.Types.Type_Expression) return Boolean is
   begin
      return
        The_Type.Kind = Lovelace.Compiler.Types.Integer_Kind
        and then The_Type.The_Signedness = Lovelace.Compiler.Types.Signed
        and then The_Type.Integer_Bit_Size = Lovelace.Compiler.Types.Bits_32;
   end Is_Default_Integer;

   function Is_Print_Integer_Stdout
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence) return Boolean is
   begin
      if Module_Name /= "augusta.std.io" or else Subroutine_Name /= "print" then
         return False;
      end if;

      if Return_Type /= Lovelace.Lir.Types.Unit then
         return False;
      end if;

      if Lir_Length (Parameters) /= 1 then
         return False;
      end if;

      declare
         First : constant Lir_Types.Parameter := Lir_Element (Parameters, 1);
      begin
         return First.The_Type = Lir_Types.I32;
      end;
   end Is_Print_Integer_Stdout;

   function Match_Intrinsic
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence) return Intrinsic_Kind_Option is
   begin
      if Is_Print_Integer_Stdout (Module_Name, Subroutine_Name, Return_Type, Parameters) then
         return (Present => True, Kind => Print_Integer_Stdout);
      end if;

      return (Present => False);
   end Match_Intrinsic;

   function Match_Intrinsic (Module_Name : String; The_Subroutine : Ast.Subroutine) return Intrinsic_Kind_Option is
      Return_Type : constant Compiler_Types.Type_Expression := Ast_Return_Type (The_Subroutine);
      Formals     : constant Ast.Parameter_Sequence := Ast_Parameters (The_Subroutine);
   begin
      if Module_Name = "augusta.std.io"
        and then Ast_Name (The_Subroutine) = "print"
        and then Return_Type.Kind = Compiler_Types.Unit
        and then Ast_Length (Formals) = 1
      then
         declare
            First : constant Ast.Parameter := Ast_Element (Formals, 1);
         begin
            if Is_Default_Integer (First.Parameter_Type) then
               return (Present => True, Kind => Print_Integer_Stdout);
            end if;
         end;
      end if;

      return (Present => False);
   end Match_Intrinsic;

   procedure Split_Lir_Subroutine_Name
     (Root_Module_Name : String;
      Lir_Name         : String;
      Module_Name      : out Ada.Strings.Unbounded.Unbounded_String;
      Subroutine_Name  : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Dot : Natural := 0;
   begin
      for Index in reverse Lir_Name'Range loop
         if Lir_Name (Index) = '.' then
            Dot := Index;
            exit;
         end if;
      end loop;

      if Dot = 0 then
         Module_Name := Ada.Strings.Unbounded.To_Unbounded_String (Root_Module_Name);
         Subroutine_Name := Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name);
      else
         Module_Name := Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name (Lir_Name'First .. Dot - 1));
         Subroutine_Name := Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name (Dot + 1 .. Lir_Name'Last));
      end if;
   end Split_Lir_Subroutine_Name;

end Lovelace.Compiler.Intrinsics;
