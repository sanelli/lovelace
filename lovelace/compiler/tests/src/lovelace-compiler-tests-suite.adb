with AUnit.Test_Caller;

with Lovelace.Compiler.Tests.Backend;
with Lovelace.Compiler.Tests.Diagnostics;
with Lovelace.Compiler.Tests.Ir_Generator;
with Lovelace.Compiler.Tests.Literals;
with Lovelace.Compiler.Tests.Module_Path;
with Lovelace.Compiler.Tests.Parser;
with Lovelace.Compiler.Tests.Semantics;
with Lovelace.Compiler.Tests.Tokenizer;
with Lovelace.Compiler.Tests.Unit_Graph;

package body Lovelace.Compiler.Tests.Suite is

   package Backend_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Backend.Fixture);
   package Diagnostics_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Diagnostics.Fixture);
   package Ir_Generator_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Ir_Generator.Fixture);
   package Literals_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Literals.Fixture);
   package Module_Path_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Module_Path.Fixture);
   package Parser_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Parser.Fixture);
   package Semantics_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Semantics.Fixture);
   package Tokenizer_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Tokenizer.Fixture);
   package Unit_Graph_Caller is new
     AUnit.Test_Caller (Lovelace.Compiler.Tests.Unit_Graph.Fixture);

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
           ("tokenizer: export keyword",
            Lovelace.Compiler.Tests.Tokenizer.Test_Export_Keyword'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: import identifier",
            Lovelace.Compiler.Tests.Tokenizer.Test_Import_Identifier'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: native identifier",
            Lovelace.Compiler.Tests.Tokenizer.Test_Native_Identifier'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: declare keyword",
            Lovelace.Compiler.Tests.Tokenizer.Test_Declare_Keyword'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: using keyword",
            Lovelace.Compiler.Tests.Tokenizer.Test_Using_Keyword'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: assign punctuation",
            Lovelace.Compiler.Tests.Tokenizer.Test_Assign_Punctuation'Access));
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
        (Tokenizer_Caller.Create
           ("tokenizer: comments",
            Lovelace.Compiler.Tests.Tokenizer.Test_Comments'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: comment errors",
            Lovelace.Compiler.Tests.Tokenizer.Test_Comment_Errors'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: directives and strings",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Directives_And_Strings'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("tokenizer: directive and string errors",
            Lovelace
              .Compiler
              .Tests
              .Tokenizer
              .Test_Directive_And_String_Errors'Access));

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
           ("parser: comments",
            Lovelace.Compiler.Tests.Parser.Test_Comments'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: declare locals",
            Lovelace.Compiler.Tests.Parser.Test_Declare_Locals'Access));
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
           ("parser: flavor active clash",
            Lovelace.Compiler.Tests.Parser.Test_Flavor_Active_Clash'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: overload signatures",
            Lovelace.Compiler.Tests.Parser.Test_Overload_Signatures'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor exclusive names",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Flavor_Exclusive_Names'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor inactive syntax error",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Flavor_Inactive_Syntax_Error'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor invalid condition",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Flavor_Invalid_Condition'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor nested",
            Lovelace.Compiler.Tests.Parser.Test_Flavor_Nested'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor placement in procedure",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Flavor_Placement_In_Procedure'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor placement in program",
            Lovelace
              .Compiler
              .Tests
              .Parser
              .Test_Flavor_Placement_In_Program'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: flavor selection",
            Lovelace.Compiler.Tests.Parser.Test_Flavor_Selection'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: identifier names",
            Lovelace.Compiler.Tests.Parser.Test_Identifier_Names'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: using declarations",
            Lovelace.Compiler.Tests.Parser.Test_Using_Declarations'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: obsolete import",
            Lovelace.Compiler.Tests.Parser.Test_Obsolete_Import'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: block usings",
            Lovelace.Compiler.Tests.Parser.Test_Block_Usings'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: assignment statements",
            Lovelace.Compiler.Tests.Parser.Test_Assignment_Statements'Access));
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
           ("parser: qualified calls",
            Lovelace.Compiler.Tests.Parser.Test_Qualified_Calls'Access));
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
           ("parser: export procedure",
            Lovelace.Compiler.Tests.Parser.Test_Export_Procedure'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: native procedure",
            Lovelace.Compiler.Tests.Parser.Test_Native_Procedure'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: duplicate parameter",
            Lovelace.Compiler.Tests.Parser.Test_Duplicate_Parameter'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: bad type size",
            Lovelace.Compiler.Tests.Parser.Test_Bad_Type_Size'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("parser: boolean type",
            Lovelace.Compiler.Tests.Parser.Test_Boolean_Type'Access));

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
        (Literals_Caller.Create
           ("literals: to integer 32",
            Lovelace.Compiler.Tests.Literals.Test_To_Integer_32'Access));

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
           ("ir generator: export procedure parameters",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Export_Procedure_Parameters'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: filename shared",
            Lovelace.Compiler.Tests.Ir_Generator.Test_Filename_Shared'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: flattened locals",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Flattened_Locals'Access));
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
           ("ir generator: import dependencies",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Import_Dependencies'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: assignment and local access",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Assignment_And_Local_Access'Access));
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
           ("ir generator: native binding",
            Lovelace.Compiler.Tests.Ir_Generator.Test_Native_Binding'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: parameter type mapping",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Parameter_Type_Mapping'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: cross-module calls",
            Lovelace
              .Compiler
              .Tests
              .Ir_Generator
              .Test_Cross_Module_Calls'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: same-unit calls",
            Lovelace.Compiler.Tests.Ir_Generator.Test_Same_Unit_Calls'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("ir generator: overload calls",
            Lovelace.Compiler.Tests.Ir_Generator.Test_Overload_Calls'Access));

      Result.Add_Test
        (Backend_Caller.Create
           ("backend: export only",
            Lovelace.Compiler.Tests.Backend.Test_Export_Only'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: export with parameters",
            Lovelace
              .Compiler
              .Tests
              .Backend
              .Test_Export_With_Parameters'Access));
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
           ("backend: const and call body",
            Lovelace.Compiler.Tests.Backend.Test_Const_And_Call_Body'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: local get set body",
            Lovelace.Compiler.Tests.Backend.Test_Local_Get_Set_Body'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("backend: typed locals",
            Lovelace.Compiler.Tests.Backend.Test_Typed_Locals'Access));
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
        (Backend_Caller.Create
           ("backend: native print integer",
            Lovelace.Compiler.Tests.Backend.Test_Native_Print_Integer'Access));

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
           ("diagnostics: severity policy",
            Lovelace.Compiler.Tests.Diagnostics.Test_Severity_Policy'Access));
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

      Result.Add_Test
        (Module_Path_Caller.Create
           ("module path: relative candidates",
            Lovelace
              .Compiler
              .Tests
              .Module_Path
              .Test_Relative_Candidates'Access));
      Result.Add_Test
        (Module_Path_Caller.Create
           ("module path: resolve unique missing ambiguous",
            Lovelace
              .Compiler
              .Tests
              .Module_Path
              .Test_Resolve_Unique_Missing_Ambiguous'Access));
      Result.Add_Test
        (Module_Path_Caller.Create
           ("module path: augusta root slot",
            Lovelace
              .Compiler
              .Tests
              .Module_Path
              .Test_Augusta_Root_Slot'Access));
      Result.Add_Test
        (Module_Path_Caller.Create
           ("module path: default search roots",
            Lovelace
              .Compiler
              .Tests
              .Module_Path
              .Test_Default_Search_Roots'Access));

      Result.Add_Test
        (Unit_Graph_Caller.Create
           ("unit graph: load dependency",
            Lovelace.Compiler.Tests.Unit_Graph.Test_Load_Dependency'Access));
      Result.Add_Test
        (Unit_Graph_Caller.Create
           ("unit graph: load nested using",
            Lovelace.Compiler.Tests.Unit_Graph.Test_Load_Nested_Using'Access));
      Result.Add_Test
        (Unit_Graph_Caller.Create
           ("unit graph: load failures",
            Lovelace.Compiler.Tests.Unit_Graph.Test_Load_Failures'Access));
      Result.Add_Test
        (Unit_Graph_Caller.Create
           ("unit graph: load versions",
            Lovelace.Compiler.Tests.Unit_Graph.Test_Load_Versions'Access));

      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: definite assignment",
            Lovelace
              .Compiler
              .Tests
              .Semantics
              .Test_Definite_Assignment'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: environment scopes",
            Lovelace.Compiler.Tests.Semantics.Test_Environment_Scopes'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: type mismatch",
            Lovelace.Compiler.Tests.Semantics.Test_Type_Mismatch'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: typecheck api",
            Lovelace.Compiler.Tests.Semantics.Test_Typecheck_Api'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: unused priority",
            Lovelace.Compiler.Tests.Semantics.Test_Unused_Priority'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: unused using",
            Lovelace.Compiler.Tests.Semantics.Test_Unused_Using'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: overload resolve",
            Lovelace.Compiler.Tests.Semantics.Test_Overload_Resolve'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: scoped using visibility",
            Lovelace
              .Compiler
              .Tests
              .Semantics
              .Test_Scoped_Using_Visibility'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: missing and non-exported callees",
            Lovelace
              .Compiler
              .Tests
              .Semantics
              .Test_Missing_And_Not_Exported_Callees'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: warnings do not fail",
            Lovelace
              .Compiler
              .Tests
              .Semantics
              .Test_Warnings_Do_Not_Fail'Access));
      Result.Add_Test
        (Semantics_Caller.Create
           ("semantics: reporting mapping",
            Lovelace.Compiler.Tests.Semantics.Test_Reporting_Mapping'Access));

      return Result;
   end Suite;

end Lovelace.Compiler.Tests.Suite;
