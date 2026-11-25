with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Interfaces;

with Lovelace.Compiler.Literals;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Tests.Literals is

   package Compiler_Literals renames Lovelace.Compiler.Literals;

   use type Compiler_Literals.Literal_Error_Code;
   use type Interfaces.Integer_32;
   use type Lovelace.Compiler.Types.Float_Size;
   use type Lovelace.Compiler.Types.Integer_Size;
   use type Lovelace.Compiler.Types.Signedness;

   procedure Assert_Float_Invalid (Lexeme : String; Message : String);
   procedure Assert_Integer_Invalid (Lexeme : String; Message : String);
   procedure Assert_To_Integer_32_Invalid (Lexeme : String; Message : String);
   procedure Assert_Value_Invalid (The_Value : Compiler_Literals.Integer_Literal_Value; Message : String);

   procedure Assert_Float_Invalid (Lexeme : String; Message : String) is
      Result : constant Compiler_Literals.Float_Literal_Results.Result := Compiler_Literals.Interpret_Float (Lexeme);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, Message & " should fail");

         when False =>
            AUnit.Assertions.Assert (Result.Error.Code = Compiler_Literals.Invalid_Literal, Message & " code");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.Length (Result.Error.Detail) > 0, Message & " detail");
      end case;
   end Assert_Float_Invalid;

   procedure Assert_Integer_Invalid (Lexeme : String; Message : String) is
      Result : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer (Lexeme);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, Message & " should fail");

         when False =>
            AUnit.Assertions.Assert (Result.Error.Code = Compiler_Literals.Invalid_Literal, Message & " code");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.Length (Result.Error.Detail) > 0, Message & " detail");
      end case;
   end Assert_Integer_Invalid;

   procedure Assert_To_Integer_32_Invalid (Lexeme : String; Message : String) is
      Result : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 (Lexeme);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, Message & " should fail");

         when False =>
            AUnit.Assertions.Assert (Result.Error.Code = Compiler_Literals.Invalid_Literal, Message & " code");
      end case;
   end Assert_To_Integer_32_Invalid;

   procedure Assert_Value_Invalid (The_Value : Compiler_Literals.Integer_Literal_Value; Message : String) is
      Result : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 (The_Value);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, Message & " should fail");

         when False =>
            AUnit.Assertions.Assert (Result.Error.Code = Compiler_Literals.Invalid_Literal, Message & " code");
      end case;
   end Assert_Value_Invalid;

   procedure Test_Float_Forms (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Positive_Value : constant Compiler_Literals.Float_Literal_Results.Result :=
        Compiler_Literals.Interpret_Float ("1.5");
      Negative_Value : constant Compiler_Literals.Float_Literal_Results.Result :=
        Compiler_Literals.Interpret_Float ("-7.");
      Exp_Value      : constant Compiler_Literals.Float_Literal_Results.Result :=
        Compiler_Literals.Interpret_Float ("3.4E3");
      Bare_Exp       : constant Compiler_Literals.Float_Literal_Results.Result :=
        Compiler_Literals.Interpret_Float ("1e3");
      Width_32       : constant Compiler_Literals.Float_Literal_Results.Result :=
        Compiler_Literals.Interpret_Float ("7f32");
      Width_64       : constant Compiler_Literals.Float_Literal_Results.Result :=
        Compiler_Literals.Interpret_Float ("2.3F64");
   begin
      case Positive_Value.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "1.5 should succeed");

         when True  =>
            AUnit.Assertions.Assert (not Positive_Value.Value.Is_Negative, "1.5 sign");
            AUnit.Assertions.Assert (Positive_Value.Value.The_Width = Types.Bits_32, "1.5 width 32");
      end case;

      case Negative_Value.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "-7. should succeed");

         when True  =>
            AUnit.Assertions.Assert (Negative_Value.Value.Is_Negative, "-7. sign");
            AUnit.Assertions.Assert (Negative_Value.Value.The_Width = Types.Bits_32, "-7. width 32");
      end case;

      case Exp_Value.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "3.4E3 should succeed");

         when True  =>
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.To_String (Exp_Value.Value.Lexeme) = "3.4E3", "3.4E3 lexeme");
            AUnit.Assertions.Assert (Exp_Value.Value.The_Width = Types.Bits_32, "3.4E3 width 32");
      end case;

      case Bare_Exp.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "1e3 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Bare_Exp.Value.The_Width = Types.Bits_32, "1e3 width 32");
      end case;

      case Width_32.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "7f32 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Width_32.Value.The_Width = Types.Bits_32, "7f32 width");
      end case;

      case Width_64.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "2.3F64 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Width_64.Value.The_Width = Types.Bits_64, "2.3F64 width");
      end case;

      --  Exponent signs and short lexemes that still succeed.
      declare
         Plus_Exp  : constant Compiler_Literals.Float_Literal_Results.Result :=
           Compiler_Literals.Interpret_Float ("1e+5");
         Minus_Exp : constant Compiler_Literals.Float_Literal_Results.Result :=
           Compiler_Literals.Interpret_Float ("1.5E-2f64");
      begin
         AUnit.Assertions.Assert (Plus_Exp.Ok, "1e+5 should succeed");
         AUnit.Assertions.Assert (Minus_Exp.Ok, "1.5E-2f64 should succeed");
      end;

      --  Malformed floats.
      Assert_Float_Invalid ("", "empty float");
      Assert_Float_Invalid ("f32", "width suffix only");
      Assert_Float_Invalid ("-F64", "signed width suffix only");
      Assert_Float_Invalid (".5", "missing integer digits");
      Assert_Float_Invalid ("1e", "exponent without digits");
      Assert_Float_Invalid ("1e+", "exponent sign without digits");
      Assert_Float_Invalid ("1ex", "exponent with non-digit");
      Assert_Float_Invalid ("1.5x", "trailing characters");
      Assert_Float_Invalid ("10", "integer shape");
      Assert_Float_Invalid ("1", "single digit integer shape");
   end Test_Float_Forms;

   procedure Test_Integer_Forms (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Plain  : constant Compiler_Literals.Integer_Literal_Results.Result := Compiler_Literals.Interpret_Integer ("10");
      Hex    : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("0xFF");
      Sized  : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("-8u64");
      Binary : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("0b1010");
      Octal  : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("0o755");
   begin
      case Plain.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "10 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Plain.Value.Base = 10, "10 base");
            AUnit.Assertions.Assert (not Plain.Value.Has_Signedness, "10 no signedness");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Plain.Value.Digits_Text) = "10", "10 digits");
      end case;

      case Hex.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "0xFF should succeed");

         when True  =>
            AUnit.Assertions.Assert (Hex.Value.Base = 16, "0xFF base");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Hex.Value.Digits_Text) = "FF", "0xFF digits");
      end case;

      case Sized.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "-8u64 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Sized.Value.Is_Negative, "-8u64 negative");
            AUnit.Assertions.Assert (Sized.Value.Has_Signedness, "-8u64 has signedness");
            AUnit.Assertions.Assert (Sized.Value.The_Signedness = Types.Unsigned, "-8u64 unsigned");
            AUnit.Assertions.Assert (Sized.Value.Has_Size, "-8u64 has size");
            AUnit.Assertions.Assert (Sized.Value.The_Size = Types.Bits_64, "-8u64 size 64");
      end case;

      case Binary.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "0b1010 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Binary.Value.Base = 2, "0b1010 base");
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.To_String (Binary.Value.Digits_Text) = "1010", "0b1010 digits");
      end case;

      case Octal.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "0o755 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Octal.Value.Base = 8, "0o755 base");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Octal.Value.Digits_Text) = "755", "0o755 digits");
      end case;

      --  Size suffix forms and a leading zero that is not a base prefix.
      declare
         Sized_16     : constant Compiler_Literals.Integer_Literal_Results.Result :=
           Compiler_Literals.Interpret_Integer ("8s16");
         Sized_8      : constant Compiler_Literals.Integer_Literal_Results.Result :=
           Compiler_Literals.Interpret_Integer ("8s8");
         Sign_Only    : constant Compiler_Literals.Integer_Literal_Results.Result :=
           Compiler_Literals.Interpret_Integer ("8u");
         Leading_Zero : constant Compiler_Literals.Integer_Literal_Results.Result :=
           Compiler_Literals.Interpret_Integer ("05");
         Zero_Suffix  : constant Compiler_Literals.Integer_Literal_Results.Result :=
           Compiler_Literals.Interpret_Integer ("0u8");
      begin
         AUnit.Assertions.Assert (Sized_16.Ok and then Sized_16.Value.The_Size = Types.Bits_16, "8s16 size");
         AUnit.Assertions.Assert (Sized_8.Ok and then Sized_8.Value.The_Size = Types.Bits_8, "8s8 size");
         AUnit.Assertions.Assert
           (Sign_Only.Ok and then Sign_Only.Value.Has_Signedness and then not Sign_Only.Value.Has_Size,
            "8u without size");
         AUnit.Assertions.Assert
           (Leading_Zero.Ok
            and then Ada.Strings.Unbounded.To_String (Leading_Zero.Value.Digits_Text) = "05"
            and then Leading_Zero.Value.Base = 10,
            "05 stays decimal");
         AUnit.Assertions.Assert (Zero_Suffix.Ok and then Zero_Suffix.Value.The_Size = Types.Bits_8, "0u8 size");
      end;
   end Test_Integer_Forms;

   procedure Test_Invalid_Integer (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Bad_Size : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("8u3");
      Obsolete : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("#16#FF");
   begin
      case Bad_Size.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "8u3 should fail");

         when False =>
            AUnit.Assertions.Assert (Bad_Size.Error.Code = Compiler_Literals.Invalid_Literal, "8u3 code");
      end case;

      case Obsolete.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "#16#FF should fail");

         when False =>
            AUnit.Assertions.Assert (Obsolete.Error.Code = Compiler_Literals.Invalid_Literal, "#16#FF code");
      end case;

      Assert_Integer_Invalid ("", "empty integer");
      Assert_Integer_Invalid ("-", "sign only");
      Assert_Integer_Invalid ("+", "plus only");
      Assert_Integer_Invalid ("0x", "base prefix without digits");
      Assert_Integer_Invalid ("0b2", "digit outside base");
      Assert_Integer_Invalid ("12x", "trailing characters");
      Assert_Integer_Invalid ("8s1", "truncated size suffix");
   end Test_Invalid_Integer;

   procedure Test_To_Integer_32 (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Plain    : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("42");
      Hex      : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("0xFF");
      Negative : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("-3");
      Sized    : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("42s32");
      Overflow : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("2147483648");
      Min_Ok   : constant Compiler_Literals.Integer_32_Results.Result :=
        Compiler_Literals.To_Integer_32 ("-2147483648");
   begin
      case Plain.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "42 should evaluate");

         when True  =>
            AUnit.Assertions.Assert (Plain.Value = 42, "42 value");
      end case;

      case Hex.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "0xFF should evaluate");

         when True  =>
            AUnit.Assertions.Assert (Hex.Value = 255, "0xFF value");
      end case;

      case Negative.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "-3 should evaluate");

         when True  =>
            AUnit.Assertions.Assert (Negative.Value = -3, "-3 value");
      end case;

      case Sized.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "42s32 should evaluate");

         when True  =>
            AUnit.Assertions.Assert (Sized.Value = 42, "42s32 value");
      end case;

      case Overflow.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "2147483648 should overflow");

         when False =>
            AUnit.Assertions.Assert (Overflow.Error.Code = Compiler_Literals.Invalid_Literal, "overflow code");
      end case;

      case Min_Ok.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "Integer_32'First should evaluate");

         when True  =>
            AUnit.Assertions.Assert (Min_Ok.Value = Interfaces.Integer_32'First, "min value");
      end case;

      --  Lowercase hex digits.
      declare
         Lower_Hex : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("0xff");
      begin
         AUnit.Assertions.Assert (Lower_Hex.Ok and then Lower_Hex.Value = 255, "0xff value");
      end;

      --  Interpretation failures are forwarded.
      Assert_To_Integer_32_Invalid ("abc", "non-numeric lexeme");
      Assert_To_Integer_32_Invalid ("-2147483649", "negative below Integer_32'First");
      Assert_To_Integer_32_Invalid ("99999999999999999999", "magnitude overflow");

      --  Hand-built values that bypass lexeme validation.
      declare
         No_Digits    : constant Compiler_Literals.Integer_Literal_Value := (others => <>);
         Bad_Letter   : constant Compiler_Literals.Integer_Literal_Value :=
           (Base => 16, Digits_Text => Ada.Strings.Unbounded.To_Unbounded_String ("z"), others => <>);
         Bad_For_Base : constant Compiler_Literals.Integer_Literal_Value :=
           (Base => 2, Digits_Text => Ada.Strings.Unbounded.To_Unbounded_String ("2"), others => <>);
      begin
         Assert_Value_Invalid (No_Digits, "no digits");
         Assert_Value_Invalid (Bad_Letter, "non-hex letter");
         Assert_Value_Invalid (Bad_For_Base, "digit outside base");
      end;
   end Test_To_Integer_32;

end Lovelace.Compiler.Tests.Literals;
