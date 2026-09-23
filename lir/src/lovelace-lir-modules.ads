with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Subroutines;

--  LIR modules: name, flags, dependencies, subroutines, and optional origin.

package Lovelace.Lir.Modules is

   --  Module metadata flags (u32 bitset; no bits assigned in this slice).
   type Module_Flags is mod 2**32;

   --  In-memory source origin for a module (also stored in .lir / .tlir v1.0 layouts).
   --  @field Name_Span Span of the module name in the original source.
   --  @field Span Span covering the whole compilation unit.
   --  @field Filename Optional shared filename from the frontend.
   type Module_Origin is record
      Name_Span : Lovelace.Common.Source.Source_Span;
      Span      : Lovelace.Common.Source.Source_Span;
      Filename  : Lovelace.Common.Source.Filename_Option;
   end record;

   --  Optional Module_Origin (same shape as Lovelace.Common.Option).
   --  @disc Present True when Value is stored; False when absent.
   --  @field Value Origin metadata when Present is True.
   type Origin_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Module_Origin;

         when False =>
            null;
      end case;
   end record;

   --  One LIR module.
   type Module is private;

   --  Build a module with Name, empty flags, no depends or subroutines, and
   --  no origin.
   --  @param Name UTF-8 module name.
   --  @return Module with Flags 0 and absent origin.
   function Create (Name : String) return Module;

   --  Set Flags on The_Module.
   --  @param The_Module Module to update.
   --  @param Flags New flag bitset.
   procedure Set_Flags (The_Module : in out Module; Flags : Module_Flags);

   --  Attach The_Origin to The_Module (replaces any previous origin).
   --  @param The_Module Module to update.
   --  @param The_Origin Source location metadata.
   procedure Set_Origin (The_Module : in out Module; The_Origin : Module_Origin);

   --  Append a dependency module name.
   --  @param The_Module Module to extend.
   --  @param Dependency_Name UTF-8 name of a depended-on module.
   procedure Append_Dependency (The_Module : in out Module; Dependency_Name : String);

   --  Append The_Subroutine to The_Module.
   --  @param The_Module Module to extend.
   --  @param The_Subroutine Subroutine to append.
   procedure Append_Subroutine (The_Module : in out Module; The_Subroutine : Subroutines.Subroutine);

   --  UTF-8 module name.
   --  @param The_Module Module to query.
   --  @return Name bytes.
   function Name (The_Module : Module) return String;

   --  Flag bitset of The_Module.
   --  @param The_Module Module to query.
   --  @return Flags value.
   function Flags (The_Module : Module) return Module_Flags;

   --  Optional source origin of The_Module.
   --  @param The_Module Module to query.
   --  @return Present origin, or absent when Create left it unset / codecs decode.
   function Origin (The_Module : Module) return Origin_Option;

   --  Number of dependency names.
   --  @param The_Module Module to query.
   --  @return Dependency count.
   function Dependency_Count (The_Module : Module) return Natural;

   --  Dependency name at Index (1 .. Dependency_Count).
   --  @param The_Module Module to query.
   --  @param Index 1-based index.
   --  @return Dependency name bytes.
   function Dependency_Name (The_Module : Module; Index : Positive) return String;

   --  Number of subroutines.
   --  @param The_Module Module to query.
   --  @return Subroutine count.
   function Subroutine_Count (The_Module : Module) return Natural;

   --  Subroutine at Index (1 .. Subroutine_Count).
   --  @param The_Module Module to query.
   --  @param Index 1-based index.
   --  @return Subroutine at Index.
   function Get_Subroutine (The_Module : Module; Index : Positive) return Subroutines.Subroutine;

   --  Check names, UTF-8, duplicates, self-depend, and entrypoint count.
   --  Construction may leave The_Module temporarily invalid; call before
   --  Encode or file write. Origins are not validated.
   --  @param The_Module Module to validate.
   --  @return Empty success, or an Error_Code.
   function Validate (The_Module : Module) return Errors.Validation_Results.Result;

private

   use type Ada.Strings.Unbounded.Unbounded_String;
   use type Subroutines.Subroutine;

   package Dependency_Vectors is new
     Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => Ada.Strings.Unbounded.Unbounded_String);

   package Subroutine_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Subroutines.Subroutine);

   type Module is record
      Module_Name  : Ada.Strings.Unbounded.Unbounded_String;
      Flags_Value  : Module_Flags := 0;
      Origin_Value : Origin_Option := (Present => False);
      Dependencies : Dependency_Vectors.Vector;
      Subroutines  : Subroutine_Vectors.Vector;
   end record;

end Lovelace.Lir.Modules;
