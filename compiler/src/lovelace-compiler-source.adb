package body Lovelace.Compiler.Source is

   function Absent_Filename return Filename_Option is
   begin
      return (Present => False);
   end Absent_Filename;

   overriding procedure Adjust (Object : in out Shared_Filename) is
   begin
      if Object.Block /= null then
         Object.Block.Reference_Count := Object.Block.Reference_Count + 1;
      end if;
   end Adjust;

   overriding procedure Finalize (Object : in out Shared_Filename) is
   begin
      if Object.Block = null then
         return;
      end if;

      if Object.Block.Reference_Count = 0 then
         return;
      end if;

      Object.Block.Reference_Count := Object.Block.Reference_Count - 1;

      if Object.Block.Reference_Count = 0 then
         Free_Filename_Block (Object.Block);
      end if;
   end Finalize;

   function From_Utf_8 (Filename : String) return Shared_Filename is
      Result : Shared_Filename;
   begin
      Result.Block :=
        new Filename_Block'
          (Reference_Count => 1,
           Text            => Ada.Strings.Unbounded.To_Unbounded_String (Filename));
      return Result;
   end From_Utf_8;

   function Same_Storage (Left, Right : Filename_Option) return Boolean is
   begin
      if Left.Present /= Right.Present then
         return False;
      end if;

      case Left.Present is
         when False =>
            return True;

         when True =>
            return Same_Storage (Left.Value, Right.Value);
      end case;
   end Same_Storage;

   function Same_Storage (Left, Right : Shared_Filename) return Boolean is
   begin
      if Left.Block = null or else Right.Block = null then
         return Left.Block = Right.Block;
      end if;

      return Left.Block = Right.Block;
   end Same_Storage;

   function Some_Filename (Holder : Shared_Filename) return Filename_Option is
   begin
      return (Present => True, Value => Holder);
   end Some_Filename;

end Lovelace.Compiler.Source;
