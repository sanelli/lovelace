package body Lovelace.Common.Option is

   function From_Value (Value : Element_Type) return Option is
   begin
      return (Present => True, Value => Value);
   end From_Value;

   function None return Option is
   begin
      return (Present => False);
   end None;

end Lovelace.Common.Option;
