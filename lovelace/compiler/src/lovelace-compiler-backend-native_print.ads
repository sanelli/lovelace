with Lovelace.Compiler.Backend.Model;

--  Synthesize the Print_Integer_Stdout intrinsic core body (decimal + stdout write).

package Lovelace.Compiler.Backend.Native_Print is

   --  Build locals + instructions for `@intrinsic` `augusta.std.io.print(integer)`.
   --  Param 0 is the i32 value. Uses Model Wasi stdout import slots and a fixed
   --  scratch buffer in guest linear memory.
   --  @param Locals Local types after the single i32 parameter.
   --  @param Instructions Synthesized core body (no trailing function end).
   procedure Synthesize (Locals : out Model.Core_Local_Sequence; Instructions : out Model.Instruction_Sequence);

end Lovelace.Compiler.Backend.Native_Print;
