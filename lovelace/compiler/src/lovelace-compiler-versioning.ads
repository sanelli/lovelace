with Ada.Strings.Unbounded;

with Lovelace.Compiler.Module_Path;

--  Module version strings: validation, .loveversion, and priority resolution.

package Lovelace.Compiler.Versioning is

   --  Default module version when no attribute, .loveversion, or CLI value applies.
   Default_Version : constant String := "0.0.1";

   --  Filename looked up under a library search root.
   Loveversion_Filename : constant String := ".loveversion";

   --  Optional UTF-8 version string (source @version or CLI --module-version).
   type Version_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Ada.Strings.Unbounded.Unbounded_String;

         when False =>
            null;
      end case;
   end record;

   --  True when Text matches MAJOR.MINOR.BUILD[-preview-name[.preview-number]].
   --  Numeric components are non-negative integers without leading zeroes (0 allowed).
   --  Preview name is non-empty [A-Za-z0-9-]+; preview number is a non-negative
   --  integer without leading zeroes when present.
   --  @param Text Candidate version string.
   --  @return True iff Text is a valid Lovelace module version.
   function Is_Valid_Version (Text : String) return Boolean;

   --  Longest search root that is a path prefix of Source_Path (normalized).
   --  Empty when no root matches (caller should treat as no .loveversion root).
   --  @param Source_Path Absolute or relative path of a .love file.
   --  @param Roots Module search roots from Default_Search_Roots.
   --  @return Library root directory for .loveversion lookup.
   function Library_Root_For (Source_Path : String; Roots : Module_Path.Path_Sequence) return String;

   --  Read Loveversion_Filename under Library_Root when present.
   --  @param Library_Root Directory that may contain .loveversion.
   --  @param Version Set to the @version string when Ok and Present.
   --  @param Detail Failure detail when Ok is False.
   --  @return Ok True when absent or a valid @version was read; False on I/O or
   --  syntax/validation failure. Present True only when a file supplied a version.
   procedure Try_Read_Loveversion
     (Library_Root : String;
      Version      : out Version_Option;
      Ok           : out Boolean;
      Detail       : out Ada.Strings.Unbounded.Unbounded_String);

   --  Resolve a module version with priority: file @version, then .loveversion,
   --  then CLI --module-version, then Default_Version.
   --  @param File_Version Optional @version from the .love unit.
   --  @param Library_Root Root for .loveversion (may be empty).
   --  @param Cli_Version Optional --module-version from the CLI.
   --  @param Version Resolved version string when Ok.
   --  @param Ok False when .loveversion exists but is invalid.
   --  @param Detail Failure detail when Ok is False.
   procedure Resolve_Version
     (File_Version : Version_Option;
      Library_Root : String;
      Cli_Version  : Version_Option;
      Version      : out Ada.Strings.Unbounded.Unbounded_String;
      Ok           : out Boolean;
      Detail       : out Ada.Strings.Unbounded.Unbounded_String);

end Lovelace.Compiler.Versioning;
