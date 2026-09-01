package body Lovelace.Common.Utf_8 is

   procedure Decode
     (Source : String;
      Index  : Positive;
      Point  : out Code_Point;
      Length : out Natural;
      Valid  : out Boolean)
   is
      Lead_Byte    : Natural;
      Second_Byte  : Natural;
      Third_Byte   : Natural;
      Fourth_Byte  : Natural;
      Scalar_Value : Natural;
   begin
      Point := Wide_Wide_Character'Val (0);
      Length := 0;
      Valid := False;

      if Index not in Source'Range then
         return;
      end if;

      Lead_Byte := Character'Pos (Source (Index));

      if Lead_Byte <= 16#7F# then
         Length := 1;
         Point := Wide_Wide_Character'Val (Lead_Byte);
         Valid := True;
         return;
      end if;

      if Lead_Byte in 16#C2# .. 16#DF# then
         if Index + 1 > Source'Last then
            return;
         end if;
         Second_Byte := Character'Pos (Source (Index + 1));
         if Second_Byte not in 16#80# .. 16#BF# then
            return;
         end if;
         Scalar_Value :=
           (Lead_Byte - 16#C0#) * 64 + (Second_Byte - 16#80#);
         Length := 2;
         Point := Wide_Wide_Character'Val (Scalar_Value);
         Valid := True;
         return;
      end if;

      if Lead_Byte in 16#E0# .. 16#EF# then
         if Index + 2 > Source'Last then
            return;
         end if;
         Second_Byte := Character'Pos (Source (Index + 1));
         Third_Byte := Character'Pos (Source (Index + 2));
         if Second_Byte not in 16#80# .. 16#BF#
           or else Third_Byte not in 16#80# .. 16#BF#
         then
            return;
         end if;
         if Lead_Byte = 16#E0# and then Second_Byte < 16#A0# then
            return;
         end if;
         if Lead_Byte = 16#ED# and then Second_Byte > 16#9F# then
            return;
         end if;
         Scalar_Value :=
           (Lead_Byte - 16#E0#) * 4096
           + (Second_Byte - 16#80#) * 64
           + (Third_Byte - 16#80#);
         Length := 3;
         Point := Wide_Wide_Character'Val (Scalar_Value);
         Valid := True;
         return;
      end if;

      if Lead_Byte in 16#F0# .. 16#F4# then
         if Index + 3 > Source'Last then
            return;
         end if;
         Second_Byte := Character'Pos (Source (Index + 1));
         Third_Byte := Character'Pos (Source (Index + 2));
         Fourth_Byte := Character'Pos (Source (Index + 3));
         if Second_Byte not in 16#80# .. 16#BF#
           or else Third_Byte not in 16#80# .. 16#BF#
           or else Fourth_Byte not in 16#80# .. 16#BF#
         then
            return;
         end if;
         if Lead_Byte = 16#F0# and then Second_Byte < 16#90# then
            return;
         end if;
         if Lead_Byte = 16#F4# and then Second_Byte > 16#8F# then
            return;
         end if;
         Scalar_Value :=
           (Lead_Byte - 16#F0#) * 262144
           + (Second_Byte - 16#80#) * 4096
           + (Third_Byte - 16#80#) * 64
           + (Fourth_Byte - 16#80#);
         if Scalar_Value > 16#10FFFF# then
            return;
         end if;
         Length := 4;
         Point := Wide_Wide_Character'Val (Scalar_Value);
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
      Scalar_Value : constant Natural :=
        Wide_Wide_Character'Pos (Point);
      Bytes        : Ada.Strings.Unbounded.Unbounded_String;
      Is_Invalid   : constant Boolean :=
        Scalar_Value in 16#D800# .. 16#DFFF#
        or else Scalar_Value > 16#10FFFF#;
   begin
      case Is_Invalid is
         when True =>
            return Encode_Results.From_Failure
              (Utf_8_Error
                 (Internal_Errors.Make
                    (Group   => Invalid_Code_Point,
                     Message => "invalid code point")));
         when False =>
            if Scalar_Value <= 16#7F# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (Scalar_Value)]);
            elsif Scalar_Value <= 16#7FF# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#C0# + Scalar_Value / 64),
                     Character'Val
                       (16#80# + Scalar_Value mod 64)]);
            elsif Scalar_Value <= 16#FFFF# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val
                       (16#E0# + Scalar_Value / 16#1000#),
                     Character'Val
                       (16#80# + (Scalar_Value / 64) mod 64),
                     Character'Val
                       (16#80# + Scalar_Value mod 64)]);
            else
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val
                       (16#F0# + Scalar_Value / 16#40000#),
                     Character'Val
                       (16#80#
                        + (Scalar_Value / 16#1000#) mod 64),
                     Character'Val
                       (16#80# + (Scalar_Value / 64) mod 64),
                     Character'Val
                       (16#80# + Scalar_Value mod 64)]);
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
