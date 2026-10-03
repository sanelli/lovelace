with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Compiler.Literals;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Tests.Literals is

   package Compiler_Literals renames Lovelace.Compiler.Literals;

   use type Compiler_Literals.Literal_Error_Code;
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
   begin
      case Positive_Value.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "1.5 should succeed");

         when True  =>
            AUnit.Assertions.Assert (not Positive_Value.Value.Is_Negative, "1.5 sign");
      end case;

      case Negative_Value.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "-7. should succeed");

         when True  =>
            AUnit.Assertions.Assert (Negative_Value.Value.Is_Negative, "-7. sign");
      end case;

      case Exp_Value.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "3.4E3 should succeed");

         when True  =>
            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.To_String (Exp_Value.Value.Lexeme) = "3.4E3", "3.4E3 lexeme");
      end case;
   end Test_Float_Forms;

   procedure Test_Integer_Forms (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Plain  : constant Compiler_Literals.Integer_Literal_Results.Result := Compiler_Literals.Interpret_Integer ("10");
      Based  : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("#16#FF");
      Sized  : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("-8u64");
      Binary : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("#2#1010");
   begin
      case Plain.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "10 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Plain.Value.Base = 10, "10 base");
            AUnit.Assertions.Assert (not Plain.Value.Has_Signedness, "10 no signedness");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Plain.Value.Digits_Text) = "10", "10 digits");
      end case;

      case Based.Ok is
         when False =>
            AUnit.Assertions.Assert (False, "#16#FF should succeed");

         when True  =>
            AUnit.Assertions.Assert (Based.Value.Base = 16, "#16#FF base");
            AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Based.Value.Digits_Text) = "FF", "#16#FF digits");
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
            AUnit.Assertions.Assert (False, "#2#1010 should succeed");

         when True  =>
            AUnit.Assertions.Assert (Binary.Value.Base = 2, "#2#1010 base");
      end case;
   end Test_Integer_Forms;

   procedure Test_Invalid_Integer (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Bad_Size : constant Compiler_Literals.Integer_Literal_Results.Result :=
        Compiler_Literals.Interpret_Integer ("8u3");
   begin
      case Bad_Size.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "8u3 should fail");

         when False =>
            AUnit.Assertions.Assert (Bad_Size.Error.Code = Compiler_Literals.Invalid_Literal, "8u3 code");
      end case;
   end Test_Invalid_Integer;

end Lovelace.Compiler.Tests.Literals;
