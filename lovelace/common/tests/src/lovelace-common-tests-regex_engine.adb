with Lovelace.Common.Regex;
with Lovelace.Common.Tests.Support;

package body Lovelace.Common.Tests.Regex_Engine is

   procedure Test_Alternation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "cat|dog", Input => "dog!", From => 1, Expected_Length => 3, Message => "alt dog");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "cat|dog", Input => "cat!", From => 1, Expected_Length => 3, Message => "alt cat");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a|ab", Input => "ab", From => 1, Expected_Length => 2, Message => "alt longest");
   end Test_Alternation;

   procedure Test_Any (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Rocket : constant String := Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#));
      Input  : constant String := "a" & Rocket & "c";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a.c", Input => Input, From => 1, Expected_Length => Input'Length, Message => "dot over emoji");
   end Test_Any;

   procedure Test_Classes (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "[abc]", Input => "b", From => 1, Expected_Length => 1, Message => "class hit");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "[a-c]", Input => "b", From => 1, Expected_Length => 1, Message => "class range");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "[^0-9]", Input => "x9", From => 1, Expected_Length => 1, Message => "negated class");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "[^0-9]", Input => "9", From => 1, Expected_Length => 0, Message => "negated class miss");
   end Test_Classes;

   procedure Test_Concatenation (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "ab", Input => "abcd", From => 1, Expected_Length => 2, Message => "concat ab");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "ab", Input => "a", From => 1, Expected_Length => 0, Message => "concat incomplete");
   end Test_Concatenation;

   procedure Test_Invalid_Patterns (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Compile_Fails ("", "empty pattern");
      Lovelace.Common.Tests.Support.Assert_Compile_Fails ("[z-a]", "bad range");
      Lovelace.Common.Tests.Support.Assert_Compile_Fails ("\q", "bad escape");
      Lovelace.Common.Tests.Support.Assert_Compile_Fails ("(ab", "unclosed group");
      Lovelace.Common.Tests.Support.Assert_Compile_Fails ("\u{}", "empty unicode escape");
   end Test_Invalid_Patterns;

   procedure Test_Literal (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a", Input => "abc", From => 1, Expected_Length => 1, Message => "literal a");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a", Input => "x", From => 1, Expected_Length => 0, Message => "literal miss");
   end Test_Literal;

   procedure Test_Offsets (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Engine : constant Lovelace.Common.Regex.Engine := Lovelace.Common.Tests.Support.Must_Compile ("ab");
   begin
      Lovelace.Common.Tests.Support.Assert_Match_Length
        (The_Engine => The_Engine, Input => "xxabyy", From => 3, Expected_Length => 2, Message => "offset match");
      Lovelace.Common.Tests.Support.Assert_Match_Length
        (The_Engine      => The_Engine,
         Input           => "xxabyy",
         From            => 1,
         Expected_Length => 0,
         Message         => "offset miss at start");
   end Test_Offsets;

   procedure Test_Quantifiers (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a*", Input => "aaab", From => 1, Expected_Length => 3, Message => "star");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a*", Input => "b", From => 1, Expected_Length => 0, Message => "star empty-only is no match");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a+", Input => "aaab", From => 1, Expected_Length => 3, Message => "plus");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a+", Input => "b", From => 1, Expected_Length => 0, Message => "plus miss");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a?", Input => "ab", From => 1, Expected_Length => 1, Message => "question present");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => "a?b", Input => "b", From => 1, Expected_Length => 1, Message => "question absent");
   end Test_Quantifiers;

   procedure Test_Utf_8_Literals (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      E_Acute   : constant String := Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#E9#));
      Cafe      : constant String := "caf" & E_Acute;
      Rocket    : constant String := Lovelace.Common.Tests.Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#));
      Rocket_Go : constant String := Rocket & "go";
   begin
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern => Cafe, Input => Cafe & "!", From => 1, Expected_Length => Cafe'Length, Message => "cafe literal");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => Rocket,
         Input           => Rocket_Go,
         From            => 1,
         Expected_Length => Rocket'Length,
         Message         => "emoji literal");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => "\u{1F680}",
         Input           => Rocket,
         From            => 1,
         Expected_Length => Rocket'Length,
         Message         => "unicode escape rocket");
      Lovelace.Common.Tests.Support.Assert_Pattern_Match
        (Pattern         => "\u{e9}",
         Input           => E_Acute,
         From            => 1,
         Expected_Length => E_Acute'Length,
         Message         => "unicode escape e-acute");
   end Test_Utf_8_Literals;

end Lovelace.Common.Tests.Regex_Engine;
