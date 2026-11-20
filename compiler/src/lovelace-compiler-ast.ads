with Ada.Containers.Indefinite_Vectors;
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

   --  Bit 2: subroutine is an `@native("lib", "fn")` FFI binding (no Lovelace body).
   Native_Flag : constant Subroutine_Flags := 2**2;

   --  Bit 3: subroutine is an `@intrinsic` (compiler-synthesized body; no Lovelace body).
   Intrinsic_Flag : constant Subroutine_Flags := 2**3;

   --  Shared-library FFI binding from `@native("library", "function")`.
   --  @field Library UTF-8 shared-library name.
   --  @field Function_Name UTF-8 native function name.
   type Native_Binding is record
      Library       : Ada.Strings.Unbounded.Unbounded_String;
      Function_Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Optional native binding on a subroutine.
   --  @disc Present True when Value is stored; False when absent.
   --  @field Value Binding when Present is True.
   type Native_Binding_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Native_Binding;

         when False =>
            null;
      end case;
   end record;

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

   --  One integer literal argument to a call.
   --  @field Lexeme UTF-8 integer literal spelling from the tokenizer.
   --  @field Span Source span of the literal token.
   --  @field Filename Optional shared filename from the literal token.
   type Call_Argument is record
      Lexeme   : Ada.Strings.Unbounded.Unbounded_String;
      Span     : Source.Source_Span;
      Filename : Source.Filename_Option;
   end record;

   --  Ordered list of call arguments.
   type Argument_Sequence is private;

   --  One qualified call statement (MODULE.SUBROUTINE with literal args).
   --  @field Callee_Name UTF-8 dotted callee (at least one '.').
   --  @field Name_Span Source span of the whole callee name.
   --  @field Filename Optional shared filename from the callee name.
   --  @field Arguments Ordered integer-literal arguments.
   type Call_Statement is record
      Callee_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Arguments   : Argument_Sequence;
   end record;

   --  Statement kind in a subroutine body.
   --  @enum Call Qualified call with optional integer literal arguments.
   type Statement_Kind is (Call);

   --  One statement in a subroutine body.
   --  @disc Kind Selects the statement variant.
   --  @field The_Call Call_Statement when Kind is Call.
   type Statement (Kind : Statement_Kind := Call) is record
      case Kind is
         when Call =>
            The_Call : Call_Statement;
      end case;
   end record;

   --  Ordered list of statements in a subroutine body.
   type Statement_Sequence is private;

   --  One subroutine declaration in the AST.
   type Subroutine is private;

   --  Ordered list of subroutines in a module.
   type Subroutine_Sequence is private;

   --  One unit-level import declaration (module name only; no alias yet).
   --  @field Module_Name UTF-8 dotted module name.
   --  @field Name_Span Source span of the whole qualified name.
   --  @field Filename Optional shared filename from the name token.
   type Import_Declaration is record
      Module_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
   end record;

   --  Ordered list of import declarations on a compilation unit.
   type Import_Sequence is private;

   --  One compilation-unit module in the AST.
   type Module is private;

   --  Which surface form produced this compilation-unit AST.
   --  @enum Program_Unit Source used program IDENTIFIER; begin â¦ end.
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

   --  True when Flags includes Intrinsic_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff intrinsic bit is set.
   function Has_Intrinsic (Flags : Subroutine_Flags) return Boolean;

   --  True when Flags includes Native_Flag.
   --  @param Flags Flag bitset.
   --  @return True iff native bit is set.
   function Has_Native (Flags : Subroutine_Flags) return Boolean;

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

   --  Empty argument sequence.
   --  @return Sequence with no elements.
   function Empty_Argument_Sequence return Argument_Sequence;

   --  Append The_Argument to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Argument Argument to append.
   procedure Append (Sequence : in out Argument_Sequence; The_Argument : Call_Argument);

   --  Number of arguments in Sequence.
   --  @param Sequence Argument list.
   --  @return Element count.
   function Length (Sequence : Argument_Sequence) return Natural;

   --  Argument at Index (1 .. Length (Sequence)).
   --  @param Sequence Argument list.
   --  @param Index 1-based index.
   --  @return Argument at Index.
   function Element (Sequence : Argument_Sequence; Index : Positive) return Call_Argument;

   --  Empty statement sequence (no statements).
   --  @return Sequence with length 0.
   function Empty_Body return Statement_Sequence;

   --  Append The_Statement to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Statement Statement to append.
   procedure Append (Sequence : in out Statement_Sequence; The_Statement : Statement);

   --  Number of statements in The_Body.
   --  @param The_Body Statement list.
   --  @return Element count.
   function Length (The_Body : Statement_Sequence) return Natural;

   --  Statement at Index (1 .. Length (The_Body)).
   --  @param The_Body Statement list.
   --  @param Index 1-based index.
   --  @return Statement at Index.
   function Element (The_Body : Statement_Sequence; Index : Positive) return Statement;

   --  Build a subroutine with the given metadata, parameters, and body.
   --  Full_Name is Module_Name & "." & Name.
   --  @param Name UTF-8 unqualified subroutine name.
   --  @param Module_Name UTF-8 enclosing module name (may be dotted).
   --  @param Name_Span Source span of the name identifier.
   --  @param Filename Optional shared filename from the name token.
   --  @param Flags Flag bits (export, entrypoint, and others).
   --  @param Return_Type Frontend return type expression.
   --  @param Parameters Ordered parameter list.
   --  @param The_Body Statement list (may be empty; must be empty when intrinsic/native).
   --  @param Native Optional `@native("library", "function")` binding.
   --  @return Subroutine value.
   function Create_Subroutine
     (Name        : String;
      Module_Name : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Flags       : Subroutine_Flags;
      Return_Type : Types.Type_Expression;
      Parameters  : Parameter_Sequence;
      The_Body    : Statement_Sequence;
      Native      : Native_Binding_Option) return Subroutine;

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

   --  Optional native binding of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Present binding, or absent when not native.
   function Native (The_Subroutine : Subroutine) return Native_Binding_Option;

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

   --  Empty import sequence.
   --  @return Sequence with no elements.
   function Empty_Import_Sequence return Import_Sequence;

   --  Append The_Import to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Import Import declaration to append.
   procedure Append (Sequence : in out Import_Sequence; The_Import : Import_Declaration);

   --  Number of imports in Sequence.
   --  @param Sequence Import list.
   --  @return Element count.
   function Length (Sequence : Import_Sequence) return Natural;

   --  Import at Index (1 .. Length (Sequence)).
   --  @param Sequence Import list.
   --  @param Index 1-based index.
   --  @return Import at Index.
   function Element (Sequence : Import_Sequence; Index : Positive) return Import_Declaration;

   --  Build a module with Name, Kind, Imports, and Subroutines (may be empty).
   --  @param Name UTF-8 module name (may be dotted for Module_Unit).
   --  @param Name_Span Source span of the name (whole qualified name).
   --  @param Filename Optional shared filename from the name token.
   --  @param Span Source span covering the whole compilation unit.
   --  @param Kind Program_Unit or Module_Unit.
   --  @param Imports Ordered unit-level import list (may be empty).
   --  @param Subroutines Ordered subroutine list (empty for empty modules).
   --  @return Module value.
   function Create_Module
     (Name        : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Kind        : Unit_Kind;
      Imports     : Import_Sequence;
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

   --  Number of imports in The_Module.
   --  @param The_Module Module to query.
   --  @return Import count.
   function Import_Count (The_Module : Module) return Natural;

   --  Import at Index (1 .. Import_Count (The_Module)).
   --  @param The_Module Module to query.
   --  @param Index 1-based index.
   --  @return Import at Index.
   function Get_Import (The_Module : Module; Index : Positive) return Import_Declaration;

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

   package Argument_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Call_Argument);

   type Argument_Sequence is record
      Items : Argument_Vectors.Vector;
   end record;

   package Statement_Vectors is new
     Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => Statement);

   type Statement_Sequence is record
      Items : Statement_Vectors.Vector;
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
      Native_Value      : Native_Binding_Option := (Present => False);
   end record;

   package Subroutine_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Subroutine);

   type Subroutine_Sequence is record
      Items : Subroutine_Vectors.Vector;
   end record;

   package Import_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Import_Declaration);

   type Import_Sequence is record
      Items : Import_Vectors.Vector;
   end record;

   type Module is record
      Module_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span_Value : Source.Source_Span;
      Filename_Value  : Source.Filename_Option;
      Span_Value      : Source.Source_Span;
      Kind_Value      : Unit_Kind := Program_Unit;
      Imports         : Import_Sequence;
      Subroutines     : Subroutine_Sequence;
   end record;

end Lovelace.Compiler.Ast;
