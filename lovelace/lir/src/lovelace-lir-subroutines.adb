package body Lovelace.Lir.Subroutines is

   procedure Append_Instruction (The_Subroutine : in out Subroutine; Item : Instructions.Instruction) is
   begin
      Instructions.Append (The_Subroutine.Instruction_Body, Item);
   end Append_Instruction;

   procedure Append_Local
     (The_Subroutine : in out Subroutine; Name : String; The_Type : Types.Value_Type)
   is
   begin
      Types.Append (The_Subroutine.Locals, Name, The_Type);
   end Append_Local;

   function Create (The_Signature : Signature; Flags : Subroutine_Flags := 0) return Subroutine is
   begin
      return
        (The_Signature    => The_Signature,
         Locals           => Types.Empty_Sequence,
         Flags            => Flags,
         Origin_Value     => (Present => False),
         Native_Value     => (Present => False),
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

   function Get_Locals (The_Subroutine : Subroutine) return Types.Parameter_Sequence is
   begin
      return The_Subroutine.Locals;
   end Get_Locals;

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

   function Has_Intrinsic (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Intrinsic_Flag) /= 0;
   end Has_Intrinsic;

   function Has_Native (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Native_Flag) /= 0;
   end Has_Native;

   function Native (The_Subroutine : Subroutine) return Native_Binding_Option is
   begin
      return The_Subroutine.Native_Value;
   end Native;

   function Origin (The_Subroutine : Subroutine) return Origin_Option is
   begin
      return The_Subroutine.Origin_Value;
   end Origin;

   procedure Set_Intrinsic (The_Subroutine : in out Subroutine) is
   begin
      The_Subroutine.Flags :=
        (The_Subroutine.Flags or Intrinsic_Flag) and not Native_Flag;
      The_Subroutine.Native_Value := (Present => False);
   end Set_Intrinsic;

   procedure Set_Native_Binding
     (The_Subroutine : in out Subroutine; Library : String; Function_Name : String)
   is
   begin
      The_Subroutine.Flags :=
        (The_Subroutine.Flags or Native_Flag) and not Intrinsic_Flag;
      The_Subroutine.Native_Value :=
        (Present => True,
         Value   =>
           (Library       => Ada.Strings.Unbounded.To_Unbounded_String (Library),
            Function_Name => Ada.Strings.Unbounded.To_Unbounded_String (Function_Name)));
   end Set_Native_Binding;

   procedure Set_Origin (The_Subroutine : in out Subroutine; The_Origin : Subroutine_Origin) is
   begin
      The_Subroutine.Origin_Value := (Present => True, Value => The_Origin);
   end Set_Origin;

end Lovelace.Lir.Subroutines;
