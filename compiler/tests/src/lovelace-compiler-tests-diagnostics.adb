with AUnit.Assertions;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Diagnostics;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Reporting;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokenizer;

package body Lovelace.Compiler.Tests.Diagnostics is

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
   end Test_Error_Code_Labels;

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
        "[err] Hello.love:1,9"
        & ASCII.LF
        & "program Hello; begin end."
        & ASCII.LF
        & "        ^^^^^"
        & ASCII.LF
        & "[LV00009] program name does not match file name"
        & ASCII.LF;
   begin
      AUnit.Assertions.Assert (Formatted = Expected, "diagnostic shape");
   end Test_Format_Shape;

   procedure Test_Love_Basename (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("Hello.love") = "Hello", "simple");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("samples/Hello.love") = "Hello",
         "with directory");
      AUnit.Assertions.Assert
        (Reporting.Love_Basename ("Hello") = "Hello", "no suffix");
   end Test_Love_Basename;

   procedure Test_Program_Name_Matches_File (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program Hello; begin end.";
      The_Module  : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "parse");
   begin
      AUnit.Assertions.Assert
        (Reporting.Program_Name_Matches_File (The_Module, "Hello.love"),
         "match");
      AUnit.Assertions.Assert
        (not Reporting.Program_Name_Matches_File (The_Module, "Other.love"),
         "mismatch");
   end Test_Program_Name_Matches_File;

   procedure Test_Stage_Mappings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      use type Error_Codes.Error_Code;
   begin
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Tokenizer.Unrecognized_Symbol)
         = Error_Codes.Unrecognized_Symbol,
         "tokenizer map");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Parser.Unexpected_Trailing)
         = Error_Codes.Unexpected_Trailing,
         "parser map");
   end Test_Stage_Mappings;

end Lovelace.Compiler.Tests.Diagnostics;
