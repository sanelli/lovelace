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
   end Test_Invalid_Integer;

   procedure Test_To_Integer_32 (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Plain    : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("42");
      Hex      : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("0xFF");
      Negative : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("-3");
      Sized    : constant Compiler_Literals.Integer_32_Results.Result := Compiler_Literals.To_Integer_32 ("42s32");
      Overflow : constant Compiler_Literals.Integer_32_Results.Result :=
        Compiler_Literals.To_Integer_32 ("2147483648");
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
   end Test_To_Integer_32;

end Lovelace.Compiler.Tests.Literals;
