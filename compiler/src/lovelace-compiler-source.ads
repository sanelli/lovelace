with Ada.Finalization;
with Ada.Strings.Unbounded;

private with Ada.Unchecked_Deallocation;

--  Source locations and optional shared filenames for compiler diagnostics.

package Lovelace.Compiler.Source is

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

   --  Refcounted immutable UTF-8 filename shared across compiler values.
   type Shared_Filename is new Ada.Finalization.Controlled with private;

   --  Optional Shared_Filename (same shape as Lovelace.Common.Option).
   --  @disc Present True when Value is stored; False when absent.
   type Filename_Option (Present : Boolean := False) is private;

   --  Absent filename when no path was supplied.
   --  @return Filename_Option with Present False.
   function Absent_Filename return Filename_Option;

   --  Allocate one immutable shared filename from UTF-8 bytes.
   --  @param Filename UTF-8 path or label.
   --  @return Holder referencing shared storage.
   function From_Utf_8 (Filename : String) return Shared_Filename;

   --  Filename_Option wrapping one shared holder.
   --  @param Holder Shared filename storage.
   --  @return Present filename option.
   function Some_Filename (Holder : Shared_Filename) return Filename_Option;

   --  True when Left and Right reference the same shared storage.
   --  @param Left First holder.
   --  @param Right Second holder.
   --  @return True when both reference one block.
   function Same_Storage (Left, Right : Shared_Filename) return Boolean;

private

   type Filename_Block is record
      Reference_Count : Natural;
      Text            : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Filename_Block_Access is access Filename_Block;

   procedure Free_Filename_Block is new Ada.Unchecked_Deallocation (Filename_Block, Filename_Block_Access);

   type Shared_Filename is new Ada.Finalization.Controlled with record
      Block : Filename_Block_Access;
   end record;

   overriding procedure Adjust (Object : in out Shared_Filename);
   overriding procedure Finalize (Object : in out Shared_Filename);

   --  @field Value Shared filename when Present is True.
   type Filename_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Shared_Filename;

         when False =>
            null;
      end case;
   end record;

end Lovelace.Compiler.Source;
