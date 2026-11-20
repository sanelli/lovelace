with Lovelace.Common.Tests.Support;

package body Lovelace.Common.Tests.Token_Classes is

   Block_Comment_Pattern : constant String := "\{[^}]*\}";

   Character_Literal_Pattern : constant String := "'([^'\\]|\\[\\n""'erf]|\\u\{[0-9A-Fa-f]+\})'";

   Combined_String_Pattern : constant String := "\$@""([^""{]|\{" & Identifier_Pattern & "\})*""";

   Interpolated_String_Pattern : constant String := "\$""([^""{" & ASCII.LF & "]|\{" & Identifier_Pattern & "\})*""";

   Keyword_Pattern : constant String :=
     "program|function|procedure|begin|end|const|vars|declare|and|or|not|if|then|else|loop|for";

   Multiline_String_Pattern : constant String := "@""[^""]*""";

   Operator_Pattern : constant String := "\+|-|\*|/|%";

   Parenthesis_Pattern : constant String := "\(|\)|\[|\]|<|>";

   Punctuation_Pattern : constant String := ";|,|\.";

   Single_Line_String_Pattern : constant String := """([^""\\" & ASCII.LF & "]|\\[\\n""'erf]|\\u\{[0-9A-Fa-f]+\})*""";

   procedure Test_Block_Comments (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Spanning : constant String := "{" & ASCII.LF & " note " & ASCII.LF & "}";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Block_Comment_Pattern,
         Input           => "{ hi }code",
         From            => 1,
         Expected_Length => 6,
         Message         => "block comment");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Block_Comment_Pattern,
         Input           => Spanning & "x",
         From            => 1,
         Expected_Length => Spanning'Length,
         Message         => "block comment spanning lines");
   end Test_Block_Comments;

   procedure Test_Character_Literals (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Emoji_Literal : constant String :=
        "'" & Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#)) & "'";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Character_Literal_Pattern, Input => "'a';", From => 1, Expected_Length => 3, Message => "char a");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Character_Literal_Pattern,
         Input           => Emoji_Literal & ";",
         From            => 1,
         Expected_Length => Emoji_Literal'Length,
         Message         => "char emoji");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Character_Literal_Pattern,
         Input           => "'" & "\u{1F680}" & "';",
         From            => 1,
         Expected_Length => 11,
         Message         => "char unicode escape");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Character_Literal_Pattern,
         Input           => "'" & "\n" & "';",
         From            => 1,
         Expected_Length => 4,
         Message         => "char escape n");
   end Test_Character_Literals;

   procedure Test_Combined_Strings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Hole     : constant String := Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#)) & "go";
      Combined : constant String := "$@""" & "hi {" & Hole & "}" & ASCII.LF & "there" & """";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Combined_String_Pattern,
         Input           => Combined & ";",
         From            => 1,
         Expected_Length => Combined'Length,
         Message         => "combined multiline interpolated string");
   end Test_Combined_Strings;

   procedure Test_Identifiers (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe      : constant String := "caf" & Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#E9#));
      Rocket_Go : constant String :=
        Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#)) & "go";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Identifier_Pattern,
         Input           => "name;",
         From            => 1,
         Expected_Length => 4,
         Message         => "ascii identifier");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Identifier_Pattern,
         Input           => Cafe & ";",
         From            => 1,
         Expected_Length => Cafe'Length,
         Message         => "cafe identifier");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Identifier_Pattern,
         Input           => Rocket_Go & ";",
         From            => 1,
         Expected_Length => Rocket_Go'Length,
         Message         => "emoji identifier");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Identifier_Pattern,
         Input           => "a+b",
         From            => 1,
         Expected_Length => 1,
         Message         => "identifier glued before plus");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Identifier_Pattern,
         Input           => "a + b",
         From            => 1,
         Expected_Length => 1,
         Message         => "identifier before space");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Identifier_Pattern,
         Input           => "9abc",
         From            => 1,
         Expected_Length => 0,
         Message         => "reject digit start");
   end Test_Identifiers;

   procedure Test_Interpolated_Strings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Interpolated : constant String := "$""hello {name}!""";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Interpolated_String_Pattern,
         Input           => Interpolated & ";",
         From            => 1,
         Expected_Length => Interpolated'Length,
         Message         => "interpolated string");
   end Test_Interpolated_Strings;

   procedure Test_Keywords (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Keyword_Pattern, Input => "program", From => 1, Expected_Length => 7, Message => "program alone");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Keyword_Pattern,
         Input           => "program begin",
         From            => 1,
         Expected_Length => 7,
         Message         => "program then space");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Keyword_Pattern,
         Input           => "program" & ASCII.HT & "begin",
         From            => 1,
         Expected_Length => 7,
         Message         => "program then tab");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Keyword_Pattern,
         Input           => "xprogram",
         From            => 2,
         Expected_Length => 7,
         Message         => "program glued after x");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Keyword_Pattern, Input => "function", From => 1, Expected_Length => 8, Message => "function");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Keyword_Pattern, Input => "for", From => 1, Expected_Length => 3, Message => "for");
   end Test_Keywords;

   procedure Test_Multiline_Strings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Multiline : constant String := "@""" & "line1" & ASCII.LF & "line2" & """";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Multiline_String_Pattern,
         Input           => Multiline & ";",
         From            => 1,
         Expected_Length => Multiline'Length,
         Message         => "multiline string");
   end Test_Multiline_Strings;

   procedure Test_Operators (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Operator_Pattern, Input => "a+b", From => 2, Expected_Length => 1, Message => "plus glued");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Operator_Pattern, Input => "a + b", From => 3, Expected_Length => 1, Message => "plus spaced");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Operator_Pattern, Input => "a-b", From => 2, Expected_Length => 1, Message => "minus");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Operator_Pattern, Input => "a*b", From => 2, Expected_Length => 1, Message => "star op");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Operator_Pattern, Input => "a/b", From => 2, Expected_Length => 1, Message => "slash");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Operator_Pattern, Input => "a%b", From => 2, Expected_Length => 1, Message => "percent");
   end Test_Operators;

   procedure Test_Parentheses (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Parenthesis_Pattern, Input => "(a)", From => 1, Expected_Length => 1, Message => "open paren");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Parenthesis_Pattern, Input => "(a)", From => 3, Expected_Length => 1, Message => "close paren");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Parenthesis_Pattern, Input => "[a]", From => 1, Expected_Length => 1, Message => "open bracket");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Parenthesis_Pattern, Input => "<a>", From => 1, Expected_Length => 1, Message => "less-than");
   end Test_Parentheses;

   procedure Test_Punctuation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Punctuation_Pattern, Input => "a;b", From => 2, Expected_Length => 1, Message => "semicolon");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Punctuation_Pattern, Input => "a,b", From => 2, Expected_Length => 1, Message => "comma");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Punctuation_Pattern, Input => "a.b", From => 2, Expected_Length => 1, Message => "dot");
   end Test_Punctuation;

   procedure Test_Single_Line_Strings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Backslash_Escape : constant String := """a\\\\b""";
      --  "a\\b"
      Newline_Escape   : constant String := """hi\\n""";
      --  "hi\n"
      Quote_Escape     : constant String := '"' & "x\" & '"' & "y" & '"';
      --  "x\"y"
      Unicode_Escape   : constant String := '"' & "\u{1F680}" & '"';
      --  "\u{1F680}"
      With_Newline     : constant String := """hello" & ASCII.LF & "world""";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => """hi"";",
         From            => 1,
         Expected_Length => 4,
         Message         => "simple string");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => Backslash_Escape & ";",
         From            => 1,
         Expected_Length => Backslash_Escape'Length,
         Message         => "string backslash escape");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => Newline_Escape & ";",
         From            => 1,
         Expected_Length => Newline_Escape'Length,
         Message         => "string newline escape");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => Quote_Escape & ";",
         From            => 1,
         Expected_Length => Quote_Escape'Length,
         Message         => "string quote escape");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => Unicode_Escape & ";",
         From            => 1,
         Expected_Length => Unicode_Escape'Length,
         Message         => "string unicode escape");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => """\e\r\f"";",
         From            => 1,
         Expected_Length => 8,
         Message         => "string e r f escapes");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Single_Line_String_Pattern,
         Input           => With_Newline,
         From            => 1,
         Expected_Length => 0,
         Message         => "reject unescaped newline in string");
   end Test_Single_Line_Strings;

end Lovelace.Common.Tests.Token_Classes;
