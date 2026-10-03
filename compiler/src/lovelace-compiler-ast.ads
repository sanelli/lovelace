with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Types;

--  Frontend abstract syntax tree for one Lovelace compilation unit.
--  Distinct from Lovelace.Lir modules and subroutines.

package Lovelace.Compiler.Ast is

   package Source renames Lovelace.Common.Source;

   --  Flag bitset for a frontend subroutine (not string tags; not LIR flags).
   type Subroutine_Flags is mod 2**32;

   --  Bit 0: subroutine is exported from the module.
   Export_Flag : constant Subroutine_Flags := 2**0;

   --  Bit 1: subroutine is the module entrypoint.
   Entrypoint_Flag : constant Subroutine_Flags := 2**1;

   --  One procedure parameter in the AST.
   --  @field Parameter_Name UTF-8 parameter name.
   --  @field Name_Span Source span of the parameter name.
   --  @field Filename Optional shared filename from the name token.
   --  @field Parameter_Type Frontend type expression.
   type Parameter is record
      Parameter_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span      : Source.Source_Span;
      Filename       : Source.Filename_Option;
      Parameter_Type : Types.Type_Expression;
   end record;

   --  Ordered list of parameters on a subroutine.
   type Parameter_Sequence is private;

   --  Ordered list of statements in a subroutine body (empty in this slice).
   type Statement_Sequence is private;

   --  One subroutine declaration in the AST.
   type Subroutine is private;

   --  Ordered list of subroutines in a module.
   type Subroutine_Sequence is private;

   --  One compilation-unit module in the AST.
   type Module is private;

   --  Which surface form produced this compilation-unit AST.
   --  @enum Program_Unit Source used program IDENTIFIER; begin end.
   --  @enum Module_Unit Source used module qualified_identifier; end.
   type Unit_Kind is (Program_Unit, Module_Unit);

   --  True when Flags includes Export_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff export bit is set.
   function Has_Export (Flags : Subroutine_Flags) return Boolean;

   --  True when Flags includes Entrypoint_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff entrypoint bit is set.
   function Has_Entrypoint (Flags : Subroutine_Flags) return Boolean;

   --  Empty parameter sequence.
   --  @return Sequence with no elements.
   function Empty_Parameter_Sequence return Parameter_Sequence;

   --  Append The_Parameter to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Parameter Parameter to append.
   procedure Append (Sequence : in out Parameter_Sequence; The_Parameter : Parameter);

   --  Number of parameters in Sequence.
   --  @param Sequence Parameter list.
   --  @return Element count.
   function Length (Sequence : Parameter_Sequence) return Natural;

   --  Parameter at Index (1 .. Length (Sequence)).
   --  @param Sequence Parameter list.
   --  @param Index 1-based index.
   --  @return Parameter at Index.
   function Element (Sequence : Parameter_Sequence; Index : Positive) return Parameter;

   --  Empty statement sequence (no statements).
   --  @return Sequence with length 0.
   function Empty_Body return Statement_Sequence;

   --  Number of statements in The_Body.
   --  @param The_Body Statement list.
   --  @return Element count.
   function Length (The_Body : Statement_Sequence) return Natural;

   --  Build a subroutine with the given metadata, parameters, and body.
   --  Full_Name is Module_Name & "." & Name.
   --  @param Name UTF-8 unqualified subroutine name.
   --  @param Module_Name UTF-8 enclosing module name (may be dotted).
   --  @param Name_Span Source span of the name identifier.
   --  @param Filename Optional shared filename from the name token.
   --  @param Flags Flag bits (export, entrypoint, and others).
   --  @param Return_Type Frontend return type expression.
   --  @param Parameters Ordered parameter list.
   --  @param The_Body Statement list (empty in this slice).
   --  @return Subroutine value.
   function Create_Subroutine
     (Name        : String;
      Module_Name : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Flags       : Subroutine_Flags;
      Return_Type : Types.Type_Expression;
      Parameters  : Parameter_Sequence;
      The_Body    : Statement_Sequence) return Subroutine;

   --  UTF-8 unqualified name of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Name bytes.
   function Name (The_Subroutine : Subroutine) return String;

   --  UTF-8 full name ModuleName.ProcedureName.
   --  @param The_Subroutine Subroutine to query.
   --  @return Full name bytes.
   function Full_Name (The_Subroutine : Subroutine) return String;

   --  Source span of the subroutine name.
   --  @param The_Subroutine Subroutine to query.
   --  @return Name span.
   function Name_Span (The_Subroutine : Subroutine) return Source.Source_Span;

   --  Optional filename associated with the subroutine name.
   --  @param The_Subroutine Subroutine to query.
   --  @return Filename option from construction.
   function Filename (The_Subroutine : Subroutine) return Source.Filename_Option;

   --  Flag bits of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Flag bitset.
   function Get_Flags (The_Subroutine : Subroutine) return Subroutine_Flags;

   --  Return type expression of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Frontend type expression.
   function Return_Type (The_Subroutine : Subroutine) return Types.Type_Expression;

   --  Parameters of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Parameter sequence.
   function Parameters (The_Subroutine : Subroutine) return Parameter_Sequence;

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

   --  Build a module with Name, Kind, and Subroutines (may be empty).
   --  @param Name UTF-8 module name (may be dotted for Module_Unit).
   --  @param Name_Span Source span of the name (whole qualified name).
   --  @param Filename Optional shared filename from the name token.
   --  @param Span Source span covering the whole compilation unit.
   --  @param Kind Program_Unit or Module_Unit.
   --  @param Subroutines Ordered subroutine list (empty for empty modules).
   --  @return Module value.
   function Create_Module
     (Name        : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Kind        : Unit_Kind;
      Subroutines : Subroutine_Sequence) return Module;

   --  UTF-8 name of The_Module.
   --  @param The_Module Module to query.
   --  @return Name bytes.
   function Name (The_Module : Module) return String;

   --  Compilation-unit kind of The_Module.
   --  @param The_Module Module to query.
   --  @return Program_Unit or Module_Unit.
   function Kind (The_Module : Module) return Unit_Kind;

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

   package Parameter_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Parameter);

   type Parameter_Sequence is record
      Items : Parameter_Vectors.Vector;
   end record;

   --  Empty body representation for this slice; replaced by a statement
   --  vector when statement nodes exist.
   type Statement_Sequence is record
      Count : Natural := 0;
   end record;

   type Subroutine is record
      Subroutine_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Full_Name_Value   : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span_Value   : Source.Source_Span;
      Filename_Value    : Source.Filename_Option;
      Flags_Value       : Subroutine_Flags := 0;
      Return_Type_Value : Types.Type_Expression := Types.Unit_Type;
      Parameters_Value  : Parameter_Sequence;
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
      Kind_Value      : Unit_Kind := Program_Unit;
      Subroutines     : Subroutine_Sequence;
   end record;

end Lovelace.Compiler.Ast;
