package body Lovelace.Lir.Instructions is

   procedure Append (Sequence : in out Instruction_Sequence; Item : Instruction) is
   begin
      Sequence.Items.Append (Item);
   end Append;

   function Element (Sequence : Instruction_Sequence; Index : Positive) return Instruction is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Sequence return Instruction_Sequence is
   begin
      return (Items => Instruction_Vectors.Empty_Vector);
   end Empty_Sequence;

   function Length (Sequence : Instruction_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

end Lovelace.Lir.Instructions;
