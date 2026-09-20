package body Lovelace.Compiler.Backend is

   procedure Append (Sequence : in out Byte_Sequence; One_Byte : Interfaces.Unsigned_8) is
   begin
      Sequence.Items.Append (One_Byte);
   end Append;

   function Element (Sequence : Byte_Sequence; Index : Positive) return Interfaces.Unsigned_8 is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Bytes return Byte_Sequence is
   begin
      return (Items => Byte_Vectors.Empty_Vector);
   end Empty_Bytes;

   function Length (Sequence : Byte_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Make_Error (Code : Backend_Error_Code; Detail : String) return Backend_Error is
   begin
      return (Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail));
   end Make_Error;

end Lovelace.Compiler.Backend;
