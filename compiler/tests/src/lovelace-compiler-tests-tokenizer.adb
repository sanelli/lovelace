with AUnit.Assertions;

with Lovelace.Compiler.Source;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokens;
with Lovelace.Compiler.Tokenizer;

package body Lovelace.Compiler.Tests.Tokenizer is

   package Compiler_Tokenizer renames Lovelace.Compiler.Tokenizer;

   procedure Assert_Program_Begin_End
     (Source_Text : String; Token_List : Tokens.Token_Sequence; Message : String);

   procedure Assert_Program_Begin_End
     (Source_Text : String; Token_List : Tokens.Token_Sequence; Message : String)
   is
   begin
      Support.Assert_Token_Count (Token_List, 4, Message);
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.Program_Keyword, Message & " program");
      Support.Assert_Keyword (Source_Text, Token_List, 2, Tokens.Begin_Keyword, Message & " begin");
      Support.Assert_Keyword (Source_Text, Token_List, 3, Tokens.End_Keyword, Message & " end");
      Support.Assert_Punctuation (Token_List, 4, Tokens.Full_Stop, Message & " full stop");
   end Assert_Program_Begin_End;

   procedure Test_Ascii_Identifiers (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Names : constant String := "name foo_bar _x foo2";
      Token_List : constant Tokens.Token_Sequence := Support.Must_Succeed (Names, "ascii identifiers");
   begin
      Support.Assert_Token_Count (Token_List, 4, "ascii identifiers");
      Support.Assert_Identifier (Names, Token_List, 1, "name", "name");
      Support.Assert_Identifier (Names, Token_List, 2, "foo_bar", "foo_bar");
      Support.Assert_Identifier (Names, Token_List, 3, "_x", "_x");
      Support.Assert_Identifier (Names, Token_List, 4, "foo2", "foo2");
   end Test_Ascii_Identifiers;

   procedure Test_At_Prefix (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      At_Foo     : constant String := "@foo";
      Foo_At_Bar : constant String := "foo@bar";
      At_Foo_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (At_Foo, "@foo");
      At_Alone      : constant Compiler_Tokenizer.Tokenizer_Error_Sequence :=
        Support.Must_Fail ("@", "@ alone");
      Foo_At_Errors : constant Compiler_Tokenizer.Tokenizer_Error_Sequence :=
        Support.Must_Fail (Foo_At_Bar, "foo@bar");
   begin
      Support.Assert_Token_Count (At_Foo_Tokens, 1, "@foo");
      Support.Assert_Identifier (At_Foo, At_Foo_Tokens, 1, "@foo", "@foo lexeme");
      Support.Assert_Error_Count (At_Alone, 1, "@ alone");
      Support.Assert_Error_Code (At_Alone, 1, Compiler_Tokenizer.Unrecognized_Symbol, "@ alone code");
      Support.Assert_Error_Count (Foo_At_Errors, 1, "foo@bar");
      Support.Assert_Error_Code (Foo_At_Errors, 1, Compiler_Tokenizer.Unrecognized_Symbol, "foo@bar @");
   end Test_At_Prefix;

   procedure Test_Clean_Begin (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "begin";
      Token_List  : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "begin");
   begin
      Support.Assert_Token_Count (Token_List, 1, "begin");
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.Begin_Keyword, "begin");
   end Test_Clean_Begin;

   procedure Test_Empty_And_Whitespace (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Nbsp       : constant String := Support.To_Utf_8 (Wide_Wide_Character'Val (16#00A0#));
      Empty_List : constant Tokens.Token_Sequence := Support.Must_Succeed ("", "empty");
      Spaces     : constant Tokens.Token_Sequence := Support.Must_Succeed ("   ", "ascii spaces");
      Tabs       : constant Tokens.Token_Sequence :=
        Support.Must_Succeed (String'(1 => ASCII.HT, 2 => ASCII.LF, 3 => ASCII.CR), "ascii ws");
      Unicode    : constant Tokens.Token_Sequence := Support.Must_Succeed (Nbsp & " ", "nbsp");
   begin
      Support.Assert_Token_Count (Empty_List, 0, "empty");
      Support.Assert_Token_Count (Spaces, 0, "ascii spaces");
      Support.Assert_Token_Count (Tabs, 0, "ascii ws");
      Support.Assert_Token_Count (Unicode, 0, "nbsp");
   end Test_Empty_And_Whitespace;

   procedure Test_Filename_Omitted (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Token_List : constant Tokens.Token_Sequence := Support.Must_Succeed ("begin", "omitted filename");
      Item       : constant Tokens.Token := Tokens.Element (Token_List, 1);
   begin
      AUnit.Assertions.Assert (not Item.Filename.Present, "omitted filename is absent");
   end Test_Filename_Omitted;

   procedure Test_Filename_Shared_On_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Compiler_Tokenizer.Tokenizer_Error_Sequence :=
        Support.Must_Fail ("+$", "src.love", "filename on errors");
      First  : Compiler_Tokenizer.Tokenizer_Error;
      Second : Compiler_Tokenizer.Tokenizer_Error;
   begin
      Support.Assert_Error_Count (Errors, 2, "filename on errors");
      First := Compiler_Tokenizer.Element (Errors, 1);
      Second := Compiler_Tokenizer.Element (Errors, 2);
      AUnit.Assertions.Assert (First.Filename.Present, "first error has filename");
      AUnit.Assertions.Assert
        (Source.Same_Storage (First.Filename, Second.Filename), "errors share filename storage");
   end Test_Filename_Shared_On_Errors;

   procedure Test_Filename_Shared_On_Tokens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Token_List : constant Tokens.Token_Sequence :=
        Support.Must_Succeed ("begin end", "unit.love", "filename on tokens");
      First      : constant Tokens.Token := Tokens.Element (Token_List, 1);
      Second     : constant Tokens.Token := Tokens.Element (Token_List, 2);
   begin
      Support.Assert_Token_Count (Token_List, 2, "filename on tokens");
      AUnit.Assertions.Assert (First.Filename.Present, "first token has filename");
      AUnit.Assertions.Assert
        (Source.Same_Storage (First.Filename, Second.Filename), "tokens share filename storage");
   end Test_Filename_Shared_On_Tokens;

   procedure Test_Glued_Punctuation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Glued  : constant String := "end;";
      Spaced : constant String := "end ;";
      Glued_Tokens  : constant Tokens.Token_Sequence := Support.Must_Succeed (Glued, "end;");
      Spaced_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Spaced, "end ;");
   begin
      Support.Assert_Token_Count (Glued_Tokens, 2, "end;");
      Support.Assert_Keyword (Glued, Glued_Tokens, 1, Tokens.End_Keyword, "end; keyword");
      Support.Assert_Punctuation (Glued_Tokens, 2, Tokens.Semicolon, "end; semicolon");
      Support.Assert_Token_Count (Spaced_Tokens, 2, "end ;");
      Support.Assert_Keyword (Spaced, Spaced_Tokens, 1, Tokens.End_Keyword, "end ; keyword");
      Support.Assert_Punctuation (Spaced_Tokens, 2, Tokens.Semicolon, "end ; semicolon");
   end Test_Glued_Punctuation;

   procedure Test_Invalid_Utf_8 (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Broken : constant String := Character'Val (16#FF#) & "+";
      Errors : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail (Broken, "invalid utf-8");
   begin
      Support.Assert_Error_Count (Errors, 2, "invalid then plus");
      Support.Assert_Error_Code (Errors, 1, Compiler_Tokenizer.Invalid_Utf_8, "invalid utf-8");
      Support.Assert_Error_Code (Errors, 2, Compiler_Tokenizer.Unrecognized_Symbol, "plus after invalid");
   end Test_Invalid_Utf_8;

   procedure Test_Keyword_Case (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Ident : constant String := "Program";
      Begin_Ident   : constant String := "BEGIN";
      Program_Tokens : constant Tokens.Token_Sequence :=
        Support.Must_Succeed (Program_Ident, "Program");
      Begin_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Begin_Ident, "BEGIN");
   begin
      Support.Assert_Token_Count (Program_Tokens, 1, "Program");
      Support.Assert_Identifier (Program_Ident, Program_Tokens, 1, "Program", "Program");
      Support.Assert_Token_Count (Begin_Tokens, 1, "BEGIN");
      Support.Assert_Identifier (Begin_Ident, Begin_Tokens, 1, "BEGIN", "BEGIN");
   end Test_Keyword_Case;

   procedure Test_Keyword_Reservation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Programmer : constant String := "programmer";
      Glued      : constant String := "programbegin";
      Programmer_Tokens : constant Tokens.Token_Sequence :=
        Support.Must_Succeed (Programmer, "programmer");
      Glued_Tokens      : constant Tokens.Token_Sequence := Support.Must_Succeed (Glued, "programbegin");
   begin
      Support.Assert_Token_Count (Programmer_Tokens, 1, "programmer");
      Support.Assert_Identifier (Programmer, Programmer_Tokens, 1, "programmer", "programmer");
      Support.Assert_Token_Count (Glued_Tokens, 1, "programbegin");
      Support.Assert_Identifier (Glued, Glued_Tokens, 1, "programbegin", "programbegin");
   end Test_Keyword_Reservation;

   procedure Test_Leading_Digits (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Two      : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("2", "2");
      Two_Foo  : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("2foo", "2foo");
   begin
      Support.Assert_Error_Count (Two, 1, "2");
      Support.Assert_Error_Code (Two, 1, Compiler_Tokenizer.Unrecognized_Symbol, "2");
      Support.Assert_Error_Count (Two_Foo, 1, "2foo");
      Support.Assert_Error_Code (Two_Foo, 1, Compiler_Tokenizer.Unrecognized_Symbol, "2foo");
   end Test_Leading_Digits;

   procedure Test_Multi_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Compiler_Tokenizer.Tokenizer_Error_Sequence :=
        Support.Must_Fail ("program + begin $ end.", "multi-error");
   begin
      Support.Assert_Error_Count (Errors, 2, "multi-error");
      Support.Assert_Error_Code (Errors, 1, Compiler_Tokenizer.Unrecognized_Symbol, "plus");
      Support.Assert_Error_Code (Errors, 2, Compiler_Tokenizer.Unrecognized_Symbol, "dollar");
   end Test_Multi_Error;

   procedure Test_Newline_Line_Column (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "end" & ASCII.LF & "begin";
      Token_List  : constant Tokens.Token_Sequence :=
        Support.Must_Succeed (Source_Text, "newline");
   begin
      Support.Assert_Token_Count (Token_List, 2, "newline");
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.End_Keyword, "end");
      Support.Assert_First_Position (Token_List, 1, 1, 1, "end position");
      Support.Assert_Keyword (Source_Text, Token_List, 2, Tokens.Begin_Keyword, "begin");
      Support.Assert_First_Position (Token_List, 2, 2, 1, "begin after newline");
   end Test_Newline_Line_Column;

   procedure Test_Program_Begin_End (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program begin end.";
      Token_List  : constant Tokens.Token_Sequence :=
        Support.Must_Succeed (Source_Text, "program begin end.");
   begin
      Assert_Program_Begin_End (Source_Text, Token_List, "program begin end.");
      Support.Assert_First_Position (Token_List, 1, 1, 1, "program");
      Support.Assert_First_Position (Token_List, 2, 1, 9, "begin");
      Support.Assert_First_Position (Token_List, 3, 1, 15, "end");
      Support.Assert_First_Position (Token_List, 4, 1, 18, "full stop");
   end Test_Program_Begin_End;

   procedure Test_Unicode_Identifiers (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe   : constant String := "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Rocket : constant String := Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#)) & "go";
      Cafe_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Cafe, "cafe");
      Rocket_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Rocket, "emoji");
      Cafe_Token    : constant Tokens.Token := Tokens.Element (Cafe_Tokens, 1);
   begin
      Support.Assert_Token_Count (Cafe_Tokens, 1, "cafe");
      Support.Assert_Identifier (Cafe, Cafe_Tokens, 1, Cafe, "cafe lexeme");
      AUnit.Assertions.Assert
        (Cafe_Token.Span.Last.Byte_Index = Cafe'Length, "cafe byte span covers UTF-8");
      Support.Assert_Token_Count (Rocket_Tokens, 1, "emoji");
      Support.Assert_Identifier (Rocket, Rocket_Tokens, 1, Rocket, "emoji lexeme");
   end Test_Unicode_Identifiers;

   procedure Test_Unrecognized_Identifier_Characters (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Symbols : constant String := "$%^~'?";
   begin
      for Index in Symbols'Range loop
         declare
            Errors : constant Compiler_Tokenizer.Tokenizer_Error_Sequence :=
              Support.Must_Fail (String'(1 => Symbols (Index)), "symbol" & Natural'Image (Index));
         begin
            Support.Assert_Error_Count (Errors, 1, "one symbol");
            Support.Assert_Error_Code (Errors, 1, Compiler_Tokenizer.Unrecognized_Symbol, "symbol code");
         end;
      end loop;
   end Test_Unrecognized_Identifier_Characters;

   procedure Test_Unrecognized_Symbols (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Plus   : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("+", "plus");
      Comma  : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail (",", "comma");
      Quote  : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("""", "quote");
   begin
      Support.Assert_Error_Count (Plus, 1, "plus");
      Support.Assert_Error_Code (Plus, 1, Compiler_Tokenizer.Unrecognized_Symbol, "plus");
      Support.Assert_Error_Count (Comma, 1, "comma");
      Support.Assert_Error_Code (Comma, 1, Compiler_Tokenizer.Unrecognized_Symbol, "comma");
      Support.Assert_Error_Count (Quote, 1, "quote");
      Support.Assert_Error_Code (Quote, 1, Compiler_Tokenizer.Unrecognized_Symbol, "quote");
   end Test_Unrecognized_Symbols;

   procedure Test_Whitespace_Kinds (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Nbsp     : constant String := Support.To_Utf_8 (Wide_Wide_Character'Val (16#00A0#));
      Spaced   : constant String := "program begin end.";
      Tabbed   : constant String := "program" & ASCII.HT & "begin" & ASCII.HT & "end.";
      Newlined : constant String := "program" & ASCII.LF & "begin" & ASCII.CR & "end.";
      Mixed    : constant String := "program " & Nbsp & "begin   end.";
      Spaced_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Spaced, "spaces");
      Tabbed_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Tabbed, "tabs");
      Newlined_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Newlined, "newlines");
      Mixed_Tokens    : constant Tokens.Token_Sequence := Support.Must_Succeed (Mixed, "mixed");
   begin
      Assert_Program_Begin_End (Spaced, Spaced_Tokens, "spaces");
      Assert_Program_Begin_End (Tabbed, Tabbed_Tokens, "tabs");
      Assert_Program_Begin_End (Newlined, Newlined_Tokens, "newlines");
      Assert_Program_Begin_End (Mixed, Mixed_Tokens, "mixed");
   end Test_Whitespace_Kinds;

end Lovelace.Compiler.Tests.Tokenizer;
