with AUnit.Assertions;

with Lovelace.Common.Source;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokens;
with Lovelace.Compiler.Tokenizer;

package body Lovelace.Compiler.Tests.Tokenizer is

   package Source renames Lovelace.Common.Source;
   package Compiler_Tokenizer renames Lovelace.Compiler.Tokenizer;

   procedure Assert_Program_Begin_End (Source_Text : String; Token_List : Tokens.Token_Sequence; Message : String);

   procedure Assert_Program_Begin_End (Source_Text : String; Token_List : Tokens.Token_Sequence; Message : String) is
   begin
      Support.Assert_Token_Count (Token_List, 4, Message);
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.Program_Keyword, Message & " program");
      Support.Assert_Keyword (Source_Text, Token_List, 2, Tokens.Begin_Keyword, Message & " begin");
      Support.Assert_Keyword (Source_Text, Token_List, 3, Tokens.End_Keyword, Message & " end");
      Support.Assert_Punctuation (Token_List, 4, Tokens.Full_Stop, Message & " full stop");
   end Assert_Program_Begin_End;

   procedure Test_Ascii_Identifiers (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Names      : constant String := "name foo_bar _x foo2";
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
      At_Foo        : constant String := "@foo";
      Foo_At_Bar    : constant String := "foo@bar";
      At_Foo_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (At_Foo, "@foo");
      At_Alone      : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("@", "@ alone");
      Foo_At_Errors : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail (Foo_At_Bar, "foo@bar");
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

   procedure Test_Directive_And_String_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Bare_Hash   : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("#", "bare hash");
      Pragma_Text : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("#pragma", "pragma");
      Quote       : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("""", "quote");
      Open_String : constant Compiler_Tokenizer.Tokenizer_Error_Sequence :=
        Support.Must_Fail ("""hello", "open string");
   begin
      Support.Assert_Error_Count (Bare_Hash, 1, "bare hash");
      Support.Assert_Error_Code (Bare_Hash, 1, Compiler_Tokenizer.Unrecognized_Symbol, "bare hash");
      Support.Assert_Error_Count (Pragma_Text, 1, "pragma");
      Support.Assert_Error_Code (Pragma_Text, 1, Compiler_Tokenizer.Unrecognized_Symbol, "pragma");
      Support.Assert_Error_Count (Quote, 1, "quote");
      Support.Assert_Error_Code (Quote, 1, Compiler_Tokenizer.Unterminated_String_Literal, "quote");
      Support.Assert_Error_Count (Open_String, 1, "open string");
      Support.Assert_Error_Code (Open_String, 1, Compiler_Tokenizer.Unterminated_String_Literal, "open string");
   end Test_Directive_And_String_Errors;

   procedure Test_Directives_And_Strings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "#if #elsif #else #end ""wasi"" = #16#FFs32";
      Token_List  : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "directives strings");
   begin
      Support.Assert_Token_Count (Token_List, 7, "directives strings");
      Support.Assert_Directive (Source_Text, Token_List, 1, Tokens.If_Directive, "#if");
      Support.Assert_Directive (Source_Text, Token_List, 2, Tokens.Elsif_Directive, "#elsif");
      Support.Assert_Directive (Source_Text, Token_List, 3, Tokens.Else_Directive, "#else");
      Support.Assert_Directive (Source_Text, Token_List, 4, Tokens.End_Directive, "#end");
      Support.Assert_String_Literal (Source_Text, Token_List, 5, """wasi""", "string");
      Support.Assert_Punctuation (Token_List, 6, Tokens.Equals, "equals");
      Support.Assert_Integer_Literal (Source_Text, Token_List, 7, "#16#FFs32", "based integer");
   end Test_Directives_And_Strings;

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
      AUnit.Assertions.Assert (Source.Same_Storage (First.Filename, Second.Filename), "errors share filename storage");
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
      AUnit.Assertions.Assert (Source.Same_Storage (First.Filename, Second.Filename), "tokens share filename storage");
   end Test_Filename_Shared_On_Tokens;

   procedure Test_Glued_Punctuation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Glued         : constant String := "end;";
      Spaced        : constant String := "end ;";
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
      Program_Ident  : constant String := "Program";
      Module_Ident   : constant String := "Module";
      Begin_Ident    : constant String := "BEGIN";
      Program_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Program_Ident, "Program");
      Module_Tokens  : constant Tokens.Token_Sequence := Support.Must_Succeed (Module_Ident, "Module");
      Begin_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Begin_Ident, "BEGIN");
   begin
      Support.Assert_Token_Count (Program_Tokens, 1, "Program");
      Support.Assert_Identifier (Program_Ident, Program_Tokens, 1, "Program", "Program");
      Support.Assert_Token_Count (Module_Tokens, 1, "Module");
      Support.Assert_Identifier (Module_Ident, Module_Tokens, 1, "Module", "Module");
      Support.Assert_Token_Count (Begin_Tokens, 1, "BEGIN");
      Support.Assert_Identifier (Begin_Ident, Begin_Tokens, 1, "BEGIN", "BEGIN");
   end Test_Keyword_Case;

   procedure Test_Keyword_Reservation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Programmer        : constant String := "programmer";
      Glued             : constant String := "programbegin";
      Module_X          : constant String := "modulex";
      Modules           : constant String := "modules";
      Programmer_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Programmer, "programmer");
      Glued_Tokens      : constant Tokens.Token_Sequence := Support.Must_Succeed (Glued, "programbegin");
      Module_X_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Module_X, "modulex");
      Modules_Tokens    : constant Tokens.Token_Sequence := Support.Must_Succeed (Modules, "modules");
   begin
      Support.Assert_Token_Count (Programmer_Tokens, 1, "programmer");
      Support.Assert_Identifier (Programmer, Programmer_Tokens, 1, "programmer", "programmer");
      Support.Assert_Token_Count (Glued_Tokens, 1, "programbegin");
      Support.Assert_Identifier (Glued, Glued_Tokens, 1, "programbegin", "programbegin");
      Support.Assert_Token_Count (Module_X_Tokens, 1, "modulex");
      Support.Assert_Identifier (Module_X, Module_X_Tokens, 1, "modulex", "modulex");
      Support.Assert_Token_Count (Modules_Tokens, 1, "modules");
      Support.Assert_Identifier (Modules, Modules_Tokens, 1, "modules", "modules");
   end Test_Keyword_Reservation;

   procedure Test_Leading_Digits (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Two_Source     : constant String := "2";
      Two_Foo_Source : constant String := "2foo";
      Two_Tokens     : constant Tokens.Token_Sequence := Support.Must_Succeed (Two_Source, "2");
      Two_Foo_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Two_Foo_Source, "2foo");
   begin
      Support.Assert_Token_Count (Two_Tokens, 1, "2");
      Support.Assert_Integer_Literal (Two_Source, Two_Tokens, 1, "2", "2");
      Support.Assert_Token_Count (Two_Foo_Tokens, 2, "2foo");
      Support.Assert_Integer_Literal (Two_Foo_Source, Two_Foo_Tokens, 1, "2", "2foo digit");
      Support.Assert_Identifier (Two_Foo_Source, Two_Foo_Tokens, 2, "foo", "2foo ident");
   end Test_Leading_Digits;

   procedure Test_Module_Keyword (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "module";
      Token_List  : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "module keyword");
   begin
      Support.Assert_Token_Count (Token_List, 1, "module keyword");
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.Module_Keyword, "module keyword");
   end Test_Module_Keyword;

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
      Token_List  : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "newline");
   begin
      Support.Assert_Token_Count (Token_List, 2, "newline");
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.End_Keyword, "end");
      Support.Assert_First_Position (Token_List, 1, 1, 1, "end position");
      Support.Assert_Keyword (Source_Text, Token_List, 2, Tokens.Begin_Keyword, "begin");
      Support.Assert_First_Position (Token_List, 2, 2, 1, "begin after newline");
   end Test_Newline_Line_Column;

   procedure Test_Numeric_Literals (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Mixed        : constant String := "10 -8u64 #16#FF 1.5 7. 3.4E3";
      Mixed_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Mixed, "mixed literals");
   begin
      Support.Assert_Token_Count (Mixed_Tokens, 6, "mixed literals");
      Support.Assert_Integer_Literal (Mixed, Mixed_Tokens, 1, "10", "10");
      Support.Assert_Integer_Literal (Mixed, Mixed_Tokens, 2, "-8u64", "-8u64");
      Support.Assert_Integer_Literal (Mixed, Mixed_Tokens, 3, "#16#FF", "#16#FF");
      Support.Assert_Float_Literal (Mixed, Mixed_Tokens, 4, "1.5", "1.5");
      Support.Assert_Float_Literal (Mixed, Mixed_Tokens, 5, "7.", "7.");
      Support.Assert_Float_Literal (Mixed, Mixed_Tokens, 6, "3.4E3", "3.4E3");
   end Test_Numeric_Literals;

   procedure Test_Procedure_Type_Tokens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "procedure integer float signed unsigned ( ) , : < >";
      Token_List  : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "proc type tokens");
   begin
      Support.Assert_Token_Count (Token_List, 11, "proc type tokens");
      Support.Assert_Keyword (Source_Text, Token_List, 1, Tokens.Procedure_Keyword, "procedure");
      Support.Assert_Keyword (Source_Text, Token_List, 2, Tokens.Integer_Keyword, "integer");
      Support.Assert_Keyword (Source_Text, Token_List, 3, Tokens.Float_Keyword, "float");
      Support.Assert_Keyword (Source_Text, Token_List, 4, Tokens.Signed_Keyword, "signed");
      Support.Assert_Keyword (Source_Text, Token_List, 5, Tokens.Unsigned_Keyword, "unsigned");
      Support.Assert_Punctuation (Token_List, 6, Tokens.Left_Parenthesis, "(");
      Support.Assert_Punctuation (Token_List, 7, Tokens.Right_Parenthesis, ")");
      Support.Assert_Punctuation (Token_List, 8, Tokens.Comma, ",");
      Support.Assert_Punctuation (Token_List, 9, Tokens.Colon, ":");
      Support.Assert_Punctuation (Token_List, 10, Tokens.Less_Than, "<");
      Support.Assert_Punctuation (Token_List, 11, Tokens.Greater_Than, ">");
   end Test_Procedure_Type_Tokens;

   procedure Test_Program_Begin_End (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program begin end.";
      Token_List  : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "program begin end.");
   begin
      Assert_Program_Begin_End (Source_Text, Token_List, "program begin end.");
      Support.Assert_First_Position (Token_List, 1, 1, 1, "program");
      Support.Assert_First_Position (Token_List, 2, 1, 9, "begin");
      Support.Assert_First_Position (Token_List, 3, 1, 15, "end");
      Support.Assert_First_Position (Token_List, 4, 1, 18, "full stop");
   end Test_Program_Begin_End;

   procedure Test_Unicode_Identifiers (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe          : constant String := "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Rocket        : constant String := Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#)) & "go";
      Cafe_Tokens   : constant Tokens.Token_Sequence := Support.Must_Succeed (Cafe, "cafe");
      Rocket_Tokens : constant Tokens.Token_Sequence := Support.Must_Succeed (Rocket, "emoji");
      Cafe_Token    : constant Tokens.Token := Tokens.Element (Cafe_Tokens, 1);
   begin
      Support.Assert_Token_Count (Cafe_Tokens, 1, "cafe");
      Support.Assert_Identifier (Cafe, Cafe_Tokens, 1, Cafe, "cafe lexeme");
      AUnit.Assertions.Assert (Cafe_Token.Span.Last.Byte_Index = Cafe'Length, "cafe byte span covers UTF-8");
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
      Plus       : constant Compiler_Tokenizer.Tokenizer_Error_Sequence := Support.Must_Fail ("+", "plus");
      Comma_Text : constant String := ",";
      Comma_List : constant Tokens.Token_Sequence := Support.Must_Succeed (Comma_Text, "comma");
   begin
      Support.Assert_Error_Count (Plus, 1, "plus");
      Support.Assert_Error_Code (Plus, 1, Compiler_Tokenizer.Unrecognized_Symbol, "plus");
      Support.Assert_Token_Count (Comma_List, 1, "comma");
      Support.Assert_Punctuation (Comma_List, 1, Tokens.Comma, "comma punct");
   end Test_Unrecognized_Symbols;

   procedure Test_Whitespace_Kinds (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Nbsp            : constant String := Support.To_Utf_8 (Wide_Wide_Character'Val (16#00A0#));
      Spaced          : constant String := "program begin end.";
      Tabbed          : constant String := "program" & ASCII.HT & "begin" & ASCII.HT & "end.";
      Newlined        : constant String := "program" & ASCII.LF & "begin" & ASCII.CR & "end.";
      Mixed           : constant String := "program " & Nbsp & "begin   end.";
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
