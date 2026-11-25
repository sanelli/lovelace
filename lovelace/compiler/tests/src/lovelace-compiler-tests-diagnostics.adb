with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Diagnostics;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Ir_Generator;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Reporting;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokenizer;

package body Lovelace.Compiler.Tests.Diagnostics is

   function Block
     (Line_Text   : String;
      Line        : Positive;
      Column      : Positive;
      Caret       : String;
      Source_Text : String) return String;
   --  Format Source_Text at Line / Column for Name_Clash; return "" when the text equals the
   --  expected four-line block (Line_Text under the header, Caret line), else the actual text.

   function Block
     (Line_Text   : String;
      Line        : Positive;
      Column      : Positive;
      Caret       : String;
      Source_Text : String) return String
   is
      Span     : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => Line, Column => Column),
         Last  => (Byte_Index => 1, Line => Line, Column => Column));
      Text     : constant String :=
        Lovelace.Compiler.Diagnostics.Format
          (Filename    => "F.love",
           Span        => Span,
           Source_Text => Source_Text,
           Code        => Error_Codes.Name_Clash,
           Description => "d");
      Expected : constant String :=
        "[error] F.love:"
        & Ada.Strings.Fixed.Trim (Positive'Image (Line), Ada.Strings.Left)
        & ","
        & Ada.Strings.Fixed.Trim (Positive'Image (Column), Ada.Strings.Left)
        & ASCII.LF
        & Line_Text
        & ASCII.LF
        & Caret
        & ASCII.LF
        & "[LV00011] d"
        & ASCII.LF;
   begin
      return (if Text = Expected then "" else Text);
   end Block;

   procedure Test_Error_Code_Labels (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Internal_Error) = "LV00001",
         "LV00001");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unrecognized_Symbol) = "LV00002",
         "LV00002");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Invalid_Utf_8) = "LV00003", "LV00003");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unexpected_End_Of_Input) = "LV00004",
         "LV00004");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unexpected_Token) = "LV00005",
         "LV00005");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unexpected_Trailing) = "LV00006",
         "LV00006");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unsupported_Type) = "LV00007",
         "LV00007");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Invalid_Module) = "LV00008",
         "LV00008");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Program_Name_Filename_Mismatch)
         = "LV00009",
         "LV00009");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Source_File_Io) = "LV00010",
         "LV00010");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Name_Clash) = "LV00011", "LV00011");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Invalid_Flavor_Condition) = "LV00012",
         "LV00012");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unterminated_String_Literal)
         = "LV00013",
         "LV00013");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unresolved_Call) = "LV00014",
         "LV00014");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Invalid_Arguments) = "LV00015",
         "LV00015");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unknown_Module) = "LV00016",
         "LV00016");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Call_Without_Using) = "LV00017",
         "LV00017");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Not_Exported) = "LV00018", "LV00018");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Circular_Import) = "LV00019",
         "LV00019");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Ambiguous_Module_Path) = "LV00020",
         "LV00020");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unknown_Native_Binding) = "LV00021",
         "LV00021");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unterminated_Comment) = "LV00022",
         "LV00022");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Nested_Comment) = "LV00023",
         "LV00023");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Stray_Comment_Closer) = "LV00024",
         "LV00024");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unknown_Intrinsic) = "LV00025",
         "LV00025");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Use_Before_Assignment) = "LV00026",
         "LV00026");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Type_Mismatch) = "LV00027", "LV00027");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unused_Variable) = "LV00028",
         "LV00028");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unused_Assignment) = "LV00029",
         "LV00029");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Invalid_Warning_Suppression)
         = "LV00030",
         "LV00030");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unresolved_Name) = "LV00031",
         "LV00031");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Unused_Using) = "LV00032", "LV00032");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Ambiguous_Call) = "LV00033",
         "LV00033");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Error_Codes.Invalid_Module_Version) = "LV00034",
         "LV00034");
   end Test_Error_Code_Labels;

   procedure Test_Format_Inverted_Span (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Span     : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 5, Line => 1, Column => 5),
         Last  => (Byte_Index => 2, Line => 1, Column => 2));
      Text     : constant String :=
        Lovelace.Compiler.Diagnostics.Format
          (Filename    => "F.love",
           Span        => Span,
           Source_Text => "abcdef",
           Code        => Error_Codes.Name_Clash,
           Description => "d");
      Expected : constant String :=
        "[error] F.love:1,5"
        & ASCII.LF
        & "abcdef"
        & ASCII.LF
        & "    ^"
        & ASCII.LF
        & "[LV00011] d"
        & ASCII.LF;
   begin
      AUnit.Assertions.Assert
        (Text = Expected,
         "inverted span uses a single caret at the start column");
   end Test_Format_Inverted_Span;

   procedure Test_Format_Line_Endings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Line_Feed       : constant Character := ASCII.LF;
      Carriage_Return : constant Character := ASCII.CR;
      Bad_Byte        : constant Character := Character'Val (16#FF#);
      Lead_Byte       : constant Character := Character'Val (16#C3#);
      Cont_Byte       : constant Character := Character'Val (16#A9#);
   begin
      AUnit.Assertions.Assert
        (Block ("ab", 1, 1, "^", "ab" & Line_Feed & "cd" & Line_Feed & "ef")
         = "",
         "Line_Feed line 1");
      AUnit.Assertions.Assert
        (Block ("cd", 2, 2, " ^", "ab" & Line_Feed & "cd" & Line_Feed & "ef")
         = "",
         "Line_Feed line 2");
      AUnit.Assertions.Assert
        (Block ("ef", 3, 1, "^", "ab" & Line_Feed & "cd" & Line_Feed & "ef")
         = "",
         "Line_Feed last line");
      AUnit.Assertions.Assert
        (Block ("cd", 2, 1, "^", "ab" & Carriage_Return & Line_Feed & "cd")
         = "",
         "CRLF line 2");
      AUnit.Assertions.Assert
        (Block ("cd", 2, 1, "^", "ab" & Carriage_Return & "cd") = "",
         "Carriage_Return line 2");
      AUnit.Assertions.Assert
        (Block
           ("cd", 3, 1, "^", "ab" & Carriage_Return & Carriage_Return & "cd")
         = "",
         "Carriage_Return Carriage_Return line 3");
      AUnit.Assertions.Assert
        (Block ("", 2, 1, "^", "ab" & Line_Feed) = "",
         "empty line after trailing Line_Feed");
      AUnit.Assertions.Assert
        (Block ("", 3, 1, "^", "ab" & Line_Feed) = "",
         "line past end of source");
      AUnit.Assertions.Assert
        (Block ("", 1, 1, "^", "") = "", "empty source line 1");
      AUnit.Assertions.Assert
        (Block ("", 2, 1, "^", "") = "", "empty source line 2");
      AUnit.Assertions.Assert
        (Block ("cd", 2, 1, "^", "a" & Bad_Byte & "b" & Line_Feed & "cd") = "",
         "invalid byte skipped");
      AUnit.Assertions.Assert
        (Block
           ("a" & Bad_Byte & "b",
            1,
            1,
            "^",
            "a" & Bad_Byte & "b" & Line_Feed & "cd")
         = "",
         "invalid byte kept");
      AUnit.Assertions.Assert
        (Block
           ("yy", 2, 1, "^", "x" & Lead_Byte & Cont_Byte & Line_Feed & "yy")
         = "",
         "valid two-byte character");
      AUnit.Assertions.Assert
        (Block ("yy", 2, 1, "^", "x" & Lead_Byte & Line_Feed & "yy") = "",
         "truncated two-byte character");
   end Test_Format_Line_Endings;

   procedure Test_Format_Shape (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program Hello; begin end.";
      Span        : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 9, Line => 1, Column => 9),
         Last  => (Byte_Index => 13, Line => 1, Column => 13));
      Formatted   : constant String :=
        Lovelace.Compiler.Diagnostics.Format
          (Filename    => "Hello.love",
           Span        => Span,
           Source_Text => Source_Text,
           Code        => Error_Codes.Program_Name_Filename_Mismatch,
           Description => "program name does not match file name");
      Expected    : constant String :=
        "[error] Hello.love:1,9"
        & ASCII.LF
        & "program Hello; begin end."
        & ASCII.LF
        & "        ^^^^^"
        & ASCII.LF
        & "[LV00009] program name does not match file name"
        & ASCII.LF;
      Warn_Fmt    : constant String :=
        Lovelace.Compiler.Diagnostics.Format
          (Filename    => "Hello.love",
           Span        => Span,
           Source_Text => Source_Text,
           Code        => Error_Codes.Unused_Variable,
           Description => "local X is never read");
      Warn_Exp    : constant String :=
        "[warning] Hello.love:1,9"
        & ASCII.LF
        & "program Hello; begin end."
        & ASCII.LF
        & "        ^^^^^"
        & ASCII.LF
        & "[LV00028] local X is never read"
        & ASCII.LF;
   begin
      AUnit.Assertions.Assert (Formatted = Expected, "diagnostic shape");
      AUnit.Assertions.Assert (Warn_Fmt = Warn_Exp, "warning shape");
   end Test_Format_Shape;

   procedure Test_Love_Basename (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("Hello.love") = "Hello", "simple");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("samples/program/Hello.love") = "Hello",
         "with directory");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("Hello") = "Hello", "no suffix");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("Foo.Bar.love") = "Foo.Bar", "dotted stem");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("samples/module/Foo.Bar.love") = "Foo.Bar",
         "dotted with directory");
   end Test_Love_Basename;

   procedure Test_Policy_Accessors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      use type Ada.Strings.Unbounded.Unbounded_String;
      The_Policy : Lovelace.Compiler.Diagnostics.Policy :=
        Lovelace.Compiler.Diagnostics.Default_Policy;
      Ok         : Boolean;
      Span       : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 1, Line => 1, Column => 1));
   begin
      AUnit.Assertions.Assert
        (not Lovelace.Compiler.Diagnostics.Promote_Warnings (The_Policy),
         "default no promote");
      Lovelace.Compiler.Diagnostics.Set_Promote_Warnings (The_Policy, True);
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Promote_Warnings (The_Policy),
         "promote enabled");
      Lovelace.Compiler.Diagnostics.Set_Promote_Warnings (The_Policy, False);
      AUnit.Assertions.Assert
        (not Lovelace.Compiler.Diagnostics.Promote_Warnings (The_Policy),
         "promote disabled");

      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Format_Unbounded
           ("X.love",
            Span,
            "x",
            Error_Codes.Unused_Variable,
            "unused",
            The_Policy)
         = Ada.Strings.Unbounded.To_Unbounded_String
             (Lovelace.Compiler.Diagnostics.Format
                ("X.love",
                 Span,
                 "x",
                 Error_Codes.Unused_Variable,
                 "unused",
                 The_Policy)),
         "Format_Unbounded matches Format");

      Lovelace.Compiler.Diagnostics.Suppress_Warning
        (The_Policy, Error_Codes.Unused_Variable, Ok);
      AUnit.Assertions.Assert (Ok, "first suppress ok");
      Lovelace.Compiler.Diagnostics.Suppress_Warning
        (The_Policy, Error_Codes.Unused_Variable, Ok);
      AUnit.Assertions.Assert (Ok, "repeated suppress ok");
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Is_Suppressed
           (The_Policy, Error_Codes.Unused_Variable),
         "still suppressed");
      AUnit.Assertions.Assert
        (not Lovelace.Compiler.Diagnostics.Is_Suppressed
               (The_Policy, Error_Codes.Unused_Using),
         "other warning not suppressed");
   end Test_Policy_Accessors;

   procedure Test_Severity_Policy (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      use type Error_Codes.Severity;
      The_Policy : Lovelace.Compiler.Diagnostics.Policy :=
        Lovelace.Compiler.Diagnostics.Default_Policy;
      Ok         : Boolean;
      Span       : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 1, Line => 1, Column => 1));
   begin
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Unused_Variable)
         = Error_Codes.Warning,
         "unused variable is warning");
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Unused_Using)
         = Error_Codes.Warning,
         "unused using is warning");
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Unused_Assignment)
         = Error_Codes.Warning,
         "unused assignment is warning");
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Use_Before_Assignment)
         = Error_Codes.Error,
         "use before assignment is error");
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Effective_Severity
           (Error_Codes.Unused_Variable, The_Policy)
         = Error_Codes.Warning,
         "effective warning");

      Lovelace.Compiler.Diagnostics.Set_Promote_Warnings (The_Policy, True);
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Effective_Severity
           (Error_Codes.Unused_Variable, The_Policy)
         = Error_Codes.Error,
         "promoted warning");
      declare
         Text : constant String :=
           Lovelace.Compiler.Diagnostics.Format
             (Filename    => "X.love",
              Span        => Span,
              Source_Text => "x",
              Code        => Error_Codes.Unused_Variable,
              Description => "unused",
              The_Policy  => The_Policy);
      begin
         AUnit.Assertions.Assert
           (Text'Length >= 8
            and then Text (Text'First .. Text'First + 7) = "[error] ",
            "promoted prints as error");
      end;

      The_Policy := Lovelace.Compiler.Diagnostics.Default_Policy;
      Lovelace.Compiler.Diagnostics.Suppress_Warning
        (The_Policy, Error_Codes.Unused_Variable, Ok);
      AUnit.Assertions.Assert (Ok, "suppress warning ok");
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Is_Suppressed
           (The_Policy, Error_Codes.Unused_Variable),
         "suppressed");
      Lovelace.Compiler.Diagnostics.Suppress_Warning
        (The_Policy, Error_Codes.Name_Clash, Ok);
      AUnit.Assertions.Assert (not Ok, "cannot suppress error code");
   end Test_Severity_Policy;

   procedure Test_Stage_Mappings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      use type Error_Codes.Error_Code;
   begin
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unrecognized_Symbol)
         = Error_Codes.Unrecognized_Symbol,
         "tokenizer map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unterminated_String_Literal)
         = Error_Codes.Unterminated_String_Literal,
         "unterminated string map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unterminated_Comment)
         = Error_Codes.Unterminated_Comment,
         "unterminated comment map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Nested_Comment)
         = Error_Codes.Nested_Comment,
         "nested comment map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Stray_Comment_Closer)
         = Error_Codes.Stray_Comment_Closer,
         "stray comment closer map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Parser.Unexpected_Trailing)
         = Error_Codes.Unexpected_Trailing,
         "parser map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Parser.Name_Clash) = Error_Codes.Name_Clash,
         "name clash map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Parser.Invalid_Flavor_Condition)
         = Error_Codes.Invalid_Flavor_Condition,
         "invalid flavor map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Unknown_Native_Binding)
         = Error_Codes.Unknown_Native_Binding,
         "unknown native binding map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Unknown_Intrinsic)
         = Error_Codes.Unknown_Intrinsic,
         "unknown intrinsic map");
   end Test_Stage_Mappings;

   procedure Test_Unit_Kind_Label (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Module : constant Ast.Module :=
        Support.Must_Parse ("program Hello; begin end.", "kind program");
      Module_Unit    : constant Ast.Module :=
        Support.Must_Parse ("module Empty; end.", "kind module");
   begin
      AUnit.Assertions.Assert
        (Reporting.Unit_Kind_Label (Program_Module) = "program",
         "program label");
      AUnit.Assertions.Assert
        (Reporting.Unit_Kind_Label (Module_Unit) = "module", "module label");
   end Test_Unit_Kind_Label;

   procedure Test_Unit_Name_Matches_File (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Module : constant Ast.Module :=
        Support.Must_Parse ("program Hello; begin end.", "parse program");
      Module_Unit    : constant Ast.Module :=
        Support.Must_Parse ("module Foo.Bar; end.", "parse module");
   begin
      AUnit.Assertions.Assert
        (Reporting.Unit_Name_Matches_File (Program_Module, "Hello.love"),
         "program match");
      AUnit.Assertions.Assert
        (not Reporting.Unit_Name_Matches_File (Program_Module, "Other.love"),
         "program mismatch");
      AUnit.Assertions.Assert
        (Reporting.Unit_Name_Matches_File (Module_Unit, "Foo.Bar.love"),
         "module match");
      AUnit.Assertions.Assert
        (Reporting.Unit_Name_Matches_File
           (Module_Unit, "samples/module/Foo.Bar.love"),
         "module match path");
      AUnit.Assertions.Assert
        (not Reporting.Unit_Name_Matches_File (Module_Unit, "Foo.love"),
         "module mismatch");
   end Test_Unit_Name_Matches_File;

end Lovelace.Compiler.Tests.Diagnostics;
