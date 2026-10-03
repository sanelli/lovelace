package body Lovelace.Compiler.Types is

   function Float_Type (The_Size : Float_Size) return Type_Expression is
   begin
      return (Kind => Float, The_Signedness => Signed, Integer_Bit_Size => Bits_32, Float_Bit_Size => The_Size);
   end Float_Type;

   function Integer_Type (The_Signedness : Signedness; The_Size : Integer_Size) return Type_Expression is
   begin
      return
        (Kind => Integer, The_Signedness => The_Signedness, Integer_Bit_Size => The_Size, Float_Bit_Size => Bits_32);
   end Integer_Type;

   function Unit_Type return Type_Expression is
   begin
      return (Kind => Unit, The_Signedness => Signed, Integer_Bit_Size => Bits_32, Float_Bit_Size => Bits_32);
   end Unit_Type;

end Lovelace.Compiler.Types;
