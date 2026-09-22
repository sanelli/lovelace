with Interfaces;

--  LEB128 encoders for WASM / component binary emission.

package Lovelace.Compiler.Backend.Leb128 is

   --  Append unsigned LEB128 encoding of Value to Sequence.
   --  @param Sequence Byte buffer to extend.
   --  @param Value Unsigned value to encode.
   procedure Append_Unsigned (Sequence : in out Byte_Sequence; Value : Interfaces.Unsigned_32);

   --  Append signed LEB128 encoding of Value to Sequence.
   --  @param Sequence Byte buffer to extend.
   --  @param Value Signed value to encode.
   procedure Append_Signed (Sequence : in out Byte_Sequence; Value : Interfaces.Integer_32);

end Lovelace.Compiler.Backend.Leb128;
