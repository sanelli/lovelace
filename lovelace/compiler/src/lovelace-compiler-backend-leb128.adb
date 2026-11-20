with Ada.Unchecked_Conversion;

package body Lovelace.Compiler.Backend.Leb128 is

   function To_Unsigned_32 is new
     Ada.Unchecked_Conversion (Source => Interfaces.Integer_32, Target => Interfaces.Unsigned_32);

   procedure Append_Signed (Sequence : in out Byte_Sequence; Value : Interfaces.Integer_32) is
      use type Interfaces.Unsigned_32;

      Remaining : Interfaces.Unsigned_32 := To_Unsigned_32 (Value);
      Byte      : Interfaces.Unsigned_8;
      More      : Boolean;
   begin
      loop
         Byte := Interfaces.Unsigned_8 (Remaining and 16#7F#);
         Remaining := Interfaces.Shift_Right_Arithmetic (Remaining, 7);

         if (Remaining = 0 and then (Byte and 16#40#) = 0)
           or else (Remaining = Interfaces.Unsigned_32'Last and then (Byte and 16#40#) /= 0)
         then
            More := False;
         else
            More := True;
            Byte := Byte or 16#80#;
         end if;

         Append (Sequence, Byte);
         exit when not More;
      end loop;
   end Append_Signed;

   procedure Append_Unsigned (Sequence : in out Byte_Sequence; Value : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;

      Remaining : Interfaces.Unsigned_32 := Value;
      Byte      : Interfaces.Unsigned_8;
   begin
      loop
         Byte := Interfaces.Unsigned_8 (Remaining and 16#7F#);
         Remaining := Interfaces.Shift_Right (Remaining, 7);

         if Remaining /= 0 then
            Byte := Byte or 16#80#;
         end if;

         Append (Sequence, Byte);
         exit when Remaining = 0;
      end loop;
   end Append_Unsigned;

end Lovelace.Compiler.Backend.Leb128;
