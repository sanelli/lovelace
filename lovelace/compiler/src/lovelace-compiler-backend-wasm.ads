with Lovelace.Lir.Modules;

--  Emit component WASM binary and companion WIT from a LIR module.

package Lovelace.Compiler.Backend.Wasm is

   --  Lower The_Module and emit component .wasm bytes plus companion WIT.
   --  @param The_Module LIR module to emit.
   --  @return Wasm_Bytes and Wit_Text, or a Backend_Error.
   function Emit_Wasm (The_Module : Lovelace.Lir.Modules.Module) return Wasm_Emit_Result;

end Lovelace.Compiler.Backend.Wasm;
