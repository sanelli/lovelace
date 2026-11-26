with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Hash;

package body Lovelace.Common.Source is

   package Text_Vectors is new Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => String);

   package Text_Maps is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Positive,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

   --  Global intern table. Protected for future parallel tokenize/parse.
   protected Pool is
      procedure Intern (Text : String; Id : out Positive);
      function Element (Id : Positive) return String;
      procedure Clear;
   private
      Texts   : Text_Vectors.Vector;
      By_Text : Text_Maps.Map;
   end Pool;

   protected body Pool is

      procedure Clear is
      begin
         Texts.Clear;
         By_Text.Clear;
      end Clear;

      function Element (Id : Positive) return String is
      begin
         if Id > Texts.Last_Index then
            raise Program_Error with "Shared_Filename id invalidated by Clear_Filename_Pool";
         end if;

         return Texts.Element (Id);
      end Element;

      procedure Intern (Text : String; Id : out Positive) is
         Position : constant Text_Maps.Cursor := By_Text.Find (Text);
      begin
         if Text_Maps.Has_Element (Position) then
            Id := Text_Maps.Element (Position);
            return;
         end if;

         Texts.Append (Text);
         Id := Texts.Last_Index;
         By_Text.Insert (Text, Id);
      end Intern;

   end Pool;

   function Absent_Filename return Filename_Option is
   begin
      return (Present => False);
   end Absent_Filename;

   procedure Clear_Filename_Pool is
   begin
      Pool.Clear;
   end Clear_Filename_Pool;

   function From_Utf_8 (Filename : String) return Shared_Filename is
      Id : Positive;
   begin
      Pool.Intern (Filename, Id);
      return (Id => Id);
   end From_Utf_8;

   function Same_Storage (Left, Right : Filename_Option) return Boolean is
   begin
      if Left.Present /= Right.Present then
         return False;
      end if;

      case Left.Present is
         when False =>
            return True;

         when True  =>
            return Same_Storage (Left.Value, Right.Value);
      end case;
   end Same_Storage;

   function Same_Storage (Left, Right : Shared_Filename) return Boolean is
   begin
      return Left.Id = Right.Id;
   end Same_Storage;

   function Some_Filename (Holder : Shared_Filename) return Filename_Option is
   begin
      return (Present => True, Value => Holder);
   end Some_Filename;

   function To_Utf_8 (Holder : Shared_Filename) return String is
   begin
      return Pool.Element (Holder.Id);
   end To_Utf_8;

   function To_Utf_8 (Option : Filename_Option) return String is
   begin
      case Option.Present is
         when False =>
            return "";

         when True  =>
            return To_Utf_8 (Option.Value);
      end case;
   end To_Utf_8;

end Lovelace.Common.Source;
