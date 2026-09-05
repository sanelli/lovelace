with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Common.Utf_8;

package body Lovelace.Common.Tests.Support is

   procedure Assert_Compile_Fails (Pattern : String; Message : String) is
      Result : constant Lovelace.Common.Regex.Regex_Result := Lovelace.Common.Regex.Compile (Pattern);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, Message);

         when False =>
            null;
      end case;
   end Assert_Compile_Fails;

   procedure Assert_Match_Length
     (The_Engine      : Lovelace.Common.Regex.Engine;
      Input           : String;
      From            : Positive;
      Expected_Length : Natural;
      Message         : String)
   is
      Actual_Length : constant Natural :=
        Lovelace.Common.Regex.Match_Prefix (The_Engine => The_Engine, Input => Input, From => From);
   begin
      AUnit.Assertions.Assert
        (Actual_Length = Expected_Length,
         Message & ": expected" & Natural'Image (Expected_Length) & " got" & Natural'Image (Actual_Length));
   end Assert_Match_Length;

   procedure Assert_Pattern_Match
     (Pattern : String; Input : String; From : Positive; Expected_Length : Natural; Message : String)
   is
      The_Engine : constant Lovelace.Common.Regex.Engine := Must_Compile (Pattern, Message & " (compile)");
   begin
      Assert_Match_Length
        (The_Engine      => The_Engine,
         Input           => Input,
         From            => From,
         Expected_Length => Expected_Length,
         Message         => Message);
   end Assert_Pattern_Match;

   function Must_Compile (Pattern : String; Message : String := "compile failed") return Lovelace.Common.Regex.Engine is
      Result : constant Lovelace.Common.Regex.Regex_Result := Lovelace.Common.Regex.Compile (Pattern);
   begin
      case Result.Ok is
         when True  =>
            return Result.Value;

         when False =>
            declare
               Unused_Engine : Lovelace.Common.Regex.Engine;
            begin
               AUnit.Assertions.Assert (False, Message & ": " & Ada.Strings.Unbounded.To_String (Result.Error.Message));
               return Unused_Engine;
            end;
      end case;
   end Must_Compile;

   function To_Utf_8 (Point : Wide_Wide_Character) return String is
      Result : constant Lovelace.Common.Utf_8.Encode_Results.Result := Lovelace.Common.Utf_8.Encode (Point);
   begin
      case Result.Ok is
         when True  =>
            return Ada.Strings.Unbounded.To_String (Result.Value);

         when False =>
            AUnit.Assertions.Assert
              (False, "UTF-8 encode failed: " & Ada.Strings.Unbounded.To_String (Result.Error.Message));
            return "";
      end case;
   end To_Utf_8;

   function To_Utf_8 (Points : Wide_Wide_String) return String is
      Accumulator : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Index in Points'Range loop
         Ada.Strings.Unbounded.Append (Accumulator, To_Utf_8 (Points (Index)));
      end loop;
      return Ada.Strings.Unbounded.To_String (Accumulator);
   end To_Utf_8;

end Lovelace.Common.Tests.Support;
