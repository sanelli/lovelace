with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Common.Utf_8;

package body Lovelace.Compiler.Tests.Support is

   use type Tokens.Keyword_Subtype;
   use type Tokens.Punctuation_Subtype;
   use type Tokens.Token_Kind;
   use type Tokenizer.Tokenizer_Error_Code;

   procedure Assert_Error_Code
     (Errors  : Tokenizer.Tokenizer_Error_Sequence;
      Index   : Positive;
      Code    : Tokenizer.Tokenizer_Error_Code;
      Message : String)
   is
      Item : constant Tokenizer.Tokenizer_Error := Tokenizer.Element (Errors, Index);
   begin
      AUnit.Assertions.Assert (Item.Code = Code, Message);
   end Assert_Error_Code;

   procedure Assert_Error_Count
     (Errors : Tokenizer.Tokenizer_Error_Sequence; Expected_Length : Natural; Message : String)
   is
      Actual_Length : constant Natural := Tokenizer.Length (Errors);
   begin
      AUnit.Assertions.Assert
        (Actual_Length = Expected_Length,
         Message & ": expected" & Natural'Image (Expected_Length) & " got" & Natural'Image (Actual_Length));
   end Assert_Error_Count;

   procedure Assert_First_Position
     (Token_List : Tokens.Token_Sequence;
      Index      : Positive;
      Line       : Positive;
      Column     : Positive;
      Message    : String)
   is
      Item : constant Tokens.Token := Tokens.Element (Token_List, Index);
   begin
      AUnit.Assertions.Assert
        (Item.Span.First.Line = Line,
         Message & ": line expected" & Positive'Image (Line) & " got"
         & Positive'Image (Item.Span.First.Line));
      AUnit.Assertions.Assert
        (Item.Span.First.Column = Column,
         Message & ": column expected" & Positive'Image (Column) & " got"
         & Positive'Image (Item.Span.First.Column));
   end Assert_First_Position;

   procedure Assert_Identifier
     (Source_Text     : String;
      Token_List      : Tokens.Token_Sequence;
      Index           : Positive;
      Expected_Lexeme : String;
      Message         : String)
   is
      Item : constant Tokens.Token := Tokens.Element (Token_List, Index);
   begin
      AUnit.Assertions.Assert (Item.Kind = Tokens.Identifier, Message & ": kind Identifier");
      AUnit.Assertions.Assert
        (Tokens.Lexeme (Source_Text, Item) = Expected_Lexeme, Message & ": lexeme");
   end Assert_Identifier;

   procedure Assert_Keyword
     (Source_Text : String;
      Token_List  : Tokens.Token_Sequence;
      Index       : Positive;
      Value       : Tokens.Keyword_Subtype;
      Message     : String)
   is
      Item : constant Tokens.Token := Tokens.Element (Token_List, Index);
   begin
      AUnit.Assertions.Assert (Item.Kind = Tokens.Keyword, Message & ": kind Keyword");
      case Item.Kind is
         when Tokens.Keyword =>
            AUnit.Assertions.Assert (Item.Keyword_Value = Value, Message & ": keyword subtype");

         when others =>
            null;
      end case;
      AUnit.Assertions.Assert
        (Tokens.Lexeme (Source_Text, Item)'Length > 0, Message & ": non-empty lexeme");
   end Assert_Keyword;

   procedure Assert_Punctuation
     (Token_List : Tokens.Token_Sequence;
      Index      : Positive;
      Value      : Tokens.Punctuation_Subtype;
      Message    : String)
   is
      Item : constant Tokens.Token := Tokens.Element (Token_List, Index);
   begin
      AUnit.Assertions.Assert (Item.Kind = Tokens.Punctuation, Message & ": kind Punctuation");
      case Item.Kind is
         when Tokens.Punctuation =>
            AUnit.Assertions.Assert (Item.Punctuation_Value = Value, Message & ": punctuation subtype");

         when others =>
            null;
      end case;
   end Assert_Punctuation;

   procedure Assert_Token_Count
     (Token_List : Tokens.Token_Sequence; Expected_Length : Natural; Message : String)
   is
      Actual_Length : constant Natural := Tokens.Length (Token_List);
   begin
      AUnit.Assertions.Assert
        (Actual_Length = Expected_Length,
         Message & ": expected" & Natural'Image (Expected_Length) & " got" & Natural'Image (Actual_Length));
   end Assert_Token_Count;

   function Must_Fail (Source_Text : String; Message : String) return Tokenizer.Tokenizer_Error_Sequence is
      Result : constant Tokenizer.Tokenize_Result := Tokenizer.Tokenize (Source_Text);
   begin
      case Result.Ok is
         when False =>
            return Result.Errors;

         when True =>
            AUnit.Assertions.Assert (False, Message & ": expected errors");
            return Tokenizer.Empty_Error_Sequence;
      end case;
   end Must_Fail;

   function Must_Fail
     (Source_Text : String; Filename : String; Message : String)
      return Tokenizer.Tokenizer_Error_Sequence
   is
      Result : constant Tokenizer.Tokenize_Result := Tokenizer.Tokenize (Source_Text, Filename);
   begin
      case Result.Ok is
         when False =>
            return Result.Errors;

         when True =>
            AUnit.Assertions.Assert (False, Message & ": expected errors");
            return Tokenizer.Empty_Error_Sequence;
      end case;
   end Must_Fail;

   function Must_Succeed (Source_Text : String; Message : String) return Tokens.Token_Sequence is
      Result : constant Tokenizer.Tokenize_Result := Tokenizer.Tokenize (Source_Text);
   begin
      case Result.Ok is
         when True =>
            return Result.Tokens;

         when False =>
            AUnit.Assertions.Assert
              (False,
               Message & ": unexpected errors (" & Natural'Image (Tokenizer.Length (Result.Errors)) & ")");
            return Tokens.Empty_Sequence;
      end case;
   end Must_Succeed;

   function Must_Succeed
     (Source_Text : String; Filename : String; Message : String) return Tokens.Token_Sequence
   is
      Result : constant Tokenizer.Tokenize_Result := Tokenizer.Tokenize (Source_Text, Filename);
   begin
      case Result.Ok is
         when True =>
            return Result.Tokens;

         when False =>
            AUnit.Assertions.Assert
              (False,
               Message & ": unexpected errors (" & Natural'Image (Tokenizer.Length (Result.Errors)) & ")");
            return Tokens.Empty_Sequence;
      end case;
   end Must_Succeed;

   function To_Utf_8 (Point : Wide_Wide_Character) return String is
      Result : constant Lovelace.Common.Utf_8.Encode_Results.Result := Lovelace.Common.Utf_8.Encode (Point);
   begin
      case Result.Ok is
         when True =>
            return Ada.Strings.Unbounded.To_String (Result.Value);

         when False =>
            AUnit.Assertions.Assert
              (False, "UTF-8 encode failed: " & Ada.Strings.Unbounded.To_String (Result.Error.Message));
            return "";
      end case;
   end To_Utf_8;

end Lovelace.Compiler.Tests.Support;
