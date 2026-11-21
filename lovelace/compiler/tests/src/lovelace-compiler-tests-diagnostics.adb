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

   procedure Test_Error_Code_Labels (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Internal_Error) = "LV00001", "LV00001");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unrecognized_Symbol) = "LV00002", "LV00002");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Invalid_Utf_8) = "LV00003", "LV00003");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unexpected_End_Of_Input) = "LV00004", "LV00004");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unexpected_Token) = "LV00005", "LV00005");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unexpected_Trailing) = "LV00006", "LV00006");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unsupported_Type) = "LV00007", "LV00007");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Invalid_Module) = "LV00008", "LV00008");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Program_Name_Filename_Mismatch) = "LV00009", "LV00009");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Source_File_Io) = "LV00010", "LV00010");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Name_Clash) = "LV00011", "LV00011");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Invalid_Flavor_Condition) = "LV00012", "LV00012");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unterminated_String_Literal) = "LV00013", "LV00013");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unresolved_Call) = "LV00014", "LV00014");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Invalid_Arguments) = "LV00015", "LV00015");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unknown_Module) = "LV00016", "LV00016");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Call_Without_Using) = "LV00017", "LV00017");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Not_Exported) = "LV00018", "LV00018");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Circular_Import) = "LV00019", "LV00019");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Ambiguous_Module_Path) = "LV00020", "LV00020");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unknown_Native_Binding) = "LV00021", "LV00021");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unterminated_Comment) = "LV00022", "LV00022");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Nested_Comment) = "LV00023", "LV00023");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Stray_Comment_Closer) = "LV00024", "LV00024");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unknown_Intrinsic) = "LV00025", "LV00025");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Use_Before_Assignment) = "LV00026", "LV00026");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Type_Mismatch) = "LV00027", "LV00027");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unused_Variable) = "LV00028", "LV00028");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Unused_Assignment) = "LV00029", "LV00029");
      AUnit.Assertions.Assert (Error_Codes.Label (Error_Codes.Invalid_Warning_Suppression) = "LV00030", "LV00030");
   end Test_Error_Code_Labels;

   procedure Test_Format_Shape (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program Hello; begin end.";
      Span        : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 9, Line => 1, Column => 9), Last => (Byte_Index => 13, Line => 1, Column => 13));
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
      AUnit.Assertions.Assert (Reporting.Love_Basename ("Hello.love") = "Hello", "simple");
      AUnit.Assertions.Assert (Reporting.Love_Basename ("samples/program/Hello.love") = "Hello", "with directory");
      AUnit.Assertions.Assert (Reporting.Love_Basename ("Hello") = "Hello", "no suffix");
      AUnit.Assertions.Assert (Reporting.Love_Basename ("Foo.Bar.love") = "Foo.Bar", "dotted stem");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("samples/module/Foo.Bar.love") = "Foo.Bar", "dotted with directory");
   end Test_Love_Basename;

   procedure Test_Severity_Policy (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      use type Error_Codes.Severity;
      The_Policy : Lovelace.Compiler.Diagnostics.Policy := Lovelace.Compiler.Diagnostics.Default_Policy;
      Ok         : Boolean;
      Span       : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1));
   begin
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Unused_Variable) = Error_Codes.Warning,
         "unused variable is warning");
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Unused_Assignment) = Error_Codes.Warning,
         "unused assignment is warning");
      AUnit.Assertions.Assert
        (Error_Codes.Default_Severity (Error_Codes.Use_Before_Assignment) = Error_Codes.Error,
         "use before assignment is error");
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Effective_Severity (Error_Codes.Unused_Variable, The_Policy)
         = Error_Codes.Warning,
         "effective warning");

      Lovelace.Compiler.Diagnostics.Set_Promote_Warnings (The_Policy, True);
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Effective_Severity (Error_Codes.Unused_Variable, The_Policy) = Error_Codes.Error,
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
           (Text'Length >= 8 and then Text (Text'First .. Text'First + 7) = "[error] ", "promoted prints as error");
      end;

      The_Policy := Lovelace.Compiler.Diagnostics.Default_Policy;
      Lovelace.Compiler.Diagnostics.Suppress_Warning (The_Policy, Error_Codes.Unused_Variable, Ok);
      AUnit.Assertions.Assert (Ok, "suppress warning ok");
      AUnit.Assertions.Assert
        (Lovelace.Compiler.Diagnostics.Is_Suppressed (The_Policy, Error_Codes.Unused_Variable), "suppressed");
      Lovelace.Compiler.Diagnostics.Suppress_Warning (The_Policy, Error_Codes.Name_Clash, Ok);
      AUnit.Assertions.Assert (not Ok, "cannot suppress error code");
   end Test_Severity_Policy;

   procedure Test_Stage_Mappings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      use type Error_Codes.Error_Code;
   begin
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unrecognized_Symbol) = Error_Codes.Unrecognized_Symbol, "tokenizer map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unterminated_String_Literal) = Error_Codes.Unterminated_String_Literal,
         "unterminated string map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unterminated_Comment) = Error_Codes.Unterminated_Comment,
         "unterminated comment map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Nested_Comment) = Error_Codes.Nested_Comment, "nested comment map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Stray_Comment_Closer) = Error_Codes.Stray_Comment_Closer,
         "stray comment closer map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Parser.Unexpected_Trailing) = Error_Codes.Unexpected_Trailing, "parser map");
      AUnit.Assertions.Assert (Reporting.To_Error_Code (Parser.Name_Clash) = Error_Codes.Name_Clash, "name clash map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Parser.Invalid_Flavor_Condition) = Error_Codes.Invalid_Flavor_Condition,
         "invalid flavor map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Unresolved_Call) = Error_Codes.Unresolved_Call, "unresolved call map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Invalid_Arguments) = Error_Codes.Invalid_Arguments,
         "invalid arguments map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Call_Without_Using) = Error_Codes.Call_Without_Using,
         "call without using map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Not_Exported) = Error_Codes.Not_Exported, "not exported map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Unknown_Native_Binding) = Error_Codes.Unknown_Native_Binding,
         "unknown native binding map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Ir_Generator.Unknown_Intrinsic) = Error_Codes.Unknown_Intrinsic,
         "unknown intrinsic map");
   end Test_Stage_Mappings;

   procedure Test_Unit_Kind_Label (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Module : constant Ast.Module := Support.Must_Parse ("program Hello; begin end.", "kind program");
      Module_Unit    : constant Ast.Module := Support.Must_Parse ("module Empty; end.", "kind module");
   begin
      AUnit.Assertions.Assert (Reporting.Unit_Kind_Label (Program_Module) = "program", "program label");
      AUnit.Assertions.Assert (Reporting.Unit_Kind_Label (Module_Unit) = "module", "module label");
   end Test_Unit_Kind_Label;

   procedure Test_Unit_Name_Matches_File (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Module : constant Ast.Module := Support.Must_Parse ("program Hello; begin end.", "parse program");
      Module_Unit    : constant Ast.Module := Support.Must_Parse ("module Foo.Bar; end.", "parse module");
   begin
      AUnit.Assertions.Assert (Reporting.Unit_Name_Matches_File (Program_Module, "Hello.love"), "program match");
      AUnit.Assertions.Assert (not Reporting.Unit_Name_Matches_File (Program_Module, "Other.love"), "program mismatch");
      AUnit.Assertions.Assert (Reporting.Unit_Name_Matches_File (Module_Unit, "Foo.Bar.love"), "module match");
      AUnit.Assertions.Assert
        (Reporting.Unit_Name_Matches_File (Module_Unit, "samples/module/Foo.Bar.love"), "module match path");
      AUnit.Assertions.Assert (not Reporting.Unit_Name_Matches_File (Module_Unit, "Foo.love"), "module mismatch");
   end Test_Unit_Name_Matches_File;

end Lovelace.Compiler.Tests.Diagnostics;
