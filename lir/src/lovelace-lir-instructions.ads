with Ada.Containers.Indefinite_Vectors;

with Lovelace.Lir.Opcodes;

--  LIR instructions and ordered instruction sequences.

package Lovelace.Lir.Instructions is

   --  One instruction selected by Operation.
   --  @disc Operation Opcode that selects the instruction variant.
   type Instruction (Operation : Opcodes.Opcode := Opcodes.No_Operation) is record
      case Operation is
         when Opcodes.No_Operation =>
            null;
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
