with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Compiler.Source;
with Lovelace.Compiler.Types;

--  Frontend abstract syntax tree for one Lovelace compilation unit.
--  Distinct from Lovelace.Lir modules and subroutines.

package Lovelace.Compiler.Ast is

   --  Ordered list of statements in a subroutine body (empty in this slice).
   type Statement_Sequence is private;

   --  One subroutine declaration in the AST.
   type Subroutine is private;

   --  Ordered list of subroutines in a module.
   type Subroutine_Sequence is private;

   --  One compilation-unit module in the AST.
   type Module is private;

   --  Empty statement sequence (no statements).
   --  @return Sequence with length 0.
   function Empty_Body return Statement_Sequence;

   --  Number of statements in The_Body.
   --  @param The_Body Statement list.
   --  @return Element count.
   function Length (The_Body : Statement_Sequence) return Natural;

   --  Build a subroutine with the given metadata and body.
   --  @param Name UTF-8 subroutine name.
   --  @param Name_Span Source span of the name identifier.
   --  @param Filename Optional shared filename from the name token.
   --  @param Is_Entrypoint True when this subroutine is the module entrypoint.
   --  @param Is_Export True when this subroutine is exported.
   --  @param Return_Type Frontend return type expression.
   --  @param The_Body Statement list (empty in this slice).
   --  @return Subroutine value.
   function Create_Subroutine
     (Name          : String;
      Name_Span     : Source.Source_Span;
      Filename      : Source.Filename_Option;
      Is_Entrypoint : Boolean;
      Is_Export     : Boolean;
      Return_Type   : Types.Type_Expression;
      The_Body      : Statement_Sequence) return Subroutine;

   --  UTF-8 name of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Name bytes.
   function Name (The_Subroutine : Subroutine) return String;

   --  Source span of the subroutine name.
   --  @param The_Subroutine Subroutine to query.
   --  @return Name span.
   function Name_Span (The_Subroutine : Subroutine) return Source.Source_Span;

   --  Optional filename associated with the subroutine name.
   --  @param The_Subroutine Subroutine to query.
   --  @return Filename option from construction.
   function Filename (The_Subroutine : Subroutine) return Source.Filename_Option;

   --  True when The_Subroutine is marked as the module entrypoint.
   --  @param The_Subroutine Subroutine to query.
   --  @return Entrypoint flag.
   function Is_Entrypoint (The_Subroutine : Subroutine) return Boolean;

   --  True when The_Subroutine is marked as exported.
   --  @param The_Subroutine Subroutine to query.
   --  @return Export flag.
   function Is_Export (The_Subroutine : Subroutine) return Boolean;

   --  Return type expression of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Frontend type expression.
   function Return_Type (The_Subroutine : Subroutine) return Types.Type_Expression;

   --  Statement body of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Statement sequence.
   function Get_Body (The_Subroutine : Subroutine) return Statement_Sequence;

   --  Empty subroutine sequence.
   --  @return Sequence with no elements.
   function Empty_Subroutine_Sequence return Subroutine_Sequence;

   --  Append The_Subroutine to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Subroutine Subroutine to append.
   procedure Append (Sequence : in out Subroutine_Sequence; The_Subroutine : Subroutine);

   --  Number of subroutines in Sequence.
   --  @param Sequence Subroutine list.
   --  @return Element count.
   function Length (Sequence : Subroutine_Sequence) return Natural;

   --  Subroutine at Index (1 .. Length (Sequence)).
   --  @param Sequence Subroutine list.
   --  @param Index 1-based index.
   --  @return Subroutine at Index.
   function Element (Sequence : Subroutine_Sequence; Index : Positive) return Subroutine;

   --  Build a module with Name and a single The_Subroutine.
   --  @param Name UTF-8 module name.
   --  @param Name_Span Source span of the name identifier.
   --  @param Filename Optional shared filename from the name token.
   --  @param Span Source span covering the whole compilation unit.
   --  @param The_Subroutine Sole subroutine contained in the module.
   --  @return Module with one subroutine.
   function Create_Module
     (Name           : String;
      Name_Span      : Source.Source_Span;
      Filename       : Source.Filename_Option;
      Span           : Source.Source_Span;
      The_Subroutine : Subroutine) return Module;

   --  UTF-8 name of The_Module.
   --  @param The_Module Module to query.
   --  @return Name bytes.
   function Name (The_Module : Module) return String;

   --  Source span of the module name.
   --  @param The_Module Module to query.
   --  @return Name span.
   function Name_Span (The_Module : Module) return Source.Source_Span;

   --  Optional filename associated with the module name.
   --  @param The_Module Module to query.
   --  @return Filename option from construction.
   function Filename (The_Module : Module) return Source.Filename_Option;

   --  Source span covering the whole compilation unit.
   --  @param The_Module Module to query.
   --  @return Unit span.
   function Span (The_Module : Module) return Source.Source_Span;

   --  Number of subroutines in The_Module.
   --  @param The_Module Module to query.
   --  @return Subroutine count.
   function Subroutine_Count (The_Module : Module) return Natural;

   --  Subroutine at Index (1 .. Subroutine_Count (The_Module)).
   --  @param The_Module Module to query.
   --  @param Index 1-based index.
   --  @return Subroutine at Index.
   function Get_Subroutine (The_Module : Module; Index : Positive) return Subroutine;

private

   --  Empty body representation for this slice; replaced by a statement
   --  vector when statement nodes exist.
   type Statement_Sequence is record
      Count : Natural := 0;
   end record;

   --  This slice only constructs Unit return types; constrained for a definite record.
   subtype Unit_Type_Expression is Types.Type_Expression (Kind => Types.Unit);

   type Subroutine is record
      Subroutine_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span_Value   : Source.Source_Span;
      Filename_Value    : Source.Filename_Option;
      Entrypoint_Flag   : Boolean;
      Export_Flag       : Boolean;
      Return_Type_Value : Unit_Type_Expression;
      Body_Value        : Statement_Sequence;
   end record;

   package Subroutine_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Subroutine);

   type Subroutine_Sequence is record
      Items : Subroutine_Vectors.Vector;
   end record;

   type Module is record
      Module_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span_Value : Source.Source_Span;
      Filename_Value  : Source.Filename_Option;
      Span_Value      : Source.Source_Span;
      Subroutines     : Subroutine_Sequence;
   end record;

end Lovelace.Compiler.Ast;
