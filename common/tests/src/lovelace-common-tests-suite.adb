with AUnit.Test_Caller;

with Lovelace.Common.Tests.Option;
with Lovelace.Common.Tests.Regex_Engine;
with Lovelace.Common.Tests.Source;
with Lovelace.Common.Tests.Token_Classes;

package body Lovelace.Common.Tests.Suite is

   package Option_Caller is new
     AUnit.Test_Caller (Lovelace.Common.Tests.Option.Fixture);
   package Regex_Caller is new
     AUnit.Test_Caller (Lovelace.Common.Tests.Regex_Engine.Fixture);
   package Source_Caller is new
     AUnit.Test_Caller (Lovelace.Common.Tests.Source.Fixture);
   package Token_Caller is new
     AUnit.Test_Caller (Lovelace.Common.Tests.Token_Classes.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Option_Caller.Create
           ("option: none variant",
            Lovelace.Common.Tests.Option.Test_None'Access));
      Result.Add_Test
        (Option_Caller.Create
           ("option: from value",
            Lovelace.Common.Tests.Option.Test_From_Value'Access));
      Result.Add_Test
        (Option_Caller.Create
           ("option: present discriminant",
            Lovelace.Common.Tests.Option.Test_Present_Discriminant'Access));

      Result.Add_Test
        (Source_Caller.Create
           ("source: span fields",
            Lovelace.Common.Tests.Source.Test_Source_Span_Fields'Access));
      Result.Add_Test
        (Source_Caller.Create
           ("source: absent filename",
            Lovelace.Common.Tests.Source.Test_Absent_Filename'Access));
      Result.Add_Test
        (Source_Caller.Create
           ("source: shared filename storage",
            Lovelace
              .Common
              .Tests
              .Source
              .Test_Same_Storage_Shared_Filename'Access));
      Result.Add_Test
        (Source_Caller.Create
           ("source: filename option storage",
            Lovelace
              .Common
              .Tests
              .Source
              .Test_Same_Storage_Filename_Option'Access));
      Result.Add_Test
        (Source_Caller.Create
           ("source: to utf-8",
            Lovelace.Common.Tests.Source.Test_To_Utf_8'Access));

      Result.Add_Test
        (Regex_Caller.Create
           ("regex: literal match",
            Lovelace.Common.Tests.Regex_Engine.Test_Literal'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: concatenation",
            Lovelace.Common.Tests.Regex_Engine.Test_Concatenation'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: alternation",
            Lovelace.Common.Tests.Regex_Engine.Test_Alternation'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: quantifiers",
            Lovelace.Common.Tests.Regex_Engine.Test_Quantifiers'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: character classes",
            Lovelace.Common.Tests.Regex_Engine.Test_Classes'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: any-character",
            Lovelace.Common.Tests.Regex_Engine.Test_Any'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: match offsets",
            Lovelace.Common.Tests.Regex_Engine.Test_Offsets'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: invalid patterns",
            Lovelace.Common.Tests.Regex_Engine.Test_Invalid_Patterns'Access));
      Result.Add_Test
        (Regex_Caller.Create
           ("regex: utf-8 literals",
            Lovelace.Common.Tests.Regex_Engine.Test_Utf_8_Literals'Access));

      Result.Add_Test
        (Token_Caller.Create
           ("token class: block comments",
            Lovelace.Common.Tests.Token_Classes.Test_Block_Comments'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: single-line strings",
            Lovelace
              .Common
              .Tests
              .Token_Classes
              .Test_Single_Line_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: multiline strings",
            Lovelace
              .Common
              .Tests
              .Token_Classes
              .Test_Multiline_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: interpolated strings",
            Lovelace
              .Common
              .Tests
              .Token_Classes
              .Test_Interpolated_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: combined strings",
            Lovelace.Common.Tests.Token_Classes.Test_Combined_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: character literals",
            Lovelace
              .Common
              .Tests
              .Token_Classes
              .Test_Character_Literals'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: operators",
            Lovelace.Common.Tests.Token_Classes.Test_Operators'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: punctuation",
            Lovelace.Common.Tests.Token_Classes.Test_Punctuation'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: keywords",
            Lovelace.Common.Tests.Token_Classes.Test_Keywords'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: parentheses",
            Lovelace.Common.Tests.Token_Classes.Test_Parentheses'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("token class: identifiers",
            Lovelace.Common.Tests.Token_Classes.Test_Identifiers'Access));

      return Result;
   end Suite;

end Lovelace.Common.Tests.Suite;
