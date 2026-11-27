package body Lovelace.Compiler.Literals is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_64;

   function Failure (Code : Literal_Error_Code; Detail : String) return Integer_Literal_Results.Result;
   function Float_Failure (Code : Literal_Error_Code; Detail : String) return Float_Literal_Results.Result;
   function Integer_32_Failure (Code : Literal_Error_Code; Detail : String) return Integer_32_Results.Result;
   function Digit_Value (Byte : Character; Base : Positive; Value : out Natural) return Boolean;
   function Is_Digit_For_Base (Byte : Character; Base : Positive) return Boolean;
   function Parse_Size_Suffix
     (Text : String; Index : in out Positive; The_Size : out Types.Integer_Size) return Boolean;
   function Parse_Float_Width_Suffix
     (Text : String; Last : in out Natural; The_Width : out Types.Float_Size; Found : out Boolean) return Boolean;
   function Is_Decimal_Digit (Byte : Character) return Boolean;
   function Has_Char
     (Text : String; Index : Positive; Last : Natural; First_Char : Character; Second_Char : Character) return Boolean;
   procedure Parse_Base_Prefix (Text : String; Index : in out Positive; Base : out Positive);
   procedure Parse_Digits
     (Text : String; Index : in out Positive; Base : Positive; Digits_First : out Positive; Digits_Last : out Natural);
   function Parse_Float_Body
     (Text : String; First : Positive; Last : Natural; Has_Dot : out Boolean; Has_Exponent : out Boolean) return String;
   function Parse_Float_Exponent
     (Text : String; Index : in out Positive; Last : Natural; Has_Exponent : out Boolean) return Boolean;
   function Parse_Integer_Suffix
     (Text           : String;
      Index          : in out Positive;
      Has_Signedness : out Boolean;
      The_Signedness : out Types.Signedness;
      Has_Size       : out Boolean;
      The_Size       : out Types.Integer_Size) return Boolean;
   procedure Parse_Sign (Text : String; Index : in out Positive; Is_Negative : out Boolean);
   function Skip_Decimal_Digits (Text : String; From : Positive; Last : Natural) return Positive;

   function Digit_Value (Byte : Character; Base : Positive; Value : out Natural) return Boolean is
   begin
      Value := 0;
      if Byte in '0' .. '9' then
         Value := Character'Pos (Byte) - Character'Pos ('0');
      elsif Byte in 'A' .. 'F' then
         Value := 10 + (Character'Pos (Byte) - Character'Pos ('A'));
      elsif Byte in 'a' .. 'f' then
         Value := 10 + (Character'Pos (Byte) - Character'Pos ('a'));
      else
         return False;
      end if;
      return Value < Base;
   end Digit_Value;

   function Failure (Code : Literal_Error_Code; Detail : String) return Integer_Literal_Results.Result is
   begin
      return (Ok => False, Error => (Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Failure;

   function Float_Failure (Code : Literal_Error_Code; Detail : String) return Float_Literal_Results.Result is
   begin
      return (Ok => False, Error => (Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Float_Failure;

   function Has_Char
     (Text : String; Index : Positive; Last : Natural; First_Char : Character; Second_Char : Character) return Boolean
   is
   begin
      return Index <= Last and then (Text (Index) = First_Char or else Text (Index) = Second_Char);
   end Has_Char;

   function Integer_32_Failure (Code : Literal_Error_Code; Detail : String) return Integer_32_Results.Result is
   begin
      return (Ok => False, Error => (Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Integer_32_Failure;

   function Interpret_Float (Lexeme : String) return Float_Literal_Results.Result is
      Index       : Positive := Lexeme'First;
      Body_Last   : Natural;
      Is_Negative : Boolean;
      The_Width   : Types.Float_Size := Types.Bits_32;
      Has_Width   : Boolean := False;
      Has_Dot     : Boolean;
      Has_Exp     : Boolean;
   begin
      if Lexeme'Length = 0 then
         return Float_Failure (Invalid_Literal, "empty float literal");
      end if;

      Parse_Sign (Lexeme, Index, Is_Negative);

      Body_Last := Lexeme'Last;
      if not Parse_Float_Width_Suffix (Lexeme, Body_Last, The_Width, Has_Width) then
         return Float_Failure (Invalid_Literal, "invalid float width suffix");
      end if;

      if Index > Body_Last then
         return Float_Failure (Invalid_Literal, "float literal missing digits");
      end if;

      declare
         Detail : constant String := Parse_Float_Body (Lexeme, Index, Body_Last, Has_Dot, Has_Exp);
      begin
         if Detail'Length > 0 then
            return Float_Failure (Invalid_Literal, Detail);
         end if;
      end;

      if not Has_Dot and then not Has_Exp and then not Has_Width then
         return Float_Failure (Invalid_Literal, "float literal requires '.' exponent or width suffix");
      end if;

      return
        (Ok    => True,
         Value =>
           (Is_Negative => Is_Negative,
            The_Width   => The_Width,
            Lexeme      => Ada.Strings.Unbounded.To_Unbounded_String (Lexeme)));
   end Interpret_Float;

   function Interpret_Integer (Lexeme : String) return Integer_Literal_Results.Result is
      Index          : Positive := Lexeme'First;
      Is_Negative    : Boolean;
      Base           : Positive;
      Digits_First   : Positive;
      Digits_Last    : Natural;
      Has_Signedness : Boolean;
      The_Signedness : Types.Signedness;
      Has_Size       : Boolean;
      The_Size       : Types.Integer_Size;
   begin
      if Lexeme'Length = 0 then
         return Failure (Invalid_Literal, "empty integer literal");
      end if;

      Parse_Sign (Lexeme, Index, Is_Negative);
      if Index > Lexeme'Last then
         return Failure (Invalid_Literal, "integer literal missing digits");
      end if;

      Parse_Base_Prefix (Lexeme, Index, Base);
      if Index > Lexeme'Last then
         return Failure (Invalid_Literal, "integer literal missing digits");
      end if;

      Parse_Digits (Lexeme, Index, Base, Digits_First, Digits_Last);
      if Digits_Last < Digits_First then
         return Failure (Invalid_Literal, "integer literal has no valid digits for its base");
      end if;

      if not Parse_Integer_Suffix (Lexeme, Index, Has_Signedness, The_Signedness, Has_Size, The_Size) then
         return Failure (Invalid_Literal, "invalid integer size suffix");
      end if;

      if Index <= Lexeme'Last then
         return Failure (Invalid_Literal, "trailing characters in integer literal");
      end if;

      return
        (Ok    => True,
         Value =>
           (Is_Negative    => Is_Negative,
            Base           => Base,
            Digits_Text    => Ada.Strings.Unbounded.To_Unbounded_String (Lexeme (Digits_First .. Digits_Last)),
            Has_Signedness => Has_Signedness,
            The_Signedness => The_Signedness,
            Has_Size       => Has_Size,
            The_Size       => The_Size));
   end Interpret_Integer;

   function Is_Decimal_Digit (Byte : Character) return Boolean is
   begin
      return Byte in '0' .. '9';
   end Is_Decimal_Digit;

   function Is_Digit_For_Base (Byte : Character; Base : Positive) return Boolean is
   begin
      case Base is
         when 2      =>
            return Byte = '0' or else Byte = '1';

         when 8      =>
            return Byte in '0' .. '7';

         when 10     =>
            return Byte in '0' .. '9';

         when 16     =>
            return Byte in '0' .. '9' or else Byte in 'A' .. 'F' or else Byte in 'a' .. 'f';

         when others =>
            return False;
      end case;
   end Is_Digit_For_Base;

   --  Consume an optional 0b/0o/0x prefix (either case); Base is 10 when absent.
   procedure Parse_Base_Prefix (Text : String; Index : in out Positive; Base : out Positive) is
   begin
      Base := 10;
      if Index < Text'Last and then Text (Index) = '0' then
         case Text (Index + 1) is
            when 'b' | 'B' =>
               Base := 2;

            when 'o' | 'O' =>
               Base := 8;

            when 'x' | 'X' =>
               Base := 16;

            when others    =>
               return;
         end case;
         Index := Index + 2;
      end if;
   end Parse_Base_Prefix;

   --  Consume the run of digits valid for Base. Digits_Last < Digits_First when none.
   procedure Parse_Digits
     (Text : String; Index : in out Positive; Base : Positive; Digits_First : out Positive; Digits_Last : out Natural)
   is
   begin
      Digits_First := Index;
      while Index <= Text'Last and then Is_Digit_For_Base (Text (Index), Base) loop
         Index := Index + 1;
      end loop;
      Digits_Last := Index - 1;
   end Parse_Digits;

   --  Validate mantissa digits, optional fraction and exponent in Text (First .. Last).
   --  Returns "" on success, otherwise the failure detail.
   function Parse_Float_Body
     (Text : String; First : Positive; Last : Natural; Has_Dot : out Boolean; Has_Exponent : out Boolean) return String
   is
      Index : Positive := Skip_Decimal_Digits (Text, First, Last);
   begin
      Has_Dot := False;
      Has_Exponent := False;

      if Index = First then
         return "float literal missing digits";
      end if;

      if Has_Char (Text, Index, Last, '.', '.') then
         Has_Dot := True;
         Index := Skip_Decimal_Digits (Text, Index + 1, Last);
      end if;

      if not Parse_Float_Exponent (Text, Index, Last, Has_Exponent) then
         return "float exponent missing digits";
      end if;

      if Index <= Last then
         return "trailing characters in float literal";
      end if;

      return "";
   end Parse_Float_Body;

   --  Consume an optional exponent. False when an exponent marker has no digits.
   function Parse_Float_Exponent
     (Text : String; Index : in out Positive; Last : Natural; Has_Exponent : out Boolean) return Boolean is
   begin
      Has_Exponent := Has_Char (Text, Index, Last, 'e', 'E');
      if not Has_Exponent then
         return True;
      end if;

      Index := Index + 1;
      if Has_Char (Text, Index, Last, '+', '-') then
         Index := Index + 1;
      end if;
      if Index > Last or else not Is_Decimal_Digit (Text (Index)) then
         return False;
      end if;

      Index := Skip_Decimal_Digits (Text, Index, Last);
      return True;
   end Parse_Float_Exponent;

   function Parse_Float_Width_Suffix
     (Text : String; Last : in out Natural; The_Width : out Types.Float_Size; Found : out Boolean) return Boolean is
   begin
      Found := False;
      The_Width := Types.Bits_32;
      if Last < Text'First + 2 then
         return True;
      end if;

      declare
         Suffix : constant String := Text (Last - 2 .. Last);
      begin
         if Suffix = "f32" or else Suffix = "F32" then
            The_Width := Types.Bits_32;
            Found := True;
            Last := Last - 3;
            return True;
         elsif Suffix = "f64" or else Suffix = "F64" then
            The_Width := Types.Bits_64;
            Found := True;
            Last := Last - 3;
            return True;
         end if;
      end;

      return True;
   end Parse_Float_Width_Suffix;

   --  Consume an optional s/u signedness marker with optional size (8/16/32/64).
   --  False when a size follows the marker but is not a valid size.
   function Parse_Integer_Suffix
     (Text           : String;
      Index          : in out Positive;
      Has_Signedness : out Boolean;
      The_Signedness : out Types.Signedness;
      Has_Size       : out Boolean;
      The_Size       : out Types.Integer_Size) return Boolean is
   begin
      Has_Signedness := False;
      The_Signedness := Types.Signed;
      Has_Size := False;
      The_Size := Types.Bits_32;

      if not Has_Char (Text, Index, Text'Last, 's', 'u') then
         return True;
      end if;

      Has_Signedness := True;
      if Text (Index) = 'u' then
         The_Signedness := Types.Unsigned;
      end if;
      Index := Index + 1;

      if Index <= Text'Last then
         if not Parse_Size_Suffix (Text, Index, The_Size) then
            return False;
         end if;
         Has_Size := True;
      end if;
      return True;
   end Parse_Integer_Suffix;

   --  Consume an optional leading '+' or '-'.
   procedure Parse_Sign (Text : String; Index : in out Positive; Is_Negative : out Boolean) is
   begin
      Is_Negative := Text (Index) = '-';
      if Has_Char (Text, Index, Text'Last, '+', '-') then
         Index := Index + 1;
      end if;
   end Parse_Sign;

   function Parse_Size_Suffix (Text : String; Index : in out Positive; The_Size : out Types.Integer_Size) return Boolean
   is
   begin
      if Index + 1 <= Text'Last and then Text (Index .. Index + 1) = "16" then
         The_Size := Types.Bits_16;
         Index := Index + 2;
         return True;
      elsif Index + 1 <= Text'Last and then Text (Index .. Index + 1) = "32" then
         The_Size := Types.Bits_32;
         Index := Index + 2;
         return True;
      elsif Index + 1 <= Text'Last and then Text (Index .. Index + 1) = "64" then
         The_Size := Types.Bits_64;
         Index := Index + 2;
         return True;
      elsif Text (Index) = '8' then
         The_Size := Types.Bits_8;
         Index := Index + 1;
         return True;
      end if;

      return False;
   end Parse_Size_Suffix;

   --  Index of the first non-decimal-digit at or after From (Last + 1 when none).
   function Skip_Decimal_Digits (Text : String; From : Positive; Last : Natural) return Positive is
      Index : Positive := From;
   begin
      while Index <= Last and then Is_Decimal_Digit (Text (Index)) loop
         Index := Index + 1;
      end loop;
      return Index;
   end Skip_Decimal_Digits;

   function To_Integer_32 (The_Value : Integer_Literal_Value) return Integer_32_Results.Result is
      Digits_Text : constant String := Ada.Strings.Unbounded.To_String (The_Value.Digits_Text);
      Magnitude   : Interfaces.Unsigned_64 := 0;
      Base_U      : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (The_Value.Base);
      Max_Pos     : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (Interfaces.Integer_32'Last);
      Max_Neg_Mag : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (Interfaces.Integer_32'Last) + 1;
   begin
      if Digits_Text'Length = 0 then
         return Integer_32_Failure (Invalid_Literal, "integer literal has no digits");
      end if;

      for Index in Digits_Text'Range loop
         declare
            Dig : Natural;
         begin
            if not Digit_Value (Digits_Text (Index), The_Value.Base, Dig) then
               return Integer_32_Failure (Invalid_Literal, "invalid digit in integer literal");
            end if;
            if Magnitude > (Interfaces.Unsigned_64'Last - Interfaces.Unsigned_64 (Dig)) / Base_U then
               return Integer_32_Failure (Invalid_Literal, "integer literal magnitude overflows");
            end if;
            Magnitude := Magnitude * Base_U + Interfaces.Unsigned_64 (Dig);
         end;
      end loop;

      if The_Value.Is_Negative then
         if Magnitude > Max_Neg_Mag then
            return Integer_32_Failure (Invalid_Literal, "integer literal out of Integer_32 range");
         end if;
         if Magnitude = Max_Neg_Mag then
            return (Ok => True, Value => Interfaces.Integer_32'First);
         end if;
         return (Ok => True, Value => -Interfaces.Integer_32 (Magnitude));
      end if;

      if Magnitude > Max_Pos then
         return Integer_32_Failure (Invalid_Literal, "integer literal out of Integer_32 range");
      end if;
      return (Ok => True, Value => Interfaces.Integer_32 (Magnitude));
   end To_Integer_32;

   function To_Integer_32 (Lexeme : String) return Integer_32_Results.Result is
      Interpreted : constant Integer_Literal_Results.Result := Interpret_Integer (Lexeme);
   begin
      case Interpreted.Ok is
         when False =>
            return (Ok => False, Error => Interpreted.Error);

         when True  =>
            return To_Integer_32 (Interpreted.Value);
      end case;
   end To_Integer_32;

end Lovelace.Compiler.Literals;
