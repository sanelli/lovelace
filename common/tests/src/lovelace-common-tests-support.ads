with Lovelace.Common.Regex;

--  Shared assertions for Compile and Match_Prefix tests.

package Lovelace.Common.Tests.Support is

   --  Encode one Unicode scalar as UTF-8 bytes.
   --  @param Point Unicode scalar.
   --  @return UTF-8 byte string.
   function To_Utf_8 (Point : Wide_Wide_Character) return String;

   --  Encode each scalar in Points as UTF-8 bytes.
   --  @param Points Sequence of Unicode scalars.
   --  @return UTF-8 byte string.
   function To_Utf_8 (Points : Wide_Wide_String) return String;

   --  Compile Pattern and require success.
   --  @param Pattern UTF-8 regular-expression source.
   --  @param Message Assertion message on compile failure.
   --  @return Compiled engine.
   function Must_Compile (Pattern : String; Message : String := "compile failed") return Lovelace.Common.Regex.Engine;

   --  Assert Match_Prefix length equals Expected_Length.
   --  @param The_Engine Compiled NFA.
   --  @param Input UTF-8 subject.
   --  @param From First byte index.
   --  @param Expected_Length Expected Match_Prefix result.
   --  @param Message Assertion message on mismatch.
   procedure Assert_Match_Length
     (The_Engine      : Lovelace.Common.Regex.Engine;
      Input           : String;
      From            : Positive;
      Expected_Length : Natural;
      Message         : String);

   --  Compile Pattern and assert Match_Prefix length.
   --  @param Pattern UTF-8 regular-expression source.
   --  @param Input UTF-8 subject.
   --  @param From First byte index.
   --  @param Expected_Length Expected Match_Prefix result.
   --  @param Message Assertion message on mismatch.
   procedure Assert_Pattern_Match
     (Pattern : String; Input : String; From : Positive; Expected_Length : Natural; Message : String);

   --  Assert Compile fails.
   --  @param Pattern UTF-8 regular-expression source.
   --  @param Message Assertion message when compile unexpectedly succeeds.
   procedure Assert_Compile_Fails (Pattern : String; Message : String);

end Lovelace.Common.Tests.Support;
