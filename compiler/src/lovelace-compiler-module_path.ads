with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

--  Map dotted Lovelace module names to .love paths under include / Augusta roots.

package Lovelace.Compiler.Module_Path is

   package Path_Vectors is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => String);

   --  Ordered list of UTF-8 filesystem paths (search roots or candidate relatives).
   subtype Path_Sequence is Path_Vectors.Vector;

   --  Outcome of resolving a module name against search roots.
   --  @enum Unique Exactly one distinct existing file matched.
   --  @enum Not_Found No candidate file exists.
   --  @enum Ambiguous Two or more distinct existing files matched.
   type Resolve_Status is (Unique, Not_Found, Ambiguous);

   --  Result of Resolve_Module_File.
   --  @disc Status Selects which path fields are meaningful.
   --  @field Path Absolute or normalized path when Status is Unique.
   --  @field Matches Distinct existing paths when Status is Ambiguous.
   type Resolve_Result (Status : Resolve_Status := Not_Found) is record
      case Status is
         when Unique =>
            Path : Ada.Strings.Unbounded.Unbounded_String;

         when Ambiguous =>
            Matches : Path_Sequence;

         when Not_Found =>
            null;
      end case;
   end record;

   --  All mixed slash/dot relative candidates for a dotted module name, each ending in .love.
   --  Enumeration is stable: separators from left to right as bits of a mask (0 = '/', 1 = '.'),
   --  counting masks from 0 upward (so a.b.c â a/b/c, a/b.c, a.b/c, a.b.c).
   --  @param Name UTF-8 dotted module name (empty â empty sequence).
   --  @return Candidate relatives under a search root.
   function Module_To_Relative_Candidates (Name : String) return Path_Sequence;

   --  Resolve Name under Roots by collecting distinct existing candidate files.
   --  @param Name UTF-8 dotted module name.
   --  @param Roots Ordered search roots (directories).
   --  @return Unique path, not-found, or ambiguous with the colliding paths.
   function Resolve_Module_File
     (Name : String; Roots : Path_Sequence) return Resolve_Result;

   --  Mutually exclusive Augusta stdlib root: AUGUSTA_HOME, else LOVELACE_HOME/lib/augusta,
   --  else ~/.lovelace/lib/augusta. Empty string when the chosen slot cannot be formed.
   --  @return Chosen Augusta root path (may not exist on disk).
   function Augusta_Root return String;

   --  Build the default ordered search-root list for a compilation.
   --  Order: directory of Root_Source_Path, cwd, each Include_Path, then Augusta_Root when
   --  that directory exists. Duplicate roots (same Full_Name) are omitted.
   --  @param Root_Source_Path Path of the root .love file.
   --  @param Include_Paths Extra roots from -I / --include-path (CLI order).
   --  @return Ordered search roots.
   function Default_Search_Roots
     (Root_Source_Path : String; Include_Paths : Path_Sequence)
      return Path_Sequence;

   --  Join Root and a possibly nested Relative path (Relative may contain '/').
   --  @param Root Directory path.
   --  @param Relative Relative file path using '/'.
   --  @return Combined path string.
   function Join_Root (Root : String; Relative : String) return String;

end Lovelace.Compiler.Module_Path;
