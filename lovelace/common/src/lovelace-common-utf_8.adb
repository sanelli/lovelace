package body Lovelace.Common.Utf_8 is

   procedure Decode_1 (Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean);
   procedure Decode_2
     (Source : String; Index : Positive; Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean);
   procedure Decode_3
     (Source : String; Index : Positive; Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean);
   procedure Decode_4
     (Source : String; Index : Positive; Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean);

   function Continuations_Valid (Source : String; First : Positive; Last : Positive) return Boolean;

   --  True iff every byte in Source (First .. Last) is a continuation byte (16#80# .. 16#BF#).
   function Continuations_Valid (Source : String; First : Positive; Last : Positive) return Boolean is
   begin
      for Position in First .. Last loop
         if Character'Pos (Source (Position)) not in 16#80# .. 16#BF# then
            return False;
         end if;
      end loop;
      return True;
   end Continuations_Valid;

   procedure Decode
     (Source : String; Index : Positive; Point : out Code_Point; Length : out Natural; Valid : out Boolean)
   is
      Lead_Byte       : Natural;
      Scalar_Value    : Natural := 0;
      Expected_Length : Natural := 0;
   begin
      Point := Wide_Wide_Character'Val (0);
      Length := 0;
      Valid := False;

      if Index not in Source'Range then
         return;
      end if;

      Lead_Byte := Character'Pos (Source (Index));

      if Lead_Byte <= 16#7F# then
         Expected_Length := 1;
         Decode_1 (Lead_Byte, Scalar_Value, Valid);
      elsif Lead_Byte in 16#C2# .. 16#DF# then
         Expected_Length := 2;
         Decode_2 (Source, Index, Lead_Byte, Scalar_Value, Valid);
      elsif Lead_Byte in 16#E0# .. 16#EF# then
         Expected_Length := 3;
         Decode_3 (Source, Index, Lead_Byte, Scalar_Value, Valid);
      elsif Lead_Byte in 16#F0# .. 16#F4# then
         Expected_Length := 4;
         Decode_4 (Source, Index, Lead_Byte, Scalar_Value, Valid);
      end if;

      if Valid then
         Length := Expected_Length;
         Point := Wide_Wide_Character'Val (Scalar_Value);
      end if;
   end Decode;

   function Decode (Source : String; Index : Positive) return Decode_Results.Result is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      Decode (Source => Source, Index => Index, Point => Point, Length => Length, Valid => Valid);
      case Valid is
         when True  =>
            return Decode_Results.From_Success (Point);

         when False =>
            return
              Decode_Results.From_Failure
                (Utf_8_Error (Internal_Errors.Make (Group => Invalid_Sequence, Message => "invalid UTF-8")));
      end case;
   end Decode;

   --  ASCII (one byte).
   procedure Decode_1 (Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean) is
   begin
      Scalar_Value := Lead_Byte;
      Valid := True;
   end Decode_1;

   --  Two-byte sequence (lead 16#C2# .. 16#DF#).
   procedure Decode_2
     (Source : String; Index : Positive; Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean) is
   begin
      Scalar_Value := 0;
      Valid := False;

      if Index + 1 > Source'Last or else not Continuations_Valid (Source, Index + 1, Index + 1) then
         return;
      end if;

      Scalar_Value := (Lead_Byte - 16#C0#) * 64 + (Character'Pos (Source (Index + 1)) - 16#80#);
      Valid := True;
   end Decode_2;

   --  Three-byte sequence (lead 16#E0# .. 16#EF#); rejects overlongs and surrogates.
   procedure Decode_3
     (Source : String; Index : Positive; Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean)
   is
      Second_Byte : Natural;
   begin
      Scalar_Value := 0;
      Valid := False;

      if Index + 2 > Source'Last or else not Continuations_Valid (Source, Index + 1, Index + 2) then
         return;
      end if;

      Second_Byte := Character'Pos (Source (Index + 1));
      if (Lead_Byte = 16#E0# and then Second_Byte < 16#A0#) or else (Lead_Byte = 16#ED# and then Second_Byte > 16#9F#)
      then
         return;
      end if;

      Scalar_Value :=
        (Lead_Byte - 16#E0#) * 4096 + (Second_Byte - 16#80#) * 64 + (Character'Pos (Source (Index + 2)) - 16#80#);
      Valid := True;
   end Decode_3;

   --  Four-byte sequence (lead 16#F0# .. 16#F4#); rejects overlongs and values above U+10FFFF.
   procedure Decode_4
     (Source : String; Index : Positive; Lead_Byte : Natural; Scalar_Value : out Natural; Valid : out Boolean)
   is
      Second_Byte : Natural;
      Candidate   : Natural;
   begin
      Scalar_Value := 0;
      Valid := False;

      if Index + 3 > Source'Last or else not Continuations_Valid (Source, Index + 1, Index + 3) then
         return;
      end if;

      Second_Byte := Character'Pos (Source (Index + 1));
      if (Lead_Byte = 16#F0# and then Second_Byte < 16#90#) or else (Lead_Byte = 16#F4# and then Second_Byte > 16#8F#)
      then
         return;
      end if;

      Candidate :=
        (Lead_Byte - 16#F0#)
        * 262144
        + (Second_Byte - 16#80#) * 4096
        + (Character'Pos (Source (Index + 2)) - 16#80#) * 64
        + (Character'Pos (Source (Index + 3)) - 16#80#);
      if Candidate > 16#10FFFF# then
         return;
      end if;

      Scalar_Value := Candidate;
      Valid := True;
   end Decode_4;

   function Encode (Point : Code_Point) return Encode_Results.Result is
      Scalar_Value : constant Natural := Wide_Wide_Character'Pos (Point);
      Bytes        : Ada.Strings.Unbounded.Unbounded_String;
      Is_Invalid   : constant Boolean := Scalar_Value in 16#D800# .. 16#DFFF# or else Scalar_Value > 16#10FFFF#;
   begin
      case Is_Invalid is
         when True  =>
            return
              Encode_Results.From_Failure
                (Utf_8_Error (Internal_Errors.Make (Group => Invalid_Code_Point, Message => "invalid code point")));

         when False =>
            if Scalar_Value <= 16#7F# then
               Bytes := Ada.Strings.Unbounded.To_Unbounded_String ([Character'Val (Scalar_Value)]);
            elsif Scalar_Value <= 16#7FF# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#C0# + Scalar_Value / 64), Character'Val (16#80# + Scalar_Value mod 64)]);
            elsif Scalar_Value <= 16#FFFF# then
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#E0# + Scalar_Value / 16#1000#),
                     Character'Val (16#80# + (Scalar_Value / 64) mod 64),
                     Character'Val (16#80# + Scalar_Value mod 64)]);
            else
               Bytes :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ([Character'Val (16#F0# + Scalar_Value / 16#40000#),
                     Character'Val (16#80# + (Scalar_Value / 16#1000#) mod 64),
                     Character'Val (16#80# + (Scalar_Value / 64) mod 64),
                     Character'Val (16#80# + Scalar_Value mod 64)]);
            end if;
            return Encode_Results.From_Success (Bytes);
      end case;
   end Encode;

   function Sequence_Length (Source : String; Index : Positive) return Natural is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      Decode (Source => Source, Index => Index, Point => Point, Length => Length, Valid => Valid);
      case Valid is
         when True  =>
            return Length;

         when False =>
            return 0;
      end case;
   end Sequence_Length;

end Lovelace.Common.Utf_8;
