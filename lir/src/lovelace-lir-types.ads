with Ada.Containers.Vectors;
with Interfaces;

with Lovelace.Common.Option;

--  Closed set of LIR value types for signatures and the stack.

package Lovelace.Lir.Types is

   --  Scalar value type known to LIR (binary codes 0 .. 12).
   --  @enum I8 Signed 8-bit integer.
   --  @enum I16 Signed 16-bit integer.
   --  @enum I32 Signed 32-bit integer.
   --  @enum I64 Signed 64-bit integer.
   --  @enum I128 Signed 128-bit integer.
   --  @enum U8 Unsigned 8-bit integer.
   --  @enum U16 Unsigned 16-bit integer.
   --  @enum U32 Unsigned 32-bit integer.
   --  @enum U64 Unsigned 64-bit integer.
   --  @enum U128 Unsigned 128-bit integer.
   --  @enum F16 16-bit floating point.
   --  @enum F32 32-bit floating point.
   --  @enum F64 64-bit floating point.
   type Value_Type is (I8, I16, I32, I64, I128, U8, U16, U32, U64, U128, F16, F32, F64);

   --  Optional Value_Type (From_Code failure, or absent return type).
   package Value_Type_Options is new Lovelace.Common.Option (Element_Type => Value_Type);

   --  Optional return type; Present False means no result.
   package Return_Type_Options renames Value_Type_Options;

   --  Ordered list of parameter types in a signature.
   type Value_Type_Sequence is private;

   --  Binary u8 code for The_Type (0 .. 12).
   --  @param The_Type Value type to encode.
   --  @return Code byte for The_Type.
   function To_Code (The_Type : Value_Type) return Interfaces.Unsigned_8;

   --  Value_Type for Code, or absent when Code is outside 0 .. 12.
   --  @param Code Binary type code.
   --  @return Present option with the type, or None.
   function From_Code (Code : Interfaces.Unsigned_8) return Value_Type_Options.Option;

   --  Empty parameter-type sequence.
   --  @return Sequence with no elements.
   function Empty_Sequence return Value_Type_Sequence;

   --  Append The_Type to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Type Type to append.
   procedure Append (Sequence : in out Value_Type_Sequence; The_Type : Value_Type);

   --  Number of types in Sequence.
   --  @param Sequence Parameter-type list.
   --  @return Element count.
   function Length (Sequence : Value_Type_Sequence) return Natural;

   --  Type at Index (1 .. Length (Sequence)).
   --  @param Sequence Parameter-type list.
   --  @param Index 1-based index.
   --  @return Type at Index.
   function Element (Sequence : Value_Type_Sequence; Index : Positive) return Value_Type;

private

   package Value_Type_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Value_Type);

   type Value_Type_Sequence is record
      Items : Value_Type_Vectors.Vector;
   end record;

end Lovelace.Lir.Types;
