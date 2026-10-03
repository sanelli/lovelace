with AUnit.Test_Caller;

with Lovelace.Compiler.Tests.Backend;
with Lovelace.Compiler.Tests.Diagnostics;
with Lovelace.Compiler.Tests.Ir_Generator;
with Lovelace.Compiler.Tests.Literals;
with Lovelace.Compiler.Tests.Parser;
with Lovelace.Compiler.Tests.Tokenizer;

package body Lovelace.Compiler.Tests.Suite is

   package Backend_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Backend.Fixture);
   package Diagnostics_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Diagnostics.Fixture);
   package Ir_Generator_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Ir_Generator.Fixture);
   package Literals_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Literals.Fixture);
   package Parser_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Parser.Fixture);
   package Tokenizer_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Tokenizer.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: empty and whitespace",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Empty_And_Whitespace'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: program begin end",
            Lovelace.Compiler.Tests.Tokenizer.Test_Program_Begin_End'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: whitespace kinds",
            Lovelace.Compiler.Tests.Tokenizer.Test_Whitespace_Kinds'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: glued punctuation",
            Lovelace.Compiler.Tests.Tokenizer.Test_Glued_Punctuation'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: keyword case",
            Lovelace.Compiler.Tests.Tokenizer.Test_Keyword_Case'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: keyword reservation",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Keyword_Reservation'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: module keyword",
            Lovelace.Compiler.Tests.Tokenizer.Test_Module_Keyword'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: ascii identifiers",
            Lovelace.Compiler.Tests.Tokenizer.Test_Ascii_Identifiers'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: leading digits rejected",
            Lovelace.Compiler.Tests.Tokenizer.Test_Leading_Digits'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: numeric literals",
            Lovelace.Compiler.Tests.Tokenizer.Test_Numeric_Literals'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: procedure type tokens",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Procedure_Type_Tokens'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: unicode identifiers",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Unicode_Identifiers'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: at-prefix identifiers",
            Lovelace.Compiler.Tests.Tokenizer.Test_At_Prefix'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: unrecognized identifier characters",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Unrecognized_Identifier_Characters'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: newline line and column",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Newline_Line_Column'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: filename omitted",
            Lovelace.Compiler.Tests.Tokenizer.Test_Filename_Omitted'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: filename shared on tokens",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Filename_Shared_On_Tokens'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: filename shared on errors",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Filename_Shared_On_Errors'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: unrecognized symbols",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Unrecognized_Symbols'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: multi-error",
            Lovelace.Compiler.Tests.Tokenizer.Test_Multi_Error'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: invalid utf-8",
            Lovelace.Compiler.Tests.Tokenizer.Test_Invalid_Utf_8'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: clean begin",
            Lovelace.Compiler.Tests.Tokenizer.Test_Clean_Begin'Access));

      Result.Add_Test
        (Parser_Caller.Create
           ("parser: canonical module",
            Lovelace.Compiler.Tests.Parser.Test_Canonical_Module'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: canonical multiline",
            Lovelace.Compiler.Tests.Parser.Test_Canonical_Multiline'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: dotted module name",
            Lovelace.Compiler.Tests.Parser.Test_Dotted_Module_Name'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: empty tokens",
            Lovelace.Compiler.Tests.Parser.Test_Empty_Tokens'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: end semicolon",
            Lovelace.Compiler.Tests.Parser.Test_End_Semicolon'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: identifier names",
            Lovelace.Compiler.Tests.Parser.Test_Identifier_Names'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: module begin rejected",
            Lovelace.Compiler.Tests.Parser.Test_Module_Begin_Rejected'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: module keyword case",
            Lovelace.Compiler.Tests.Parser.Test_Module_Keyword_Case'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: module trailing dot",
            Lovelace.Compiler.Tests.Parser.Test_Module_Trailing_Dot'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: module whitespace",
            Lovelace.Compiler.Tests.Parser.Test_Module_Whitespace'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: trailing and keyword case",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Trailing_And_Keyword_Case'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: whitespace variants",
            Lovelace.Compiler.Tests.Parser.Test_Whitespace_Variants'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: wrong order and incomplete",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Wrong_Order_And_Incomplete'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: module procedure",
            Lovelace.Compiler.Tests.Parser.Test_Module_Procedure'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: duplicate parameter",
            Lovelace.Compiler.Tests.Parser.Test_Duplicate_Parameter'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: bad type size",
            Lovelace.Compiler.Tests.Parser.Test_Bad_Type_Size'Access));

      Result.Add_Test
        (Literals_Caller.Create
           ("literals: integer forms",
            Lovelace.Compiler.Tests.Literals.Test_Integer_Forms'Access));
      Result.Add_Test
        (Literals_Caller.Create
           ("literals: float forms",
            Lovelace.Compiler.Tests.Literals.Test_Float_Forms'Access));
      Result.Add_Test
        (Literals_Caller.Create
           ("literals: invalid integer",
            Lovelace.Compiler.Tests.Literals.Test_Invalid_Integer'Access));

      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: canonical multiline",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Canonical_Multiline'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: dotted module name",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Dotted_Module_Name'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: empty module",
            Lovelace.Compiler.Tests.Ir_Generator.Test_Empty_Module'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: export-only flags",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Export_Only_Flags'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: filename shared",
            Lovelace.Compiler.Tests.Ir_Generator.Test_Filename_Shared'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: identifier names",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Identifier_Names'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: module procedure parameters",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Module_Procedure_Parameters'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: parameter type mapping",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Parameter_Type_Mapping'Access));

      Result.Add_Test
        (Backend_Caller.Create
           ("backend: export only",
            Lovelace.Compiler.Tests.Backend.Test_Export_Only'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: entrypoint",
            Lovelace.Compiler.Tests.Backend.Test_Entrypoint'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: entrypoint and export",
            Lovelace
              .Compiler
              .Tests
              .Backend
              .Test_Entrypoint_And_Export'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: two exports",
            Lovelace.Compiler.Tests.Backend.Test_Two_Exports'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: noop body",
            Lovelace.Compiler.Tests.Backend.Test_Noop_Body'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: typed parameters",
            Lovelace.Compiler.Tests.Backend.Test_Typed_Parameters'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: unsupported type",
            Lovelace.Compiler.Tests.Backend.Test_Unsupported_Type'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: invalid module",
            Lovelace.Compiler.Tests.Backend.Test_Invalid_Module'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: wasm component preamble",
            Lovelace
              .Compiler
              .Tests
              .Backend
              .Test_Wasm_Component_Preamble'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: wasm wit equality",
            Lovelace.Compiler.Tests.Backend.Test_Wasm_Wit_Equality'Access));

      Result.Add_Test
        (Diagnostics_Caller.Create
           ("diagnostics: error code labels",
            Lovelace
              .Compiler
              .Tests
              .Diagnostics
              .Test_Error_Code_Labels'Access));
      Result.Add_Test
        (Diagnostics_Caller.Create
           ("diagnostics: format shape",
            Lovelace.Compiler.Tests.Diagnostics.Test_Format_Shape'Access));
      Result.Add_Test
        (Diagnostics_Caller.Create
           ("diagnostics: love basename",
            Lovelace.Compiler.Tests.Diagnostics.Test_Love_Basename'Access));
      Result.Add_Test
        (Diagnostics_Caller.Create
           ("diagnostics: stage mappings",
            Lovelace.Compiler.Tests.Diagnostics.Test_Stage_Mappings'Access));
      Result.Add_Test
        (Diagnostics_Caller.Create
           ("diagnostics: unit kind label",
            Lovelace.Compiler.Tests.Diagnostics.Test_Unit_Kind_Label'Access));
      Result.Add_Test
        (Diagnostics_Caller.Create
           ("diagnostics: unit name matches file",
            Lovelace
              .Compiler
              .Tests
              .Diagnostics
              .Test_Unit_Name_Matches_File'Access));

      return Result;
   end Suite;

end Lovelace.Compiler.Tests.Suite;
