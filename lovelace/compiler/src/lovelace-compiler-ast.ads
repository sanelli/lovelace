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

   --  Expression kind for this slice (literals + name references).
   --  @enum Integer_Literal Integer literal token.
   --  @enum Boolean_Literal `true` / `false`.
   --  @enum Name_Reference Identifier (local / parameter).
   type Expression_Kind is (Integer_Literal, Boolean_Literal, Name_Reference);

   --  One expression node (shared by assignment RHS and call actuals).
   --  @field Kind Which expression form.
   --  @field Lexeme UTF-8 spelling (`42`, `true`, or the identifier).
   --  @field Span Source span of the expression token.
   --  @field Filename Optional shared filename from the token.
   type Expression is record
      Kind     : Expression_Kind;
      Lexeme   : Ada.Strings.Unbounded.Unbounded_String;
      Span     : Source.Source_Span;
      Filename : Source.Filename_Option;
   end record;

   --  Ordered list of expressions (call actuals).
   type Expression_Sequence is private;

   --  One qualified call statement (MODULE.SUBROUTINE with expression args).
   --  @field Callee_Name UTF-8 dotted callee (at least one '.').
   --  @field Name_Span Source span of the whole callee name.
   --  @field Filename Optional shared filename from the callee name.
   --  @field Arguments Ordered expression arguments.
   type Call_Statement is record
      Callee_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Arguments   : Expression_Sequence;
   end record;

   --  One assignment statement `Name := Expression;`.
   --  @field Target_Name UTF-8 LHS identifier.
   --  @field Name_Span Source span of the LHS name.
   --  @field Filename Optional shared filename from the name token.
   --  @field Value RHS expression.
   type Assignment_Statement is record
      Target_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Value       : Expression;
   end record;

   --  One local variable declaration (same shape as a parameter: name + type).
   subtype Local_Variable is Parameter;

   --  Ordered list of locals on a block.
   subtype Local_Sequence is Parameter_Sequence;

   --  Statement kind in a block body.
   --  @enum Call Qualified call with optional expression arguments.
   --  @enum Assignment `Name := Expression;`.
   --  @enum Nested_Block Nested `{ using } [declare...] begin ... end;` block statement.
   type Statement_Kind is (Call, Assignment, Nested_Block);

   --  One `begin`...`end` block with optional usings/locals (may nest via Nested_Block).
   type Block is private;

   --  One statement in a block body (call, assignment, or nested block).
   type Statement is private;

   --  Ordered list of statements in a block body.
   type Statement_Sequence is private;

   --  One subroutine declaration in the AST.
   type Subroutine is private;

   --  Ordered list of subroutines in a module.
   type Subroutine_Sequence is private;

   --  One `using` declaration (module name only; no alias yet).
   --  @field Module_Name UTF-8 dotted module name.
   --  @field Name_Span Source span of the whole qualified name.
   --  @field Filename Optional shared filename from the name token.
   type Using_Declaration is record
      Module_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
   end record;

   --  Ordered list of using declarations (unit-level or block preamble).
   type Using_Sequence is private;

   --  One compilation-unit module in the AST.
   type Module is private;

   --  Which surface form produced this compilation-unit AST.
   --  @enum Program_Unit Source used program IDENTIFIER; begin ... end.
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

   --  Empty local sequence (alias of empty parameters).
   --  @return Sequence with no elements.
   function Empty_Local_Sequence return Local_Sequence;

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

   --  Empty block (no locals, no statements).
   --  @return Block with empty locals and statements.
   function Empty_Block return Block;

   --  Build a block from Usings, Locals, and Statements.
   --  @param Usings Ordered block-level using declarations (may be empty).
   --  @param Locals Ordered local declarations (may be empty).
   --  @param Statements Ordered statement list (may be empty).
   --  @return Block value.
   function Create_Block
     (Usings : Using_Sequence; Locals : Local_Sequence; Statements : Statement_Sequence) return Block;

   --  Usings declared on The_Block (block preamble only; not unit-leading).
   --  @param The_Block Block to query.
   --  @return Using sequence.
   function Usings (The_Block : Block) return Using_Sequence;

   --  Locals declared on The_Block.
   --  @param The_Block Block to query.
   --  @return Local sequence.
   function Locals (The_Block : Block) return Local_Sequence;

   --  Statements in The_Block.
   --  @param The_Block Block to query.
   --  @return Statement sequence.
   function Statements (The_Block : Block) return Statement_Sequence;

   --  Build a call statement.
   --  @param The_Call Call payload.
   --  @return Statement with Kind Call.
   function Make_Call_Statement (The_Call : Call_Statement) return Statement;

   --  Build an assignment statement.
   --  @param The_Assignment Assignment payload.
   --  @return Statement with Kind Assignment.
   function Make_Assignment_Statement (The_Assignment : Assignment_Statement) return Statement;

   --  Build a nested-block statement.
   --  @param The_Block Nested block.
   --  @return Statement with Kind Nested_Block.
   function Make_Nested_Block_Statement (The_Block : Block) return Statement;

   --  Kind of The_Statement.
   --  @param The_Statement Statement to query.
   --  @return Call, Assignment, or Nested_Block.
   function Kind (The_Statement : Statement) return Statement_Kind;

   --  Call payload; requires Kind (The_Statement) = Call.
   --  @param The_Statement Call statement.
   --  @return Call_Statement.
   function Call_Of (The_Statement : Statement) return Call_Statement;

   --  Assignment payload; requires Kind (The_Statement) = Assignment.
   --  @param The_Statement Assignment statement.
   --  @return Assignment_Statement.
   function Assignment_Of (The_Statement : Statement) return Assignment_Statement;

   --  Nested block; requires Kind (The_Statement) = Nested_Block.
   --  @param The_Statement Nested-block statement.
   --  @return Block.
   function Block_Of (The_Statement : Statement) return Block;

   --  Empty expression sequence.
   --  @return Sequence with no elements.
   function Empty_Expression_Sequence return Expression_Sequence;

   --  Append The_Expression to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Expression Expression to append.
   procedure Append (Sequence : in out Expression_Sequence; The_Expression : Expression);

   --  Number of expressions in Sequence.
   --  @param Sequence Expression list.
   --  @return Element count.
   function Length (Sequence : Expression_Sequence) return Natural;

   --  Expression at Index (1 .. Length (Sequence)).
   --  @param Sequence Expression list.
   --  @param Index 1-based index.
   --  @return Expression at Index.
   function Element (Sequence : Expression_Sequence; Index : Positive) return Expression;

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
   --  @param Span Source span covering the whole procedure declaration.
   --  @param Flags Flag bits (export, entrypoint, and others).
   --  @param Return_Type Frontend return type expression.
   --  @param Parameters Ordered parameter list.
   --  @param The_Body Block body (may be empty; must be empty when intrinsic/native).
   --  @param Native Optional `@native("library", "function")` binding.
   --  @return Subroutine value.
   function Create_Subroutine
     (Name        : String;
      Module_Name : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Flags       : Subroutine_Flags;
      Return_Type : Types.Type_Expression;
      Parameters  : Parameter_Sequence;
      The_Body    : Block;
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

   --  Source span of the whole procedure declaration (header through final `;`).
   --  @param The_Subroutine Subroutine to query.
   --  @return Declaration span.
   function Span (The_Subroutine : Subroutine) return Source.Source_Span;

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

   --  Block body of The_Subroutine.
   --  @param The_Subroutine Subroutine to query.
   --  @return Body block (locals + statements).
   function Get_Body (The_Subroutine : Subroutine) return Block;

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

   --  Empty using sequence.
   --  @return Sequence with no elements.
   function Empty_Using_Sequence return Using_Sequence;

   --  Append The_Using to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Using Using declaration to append.
   procedure Append (Sequence : in out Using_Sequence; The_Using : Using_Declaration);

   --  Number of usings in Sequence.
   --  @param Sequence Using list.
   --  @return Element count.
   function Length (Sequence : Using_Sequence) return Natural;

   --  Using at Index (1 .. Length (Sequence)).
   --  @param Sequence Using list.
   --  @param Index 1-based index.
   --  @return Using at Index.
   function Element (Sequence : Using_Sequence; Index : Positive) return Using_Declaration;

   --  Build a module with Name, Kind, Usings, and Subroutines (may be empty).
   --  @param Name UTF-8 module name (may be dotted for Module_Unit).
   --  @param Name_Span Source span of the name (whole qualified name).
   --  @param Filename Optional shared filename from the name token.
   --  @param Span Source span covering the whole compilation unit.
   --  @param Kind Program_Unit or Module_Unit.
   --  @param Usings Ordered unit-level using list (may be empty).
   --  @param Subroutines Ordered subroutine list (empty for empty modules).
   --  @param Version Optional `@version("â¦")` attribute text (empty when absent).
   --  @return Module value.
   function Create_Module
     (Name        : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Kind        : Unit_Kind;
      Usings      : Using_Sequence;
      Subroutines : Subroutine_Sequence;
      Version     : String := "") return Module;

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

   --  True when The_Module carries a source `@version("â¦")` attribute.
   --  @param The_Module Module to query.
   --  @return True iff Version is non-empty.
   function Has_Version_Attribute (The_Module : Module) return Boolean;

   --  UTF-8 `@version` attribute text (empty when absent).
   --  @param The_Module Module to query.
   --  @return Version attribute bytes.
   function Version_Attribute (The_Module : Module) return String;

   --  Number of unit-level usings in The_Module.
   --  @param The_Module Module to query.
   --  @return Using count.
   function Using_Count (The_Module : Module) return Natural;

   --  Using at Index (1 .. Using_Count (The_Module)).
   --  @param The_Module Module to query.
   --  @param Index 1-based index.
   --  @return Using at Index.
   function Get_Using (The_Module : Module; Index : Positive) return Using_Declaration;

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

   package Expression_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Expression);

   type Expression_Sequence is record
      Items : Expression_Vectors.Vector;
   end record;

   type Block_Data;
   type Block is access Block_Data;

   type Statement (Kind_Value : Statement_Kind := Call) is record
      case Kind_Value is
         when Call =>
            The_Call : Call_Statement;

         when Assignment =>
            The_Assignment : Assignment_Statement;

         when Nested_Block =>
            The_Block : Block;
      end case;
   end record;

   package Statement_Vectors is new
     Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => Statement);

   type Statement_Sequence is record
      Items : Statement_Vectors.Vector;
   end record;

   type Block_Data is record
      Usings_Value     : Using_Sequence;
      Locals_Value     : Local_Sequence;
      Statements_Value : Statement_Sequence;
   end record;

   type Subroutine is record
      Subroutine_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Full_Name_Value   : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span_Value   : Source.Source_Span;
      Filename_Value    : Source.Filename_Option;
      Span_Value        : Source.Source_Span;
      Flags_Value       : Subroutine_Flags := 0;
      Return_Type_Value : Types.Type_Expression := Types.Unit_Type;
      Parameters_Value  : Parameter_Sequence;
      Body_Value        : Block;
      Native_Value      : Native_Binding_Option := (Present => False);
   end record;

   package Subroutine_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Subroutine);

   type Subroutine_Sequence is record
      Items : Subroutine_Vectors.Vector;
   end record;

   package Using_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Using_Declaration);

   type Using_Sequence is record
      Items : Using_Vectors.Vector;
   end record;

   type Module is record
      Module_Name             : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span_Value         : Source.Source_Span;
      Filename_Value          : Source.Filename_Option;
      Span_Value              : Source.Source_Span;
      Kind_Value              : Unit_Kind := Program_Unit;
      Usings                  : Using_Sequence;
      Subroutines             : Subroutine_Sequence;
      Version_Attribute_Value : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Lovelace.Compiler.Ast;
