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

   --  Bit 2: subroutine is an `@native("lib", "fn")` FFI binding (empty instruction body).
   Native_Flag : constant Subroutine_Flags := 2**2;

   --  Bit 3: subroutine is an `@intrinsic` (compiler-synthesized; empty instruction body).
   Intrinsic_Flag : constant Subroutine_Flags := 2**3;

   --  Shared-library FFI binding from `@native("library", "function")`.
   --  @field Library UTF-8 shared-library name.
   --  @field Function_Name UTF-8 native function name.
   type Native_Binding is record
      Library       : Ada.Strings.Unbounded.Unbounded_String;
      Function_Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Optional native binding on a subroutine.
   --  @disc Present True when Value is stored; False when absent.
   --  @field Value Binding when Present is True.
   type Native_Binding_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Native_Binding;

         when False =>
            null;
      end case;
   end record;

   --  Name, return type, and named parameters.
   --  @field Name UTF-8 subroutine name.
   --  @field Return_Type Result type; Unit means a procedure (no stack
   --  result) for the Lovelace backend.
   --  @field Parameters Ordered named parameters (name + type each).
   type Signature is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Return_Type : Types.Value_Type;
      Parameters  : Types.Parameter_Sequence;
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

   --  Store a native FFI binding and set Native_Flag (replaces any previous binding; clears Intrinsic_Flag).
   --  @param The_Subroutine Subroutine to update.
   --  @param Library UTF-8 shared-library name.
   --  @param Function_Name UTF-8 native function name.
   procedure Set_Native_Binding
     (The_Subroutine : in out Subroutine; Library : String; Function_Name : String);

   --  Mark The_Subroutine as `@intrinsic` (sets Intrinsic_Flag; clears Native_Flag and binding).
   --  @param The_Subroutine Subroutine to update.
   procedure Set_Intrinsic (The_Subroutine : in out Subroutine);

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

   --  Optional native binding of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Present binding, or absent when not native / Create left it unset.
   function Native (The_Subroutine : Subroutine) return Native_Binding_Option;

   --  True when Flags includes Export_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff export bit is set.
   function Has_Export (Flags : Subroutine_Flags) return Boolean;

   --  True when Flags includes Entrypoint_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff entrypoint bit is set.
   function Has_Entrypoint (Flags : Subroutine_Flags) return Boolean;

   --  True when Flags includes Intrinsic_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff intrinsic bit is set.
   function Has_Intrinsic (Flags : Subroutine_Flags) return Boolean;

   --  True when Flags includes Native_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff native bit is set.
   function Has_Native (Flags : Subroutine_Flags) return Boolean;

private

   type Subroutine is record
      The_Signature    : Signature;
      Flags            : Subroutine_Flags := 0;
      Origin_Value     : Origin_Option := (Present => False);
      Native_Value     : Native_Binding_Option := (Present => False);
      Instruction_Body : Instructions.Instruction_Sequence;
   end record;

end Lovelace.Lir.Subroutines;
