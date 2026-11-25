with Ada.Strings.Unbounded;

--  Source locations and optional filenames for host diagnostics and IR.
--  Filenames are immutable UTF-8 text (copied). Same_Storage compares text
--  equality - not used as a controlled/refcounted handle (gnatcov-safe).

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

   --  Immutable UTF-8 filename value (copied; safe under gnatcov).
   type Shared_Filename is private;

   --  Optional Shared_Filename (same shape as Lovelace.Common.Option).
   --  @disc Present True when Value is stored; False when absent.
   type Filename_Option (Present : Boolean := False) is private;

   --  Absent filename when no path was supplied.
   --  @return Filename_Option with Present False.
   function Absent_Filename return Filename_Option;

   --  Build an immutable filename from UTF-8 bytes.
   --  @param Filename UTF-8 path or label.
   --  @return Holder with a copy of Filename.
   function From_Utf_8 (Filename : String) return Shared_Filename;

   --  Filename_Option wrapping one filename value.
   --  @param Holder Filename storage.
   --  @return Present filename option.
   function Some_Filename (Holder : Shared_Filename) return Filename_Option;

   --  UTF-8 bytes stored in Holder.
   --  @param Holder Filename storage.
   --  @return Filename text.
   function To_Utf_8 (Holder : Shared_Filename) return String;

   --  UTF-8 bytes when Present, otherwise the empty string.
   --  @param Option Optional filename.
   --  @return Filename text, or "".
   function To_Utf_8 (Option : Filename_Option) return String;

   --  True when Left and Right hold the same UTF-8 filename text.
   --  @param Left First holder.
   --  @param Right Second holder.
   --  @return True when To_Utf_8 values are equal.
   function Same_Storage (Left, Right : Shared_Filename) return Boolean;

   --  True when Left and Right are both absent, or both present with equal text.
   --  @param Left First optional filename.
   --  @param Right Second optional filename.
   --  @return True when both absent, or both present and Same_Storage on the holders.
   function Same_Storage (Left, Right : Filename_Option) return Boolean;

private

   type Shared_Filename is record
      Text : Ada.Strings.Unbounded.Unbounded_String;
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
