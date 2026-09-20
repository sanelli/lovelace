with Ada.Strings.Unbounded;

with Lovelace.Compiler.Ast;
with Lovelace.Lir.Modules;

--  Lower a frontend AST module into a LIR module.

package Lovelace.Compiler.Ir_Generator is

   --  Why Generate failed (expandable in later work).
   --  @enum Internal_Error Compiler bug such as Validate failing on frontend AST.
   type Ir_Generator_Error_Code is (Internal_Error);

   --  One IR Generator failure.
   --  @field Code Predefined error code.
   --  @field Detail UTF-8 message describing the failure.
   type Ir_Generator_Error is record
      Code   : Ir_Generator_Error_Code;
      Detail : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  LIR module on success, or an internal error on failure.
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

   --  Lower The_Module into LIR (names, flags, Unit return type, origins, empty bodies).
   --  @param The_Module Frontend compilation-unit AST.
   --  @return LIR module, or Internal_Error when Validate fails.
   function Generate (The_Module : Ast.Module) return Generate_Result;

end Lovelace.Compiler.Ir_Generator;
