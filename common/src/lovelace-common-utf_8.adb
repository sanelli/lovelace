package body Lovelace.Common.Utf_8 is

   procedure Decode
     (Source : String;
      Index  : Positive;
      Point  : out Code_Point;
      Length : out Natural;
      Valid  : out Boolean)
   is
      Lead : Natural;
      B2   : Natural;
      B3   : Natural;
      B4   : Natural;
      V    : Natural;
   begin
      Point := Wide_Wide_Character'Val (0);
      Length := 0;
      Valid := False;

      if Index not in Source'Range then
         return;
      end if;

      Lead := Character'Pos (Source (Index));

      if Lead <= 16#7F# then
         Length := 1;
         Point := Wide_Wide_Character'Val (Lead);
         Valid := True;
         return;
      end if;

      if Lead in 16#C2# .. 16#DF# then
         if Index + 1 > Source'Last then
            return;
         end if;
         B2 := Character'Pos (Source (Index + 1));
         if B2 not in 16#80# .. 16#BF# then
            return;
         end if;
         V := (Lead - 16#C0#) * 64 + (B2 - 16#80#);
         Length := 2;
         Point := Wide_Wide_Character'Val (V);
         Valid := True;
         return;
      end if;

      if Lead in 16#E0# .. 16#EF# then
         if Index + 2 > Source'Last then
            return;
         end if;
         B2 := Character'Pos (Source (Index + 1));
         B3 := Character'Pos (Source (Index + 2));
         if B2 not in 16#80# .. 16#BF#
           or else B3 not in 16#80# .. 16#BF#
         then
            return;
         end if;
         if Lead = 16#E0# and then B2 < 16#A0# then
            return;
         end if;
         if Lead = 16#ED# and then B2 > 16#9F# then
            return;
         end if;
         V :=
           (Lead - 16#E0#) * 4096
           + (B2 - 16#80#) * 64
           + (B3 - 16#80#);
         Length := 3;
         Point := Wide_Wide_Character'Val (V);
         Valid := True;
         return;
      end if;

      if Lead in 16#F0# .. 16#F4# then
         if Index + 3 > Source'Last then
            return;
         end if;
         B2 := Character'Pos (Source (Index + 1));
         B3 := Character'Pos (Source (Index + 2));
         B4 := Character'Pos (Source (Index + 3));
         if B2 not in 16#80# .. 16#BF#
           or else B3 not in 16#80# .. 16#BF#
           or else B4 not in 16#80# .. 16#BF#
         then
            return;
         end if;
         if Lead = 16#F0# and then B2 < 16#90# then
            return;
         end if;
         if Lead = 16#F4# and then B2 > 16#8F# then
            return;
         end if;
         V :=
           (Lead - 16#F0#) * 262144
           + (B2 - 16#80#) * 4096
           + (B3 - 16#80#) * 64
           + (B4 - 16#80#);
         if V > 16#10FFFF# then
            return;
         end if;
         Length := 4;
         Point := Wide_Wide_Character'Val (V);
         Valid := True;
         return;
      end if;
   end Decode;

   function Decode
     (Source : String;
      Index  : Positive) return Decode_Results.Result
   is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      Decode
        (Source => Source,
         Index  => Index,
         Point  => Point,
         Length => Length,
         Valid  => Valid);
      case Valid is
         when True =>
            return Decode_Results.From_Success (Point);
         when False =>
            return Decode_Results.From_Failure
              (Utf_8_Error
                 (Internal_Errors.Make
                    (Group   => Invalid_Sequence,
                     Message => "invalid UTF-8")));
      end case;
   end Decode;

   function Encode
     (Point : Code_Point) return Encode_Results.Result
   is
      V     : constant Natural := Wide_Wide_Character'Pos (Point);
      Bytes : Ada.Strings.Unbounded.Unbounded_String;
      Bad   : constant Boolean :=
        V in 16#D800# .. 16#DFFF# or else V > 16#10FFFF#;
   begin
      case Bad is
         when True =>
            return Encode_Results.From_Failure
              (Utf_8_Error
                 (Internal_Errors.Make
                    (Group   => Invalid_Code_Point,
                     Message => "invalid code point")));
         when False =>
            if V <= 16#7F# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (V)]);
            elsif V <= 16#7FF# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#C0# + V / 64),
                     Character'Val (16#80# + V mod 64)]);
            elsif V <= 16#FFFF# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#E0# + V / 16#1000#),
                     Character'Val (16#80# + (V / 64) mod 64),
                     Character'Val (16#80# + V mod 64)]);
            else
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#F0# + V / 16#40000#),
                     Character'Val (16#80# + (V / 16#1000#) mod 64),
                     Character'Val (16#80# + (V / 64) mod 64),
                     Character'Val (16#80# + V mod 64)]);
            end if;
            return Encode_Results.From_Success (Bytes);
      end case;
   end Encode;

   function Sequence_Length
     (Source : String;
      Index  : Positive) return Natural
   is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      Decode
        (Source => Source,
         Index  => Index,
         Point  => Point,
         Length => Length,
         Valid  => Valid);
      case Valid is
         when True =>
            return Length;
         when False =>
            return 0;
      end case;
   end Sequence_Length;

end Lovelace.Common.Utf_8;
