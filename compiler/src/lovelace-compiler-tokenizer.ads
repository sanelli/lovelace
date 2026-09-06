with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Compiler.Source;
with Lovelace.Compiler.Tokens;

--  Regex-backed UTF-8 tokenizer for keywords, identifiers, and punctuation.

package Lovelace.Compiler.Tokenizer is

   --  Tokenizer problem (expandable in later work).
   --  @enum Internal_Error Compiler bug such as a hardcoded pattern failing to compile.
   --  @enum Unrecognized_Symbol Valid scalar that does not start a token.
   --  @enum Invalid_Utf_8 Bytes that are not valid UTF-8.
   type Tokenizer_Error_Code is (Internal_Error, Unrecognized_Symbol, Invalid_Utf_8);

   --  One located tokenizer diagnostic.
   --  @field Code Predefined tokenizer error code.
   --  @field Span Source extent of the problem.
   --  @field Filename Optional shared filename from tokenization.
   --  @field Detail UTF-8 message such as unrecognized symbol detail.
   type Tokenizer_Error is record
      Code     : Tokenizer_Error_Code;
      Span     : Source.Source_Span;
      Filename : Source.Filename_Option;
      Detail   : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Ordered list of tokenizer errors from one Tokenize call.
   type Tokenizer_Error_Sequence is private;

   --  Tokens on success, or every collected error on failure.
   --  @disc Ok True when Tokens is present; False when Errors is present.
   --  @field Tokens Token sequence when Ok is True.
   --  @field Errors Error sequence when Ok is False.
   type Tokenize_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Tokens : Lovelace.Compiler.Tokens.Token_Sequence;

         when False =>
            Errors : Tokenizer_Error_Sequence;
      end case;
   end record;

   --  Tokenize Source_Text without an associated filename.
   --  @param Source_Text UTF-8 input text.
   --  @return Token list, or the collected error list.
   function Tokenize (Source_Text : String) return Tokenize_Result;

   --  Tokenize Source_Text with Filename stored on every token and error.
   --  @param Source_Text UTF-8 input text.
   --  @param Filename UTF-8 path or label shared across the output.
   --  @return Token list, or the collected error list.
   function Tokenize (Source_Text : String; Filename : String) return Tokenize_Result;

   --  Number of errors in Errors.
   --  @param Errors Error list.
   --  @return Element count.
   function Length (Errors : Tokenizer_Error_Sequence) return Natural;

   --  Error at Index (1 .. Length (Errors)).
   --  @param Errors Error list.
   --  @param Index 1-based index.
   --  @return Error at Index.
   function Element (Errors : Tokenizer_Error_Sequence; Index : Positive) return Tokenizer_Error;

private

   package Error_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Tokenizer_Error);

   type Tokenizer_Error_Sequence is record
      Items : Error_Vectors.Vector;
   end record;

end Lovelace.Compiler.Tokenizer;
