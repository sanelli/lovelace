with Ada.Strings.Unbounded;

with Lovelace.Lir.Instructions;
with Lovelace.Lir.Types;

--  LIR subroutines: signature, flags, and instruction body.

package Lovelace.Lir.Subroutines is

   --  Flag bitset for a subroutine (not string tags).
   type Subroutine_Flags is mod 2**32;

   --  Bit 0: subroutine is exported from the module.
   Export_Flag : constant Subroutine_Flags := 2**0;

   --  Bit 1: subroutine is the module entrypoint.
   Entrypoint_Flag : constant Subroutine_Flags := 2**1;

   --  Name, return type, and parameter types.
   --  @field Name UTF-8 subroutine name.
   --  @field Return_Type Result type; Unit means a procedure (no stack
   --  result) for the Lovelace backend.
   --  @field Parameter_Types Ordered parameter types (unnamed).
   type Signature is record
      Name            : Ada.Strings.Unbounded.Unbounded_String;
      Return_Type     : Types.Value_Type;
      Parameter_Types : Types.Value_Type_Sequence;
   end record;

   --  One subroutine with signature, flags, and body.
   type Subroutine is private;

   --  Build a subroutine with an empty instruction body.
   --  @param The_Signature Name and types for the subroutine.
   --  @param Flags Flag bits (export, entrypoint, and others).
   --  @return Subroutine with no instructions.
   function Create (The_Signature : Signature; Flags : Subroutine_Flags := 0) return Subroutine;

   --  Append Item to the instruction body of The_Subroutine.
   --  @param The_Subroutine Subroutine to extend.
   --  @param Item Instruction to append.
   procedure Append_Instruction (The_Subroutine : in out Subroutine; Item : Instructions.Instruction);

   --  Signature of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Signature record.
   function Get_Signature (The_Subroutine : Subroutine) return Signature;

   --  Flag bits of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Flag bitset.
   function Get_Flags (The_Subroutine : Subroutine) return Subroutine_Flags;

   --  Instruction body of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Instruction sequence.
   function Get_Instructions (The_Subroutine : Subroutine) return Instructions.Instruction_Sequence;

   --  True when Flags includes Export_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff export bit is set.
   function Has_Export (Flags : Subroutine_Flags) return Boolean;

   --  True when Flags includes Entrypoint_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff entrypoint bit is set.
   function Has_Entrypoint (Flags : Subroutine_Flags) return Boolean;

private

   type Subroutine is record
      The_Signature    : Signature;
      Flags            : Subroutine_Flags := 0;
      Instruction_Body : Instructions.Instruction_Sequence;
   end record;

end Lovelace.Lir.Subroutines;
