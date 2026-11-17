with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Unit_Graph;
with Lovelace.Lir.Modules;

--  Lower frontend AST unit(s) into one LIR module (same-unit or multi-unit flatten).

package Lovelace.Compiler.Ir_Generator is

   package Source renames Lovelace.Common.Source;

   --  Why Generate failed.
   --  @enum Internal_Error Compiler bug such as Validate failing on frontend AST.
   --  @enum Unresolved_Call Call target is not a same-unit / imported procedure.
   --  @enum Invalid_Arguments Call arity or argument/formal types are not supported.
   --  @enum Call_Without_Import Callee module prefix is neither self nor an import of the caller.
   --  @enum Not_Exported Imported procedure exists but lacks Export_Flag.
   --  @enum Unknown_Native_Binding native(target, key) is not in the closed wasi intrinsic set.
   type Ir_Generator_Error_Code is
     (Internal_Error,
      Unresolved_Call,
      Invalid_Arguments,
      Call_Without_Import,
      Not_Exported,
      Unknown_Native_Binding);

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

   --  Flatten Units (root first) into one LIR module with import-gated call resolve.
   --  @param Units Compilation set from Unit_Graph.Load (root at index 1).
   --  @return Combined LIR module, or a located IR error.
   function Generate
     (Units : Unit_Graph.Compilation_Set) return Generate_Result;

end Lovelace.Compiler.Ir_Generator;
