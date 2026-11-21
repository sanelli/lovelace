with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Unit_Graph;

--  Semantic analysis between parse and IR generation: scope environment,
--  call-target resolve, definite assignment, Lovelace_Type checks, and unused warnings.
--  IR lowering assumes a unit set that passed this stage without errors.

package Lovelace.Compiler.Semantics is

   package Source renames Lovelace.Common.Source;

   --  Why a semantic diagnostic was produced (map via Reporting to LV labels).
   --  @enum Internal_Error Compiler bug or impossible state (LV00001).
   --  @enum Unresolved_Call Callee subroutine does not exist / no matching overload (LV00014).
   --  @enum Invalid_Arguments Call arity differs from the callee's formal count (LV00015).
   --  @enum Call_Without_Using Callee module prefix is neither the unit itself nor in scope via using (LV00017).
   --  @enum Not_Exported Cross-module callee exists but lacks Export_Flag (LV00018).
   --  @enum Use_Before_Assignment Read of a local that is not definitely assigned (LV00026).
   --  @enum Type_Mismatch Assignment or call actual is not assignable to the expected type (LV00027).
   --  @enum Unresolved_Name Identifier does not name a visible local or parameter (LV00031).
   --  @enum Ambiguous_Call Two or more overloads match a call equally (LV00033).
   --  @enum Unused_Variable Warning: local is never read (LV00028).
   --  @enum Unused_Assignment Warning: store whose value is never read (LV00029).
   --  @enum Unused_Using Warning: a using was never required for call resolve (LV00032).
   type Semantics_Error_Code is
     (Internal_Error,
      Unresolved_Call,
      Invalid_Arguments,
      Call_Without_Using,
      Not_Exported,
      Use_Before_Assignment,
      Type_Mismatch,
      Unresolved_Name,
      Ambiguous_Call,
      Unused_Variable,
      Unused_Assignment,
      Unused_Using);

   --  True when Code is a warning code (explicit cases; not a contiguous subtype range).
   --  @param Code Semantic diagnostic kind.
   --  @return True iff Code is Unused_Variable, Unused_Assignment, or Unused_Using.
   function Is_Warning (Code : Semantics_Error_Code) return Boolean;

   --  One semantic diagnostic (error or warning, by Code).
   --  @field Code Diagnostic kind.
   --  @field Span Source extent of the problem inside the unit's own source.
   --  @field Detail UTF-8 message describing the problem.
   --  @field Unit_Index 1-based index of the unit in the analysed compilation set.
   type Diagnostic is record
      Code       : Semantics_Error_Code := Internal_Error;
      Span       : Source.Source_Span;
      Detail     : Ada.Strings.Unbounded.Unbounded_String;
      Unit_Index : Positive := 1;
   end record;

   package Diagnostic_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Diagnostic);

   --  Ordered list of diagnostics.
   subtype Diagnostic_Sequence is Diagnostic_Vectors.Vector;

   --  Outcome of Analyze.
   --  @field Errors Fatal diagnostics (any entry means the build must fail).
   --  @field Warnings Non-fatal diagnostics (never fail the build by themselves).
   type Analysis_Result is record
      Errors   : Diagnostic_Sequence;
      Warnings : Diagnostic_Sequence;
   end record;

   --  True when Result carries no errors (warnings are ignored).
   --  @param Result Analysis outcome.
   --  @return True iff Errors is empty.
   function Succeeded (Result : Analysis_Result) return Boolean;

   --  Analyse every unit in Units (root first) after parse and before IR.
   --  @param Units Compilation set from Unit_Graph.Load.
   --  @return Errors and warnings in deterministic order (unit order, then source order).
   function Analyze
     (Units : Unit_Graph.Compilation_Set) return Analysis_Result;

   --  Analyse a single already-parsed unit (thin wrap over the multi-unit API).
   --  @param The_Module Frontend compilation-unit AST.
   --  @return Errors and warnings for the unit.
   function Analyze (The_Module : Ast.Module) return Analysis_Result;

end Lovelace.Compiler.Semantics;
