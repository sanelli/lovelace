with Lovelace.Lir.Modules;

--  Emit component WAT text and companion WIT from a LIR module.

package Lovelace.Compiler.Backend.Wat is

   --  Lower The_Module and emit component WAT plus companion WIT.
   --  @param The_Module LIR module to emit.
   --  @return Wat_Text and Wit_Text, or a Backend_Error.
   function Emit_Wat (The_Module : Lovelace.Lir.Modules.Module) return Wat_Emit_Result;

end Lovelace.Compiler.Backend.Wat;
