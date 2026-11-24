--  Frontend type expressions for the Lovelace compiler AST.
--  Distinct from Lovelace.Lir.Types. Future path / Named kinds may be
--  added without reshaping Integer_Kind, Float_Kind, and Boolean_Kind.
--  Enum literals use *_Kind names so they do not hide Standard.Boolean /
--  Integer (required for gnatcov instrumentation witnesses).

package Lovelace.Compiler.Types is

   --  Kind of a frontend type expression.
   --  @enum Unit No value; used for procedure return types.
   --  @enum Boolean_Kind Boolean type (LIR i32: 0 = false, nonzero = true).
   --  @enum Integer_Kind Signed or unsigned integral type with a bit size.
   --  @enum Float_Kind Floating-point type with a bit size.
   type Type_Kind is (Unit, Boolean_Kind, Integer_Kind, Float_Kind);

   --  Signedness of an Integer type expression.
   --  @enum Signed Two's-complement signed integer.
   --  @enum Unsigned Modular unsigned integer.
   type Signedness is (Signed, Unsigned);

   --  Bit width of an Integer type expression.
   --  @enum Bits_8 8 bits.
   --  @enum Bits_16 16 bits.
   --  @enum Bits_32 32 bits.
   --  @enum Bits_64 64 bits.
   type Integer_Size is (Bits_8, Bits_16, Bits_32, Bits_64);

   --  Bit width of a Float type expression.
   --  @enum Bits_32 32-bit binary float (WASM f32).
   --  @enum Bits_64 64-bit binary float (WASM f64).
   type Float_Size is (Bits_32, Bits_64);

   --  One frontend type expression. Fields for other kinds are unused.
   --  @field Kind Selects the type form.
   --  @field The_Signedness Signedness when Kind is Integer.
   --  @field Integer_Bit_Size Width when Kind is Integer.
   --  @field Float_Bit_Size Width when Kind is Float.
   type Type_Expression is record
      Kind             : Type_Kind := Unit;
      The_Signedness   : Signedness := Signed;
      Integer_Bit_Size : Integer_Size := Bits_32;
      Float_Bit_Size   : Float_Size := Bits_32;
   end record;

   --  The boolean type expression.
   --  @return Type_Expression with Kind Boolean_Kind.
   function Boolean_Type return Type_Expression;

   --  Float type with The_Size.
   --  @param The_Size Bit width (32 or 64).
   --  @return Type_Expression with Kind Float.
   function Float_Type (The_Size : Float_Size) return Type_Expression;

   --  Integer type with The_Signedness and The_Size.
   --  @param The_Signedness Signed or Unsigned.
   --  @param The_Size Bit width.
   --  @return Type_Expression with Kind Integer.
   function Integer_Type (The_Signedness : Signedness; The_Size : Integer_Size) return Type_Expression;

   --  The unit type expression (no value).
   --  @return Type_Expression with Kind Unit.
   function Unit_Type return Type_Expression;

end Lovelace.Compiler.Types;
