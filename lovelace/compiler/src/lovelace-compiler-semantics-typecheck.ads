with Ada.Strings.Unbounded;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Semantics.Lovelace_Types;

--  Typechecker API shared by `:=` and call actuals against formals.

package Lovelace.Compiler.Semantics.Typecheck is

   package Lovelace_Types renames Lovelace.Compiler.Semantics.Lovelace_Types;

   --  Outcome of a type query that can fail with a message.
   --  @disc Ok True when the query succeeded.
   --  @field The_Type Computed type when Ok is True.
   --  @field Detail Explanation when Ok is False.
   type Type_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            The_Type : Lovelace_Types.Lovelace_Type;

         when False =>
            Detail : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   --  Outcome of an assignability check.
   --  @disc Ok True when the source may be stored into the target.
   --  @field Detail Explanation when Ok is False.
   type Assign_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            null;

         when False =>
            Detail : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   --  Type of a literal expression (integer or boolean literal).
   --  @param The_Expression Expression with Kind Integer_Literal or Boolean_Literal.
   --  @return Literal type, or failure when the lexeme is not a valid literal.
   function Type_Of_Literal (The_Expression : Ast.Expression) return Type_Result;

   --  Check whether a value of type Source may be stored into Target.
   --  Rules: identical concrete types; Unknown on either side; integer literal into a
   --  signed/unsigned integer of at most 32 bits when the value fits.
   --  @param Target Expected type (variable or formal).
   --  @param Source Type of the right-hand side or actual.
   --  @return Ok, or a failure explaining the mismatch.
   function Check_Assignable
     (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Assign_Result;

   --  Boolean form of Check_Assignable.
   --  @param Target Expected type.
   --  @param Source Source type.
   --  @return True iff assignable.
   function Is_Assignable (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Boolean;

end Lovelace.Compiler.Semantics.Typecheck;
