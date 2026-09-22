with Lovelace.Compiler.Backend.Model;
with Lovelace.Lir.Modules;

--  Lower a LIR module into a Backend.Model component sketch.

package Lovelace.Compiler.Backend.Lowering is

   --  Component model on success, or a backend error on failure.
   --  @disc Ok True when The_Model is present; False when Error is present.
   --  @field The_Model Lowered component model when Ok is True.
   --  @field Error Failure detail when Ok is False.
   type Lower_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            The_Model : Model.Component_Model;

         when False =>
            Error : Backend_Error;
      end case;
   end record;

   --  Validate The_Module and lower it to a component model (_start / run / exports).
   --  @param The_Module LIR module to lower.
   --  @return Component model, or Invalid_Module / Unsupported_Type / Internal_Error.
   function Lower (The_Module : Lovelace.Lir.Modules.Module) return Lower_Result;

end Lovelace.Compiler.Backend.Lowering;
