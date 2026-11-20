package body Lovelace.Lir.Types is

   procedure Append (Sequence : in out Parameter_Sequence; Name : String; The_Type : Value_Type) is
      The_Parameter : constant Parameter :=
        (Name => Ada.Strings.Unbounded.To_Unbounded_String (Name), The_Type => The_Type);
   begin
      Sequence.Items.Append (The_Parameter);
   end Append;

   function Element (Sequence : Parameter_Sequence; Index : Positive) return Parameter is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Sequence return Parameter_Sequence is
   begin
      return (Items => Parameter_Vectors.Empty_Vector);
   end Empty_Sequence;

   function From_Code (Code : Interfaces.Unsigned_8) return Value_Type_Options.Option is
   begin
      if Natural (Code) > Value_Type'Pos (Value_Type'Last) then
         return Value_Type_Options.None;
      end if;

      return Value_Type_Options.From_Value (Value_Type'Val (Natural (Code)));
   end From_Code;

   function Length (Sequence : Parameter_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function To_Code (The_Type : Value_Type) return Interfaces.Unsigned_8 is
   begin
      return Interfaces.Unsigned_8 (Value_Type'Pos (The_Type));
   end To_Code;

end Lovelace.Lir.Types;
