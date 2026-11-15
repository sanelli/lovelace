with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Lir.Modules;

--  Lower a frontend AST module into a LIR module.

package Lovelace.Compiler.Ir_Generator is

   package Source renames Lovelace.Common.Source;

   --  Why Generate failed.
   --  @enum Internal_Error Compiler bug such as Validate failing on frontend AST.
   --  @enum Unresolved_Call Call target is not a same-unit procedure.
   --  @enum Invalid_Arguments Call arity or argument/formal types are not supported.
   type Ir_Generator_Error_Code is (Internal_Error, Unresolved_Call, Invalid_Arguments);

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

   --  Lower The_Module into LIR (signatures, origins, same-unit call bodies).
   --  @param The_Module Frontend compilation-unit AST.
   --  @return LIR module, or a located IR error.
   function Generate (The_Module : Ast.Module) return Generate_Result;

end Lovelace.Compiler.Ir_Generator;
