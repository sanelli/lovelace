with Interfaces;

with Lovelace.Compiler.Types;

--  Semantic type model (Lovelace_Type) shared by assignment and call checking.
--  Distinct from the syntactic Types.Type_Expression: it adds literal and unknown classes.

package Lovelace.Compiler.Semantics.Lovelace_Types is

   --  Hierarchy of type classes.
   --  Integer_Literal_Class values are integral but not yet bound to a width.
   --  @enum Unknown_Class Result of an earlier error; assignable both ways to avoid cascades.
   --  @enum Unit_Class No value.
   --  @enum Boolean_Class Boolean.
   --  @enum Integer_Class Signed or unsigned integer with a bit size.
   --  @enum Float_Class Floating-point with a bit size.
   --  @enum Integer_Literal_Class An integer literal with a known value.
   type Type_Class is (Unknown_Class, Unit_Class, Boolean_Class, Integer_Class, Float_Class, Integer_Literal_Class);

   --  One semantic type.
   --  @field Class Which class of type this is.
   --  @field Expression Concrete shape for Unit/Boolean/Integer/Float classes.
   --  @field Literal_Value Value when Class is Integer_Literal_Class.
   type Lovelace_Type is record
      Class         : Type_Class := Unknown_Class;
      Expression    : Types.Type_Expression := Types.Unit_Type;
      Literal_Value : Interfaces.Integer_32 := 0;
   end record;

   --  The unknown (error) type.
   --  @return Type with Class Unknown_Class.
   function Unknown_Type return Lovelace_Type;

   --  The boolean type.
   --  @return Type with Class Boolean_Class.
   function Boolean_Type return Lovelace_Type;

   --  Type of an integer literal with Value.
   --  @param Value Evaluated literal value.
   --  @return Type with Class Integer_Literal_Class.
   function Integer_Literal_Type (Value : Interfaces.Integer_32) return Lovelace_Type;

   --  Lift a syntactic type expression into the semantic model.
   --  @param Expression Frontend type expression.
   --  @return Matching semantic type.
   function From_Expression (Expression : Types.Type_Expression) return Lovelace_Type;

   --  True for integer and integer-literal types.
   --  @param The_Type Type to query.
   --  @return True iff integral.
   function Is_Integral (The_Type : Lovelace_Type) return Boolean;

   --  True for integral and float types.
   --  @param The_Type Type to query.
   --  @return True iff numeric.
   function Is_Numeric (The_Type : Lovelace_Type) return Boolean;

   --  Human-readable spelling for diagnostics (for example "unsigned integer<8>").
   --  @param The_Type Type to describe.
   --  @return UTF-8 description.
   function Image (The_Type : Lovelace_Type) return String;

end Lovelace.Compiler.Semantics.Lovelace_Types;
