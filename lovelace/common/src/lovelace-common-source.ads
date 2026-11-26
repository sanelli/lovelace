--  Source locations and optional filenames for host diagnostics and IR.
--  Filenames are interned in a global thread-safe pool as Positive indices
--  (gnatcov-safe; no controlled / Unbounded finalize on assign).

package Lovelace.Common.Source is

   --  One position in UTF-8 source (1-based byte index and line/column).
   --  @field Byte_Index First byte of this scalar in the source string.
   --  @field Line 1-based line number.
   --  @field Column 1-based column (Unicode scalars on the line; tab is one column).
   type Source_Position is record
      Byte_Index : Positive;
      Line       : Positive;
      Column     : Positive;
   end record;

   --  Inclusive span from first to last scalar in a source range.
   --  @field First Start position.
   --  @field Last End position.
   type Source_Span is record
      First : Source_Position;
      Last  : Source_Position;
   end record;

   --  Index into the global filename pool (interned UTF-8 path or label).
   type Shared_Filename is private;

   --  Optional Shared_Filename (same shape as Lovelace.Common.Option).
   --  @disc Present True when Value is stored; False when absent.
   type Filename_Option (Present : Boolean := False) is private;

   --  Absent filename when no path was supplied.
   --  @return Filename_Option with Present False.
   function Absent_Filename return Filename_Option;

   --  Intern Filename in the global pool (same text yields the same index).
   --  @param Filename UTF-8 path or label.
   --  @return Pool index for Filename.
   function From_Utf_8 (Filename : String) return Shared_Filename;

   --  Filename_Option wrapping one pool index.
   --  @param Holder Filename pool index.
   --  @return Present filename option.
   function Some_Filename (Holder : Shared_Filename) return Filename_Option;

   --  UTF-8 bytes for Holder from the global pool.
   --  @param Holder Filename pool index.
   --  @return Filename text.
   function To_Utf_8 (Holder : Shared_Filename) return String;

   --  UTF-8 bytes when Present, otherwise the empty string.
   --  @param Option Optional filename.
   --  @return Filename text, or "".
   function To_Utf_8 (Option : Filename_Option) return String;

   --  True when Left and Right are the same pool index.
   --  @param Left First holder.
   --  @param Right Second holder.
   --  @return True when both refer to one interned entry.
   function Same_Storage (Left, Right : Shared_Filename) return Boolean;

   --  True when Left and Right are both absent, or both present with Same_Storage.
   --  @param Left First optional filename.
   --  @param Right Second optional filename.
   --  @return True when both absent, or both present and Same_Storage on the holders.
   function Same_Storage (Left, Right : Filename_Option) return Boolean;

   --  Drop every interned filename. Invalidates existing Shared_Filename values.
   --  Called at the start and end of Lovelace.Main.Compile.Run (thread-safe).
   procedure Clear_Filename_Pool;

private

   --  @field Id 1-based index into the global pool.
   type Shared_Filename is record
      Id : Positive;
   end record;

   --  @field Value Filename when Present is True.
   type Filename_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Shared_Filename;

         when False =>
            null;
      end case;
   end record;

end Lovelace.Common.Source;
