with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Unit_Graph;
with Lovelace.Lir.Modules;

--  Lower frontend AST unit(s) into one LIR module (same-unit or multi-unit flatten).

package Lovelace.Compiler.Ir_Generator is

   package Source renames Lovelace.Common.Source;

   --  Why Generate failed. Call-target resolve, arity, and type checks live in Semantics;
   --  IR assumes a resolved, well-typed unit set and reports Internal_Error otherwise.
   --  @enum Internal_Error Compiler bug such as Validate failing, or an AST Semantics should have rejected.
   --  @enum Unknown_Native_Binding Retired path for old native(target, key) closed set (kept for mapping).
   --  @enum Unknown_Intrinsic `@intrinsic` signature is not in the closed intrinsic table.
   type Ir_Generator_Error_Code is (Internal_Error, Unknown_Native_Binding, Unknown_Intrinsic);

   --  One IR Generator failure.
   --  @field Code Predefined error code.
   --  @field Span Source extent of the problem (call name or argument).
   --  @field Detail UTF-8 message describing the failure.
   type Ir_Generator_Error is record
      Code   : Ir_Generator_Error_Code;
      Span   : Source.Source_Span;
      Detail : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  LIR module on success, or an error on failure.
   --  @disc Ok True when The_Module is present; False when Error is present.
   --  @field The_Module Generated LIR module when Ok is True.
   --  @field Error Failure detail when Ok is False.
   type Generate_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            The_Module : Lovelace.Lir.Modules.Module;

         when False =>
            Error : Ir_Generator_Error;
      end case;
   end record;

   --  Lower a single compilation-unit AST into LIR (thin wrap over the multi-unit API).
   --  @param The_Module Frontend compilation-unit AST.
   --  @return LIR module, or a located IR error.
   function Generate (The_Module : Ast.Module) return Generate_Result;

   --  Flatten Units (root first) into one LIR module; units must have passed Semantics.Analyze.
   --  @param Units Compilation set from Unit_Graph.Load (root at index 1).
   --  @return Combined LIR module, or a located IR error.
   function Generate (Units : Unit_Graph.Compilation_Set) return Generate_Result;

end Lovelace.Compiler.Ir_Generator;
