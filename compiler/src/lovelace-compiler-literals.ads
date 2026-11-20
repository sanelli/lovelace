with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Common.Result;
with Lovelace.Compiler.Types;

--  Interpret integer and float literal lexemes from the tokenizer.

package Lovelace.Compiler.Literals is

   --  Why literal interpretation failed.
   --  @enum Internal_Error Unexpected interpreter bug.
   --  @enum Invalid_Literal Lexeme shape or digits are not valid.
   type Literal_Error_Code is (Internal_Error, Invalid_Literal);

   --  Failure payload for literal interpretation.
   --  @field Code Error kind.
   --  @field Detail UTF-8 explanation.
   type Literal_Error is record
      Code   : Literal_Error_Code;
      Detail : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Interpreted integer literal (not yet typed into a Lovelace Integer type).
   --  @field Is_Negative True when the lexeme had a leading '-'.
   --  @field Base Numeric base 2, 8, 10, or 16.
   --  @field Digits_Text Digit characters after any base prefix (no sign/suffix).
   --  @field Has_Signedness True when an s/u suffix was present.
   --  @field The_Signedness Signedness from suffix when Has_Signedness.
   --  @field Has_Size True when a size suffix (8/16/32/64) was present.
   --  @field The_Size Size from suffix when Has_Size.
   type Integer_Literal_Value is record
      Is_Negative    : Boolean := False;
      Base           : Positive := 10;
      Digits_Text    : Ada.Strings.Unbounded.Unbounded_String;
      Has_Signedness : Boolean := False;
      The_Signedness : Types.Signedness := Types.Signed;
      Has_Size       : Boolean := False;
      The_Size       : Types.Integer_Size := Types.Bits_32;
   end record;

   --  Interpreted float literal.
   --  @field Is_Negative True when the lexeme had a leading '-'.
   --  @field The_Width Resolved float width (Bits_32 default when no f32/f64 suffix).
   --  @field Lexeme Full float spelling (for later evaluation).
   type Float_Literal_Value is record
      Is_Negative : Boolean := False;
      The_Width   : Types.Float_Size := Types.Bits_32;
      Lexeme      : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Integer_Literal_Results is new
     Lovelace.Common.Result (Success_Type => Integer_Literal_Value, Error_Type => Literal_Error);

   package Float_Literal_Results is new
     Lovelace.Common.Result (Success_Type => Float_Literal_Value, Error_Type => Literal_Error);

   package Integer_32_Results is new
     Lovelace.Common.Result (Success_Type => Interfaces.Integer_32, Error_Type => Literal_Error);

   --  Interpret an Integer_Literal token lexeme.
   --  @param Lexeme UTF-8 integer literal spelling from the tokenizer.
   --  @return Structured value, or Invalid_Literal / Internal_Error.
   function Interpret_Integer (Lexeme : String) return Integer_Literal_Results.Result;

   --  Interpret a Float_Literal token lexeme.
   --  @param Lexeme UTF-8 float literal spelling from the tokenizer.
   --  @return Structured value, or Invalid_Literal / Internal_Error.
   function Interpret_Float (Lexeme : String) return Float_Literal_Results.Result;

   --  Evaluate The_Value as a signed 32-bit integer (range-checked).
   --  @param The_Value Interpreted integer literal (digits + sign + base).
   --  @return Integer_32, or Invalid_Literal when out of range / bad digits.
   function To_Integer_32 (The_Value : Integer_Literal_Value) return Integer_32_Results.Result;

   --  Interpret Lexeme then evaluate as Integer_32.
   --  @param Lexeme UTF-8 integer literal spelling from the tokenizer.
   --  @return Integer_32, or Invalid_Literal / Internal_Error.
   function To_Integer_32 (Lexeme : String) return Integer_32_Results.Result;

end Lovelace.Compiler.Literals;
