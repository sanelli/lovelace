package body Lovelace.Common.Source is

   use type Ada.Strings.Unbounded.Unbounded_String;

   function Absent_Filename return Filename_Option is
   begin
      return (Present => False);
   end Absent_Filename;

   function From_Utf_8 (Filename : String) return Shared_Filename is
   begin
      return (Text => Ada.Strings.Unbounded.To_Unbounded_String (Filename));
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
      return Left.Text = Right.Text;
   end Same_Storage;

   function Some_Filename (Holder : Shared_Filename) return Filename_Option is
   begin
      return (Present => True, Value => Holder);
   end Some_Filename;

   function To_Utf_8 (Holder : Shared_Filename) return String is
   begin
      return Ada.Strings.Unbounded.To_String (Holder.Text);
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
