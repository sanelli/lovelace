with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Types;

--  LIR subroutines: signature, flags, instruction body, and optional origin.

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

   --  In-memory source origin for a subroutine (also stored in .lir / .tlir v1.0 layouts).
   --  @field Name_Span Span of the subroutine name in the original source.
   --  @field Filename Optional shared filename from the frontend.
   type Subroutine_Origin is record
      Name_Span : Lovelace.Common.Source.Source_Span;
      Filename  : Lovelace.Common.Source.Filename_Option;
   end record;

   --  Optional Subroutine_Origin (same shape as Lovelace.Common.Option).
   --  @disc Present True when Value is stored; False when absent.
   --  @field Value Origin metadata when Present is True.
   type Origin_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Subroutine_Origin;

         when False =>
            null;
      end case;
   end record;

   --  One subroutine with signature, flags, and body.
   type Subroutine is private;

   --  Build a subroutine with an empty instruction body and no origin.
   --  @param The_Signature Name and types for the subroutine.
   --  @param Flags Flag bits (export, entrypoint, and others).
   --  @return Subroutine with no instructions and absent origin.
   function Create (The_Signature : Signature; Flags : Subroutine_Flags := 0) return Subroutine;

   --  Attach The_Origin to The_Subroutine (replaces any previous origin).
   --  @param The_Subroutine Subroutine to update.
   --  @param The_Origin Source location metadata.
   procedure Set_Origin (The_Subroutine : in out Subroutine; The_Origin : Subroutine_Origin);

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

   --  Optional source origin of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Present origin, or absent when Create left it unset / codecs decode.
   function Origin (The_Subroutine : Subroutine) return Origin_Option;

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
      Origin_Value     : Origin_Option := (Present => False);
      Instruction_Body : Instructions.Instruction_Sequence;
   end record;

end Lovelace.Lir.Subroutines;
