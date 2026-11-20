with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Interfaces;

--  Compiler backends: shared error types and emit result shapes for WASM / WAT / WIT.

package Lovelace.Compiler.Backend is

   --  Why a backend emit failed.
   --  @enum Internal_Error Compiler bug or impossible state during emit.
   --  @enum Unsupported_Type LIR signature uses a type this slice cannot lower.
   --  @enum Invalid_Module LIR Modules.Validate failed before emit.
   type Backend_Error_Code is (Internal_Error, Unsupported_Type, Invalid_Module);

   --  One backend failure.
   --  @field Code Predefined error code.
   --  @field Detail UTF-8 message describing the failure.
   type Backend_Error is record
      Code   : Backend_Error_Code;
      Detail : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Ordered sequence of bytes for a .wasm component binary.
   type Byte_Sequence is private;

   --  Empty byte sequence.
   --  @return Sequence with no elements.
   function Empty_Bytes return Byte_Sequence;

   --  Append One_Byte to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param One_Byte Byte to append.
   procedure Append (Sequence : in out Byte_Sequence; One_Byte : Interfaces.Unsigned_8);

   --  Number of bytes in Sequence.
   --  @param Sequence Byte list.
   --  @return Element count.
   function Length (Sequence : Byte_Sequence) return Natural;

   --  Byte at Index (1 .. Length (Sequence)).
   --  @param Sequence Byte list.
   --  @param Index 1-based index.
   --  @return Byte at Index.
   function Element (Sequence : Byte_Sequence; Index : Positive) return Interfaces.Unsigned_8;

   --  Append Source onto the end of Destination.
   --  @param Destination Sequence to extend.
   --  @param Source Bytes to append.
   procedure Append_Bytes (Destination : in out Byte_Sequence; Source : Byte_Sequence);

   --  Build a Backend_Error with Code and Detail.
   --  @param Code Predefined error code.
   --  @param Detail UTF-8 detail message.
   --  @return Filled error record.
   function Make_Error (Code : Backend_Error_Code; Detail : String) return Backend_Error;

   --  Component .wasm bytes and companion .wit text, or a backend error.
   --  @disc Ok True when Wasm_Bytes and Wit_Text are present; False when Error is.
   --  @field Wasm_Bytes Encoded component binary when Ok is True.
   --  @field Wit_Text Companion WIT source when Ok is True.
   --  @field Error Failure detail when Ok is False.
   type Wasm_Emit_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Wasm_Bytes : Byte_Sequence;
            Wit_Text   : Ada.Strings.Unbounded.Unbounded_String;

         when False =>
            Error : Backend_Error;
      end case;
   end record;

   --  Component .wat text and companion .wit text, or a backend error.
   --  @disc Ok True when Wat_Text and Wit_Text are present; False when Error is.
   --  @field Wat_Text Encoded component WAT when Ok is True.
   --  @field Wit_Text Companion WIT source when Ok is True.
   --  @field Error Failure detail when Ok is False.
   type Wat_Emit_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Wat_Text : Ada.Strings.Unbounded.Unbounded_String;
            Wit_Text : Ada.Strings.Unbounded.Unbounded_String;

         when False =>
            Error : Backend_Error;
      end case;
   end record;

private

   use type Interfaces.Unsigned_8;

   package Byte_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Interfaces.Unsigned_8);

   type Byte_Sequence is record
      Items : Byte_Vectors.Vector;
   end record;

end Lovelace.Compiler.Backend;
