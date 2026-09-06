with Lovelace.Compiler.Tokens;
with Lovelace.Compiler.Tokenizer;

--  Shared assertions for Tokenize tests.

package Lovelace.Compiler.Tests.Support is

   --  Encode one Unicode scalar as UTF-8 bytes.
   --  @param Point Unicode scalar.
   --  @return UTF-8 byte string.
   function To_Utf_8 (Point : Wide_Wide_Character) return String;

   --  Require Tokenize success and return the token sequence.
   --  @param Source_Text UTF-8 input.
   --  @param Message Assertion message on failure.
   --  @return Token sequence.
   function Must_Succeed (Source_Text : String; Message : String) return Tokens.Token_Sequence;

   --  Require Tokenize success with Filename and return the token sequence.
   --  @param Source_Text UTF-8 input.
   --  @param Filename Shared filename label.
   --  @param Message Assertion message on failure.
   --  @return Token sequence.
   function Must_Succeed
     (Source_Text : String; Filename : String; Message : String) return Tokens.Token_Sequence;

   --  Require Tokenize failure and return the error sequence.
   --  @param Source_Text UTF-8 input.
   --  @param Message Assertion message on unexpected success.
   --  @return Error sequence.
   function Must_Fail (Source_Text : String; Message : String) return Tokenizer.Tokenizer_Error_Sequence;

   --  Require Tokenize failure with Filename and return the error sequence.
   --  @param Source_Text UTF-8 input.
   --  @param Filename Shared filename label.
   --  @param Message Assertion message on unexpected success.
   --  @return Error sequence.
   function Must_Fail
     (Source_Text : String; Filename : String; Message : String)
      return Tokenizer.Tokenizer_Error_Sequence;

   --  Assert token count.
   --  @param Token_List Token sequence.
   --  @param Expected_Length Expected Length (Token_List).
   --  @param Message Assertion message.
   procedure Assert_Token_Count
     (Token_List : Tokens.Token_Sequence; Expected_Length : Natural; Message : String);

   --  Assert error count.
   --  @param Errors Error sequence.
   --  @param Expected_Length Expected Length (Errors).
   --  @param Message Assertion message.
   procedure Assert_Error_Count
     (Errors : Tokenizer.Tokenizer_Error_Sequence; Expected_Length : Natural; Message : String);

   --  Assert token Kind, lexeme, and keyword subtype.
   --  @param Source_Text Original UTF-8 source.
   --  @param Token_List Token sequence.
   --  @param Index 1-based token index.
   --  @param Value Expected keyword subtype.
   --  @param Message Assertion message.
   procedure Assert_Keyword
     (Source_Text : String;
      Token_List  : Tokens.Token_Sequence;
      Index       : Positive;
      Value       : Tokens.Keyword_Subtype;
      Message     : String);

   --  Assert token Kind Identifier and lexeme.
   --  @param Source_Text Original UTF-8 source.
   --  @param Token_List Token sequence.
   --  @param Index 1-based token index.
   --  @param Expected_Lexeme Expected lexeme bytes.
   --  @param Message Assertion message.
   procedure Assert_Identifier
     (Source_Text     : String;
      Token_List      : Tokens.Token_Sequence;
      Index           : Positive;
      Expected_Lexeme : String;
      Message         : String);

   --  Assert token Kind Punctuation and subtype.
   --  @param Token_List Token sequence.
   --  @param Index 1-based token index.
   --  @param Value Expected punctuation subtype.
   --  @param Message Assertion message.
   procedure Assert_Punctuation
     (Token_List : Tokens.Token_Sequence;
      Index      : Positive;
      Value      : Tokens.Punctuation_Subtype;
      Message    : String);

   --  Assert token span line and column (first position).
   --  @param Token_List Token sequence.
   --  @param Index 1-based token index.
   --  @param Line Expected first line.
   --  @param Column Expected first column.
   --  @param Message Assertion message.
   procedure Assert_First_Position
     (Token_List : Tokens.Token_Sequence;
      Index      : Positive;
      Line       : Positive;
      Column     : Positive;
      Message    : String);

   --  Assert error code at Index.
   --  @param Errors Error sequence.
   --  @param Index 1-based error index.
   --  @param Code Expected error code.
   --  @param Message Assertion message.
   procedure Assert_Error_Code
     (Errors  : Tokenizer.Tokenizer_Error_Sequence;
      Index   : Positive;
      Code    : Tokenizer.Tokenizer_Error_Code;
      Message : String);

end Lovelace.Compiler.Tests.Support;
