with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Flavor;
with Lovelace.Compiler.Module_Path;
with Lovelace.Compiler.Versioning;

--  Load a root compilation unit plus its transitive import closure.

package Lovelace.Compiler.Unit_Graph is

   package Source renames Lovelace.Common.Source;

   --  Why Load failed (stage-local; map via Reporting / Surface_Error_Code).
   --  @enum Internal_Error Compiler bug or impossible state.
   --  @enum Unknown_Module Import name has no candidate .love file.
   --  @enum Ambiguous_Module_Path Two or more distinct .love files match one import.
   --  @enum Circular_Import Import cycle among units.
   --  @enum Not_A_Module Imported path parsed as a program unit.
   --  @enum Unit_Name_Mismatch Parsed unit name differs from the imported module name.
   --  @enum Source_File_Io Dependency .love missing or unreadable after resolve.
   --  @enum Frontend_Error Nested tokenizer/parser failure while loading a dependency.
   type Unit_Graph_Error_Code is
     (Internal_Error,
      Unknown_Module,
      Ambiguous_Module_Path,
      Circular_Import,
      Not_A_Module,
      Unit_Name_Mismatch,
      Source_File_Io,
      Frontend_Error);

   --  One Load failure.
   --  @field Code Stage-local reason.
   --  @field Span Source extent (usually the import name).
   --  @field Detail UTF-8 message.
   --  @field Filename Path used for diagnostics (importer or dependency).
   --  @field Source_Text UTF-8 buffer for caret formatting (importer or dependency).
   --  @field Frontend_Code LV code when Code is Frontend_Error.
   type Unit_Graph_Error is record
      Code          : Unit_Graph_Error_Code;
      Span          : Source.Source_Span;
      Detail        : Ada.Strings.Unbounded.Unbounded_String;
      Filename      : Ada.Strings.Unbounded.Unbounded_String;
      Source_Text   : Ada.Strings.Unbounded.Unbounded_String;
      Frontend_Code : Error_Codes.Error_Code := Error_Codes.Internal_Error;
   end record;

   --  One loaded compilation unit in the closure.
   --  @field The_Module Parsed AST.
   --  @field Source_Path Path of the .love file.
   --  @field Source_Text UTF-8 contents.
   --  @field Version Resolved module version (attribute, .loveversion, CLI, or default).
   type Loaded_Unit is record
      The_Module  : Ast.Module;
      Source_Path : Ada.Strings.Unbounded.Unbounded_String;
      Source_Text : Ada.Strings.Unbounded.Unbounded_String;
      Version     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Loaded_Unit_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Loaded_Unit);

   --  Ordered compilation set: root first, then dependencies in discovery order.
   subtype Compilation_Set is Loaded_Unit_Vectors.Vector;

   --  Load result: compilation set or a located error.
   --  @disc Ok True when Units is present.
   type Load_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Units : Compilation_Set;

         when False =>
            Error : Unit_Graph_Error;
      end case;
   end record;

   --  LV code to report for Error (Frontend_Error uses Frontend_Code).
   --  @param Error Load failure.
   --  @return Stable Error_Codes value.
   function Surface_Error_Code (Error : Unit_Graph_Error) return Error_Codes.Error_Code;

   --  Load Root_Module and its transitive imports under Search_Roots with Active_Flavor.
   --  @param Root_Module Already-parsed root AST.
   --  @param Root_Source_Path Path of the root .love file.
   --  @param Root_Source_Text UTF-8 contents of the root file.
   --  @param Search_Roots Module_Path search roots.
   --  @param Active_Flavor Flavor passed to Parse for every dependency.
   --  @param Cli_Version Optional --module-version fallback for every unit.
   --  @return Compilation set (root first) or a located error.
   function Load
     (Root_Module      : Ast.Module;
      Root_Source_Path : String;
      Root_Source_Text : String;
      Search_Roots     : Module_Path.Path_Sequence;
      Active_Flavor    : Flavor.Flavor;
      Cli_Version      : Versioning.Version_Option) return Load_Result;

end Lovelace.Compiler.Unit_Graph;
