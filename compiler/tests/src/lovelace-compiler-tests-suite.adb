with AUnit.Test_Caller;

with Lovelace.Compiler.Tests.Backend;
with Lovelace.Compiler.Tests.Ir_Generator;
with Lovelace.Compiler.Tests.Parser;
with Lovelace.Compiler.Tests.Tokenizer;

package body Lovelace.Compiler.Tests.Suite is

   package Backend_Caller is new AUnit.Test_Caller (Lovelace.Compiler.Tests.Backend.Fixture);
   package Ir_Generator_Caller is new AUnit.Test_Caller (Lovelace.Compiler.Tests.Ir_Generator.Fixture);
   package Parser_Caller is new AUnit.Test_Caller (Lovelace.Compiler.Tests.Parser.Fixture);
   package Tokenizer_Caller is new AUnit.Test_Caller (Lovelace.Compiler.Tests.Tokenizer.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("empty and whitespace", Lovelace.Compiler.Tests.Tokenizer.Test_Empty_And_Whitespace'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("program begin end", Lovelace.Compiler.Tests.Tokenizer.Test_Program_Begin_End'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("whitespace kinds", Lovelace.Compiler.Tests.Tokenizer.Test_Whitespace_Kinds'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("glued punctuation", Lovelace.Compiler.Tests.Tokenizer.Test_Glued_Punctuation'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("keyword case", Lovelace.Compiler.Tests.Tokenizer.Test_Keyword_Case'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("keyword reservation", Lovelace.Compiler.Tests.Tokenizer.Test_Keyword_Reservation'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("ascii identifiers", Lovelace.Compiler.Tests.Tokenizer.Test_Ascii_Identifiers'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("leading digits", Lovelace.Compiler.Tests.Tokenizer.Test_Leading_Digits'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("unicode identifiers", Lovelace.Compiler.Tests.Tokenizer.Test_Unicode_Identifiers'Access));
      Result.Add_Test (Tokenizer_Caller.Create ("at prefix", Lovelace.Compiler.Tests.Tokenizer.Test_At_Prefix'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("unrecognized identifier characters",
            Lovelace.Compiler.Tests.Tokenizer.Test_Unrecognized_Identifier_Characters'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("newline line column", Lovelace.Compiler.Tests.Tokenizer.Test_Newline_Line_Column'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("filename omitted", Lovelace.Compiler.Tests.Tokenizer.Test_Filename_Omitted'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("filename shared on tokens", Lovelace.Compiler.Tests.Tokenizer.Test_Filename_Shared_On_Tokens'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("filename shared on errors", Lovelace.Compiler.Tests.Tokenizer.Test_Filename_Shared_On_Errors'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create
           ("unrecognized symbols", Lovelace.Compiler.Tests.Tokenizer.Test_Unrecognized_Symbols'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("multi-error", Lovelace.Compiler.Tests.Tokenizer.Test_Multi_Error'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("invalid utf-8", Lovelace.Compiler.Tests.Tokenizer.Test_Invalid_Utf_8'Access));
      Result.Add_Test
        (Tokenizer_Caller.Create ("clean begin", Lovelace.Compiler.Tests.Tokenizer.Test_Clean_Begin'Access));
      Result.Add_Test
        (Parser_Caller.Create ("canonical multiline", Lovelace.Compiler.Tests.Parser.Test_Canonical_Multiline'Access));
      Result.Add_Test
        (Parser_Caller.Create ("whitespace variants", Lovelace.Compiler.Tests.Parser.Test_Whitespace_Variants'Access));
      Result.Add_Test
        (Parser_Caller.Create ("identifier names", Lovelace.Compiler.Tests.Parser.Test_Identifier_Names'Access));
      Result.Add_Test
        (Parser_Caller.Create ("end semicolon", Lovelace.Compiler.Tests.Parser.Test_End_Semicolon'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("wrong order and incomplete", Lovelace.Compiler.Tests.Parser.Test_Wrong_Order_And_Incomplete'Access));
      Result.Add_Test
        (Parser_Caller.Create
           ("trailing and keyword case", Lovelace.Compiler.Tests.Parser.Test_Trailing_And_Keyword_Case'Access));
      Result.Add_Test (Parser_Caller.Create ("empty tokens", Lovelace.Compiler.Tests.Parser.Test_Empty_Tokens'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("canonical multiline", Lovelace.Compiler.Tests.Ir_Generator.Test_Canonical_Multiline'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("filename shared", Lovelace.Compiler.Tests.Ir_Generator.Test_Filename_Shared'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("identifier names", Lovelace.Compiler.Tests.Ir_Generator.Test_Identifier_Names'Access));
      Result.Add_Test
        (Ir_Generator_Caller.Create
           ("export only flags", Lovelace.Compiler.Tests.Ir_Generator.Test_Export_Only_Flags'Access));
      Result.Add_Test (Backend_Caller.Create ("export only", Lovelace.Compiler.Tests.Backend.Test_Export_Only'Access));
      Result.Add_Test (Backend_Caller.Create ("entrypoint", Lovelace.Compiler.Tests.Backend.Test_Entrypoint'Access));
      Result.Add_Test
        (Backend_Caller.Create
           ("entrypoint and export", Lovelace.Compiler.Tests.Backend.Test_Entrypoint_And_Export'Access));
      Result.Add_Test (Backend_Caller.Create ("two exports", Lovelace.Compiler.Tests.Backend.Test_Two_Exports'Access));
      Result.Add_Test (Backend_Caller.Create ("noop body", Lovelace.Compiler.Tests.Backend.Test_Noop_Body'Access));
      Result.Add_Test
        (Backend_Caller.Create ("unsupported type", Lovelace.Compiler.Tests.Backend.Test_Unsupported_Type'Access));
      Result.Add_Test
        (Backend_Caller.Create ("invalid module", Lovelace.Compiler.Tests.Backend.Test_Invalid_Module'Access));
      return Result;
   end Suite;

end Lovelace.Compiler.Tests.Suite;
