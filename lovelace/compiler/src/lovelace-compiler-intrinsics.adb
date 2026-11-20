with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Intrinsics is

   use type Lovelace.Compiler.Types.Integer_Size;
   use type Lovelace.Compiler.Types.Signedness;
   use type Lovelace.Compiler.Types.Type_Kind;
   use type Lovelace.Lir.Types.Value_Type;

   function Is_Default_Integer (The_Type : Lovelace.Compiler.Types.Type_Expression) return Boolean;
   --  True for signed integer / integer (Bits_32).

   function Is_Print_Integer_Stdout
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence) return Boolean;
   --  Closed-table check for augusta.std.io.print(integer) → Unit.

   function Is_Default_Integer (The_Type : Lovelace.Compiler.Types.Type_Expression) return Boolean is
   begin
      return The_Type.Kind = Lovelace.Compiler.Types.Integer
        and then The_Type.The_Signedness = Lovelace.Compiler.Types.Signed
        and then The_Type.Integer_Bit_Size = Lovelace.Compiler.Types.Bits_32;
   end Is_Default_Integer;

   function Is_Print_Integer_Stdout
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence) return Boolean
   is
   begin
      if Module_Name /= "augusta.std.io" or else Subroutine_Name /= "print" then
         return False;
      end if;

      if Return_Type /= Lovelace.Lir.Types.Unit then
         return False;
      end if;

      if Lovelace.Lir.Types.Length (Parameters) /= 1 then
         return False;
      end if;

      return Lovelace.Lir.Types.Element (Parameters, 1).The_Type = Lovelace.Lir.Types.I32;
   end Is_Print_Integer_Stdout;

   function Match_Intrinsic
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence)
      return Intrinsic_Kind_Option
   is
   begin
      if Is_Print_Integer_Stdout (Module_Name, Subroutine_Name, Return_Type, Parameters) then
         return (Present => True, Kind => Print_Integer_Stdout);
      end if;

      return (Present => False);
   end Match_Intrinsic;

   function Match_Intrinsic
     (Module_Name    : String;
      The_Subroutine : Ast.Subroutine) return Intrinsic_Kind_Option
   is
   begin
      if Module_Name = "augusta.std.io"
        and then Ast.Name (The_Subroutine) = "print"
        and then Ast.Return_Type (The_Subroutine).Kind = Lovelace.Compiler.Types.Unit
        and then Ast.Length (Ast.Parameters (The_Subroutine)) = 1
        and then Is_Default_Integer (Ast.Element (Ast.Parameters (The_Subroutine), 1).Parameter_Type)
      then
         return (Present => True, Kind => Print_Integer_Stdout);
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
         Module_Name :=
           Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name (Lir_Name'First .. Dot - 1));
         Subroutine_Name :=
           Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name (Dot + 1 .. Lir_Name'Last));
      end if;
   end Split_Lir_Subroutine_Name;

end Lovelace.Compiler.Intrinsics;
