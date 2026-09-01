package body Lovelace.Common.Internal_Error is

   function Detail
     (Item : Lovelace_Internal_Error) return String
   is
   begin
      return Ada.Strings.Unbounded.To_String (Item.Message);
   end Detail;

   function Make
     (Group   : Error_Group;
      Message : String) return Lovelace_Internal_Error
   is
   begin
      return
        (Group   => Group,
         Message =>
           Ada.Strings.Unbounded.To_Unbounded_String (Message));
   end Make;

   function Report
     (Item : Lovelace_Internal_Error) return String
   is
   begin
      return "internal error: " & Detail (Item);
   end Report;

end Lovelace.Common.Internal_Error;
