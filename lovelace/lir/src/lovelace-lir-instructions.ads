with Ada.Containers.Indefinite_Vectors;
with Interfaces;

with Lovelace.Lir.Opcodes;

--  LIR instructions and ordered instruction sequences.

package Lovelace.Lir.Instructions is

   --  One instruction selected by Operation.
   --  @disc Operation Opcode that selects the instruction variant.
   --  @field Immediate_I32 Signed 32-bit constant for Constant_I32.
   --  @field Target_Index 1-based subroutine index for Call.
   --  @field Local_Index 1-based local slot for Local_Get / Local_Set (params then flattened locals).
   type Instruction (Operation : Opcodes.Opcode := Opcodes.No_Operation) is record
      case Operation is
         when Opcodes.No_Operation =>
            null;

         when Opcodes.Constant_I32 =>
            Immediate_I32 : Interfaces.Integer_32 := 0;

         when Opcodes.Call =>
            Target_Index : Interfaces.Unsigned_32 := 0;

         when Opcodes.Local_Get | Opcodes.Local_Set =>
            Local_Index : Interfaces.Unsigned_32 := 0;
      end case;
   end record;

   --  Ordered list of instructions in a subroutine body.
   type Instruction_Sequence is private;

   --  Empty instruction sequence.
   --  @return Sequence with no elements.
   function Empty_Sequence return Instruction_Sequence;

   --  Append Item to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param Item Instruction to append.
   procedure Append (Sequence : in out Instruction_Sequence; Item : Instruction);

   --  Number of instructions in Sequence.
   --  @param Sequence Instruction list.
   --  @return Element count.
   function Length (Sequence : Instruction_Sequence) return Natural;

   --  Instruction at Index (1 .. Length (Sequence)).
   --  @param Sequence Instruction list.
   --  @param Index 1-based index.
   --  @return Instruction at Index.
   function Element (Sequence : Instruction_Sequence; Index : Positive) return Instruction;

private

   package Instruction_Vectors is new
     Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => Instruction);

   type Instruction_Sequence is record
      Items : Instruction_Vectors.Vector;
   end record;

end Lovelace.Lir.Instructions;
