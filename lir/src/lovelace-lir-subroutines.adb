package body Lovelace.Lir.Subroutines is

   procedure Append_Instruction (The_Subroutine : in out Subroutine; Item : Instructions.Instruction) is
   begin
      Instructions.Append (The_Subroutine.Instruction_Body, Item);
   end Append_Instruction;

   function Create (The_Signature : Signature; Attributes : Subroutine_Attributes := 0) return Subroutine is
   begin
      return
        (The_Signature => The_Signature, Attributes => Attributes, Instruction_Body => Instructions.Empty_Sequence);
   end Create;

   function Get_Attributes (The_Subroutine : Subroutine) return Subroutine_Attributes is
   begin
      return The_Subroutine.Attributes;
   end Get_Attributes;

   function Get_Instructions (The_Subroutine : Subroutine) return Instructions.Instruction_Sequence is
   begin
      return The_Subroutine.Instruction_Body;
   end Get_Instructions;

   function Get_Signature (The_Subroutine : Subroutine) return Signature is
   begin
      return The_Subroutine.The_Signature;
   end Get_Signature;

   function Has_Entrypoint (Attributes : Subroutine_Attributes) return Boolean is
   begin
      return (Attributes and Entrypoint_Attribute) /= 0;
   end Has_Entrypoint;

   function Has_Export (Attributes : Subroutine_Attributes) return Boolean is
   begin
      return (Attributes and Export_Attribute) /= 0;
   end Has_Export;

end Lovelace.Lir.Subroutines;
