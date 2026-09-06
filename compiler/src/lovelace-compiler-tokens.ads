with Ada.Containers.Indefinite_Vectors;

with Lovelace.Compiler.Source;

--  Token kinds and sequences for the Lovelace lexer.

package Lovelace.Compiler.Tokens is

   --  Which token class was recognized.
   --  @enum Keyword Reserved word.
   --  @enum Identifier User-defined name.
   --  @enum Punctuation Separator or terminator.
   type Token_Kind is (Keyword, Identifier, Punctuation);

   --  Which keyword was matched (case-sensitive).
   --  @enum Program_Keyword program
   --  @enum Begin_Keyword begin
   --  @enum End_Keyword end
   type Keyword_Subtype is (Program_Keyword, Begin_Keyword, End_Keyword);

   --  Which punctuation token was matched.
   --  @enum Semicolon ;
   --  @enum Full_Stop .
   type Punctuation_Subtype is (Semicolon, Full_Stop);

   --  One lexical token with kind-specific subtype fields.
   --  @disc Kind Selects which variant field is present.
   --  @field Span Source extent of the token lexeme.
   --  @field Filename Optional shared filename from tokenization.
   --  @field Keyword_Value Keyword subtype when Kind is Keyword.
   --  @field Punctuation_Value Punctuation subtype when Kind is Punctuation.
   type Token (Kind : Token_Kind) is record
      Span     : Source.Source_Span;
      Filename : Source.Filename_Option;
      case Kind is
         when Keyword =>
            Keyword_Value : Keyword_Subtype;

         when Punctuation =>
            Punctuation_Value : Punctuation_Subtype;

         when Identifier =>
            null;
      end case;
   end record;

   --  Ordered list of tokens from one Tokenize call.
   type Token_Sequence is private;

   --  UTF-8 lexeme bytes for The_Token within Source_Text.
   --  @param Source_Text Original tokenized UTF-8 string.
   --  @param The_Token Token whose Span selects the slice.
   --  @return Source_Text (First.Byte_Index .. Last.Byte_Index).
   function Lexeme (Source_Text : String; The_Token : Token) return String;

   --  Empty token sequence.
   --  @return Sequence with no elements.
   function Empty_Sequence return Token_Sequence;

   --  Append a token to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param Item Token to append.
   procedure Append (Sequence : in out Token_Sequence; Item : Token);

   --  Number of tokens in Sequence.
   --  @param Sequence Token list.
   --  @return Element count.
   function Length (Sequence : Token_Sequence) return Natural;

   --  Token at Index (1 .. Length (Sequence)).
   --  @param Sequence Token list.
   --  @param Index 1-based index.
   --  @return Token at Index.
   function Element (Sequence : Token_Sequence; Index : Positive) return Token;

private

   package Token_Vectors is new Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => Token);

   type Token_Sequence is record
      Items : Token_Vectors.Vector;
   end record;

end Lovelace.Compiler.Tokens;
