package body Lovelace.Lir.Subroutines is

   procedure Append_Instruction (The_Subroutine : in out Subroutine; Item : Instructions.Instruction) is
   begin
      Instructions.Append (The_Subroutine.Instruction_Body, Item);
   end Append_Instruction;

   function Create (The_Signature : Signature; Flags : Subroutine_Flags := 0) return Subroutine is
   begin
      return
        (The_Signature    => The_Signature,
         Flags            => Flags,
         Origin_Value     => (Present => False),
         Instruction_Body => Instructions.Empty_Sequence);
   end Create;

   function Get_Flags (The_Subroutine : Subroutine) return Subroutine_Flags is
   begin
      return The_Subroutine.Flags;
   end Get_Flags;

   function Get_Instructions (The_Subroutine : Subroutine) return Instructions.Instruction_Sequence is
   begin
      return The_Subroutine.Instruction_Body;
   end Get_Instructions;

   function Get_Signature (The_Subroutine : Subroutine) return Signature is
   begin
      return The_Subroutine.The_Signature;
   end Get_Signature;

   function Has_Entrypoint (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Entrypoint_Flag) /= 0;
   end Has_Entrypoint;

   function Has_Export (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Export_Flag) /= 0;
   end Has_Export;

   function Origin (The_Subroutine : Subroutine) return Origin_Option is
   begin
      return The_Subroutine.Origin_Value;
   end Origin;

   procedure Set_Origin (The_Subroutine : in out Subroutine; The_Origin : Subroutine_Origin) is
   begin
      The_Subroutine.Origin_Value := (Present => True, Value => The_Origin);
   end Set_Origin;

end Lovelace.Lir.Subroutines;
