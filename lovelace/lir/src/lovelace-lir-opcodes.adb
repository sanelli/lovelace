package body Lovelace.Lir.Opcodes is

   use type Interfaces.Unsigned_16;

   function Encoded_Length (Operation : Opcode) return Natural is
   begin
      return 2 + Immediate_Length (Operation);
   end Encoded_Length;

   function From_Word (Word : Interfaces.Unsigned_16) return Opcode_Options.Option is
   begin
      for Candidate in Opcode loop
         if To_Word (Candidate) = Word then
            return Opcode_Options.From_Value (Candidate);
         end if;
      end loop;

      return Opcode_Options.None;
   end From_Word;

   function Immediate_Length (Operation : Opcode) return Natural is
   begin
      case Operation is
         when No_Operation        =>
            return 0;

         when Constant_I32 | Call =>
            return 4;
      end case;
   end Immediate_Length;

   function To_Word (Operation : Opcode) return Interfaces.Unsigned_16 is
   begin
      return Interfaces.Unsigned_16 (Opcode'Enum_Rep (Operation));
   end To_Word;

end Lovelace.Lir.Opcodes;
