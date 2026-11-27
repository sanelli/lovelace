with Interfaces;

with Lovelace.Common.Option;

--  Lovelace 16-bit LIR opcodes (not WASM opcode bytes).

package Lovelace.Lir.Opcodes is

   --  LIR opcode.
   --  @enum No_Operation Instruction that does nothing.
   --  @enum Constant_I32 Push a signed 32-bit integer constant.
   --  @enum Call Call a subroutine by 1-based index in this module.
   --  @enum Local_Get Push the value of a 1-based local (params first, then flattened locals).
   --  @enum Local_Set Pop and store into a 1-based local (params first, then flattened locals).
   type Opcode is (No_Operation, Constant_I32, Call, Local_Get, Local_Set);
   for Opcode use (No_Operation => 0, Constant_I32 => 1, Call => 2, Local_Get => 3, Local_Set => 4);
   for Opcode'Size use 16;

   --  Optional Opcode when decoding a raw word.
   package Opcode_Options is new Lovelace.Common.Option (Element_Type => Opcode);

   --  Little-endian stream word for Operation.
   --  @param Operation Opcode to encode.
   --  @return Unsigned_16 representation.
   function To_Word (Operation : Opcode) return Interfaces.Unsigned_16;

   --  Opcode for Word, or absent when Word is not a known opcode.
   --  @param Word Encoded opcode word from the stream.
   --  @return Present option with the opcode, or None.
   function From_Word (Word : Interfaces.Unsigned_16) return Opcode_Options.Option;

   --  Number of immediate bytes after the opcode word.
   --  @param Operation Opcode whose immediates are counted.
   --  @return Immediate byte count.
   function Immediate_Length (Operation : Opcode) return Natural;

   --  Total encoded size in the stream: 2 plus Immediate_Length.
   --  @param Operation Opcode whose encoded size is required.
   --  @return Byte length in the instruction stream.
   function Encoded_Length (Operation : Opcode) return Natural;

end Lovelace.Lir.Opcodes;
