with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Common.Option;

--  Closed set of LIR value types for signatures and the stack.

package Lovelace.Lir.Types is

   --  Scalar value type known to LIR (binary codes 0 .. 10).
   --  @enum Unit No stack value; a subroutine that returns Unit is a
   --  procedure for the Lovelace backend (never use a void type).
   --  @enum I8 Signed 8-bit integer.
   --  @enum I16 Signed 16-bit integer.
   --  @enum I32 Signed 32-bit integer.
   --  @enum I64 Signed 64-bit integer.
   --  @enum U8 Unsigned 8-bit integer.
   --  @enum U16 Unsigned 16-bit integer.
   --  @enum U32 Unsigned 32-bit integer.
   --  @enum U64 Unsigned 64-bit integer.
   --  @enum F32 32-bit floating point.
   --  @enum F64 64-bit floating point.
   type Value_Type is (Unit, I8, I16, I32, I64, U8, U16, U32, U64, F32, F64);

   --  Optional Value_Type (From_Code failure only).
   package Value_Type_Options is new Lovelace.Common.Option (Element_Type => Value_Type);

   --  One named parameter in a subroutine signature.
   --  @field Name UTF-8 parameter name (required, non-empty when validated).
   --  @field The_Type Parameter value type.
   type Parameter is record
      Name     : Ada.Strings.Unbounded.Unbounded_String;
      The_Type : Value_Type;
   end record;

   --  Ordered list of named parameters in a signature.
   type Parameter_Sequence is private;

   --  Binary u8 code for The_Type (0 .. 10).
   --  @param The_Type Value type to encode.
   --  @return Code byte for The_Type.
   function To_Code (The_Type : Value_Type) return Interfaces.Unsigned_8;

   --  Value_Type for Code, or absent when Code is outside 0 .. 10.
   --  @param Code Binary type code.
   --  @return Present option with the type, or None.
   function From_Code (Code : Interfaces.Unsigned_8) return Value_Type_Options.Option;

   --  Empty parameter sequence.
   --  @return Sequence with no elements.
   function Empty_Sequence return Parameter_Sequence;

   --  Append a named parameter to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param Name UTF-8 parameter name.
   --  @param The_Type Parameter type.
   procedure Append (Sequence : in out Parameter_Sequence; Name : String; The_Type : Value_Type);

   --  Number of parameters in Sequence.
   --  @param Sequence Parameter list.
   --  @return Element count.
   function Length (Sequence : Parameter_Sequence) return Natural;

   --  Parameter at Index (1 .. Length (Sequence)).
   --  @param Sequence Parameter list.
   --  @param Index 1-based index.
   --  @return Parameter at Index.
   function Element (Sequence : Parameter_Sequence; Index : Positive) return Parameter;

private

   package Parameter_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Parameter);

   type Parameter_Sequence is record
      Items : Parameter_Vectors.Vector;
   end record;

end Lovelace.Lir.Types;
