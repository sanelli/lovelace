with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Semantics.Environment;
with Lovelace.Compiler.Semantics.Lovelace_Types;
with Lovelace.Compiler.Unit_Graph;

--  Call-target resolution (module visibility, overload by parameter types, export check).
--  Runs before IR; IR only looks up indices for targets that resolved here.

package Lovelace.Compiler.Semantics.Resolve is

   package Type_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Lovelace_Types.Lovelace_Type,
        "="          => Lovelace_Types."=");

   --  Ordered actual types at a call site (expressions analysed first).
   subtype Actual_Type_Sequence is Type_Vectors.Vector;

   --  A call target that passed every check.
   --  @field Unit_Index 1-based index of the owning unit in the compilation set.
   --  @field Subroutine_Index 1-based index of the subroutine within that unit.
   --  @field The_Subroutine Resolved callee AST (formals, flags, return type).
   type Resolved_Callee is record
      Unit_Index       : Positive;
      Subroutine_Index : Positive;
      The_Subroutine   : Ast.Subroutine;
   end record;

   --  Resolved callee or a classified failure.
   --  @disc Ok True when Callee is present.
   --  @field Callee Resolved target when Ok is True.
   --  @field Code Failure kind when Ok is False.
   --  @field Detail UTF-8 message when Ok is False.
   type Resolve_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Callee : Resolved_Callee;

         when False =>
            Code   : Semantics_Error_Code;
            Detail : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   --  Resolve MODULE.SUBROUTINE against Actual_Types from the current scope of Caller_Unit_Index.
   --  Same-unit prefix: pick the unique overload whose formals accept Actual_Types (LV00014 /
   --  LV00033). Otherwise the module must be in scope via a using (LV00017; marks that using
   --  used), then pick among exported overloads (LV00014 / LV00018 / LV00033). Return type is
   --  not part of the signature. Only fully assignable candidates count.
   --  @param Units Compilation set (root first).
   --  @param Caller_Unit_Index 1-based index of the calling unit.
   --  @param Scope Environment at the call site (updated when a using is required).
   --  @param Callee_Name UTF-8 dotted callee as written (at least one '.').
   --  @param Actual_Types Types of the analysed call arguments (same order).
   --  @return Resolved callee, or a classified failure.
   function Resolve_Call
     (Units             : Unit_Graph.Compilation_Set;
      Caller_Unit_Index : Positive;
      Scope             : in out Environment.Scope_Stack;
      Callee_Name       : String;
      Actual_Types      : Actual_Type_Sequence) return Resolve_Result;

end Lovelace.Compiler.Semantics.Resolve;
