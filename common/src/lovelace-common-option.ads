generic
   --  Payload stored when Present is True.
   type Element_Type is private;
   --  Optional value without null access.
package Lovelace.Common.Option is

   --  Optional Element_Type, selected by Present.
   --  @disc Present True when Value is stored; False when absent.
   --  @field Value Payload when Present is True.
   type Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Element_Type;

         when False =>
            null;
      end case;
   end record;

   --  Option with Present False (no Value).
   --  @return Absent option.
   function None return Option;

   --  Option with Present True and the given Value.
   --  @param Value Stored payload.
   --  @return Present option.
   function From_Value (Value : Element_Type) return Option;

end Lovelace.Common.Option;
