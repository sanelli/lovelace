--  Frontend type expressions for the Lovelace compiler AST.
--  Distinct from Lovelace.Lir.Types; only Unit exists in this slice.

package Lovelace.Compiler.Types is

   --  Kind of a frontend type expression (extensible in later work).
   --  @enum Unit No value; used internally (e.g. procedure-like return).
   type Type_Kind is (Unit);

   --  One frontend type expression, selected by Kind.
   --  Future kinds may carry payloads (named types, pointers, aggregates).
   --  @disc Kind Selects which variant fields are present.
   type Type_Expression (Kind : Type_Kind) is record
      case Kind is
         when Unit =>
            null;
      end case;
   end record;

   --  The unit type expression (no value).
   --  @return Type_Expression with Kind Unit.
   function Unit_Type return Type_Expression;

end Lovelace.Compiler.Types;
