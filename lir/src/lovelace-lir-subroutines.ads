with Ada.Strings.Unbounded;

with Lovelace.Lir.Instructions;
with Lovelace.Lir.Types;

--  LIR subroutines: signature, attributes, and instruction body.

package Lovelace.Lir.Subroutines is

   --  Attribute bitset for a subroutine (not string tags).
   type Subroutine_Attributes is mod 2**32;

   --  Bit 0: subroutine is exported from the module.
   Export_Attribute : constant Subroutine_Attributes := 2**0;

   --  Bit 1: subroutine is the module entrypoint.
   Entrypoint_Attribute : constant Subroutine_Attributes := 2**1;

   --  Name, optional return type, and parameter types.
   --  @field Name UTF-8 subroutine name.
   --  @field Return_Type Present when the subroutine returns a value.
   --  @field Parameter_Types Ordered parameter types (unnamed).
   type Signature is record
      Name            : Ada.Strings.Unbounded.Unbounded_String;
      Return_Type     : Types.Return_Type_Options.Option;
      Parameter_Types : Types.Value_Type_Sequence;
   end record;

   --  One subroutine with signature, attributes, and body.
   type Subroutine is private;

   --  Build a subroutine with an empty instruction body.
   --  @param The_Signature Name and types for the subroutine.
   --  @param Attributes Attribute flags (export, entrypoint, and others).
   --  @return Subroutine with no instructions.
   function Create (The_Signature : Signature; Attributes : Subroutine_Attributes := 0) return Subroutine;

   --  Append Item to the instruction body of The_Subroutine.
   --  @param The_Subroutine Subroutine to extend.
   --  @param Item Instruction to append.
   procedure Append_Instruction (The_Subroutine : in out Subroutine; Item : Instructions.Instruction);

   --  Signature of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Signature record.
   function Get_Signature (The_Subroutine : Subroutine) return Signature;

   --  Attribute flags of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Attribute bitset.
   function Get_Attributes (The_Subroutine : Subroutine) return Subroutine_Attributes;

   --  Instruction body of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Instruction sequence.
   function Get_Instructions (The_Subroutine : Subroutine) return Instructions.Instruction_Sequence;

   --  True when Attributes includes Export_Attribute.
   --  @param Attributes Attribute bitset.
   --  @return True iff export bit is set.
   function Has_Export (Attributes : Subroutine_Attributes) return Boolean;

   --  True when Attributes includes Entrypoint_Attribute.
   --  @param Attributes Attribute bitset.
   --  @return True iff entrypoint bit is set.
   function Has_Entrypoint (Attributes : Subroutine_Attributes) return Boolean;

private

   type Subroutine is record
      The_Signature    : Signature;
      Attributes       : Subroutine_Attributes := 0;
      Instruction_Body : Instructions.Instruction_Sequence;
   end record;

end Lovelace.Lir.Subroutines;
