package body Lovelace.Compiler.Literals is

   function Failure (Code : Literal_Error_Code; Detail : String) return Integer_Literal_Results.Result;
   function Float_Failure (Code : Literal_Error_Code; Detail : String) return Float_Literal_Results.Result;
   function Is_Digit_For_Base (Byte : Character; Base : Positive) return Boolean;
   function Parse_Size_Suffix
     (Text : String; Index : in out Positive; The_Size : out Types.Integer_Size) return Boolean;

   function Failure (Code : Literal_Error_Code; Detail : String) return Integer_Literal_Results.Result is
   begin
      return (Ok => False, Error => (Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Failure;

   function Float_Failure (Code : Literal_Error_Code; Detail : String) return Float_Literal_Results.Result is
   begin
      return (Ok => False, Error => (Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Float_Failure;

   function Interpret_Float (Lexeme : String) return Float_Literal_Results.Result is
      Index       : Positive := Lexeme'First;
      Is_Negative : Boolean := False;
   begin
      if Lexeme'Length = 0 then
         return Float_Failure (Invalid_Literal, "empty float literal");
      end if;

      if Lexeme (Index) = '+' then
         Index := Index + 1;
      elsif Lexeme (Index) = '-' then
         Is_Negative := True;
         Index := Index + 1;
      end if;

      if Index > Lexeme'Last then
         return Float_Failure (Invalid_Literal, "float literal missing digits");
      end if;

      return
        (Ok    => True,
         Value => (Is_Negative => Is_Negative, Lexeme => Ada.Strings.Unbounded.To_Unbounded_String (Lexeme)));
   end Interpret_Float;

   function Interpret_Integer (Lexeme : String) return Integer_Literal_Results.Result is
      Index          : Positive := Lexeme'First;
      Is_Negative    : Boolean := False;
      Base           : Positive := 10;
      Digits_First   : Positive;
      Digits_Last    : Natural;
      Has_Signedness : Boolean := False;
      The_Signedness : Types.Signedness := Types.Signed;
      Has_Size       : Boolean := False;
      The_Size       : Types.Integer_Size := Types.Bits_32;
   begin
      if Lexeme'Length = 0 then
         return Failure (Invalid_Literal, "empty integer literal");
      end if;

      if Lexeme (Index) = '+' then
         Index := Index + 1;
      elsif Lexeme (Index) = '-' then
         Is_Negative := True;
         Index := Index + 1;
      end if;

      if Index > Lexeme'Last then
         return Failure (Invalid_Literal, "integer literal missing digits");
      end if;

      if Lexeme (Index) = '#' then
         if Index + 2 > Lexeme'Last then
            return Failure (Invalid_Literal, "incomplete based integer literal");
         end if;

         if Lexeme (Index .. Index + 2) = "#2#" then
            Base := 2;
            Index := Index + 3;
         elsif Lexeme (Index .. Index + 2) = "#8#" then
            Base := 8;
            Index := Index + 3;
         elsif Index + 3 <= Lexeme'Last and then Lexeme (Index .. Index + 3) = "#10#" then
            Base := 10;
            Index := Index + 4;
         elsif Index + 3 <= Lexeme'Last and then Lexeme (Index .. Index + 3) = "#16#" then
            Base := 16;
            Index := Index + 4;
         else
            return Failure (Invalid_Literal, "integer base must be 2, 8, 10, or 16");
         end if;
      end if;

      if Index > Lexeme'Last then
         return Failure (Invalid_Literal, "integer literal missing digits");
      end if;

      Digits_First := Index;
      while Index <= Lexeme'Last and then Is_Digit_For_Base (Lexeme (Index), Base) loop
         Index := Index + 1;
      end loop;
      Digits_Last := Index - 1;

      if Digits_Last < Digits_First then
         return Failure (Invalid_Literal, "integer literal has no valid digits for its base");
      end if;

      if Index <= Lexeme'Last and then (Lexeme (Index) = 's' or else Lexeme (Index) = 'u') then
         Has_Signedness := True;
         if Lexeme (Index) = 'u' then
            The_Signedness := Types.Unsigned;
         else
            The_Signedness := Types.Signed;
         end if;
         Index := Index + 1;

         if Index <= Lexeme'Last then
            if not Parse_Size_Suffix (Lexeme, Index, The_Size) then
               return Failure (Invalid_Literal, "invalid integer size suffix");
            end if;
            Has_Size := True;
         end if;
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

end Lovelace.Compiler.Literals;
