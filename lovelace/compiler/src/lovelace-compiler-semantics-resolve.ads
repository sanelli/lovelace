with Ada.Strings.Unbounded;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Semantics.Environment;
with Lovelace.Compiler.Unit_Graph;

--  Call-target resolution (module visibility, subroutine existence, export check).
--  Runs before IR; IR only looks up indices for targets that resolved here.

package Lovelace.Compiler.Semantics.Resolve is

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
   --  @field Code Failure kind (Unresolved_Call, Call_Without_Using, Not_Exported) when Ok is False.
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

   --  Resolve MODULE.SUBROUTINE as seen from the current scope of Caller_Unit_Index.
   --  Same-unit prefix: subroutine must exist (LV00014). Otherwise the module must be in scope
   --  via a using (LV00017), the subroutine must exist (LV00014), and be exported (LV00018).
   --  @param Units Compilation set (root first).
   --  @param Caller_Unit_Index 1-based index of the calling unit.
   --  @param Scope Environment at the call site (unit usings, subroutines, enclosing block usings).
   --  @param Callee_Name UTF-8 dotted callee as written (at least one '.').
   --  @return Resolved callee, or a classified failure.
   function Resolve_Call
     (Units             : Unit_Graph.Compilation_Set;
      Caller_Unit_Index : Positive;
      Scope             : Environment.Scope_Stack;
      Callee_Name       : String) return Resolve_Result;

end Lovelace.Compiler.Semantics.Resolve;
