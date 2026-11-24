package body Lovelace.Compiler.Semantics.Lovelace_Types is

   use type Types.Signedness;
   use type Types.Integer_Size;
   use type Types.Float_Size;

   function Bits_Image (Size : Types.Integer_Size) return String;

   function Bits_Image (Size : Types.Integer_Size) return String is
   begin
      case Size is
         when Types.Bits_8  =>
            return "8";

         when Types.Bits_16 =>
            return "16";

         when Types.Bits_32 =>
            return "32";

         when Types.Bits_64 =>
            return "64";
      end case;
   end Bits_Image;

   function Boolean_Type return Lovelace_Type is
   begin
      return (Class => Boolean_Class, Expression => Types.Boolean_Type, Literal_Value => 0);
   end Boolean_Type;

   function From_Expression (Expression : Types.Type_Expression) return Lovelace_Type is
   begin
      case Expression.Kind is
         when Types.Unit         =>
            return (Class => Unit_Class, Expression => Expression, Literal_Value => 0);

         when Types.Boolean_Kind =>
            return (Class => Boolean_Class, Expression => Expression, Literal_Value => 0);

         when Types.Integer_Kind =>
            return (Class => Integer_Class, Expression => Expression, Literal_Value => 0);

         when Types.Float_Kind   =>
            return (Class => Float_Class, Expression => Expression, Literal_Value => 0);
      end case;
   end From_Expression;

   function Image (The_Type : Lovelace_Type) return String is
   begin
      case The_Type.Class is
         when Unknown_Class         =>
            return "<unknown>";

         when Unit_Class            =>
            return "unit";

         when Boolean_Class         =>
            return "boolean";

         when Integer_Literal_Class =>
            return "integer literal " & Interfaces.Integer_32'Image (The_Type.Literal_Value);

         when Integer_Class         =>
            declare
               Sign : constant String :=
                 (if The_Type.Expression.The_Signedness = Types.Unsigned then "unsigned " else "");
               Size : constant String :=
                 (if The_Type.Expression.Integer_Bit_Size = Types.Bits_32
                  then ""
                  else "<" & Bits_Image (The_Type.Expression.Integer_Bit_Size) & ">");
            begin
               return Sign & "integer" & Size;
            end;

         when Float_Class           =>
            return (if The_Type.Expression.Float_Bit_Size = Types.Bits_64 then "float<64>" else "float<32>");
      end case;
   end Image;

   function Integer_Literal_Type (Value : Interfaces.Integer_32) return Lovelace_Type is
   begin
      return
        (Class         => Integer_Literal_Class,
         Expression    => Types.Integer_Type (Types.Signed, Types.Bits_32),
         Literal_Value => Value);
   end Integer_Literal_Type;

   function Is_Integral (The_Type : Lovelace_Type) return Boolean is
   begin
      return The_Type.Class in Integer_Class | Integer_Literal_Class;
   end Is_Integral;

   function Is_Numeric (The_Type : Lovelace_Type) return Boolean is
   begin
      return Is_Integral (The_Type) or else The_Type.Class = Float_Class;
   end Is_Numeric;

   function Unknown_Type return Lovelace_Type is
   begin
      return (Class => Unknown_Class, Expression => Types.Unit_Type, Literal_Value => 0);
   end Unknown_Type;

end Lovelace.Compiler.Semantics.Lovelace_Types;
