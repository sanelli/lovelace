with AUnit.Test_Caller;

with Lovelace.Common.Tests.Regex_Engine;
with Lovelace.Common.Tests.Token_Classes;

package body Lovelace.Common.Tests.Suite is

   package Regex_Caller is new AUnit.Test_Caller (Lovelace.Common.Tests.Regex_Engine.Fixture);
   package Token_Caller is new AUnit.Test_Caller (Lovelace.Common.Tests.Token_Classes.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (Regex_Caller.Create ("literal", Lovelace.Common.Tests.Regex_Engine.Test_Literal'Access));
      Result.Add_Test
        (Regex_Caller.Create ("concatenation", Lovelace.Common.Tests.Regex_Engine.Test_Concatenation'Access));
      Result.Add_Test (Regex_Caller.Create ("alternation", Lovelace.Common.Tests.Regex_Engine.Test_Alternation'Access));
      Result.Add_Test (Regex_Caller.Create ("quantifiers", Lovelace.Common.Tests.Regex_Engine.Test_Quantifiers'Access));
      Result.Add_Test (Regex_Caller.Create ("classes", Lovelace.Common.Tests.Regex_Engine.Test_Classes'Access));
      Result.Add_Test (Regex_Caller.Create ("any", Lovelace.Common.Tests.Regex_Engine.Test_Any'Access));
      Result.Add_Test (Regex_Caller.Create ("offsets", Lovelace.Common.Tests.Regex_Engine.Test_Offsets'Access));
      Result.Add_Test
        (Regex_Caller.Create ("invalid patterns", Lovelace.Common.Tests.Regex_Engine.Test_Invalid_Patterns'Access));
      Result.Add_Test
        (Regex_Caller.Create ("utf-8 literals", Lovelace.Common.Tests.Regex_Engine.Test_Utf_8_Literals'Access));

      Result.Add_Test
        (Token_Caller.Create ("block comments", Lovelace.Common.Tests.Token_Classes.Test_Block_Comments'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("single-line strings", Lovelace.Common.Tests.Token_Classes.Test_Single_Line_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create ("multiline strings", Lovelace.Common.Tests.Token_Classes.Test_Multiline_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("interpolated strings", Lovelace.Common.Tests.Token_Classes.Test_Interpolated_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create ("combined strings", Lovelace.Common.Tests.Token_Classes.Test_Combined_Strings'Access));
      Result.Add_Test
        (Token_Caller.Create
           ("character literals", Lovelace.Common.Tests.Token_Classes.Test_Character_Literals'Access));
      Result.Add_Test (Token_Caller.Create ("operators", Lovelace.Common.Tests.Token_Classes.Test_Operators'Access));
      Result.Add_Test
        (Token_Caller.Create ("punctuation", Lovelace.Common.Tests.Token_Classes.Test_Punctuation'Access));
      Result.Add_Test (Token_Caller.Create ("keywords", Lovelace.Common.Tests.Token_Classes.Test_Keywords'Access));
      Result.Add_Test
        (Token_Caller.Create ("parentheses", Lovelace.Common.Tests.Token_Classes.Test_Parentheses'Access));
      Result.Add_Test
        (Token_Caller.Create ("identifiers", Lovelace.Common.Tests.Token_Classes.Test_Identifiers'Access));

      return Result;
   end Suite;

end Lovelace.Common.Tests.Suite;
