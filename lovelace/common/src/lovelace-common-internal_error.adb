package body Lovelace.Common.Internal_Error is

   function Unbounded_Text
     (Source : Ada.Strings.Unbounded.Unbounded_String) return String
     renames Ada.Strings.Unbounded.To_String;
   function To_Unbounded
     (Source : String) return Ada.Strings.Unbounded.Unbounded_String
     renames Ada.Strings.Unbounded.To_Unbounded_String;

   function Detail (Item : Lovelace_Internal_Error) return String is
   begin
      return Unbounded_Text (Item.Message);
   end Detail;

   function Make (Group : Error_Group; Message : String) return Lovelace_Internal_Error is
   begin
      return (Group => Group, Message => To_Unbounded (Message));
   end Make;

   function Report (Item : Lovelace_Internal_Error) return String is
   begin
      return "internal error: " & Detail (Item);
   end Report;

end Lovelace.Common.Internal_Error;
