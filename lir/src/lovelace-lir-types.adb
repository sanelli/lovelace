package body Lovelace.Lir.Types is

   procedure Append (Sequence : in out Value_Type_Sequence; The_Type : Value_Type) is
   begin
      Sequence.Items.Append (The_Type);
   end Append;

   function Element (Sequence : Value_Type_Sequence; Index : Positive) return Value_Type is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Sequence return Value_Type_Sequence is
   begin
      return (Items => Value_Type_Vectors.Empty_Vector);
   end Empty_Sequence;

   function From_Code (Code : Interfaces.Unsigned_8) return Value_Type_Options.Option is
   begin
      if Natural (Code) > Value_Type'Pos (Value_Type'Last) then
         return Value_Type_Options.None;
      end if;

      return Value_Type_Options.From_Value (Value_Type'Val (Natural (Code)));
   end From_Code;

   function Length (Sequence : Value_Type_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function To_Code (The_Type : Value_Type) return Interfaces.Unsigned_8 is
   begin
      return Interfaces.Unsigned_8 (Value_Type'Pos (The_Type));
   end To_Code;

end Lovelace.Lir.Types;
