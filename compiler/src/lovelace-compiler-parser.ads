with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Tokens;

--  Parse a token sequence for one minimal Lovelace compilation unit into an AST.
--  Recursive-descent (LL(k)); consumes one token at a time.

package Lovelace.Compiler.Parser is

   package Source renames Lovelace.Common.Source;

   --  Parser problem (expandable in later work).
   --  @enum Internal_Error Compiler bug in the parser.
   --  @enum Unexpected_End_Of_Input Fewer tokens than the grammar requires.
   --  @enum Unexpected_Token Wrong token kind or subtype at the cursor.
   --  @enum Unexpected_Trailing Extra tokens after a complete unit.
   type Parser_Error_Code is (Internal_Error, Unexpected_End_Of_Input, Unexpected_Token, Unexpected_Trailing);

   --  One located parser diagnostic.
   --  @field Code Predefined parser error code.
   --  @field Span Source extent of the problem.
   --  @field Filename Optional shared filename from a related token.
   --  @field Detail UTF-8 message describing what was expected or found.
   type Parser_Error is record
      Code     : Parser_Error_Code;
      Span     : Source.Source_Span;
      Filename : Source.Filename_Option;
      Detail   : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Ordered list of parser errors from one Parse call.
   type Parser_Error_Sequence is private;

   --  Module AST on success, or every collected error on failure.
   --  @disc Ok True when The_Module is present; False when Errors is present.
   --  @field The_Module Parsed compilation-unit module when Ok is True.
   --  @field Errors Error sequence when Ok is False.
   type Parse_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            The_Module : Ast.Module;

         when False =>
            Errors : Parser_Error_Sequence;
      end case;
   end record;

   --  Parse Token_List for Source_Text into a compilation-unit AST.
   --  Grammar: program_header block "." with program_header = "program" identifier ";"
   --  and block = "begin" "end". Recursive descent; one token at a time.
   --  @param Source_Text Original UTF-8 source (for identifier lexemes).
   --  @param Token_List Tokens from a successful Tokenize of Source_Text.
   --  @return Module AST, or a single located error.
   function Parse (Source_Text : String; Token_List : Tokens.Token_Sequence) return Parse_Result;

   --  Empty error sequence.
   --  @return Sequence with no elements.
   function Empty_Error_Sequence return Parser_Error_Sequence;

   --  Number of errors in Errors.
   --  @param Errors Error list.
   --  @return Element count.
   function Length (Errors : Parser_Error_Sequence) return Natural;

   --  Error at Index (1 .. Length (Errors)).
   --  @param Errors Error list.
   --  @param Index 1-based index.
   --  @return Error at Index.
   function Element (Errors : Parser_Error_Sequence; Index : Positive) return Parser_Error;

private

   package Error_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Parser_Error);

   type Parser_Error_Sequence is record
      Items : Error_Vectors.Vector;
   end record;

end Lovelace.Compiler.Parser;
