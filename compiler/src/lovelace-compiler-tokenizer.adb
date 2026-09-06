with Lovelace.Common.Option;
with Lovelace.Common.Regex;
with Lovelace.Common.Utf_8;

package body Lovelace.Compiler.Tokenizer is

   use type Tokens.Token_Kind;

   subtype Code_Point is Lovelace.Common.Utf_8.Code_Point;

   type Scalar_Range is record
      Low  : Code_Point;
      High : Code_Point;
   end record;

   type Scalar_Range_List is array (Positive range <>) of Scalar_Range;

   type Keyword_Entry is record
      Lexeme : Ada.Strings.Unbounded.Unbounded_String;
      Value  : Tokens.Keyword_Subtype;
   end record;

   type Keyword_Entry_List is array (Positive range <>) of Keyword_Entry;

   type Punctuation_Entry is record
      Lexeme : Ada.Strings.Unbounded.Unbounded_String;
      Value  : Tokens.Punctuation_Subtype;
   end record;

   type Punctuation_Entry_List is array (Positive range <>) of Punctuation_Entry;

   type Scan_Class is record
      The_Engine : Lovelace.Common.Regex.Engine;
      Kind       : Tokens.Token_Kind;
   end record;

   package Keyword_Options is new Lovelace.Common.Option (Element_Type => Tokens.Keyword_Subtype);

   package Punctuation_Options is new Lovelace.Common.Option (Element_Type => Tokens.Punctuation_Subtype);

   package Scan_Class_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Scan_Class);

   --  Unicode space and line/paragraph separators skipped between tokens.
   Whitespace_Ranges : constant Scalar_Range_List :=
     [Scalar_Range'(Low => Wide_Wide_Character'Val (16#0009#), High => Wide_Wide_Character'Val (16#000D#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#0020#), High => Wide_Wide_Character'Val (16#0020#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#0085#), High => Wide_Wide_Character'Val (16#0085#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#00A0#), High => Wide_Wide_Character'Val (16#00A0#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#1680#), High => Wide_Wide_Character'Val (16#1680#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#2000#), High => Wide_Wide_Character'Val (16#200A#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#2028#), High => Wide_Wide_Character'Val (16#2029#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#202F#), High => Wide_Wide_Character'Val (16#202F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#205F#), High => Wide_Wide_Character'Val (16#205F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#3000#), High => Wide_Wide_Character'Val (16#3000#))];

   --  Unicode punctuation blocks excluded from identifiers.
   Punctuation_Ranges : constant Scalar_Range_List :=
     [Scalar_Range'(Low => Wide_Wide_Character'Val (16#2000#), High => Wide_Wide_Character'Val (16#206F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#2E00#), High => Wide_Wide_Character'Val (16#2E7F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#3000#), High => Wide_Wide_Character'Val (16#303F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#FE30#), High => Wide_Wide_Character'Val (16#FE4F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#FE50#), High => Wide_Wide_Character'Val (16#FE6F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#FF00#), High => Wide_Wide_Character'Val (16#FFEF#))];

   --  Unicode Other_Format (Cf) excluded from identifiers.
   Other_Format_Ranges : constant Scalar_Range_List :=
     [Scalar_Range'(Low => Wide_Wide_Character'Val (16#00AD#), High => Wide_Wide_Character'Val (16#00AD#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#0600#), High => Wide_Wide_Character'Val (16#0605#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#061C#), High => Wide_Wide_Character'Val (16#061C#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#06DD#), High => Wide_Wide_Character'Val (16#06DD#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#070F#), High => Wide_Wide_Character'Val (16#070F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#0890#), High => Wide_Wide_Character'Val (16#0891#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#08E2#), High => Wide_Wide_Character'Val (16#08E2#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#180E#), High => Wide_Wide_Character'Val (16#180E#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#200B#), High => Wide_Wide_Character'Val (16#200F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#202A#), High => Wide_Wide_Character'Val (16#202E#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#2060#), High => Wide_Wide_Character'Val (16#2064#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#2066#), High => Wide_Wide_Character'Val (16#206F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#FEFF#), High => Wide_Wide_Character'Val (16#FEFF#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#FFF9#), High => Wide_Wide_Character'Val (16#FFFB#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#110BD#), High => Wide_Wide_Character'Val (16#110BD#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#110CD#), High => Wide_Wide_Character'Val (16#110CD#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#13430#), High => Wide_Wide_Character'Val (16#1343F#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#1BCA0#), High => Wide_Wide_Character'Val (16#1BCA3#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#1D173#), High => Wide_Wide_Character'Val (16#1D17A#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#E0001#), High => Wide_Wide_Character'Val (16#E0001#)),
      Scalar_Range'(Low => Wide_Wide_Character'Val (16#E0020#), High => Wide_Wide_Character'Val (16#E007F#))];

   --  ASCII graphic punctuation excluded from identifiers (not letters, digits, or underscore).
   Ascii_Punctuation : constant String := "!""#$%&'()*+,-./:;<=>?@[\]^`{|}~";

   --  Exact lexemes classified as keywords after an identifier match.
   Keyword_Table : constant Keyword_Entry_List :=
     [Keyword_Entry'
        (Lexeme => Ada.Strings.Unbounded.To_Unbounded_String ("program"),
         Value  => Tokens.Program_Keyword),
      Keyword_Entry'
        (Lexeme => Ada.Strings.Unbounded.To_Unbounded_String ("begin"),
         Value  => Tokens.Begin_Keyword),
      Keyword_Entry'
        (Lexeme => Ada.Strings.Unbounded.To_Unbounded_String ("end"),
         Value  => Tokens.End_Keyword)];

   --  Exact lexemes classified as punctuation tokens.
   Punctuation_Table : constant Punctuation_Entry_List :=
     [Punctuation_Entry'
        (Lexeme => Ada.Strings.Unbounded.To_Unbounded_String (";"),
         Value  => Tokens.Semicolon),
      Punctuation_Entry'
        (Lexeme => Ada.Strings.Unbounded.To_Unbounded_String ("."),
         Value  => Tokens.Full_Stop)];

   Patterns_Ready    : Boolean := False;
   Whitespace_Engine : Lovelace.Common.Regex.Engine;
   Scan_Classes      : Scan_Class_Vectors.Vector;

   function Ascii_Punctuation_Class return String;
   function Ensure_Patterns (Filename : Source.Filename_Option) return Tokenizer_Error_Sequence;
   function Escape_Regex_Lexeme (Lexeme : String) return String;
   function Failure_Result (Errors : Tokenizer_Error_Sequence) return Tokenize_Result;
   function Format_Scalar (Point : Code_Point) return String;
   function Hex_Digit (Value : Natural) return Character;
   function Identifier_Pattern return String;
   function Internal_Compile_Error
     (Error : Lovelace.Common.Regex.Regex_Error; Filename : Source.Filename_Option)
      return Tokenizer_Error_Sequence;
   function Is_Excluded_Punctuation (Point : Code_Point) return Boolean;
   function Is_Identifier_Continue (Point : Code_Point) return Boolean;
   function Is_Identifier_First (Point : Code_Point) return Boolean;
   function Is_In_Ranges (Point : Code_Point; Ranges : Scalar_Range_List) return Boolean;
   function Lookup_Keyword (Lexeme : String) return Keyword_Options.Option;
   function Lookup_Punctuation (Lexeme : String) return Punctuation_Options.Option;
   function Make_Span
     (Source_Text : String;
      Position    : Positive;
      Byte_Count  : Natural;
      Line        : Positive;
      Column      : Positive) return Source.Source_Span;
   function Negated_Class (Exclusions : String) return String;
   function Punctuation_Pattern return String;
   function Register_Scan_Class
     (Pattern  : String;
      Kind     : Tokens.Token_Kind;
      Filename : Source.Filename_Option) return Tokenizer_Error_Sequence;
   function Scalar_To_Class (Point : Code_Point) return String;
   function Success_Result (Token_List : Tokens.Token_Sequence) return Tokenize_Result;
   function Tokenize_Core
     (Source_Text : String; Filename : Source.Filename_Option) return Tokenize_Result;
   function Truncate_Identifier_Length
     (Source_Text : String; From : Positive; Max_Length : Natural) return Natural;
   function Unicode_Ranges_To_Class (Ranges : Scalar_Range_List) return String;
   function Whitespace_Pattern return String;
   procedure Advance_Bytes
     (Source_Text   : String;
      Byte_Count    : Natural;
      Position      : in out Positive;
      Line          : in out Positive;
      Column        : in out Positive;
      Last_Position : out Source.Source_Position);
   procedure Append_Error
     (Errors   : in out Tokenizer_Error_Sequence;
      Code     : Tokenizer_Error_Code;
      First    : Source.Source_Position;
      Last     : Source.Source_Position;
      Filename : Source.Filename_Option;
      Detail   : String);
   procedure Append_Matched
     (Token_List   : in out Tokens.Token_Sequence;
      Errors       : in out Tokenizer_Error_Sequence;
      Source_Text  : String;
      Position     : in out Positive;
      Line         : in out Positive;
      Column       : in out Positive;
      Match_Length : Natural;
      Kind         : Tokens.Token_Kind;
      Filename     : Source.Filename_Option);
   function Compile_Cached (Pattern : String) return Lovelace.Common.Regex.Regex_Result;
   procedure Longest_Scan_Match
     (Source_Text     : String;
      Position        : Positive;
      After_Delimiter : Boolean;
      Match_Length    : out Natural;
      Kind            : out Tokens.Token_Kind);
   procedure Report_Invalid_Utf_8
     (Errors      : in out Tokenizer_Error_Sequence;
      Source_Text : String;
      Position    : in out Positive;
      Line        : in out Positive;
      Column      : in out Positive;
      Filename    : Source.Filename_Option);
   procedure Report_Unrecognized_Symbol
     (Errors      : in out Tokenizer_Error_Sequence;
      Source_Text : String;
      Position    : in out Positive;
      Line        : in out Positive;
      Column      : in out Positive;
      Filename    : Source.Filename_Option);

   procedure Advance_Bytes
     (Source_Text   : String;
      Byte_Count    : Natural;
      Position      : in out Positive;
      Line          : in out Positive;
      Column        : in out Positive;
      Last_Position : out Source.Source_Position)
   is
      Remaining : Natural := Byte_Count;
      Point     : Code_Point;
      Length    : Natural;
      Valid     : Boolean;
   begin
      Last_Position := (Byte_Index => Position, Line => Line, Column => Column);

      while Remaining > 0 and then Position <= Source_Text'Last loop
         Lovelace.Common.Utf_8.Decode
           (Source => Source_Text, Index => Position, Point => Point, Length => Length, Valid => Valid);
         exit when not Valid or else Length = 0 or else Length > Remaining;

         if Point = Wide_Wide_Character'Val (16#000D#)
           and then Length = 1
           and then Remaining >= 2
           and then Position + 1 <= Source_Text'Last
           and then Source_Text (Position + 1) = Character'Val (16#0A#)
         then
            Last_Position := (Byte_Index => Position + 1, Line => Line, Column => Column);
            Position := Position + 2;
            Remaining := Remaining - 2;
            Line := Line + 1;
            Column := 1;
         elsif Point = Wide_Wide_Character'Val (16#000A#) or else Point = Wide_Wide_Character'Val (16#000D#) then
            Last_Position := (Byte_Index => Position + Length - 1, Line => Line, Column => Column);
            Position := Position + Length;
            Remaining := Remaining - Length;
            Line := Line + 1;
            Column := 1;
         else
            Last_Position := (Byte_Index => Position + Length - 1, Line => Line, Column => Column);
            Position := Position + Length;
            Remaining := Remaining - Length;
            Column := Column + 1;
         end if;
      end loop;
   end Advance_Bytes;

   procedure Append_Error
     (Errors   : in out Tokenizer_Error_Sequence;
      Code     : Tokenizer_Error_Code;
      First    : Source.Source_Position;
      Last     : Source.Source_Position;
      Filename : Source.Filename_Option;
      Detail   : String)
   is
   begin
      Errors.Items.Append
        (Tokenizer_Error'
           (Code     => Code,
            Span     => (First => First, Last => Last),
            Filename => Filename,
            Detail   => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Append_Error;

   procedure Append_Matched
     (Token_List   : in out Tokens.Token_Sequence;
      Errors       : in out Tokenizer_Error_Sequence;
      Source_Text  : String;
      Position     : in out Positive;
      Line         : in out Positive;
      Column       : in out Positive;
      Match_Length : Natural;
      Kind         : Tokens.Token_Kind;
      Filename     : Source.Filename_Option)
   is
      Consumed          : Natural := Match_Length;
      Token_Span        : Source.Source_Span;
      Keyword_Found     : Keyword_Options.Option;
      Punctuation_Found : Punctuation_Options.Option;
      Last_Position     : Source.Source_Position;
   begin
      if Kind = Tokens.Identifier or else Kind = Tokens.Keyword then
         Consumed := Truncate_Identifier_Length (Source_Text, Position, Match_Length);
         if Consumed = 0 then
            Report_Unrecognized_Symbol (Errors, Source_Text, Position, Line, Column, Filename);
            return;
         end if;

         Token_Span :=
           Make_Span
             (Source_Text => Source_Text,
              Position    => Position,
              Byte_Count  => Consumed,
              Line        => Line,
              Column      => Column);
         Keyword_Found := Lookup_Keyword (Source_Text (Position .. Position + Consumed - 1));
         case Keyword_Found.Present is
            when True =>
               Tokens.Append
                 (Token_List,
                  Tokens.Token'
                    (Kind          => Tokens.Keyword,
                     Span          => Token_Span,
                     Filename      => Filename,
                     Keyword_Value => Keyword_Found.Value));

            when False =>
               Tokens.Append
                 (Token_List,
                  Tokens.Token'
                    (Kind => Tokens.Identifier, Span => Token_Span, Filename => Filename));
         end case;
      else
         Punctuation_Found :=
           Lookup_Punctuation (Source_Text (Position .. Position + Consumed - 1));
         case Punctuation_Found.Present is
            when False =>
               Report_Unrecognized_Symbol (Errors, Source_Text, Position, Line, Column, Filename);
               return;

            when True =>
               Token_Span :=
                 Make_Span
                   (Source_Text => Source_Text,
                    Position    => Position,
                    Byte_Count  => Consumed,
                    Line        => Line,
                    Column      => Column);
               Tokens.Append
                 (Token_List,
                  Tokens.Token'
                    (Kind              => Tokens.Punctuation,
                     Span              => Token_Span,
                     Filename          => Filename,
                     Punctuation_Value => Punctuation_Found.Value));
         end case;
      end if;

      Advance_Bytes
        (Source_Text   => Source_Text,
         Byte_Count    => Consumed,
         Position      => Position,
         Line          => Line,
         Column        => Column,
         Last_Position => Last_Position);
   end Append_Matched;

   function Ascii_Punctuation_Class return String is
      Result : Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      for Index in Ascii_Punctuation'Range loop
         Ada.Strings.Unbounded.Append
           (Result, Scalar_To_Class (Wide_Wide_Character'Val (Character'Pos (Ascii_Punctuation (Index)))));
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Ascii_Punctuation_Class;

   function Compile_Cached (Pattern : String) return Lovelace.Common.Regex.Regex_Result is
   begin
      return Lovelace.Common.Regex.Compile (Pattern);
   end Compile_Cached;

   function Element (Errors : Tokenizer_Error_Sequence; Index : Positive) return Tokenizer_Error is
   begin
      return Errors.Items.Element (Index);
   end Element;

   function Empty_Error_Sequence return Tokenizer_Error_Sequence is
   begin
      return (Items => Error_Vectors.Empty_Vector);
   end Empty_Error_Sequence;

   function Ensure_Patterns (Filename : Source.Filename_Option) return Tokenizer_Error_Sequence is
      Compile_Result : Lovelace.Common.Regex.Regex_Result;
      Class_Errors   : Tokenizer_Error_Sequence;
   begin
      if Patterns_Ready then
         return Empty_Error_Sequence;
      end if;

      Scan_Classes.Clear;

      Compile_Result := Compile_Cached (Whitespace_Pattern);
      case Compile_Result.Ok is
         when False =>
            return Internal_Compile_Error (Compile_Result.Error, Filename);
         when True  =>
            Whitespace_Engine := Compile_Result.Value;
      end case;

      Class_Errors := Register_Scan_Class (Identifier_Pattern, Tokens.Identifier, Filename);
      if Length (Class_Errors) > 0 then
         return Class_Errors;
      end if;

      Class_Errors := Register_Scan_Class (Punctuation_Pattern, Tokens.Punctuation, Filename);
      if Length (Class_Errors) > 0 then
         return Class_Errors;
      end if;

      Patterns_Ready := True;
      return Empty_Error_Sequence;
   end Ensure_Patterns;

   function Escape_Regex_Lexeme (Lexeme : String) return String is
      Result            : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Current_Character : Character;
   begin
      for Index in Lexeme'Range loop
         Current_Character := Lexeme (Index);
         case Current_Character is
            when '\' | '|' | '(' | ')' | '[' | ']' | '*' | '+' | '?' | '.' | '^' | '$' | '{' | '}' =>
               Ada.Strings.Unbounded.Append (Result, '\');
            when others                                                                           =>
               null;
         end case;
         Ada.Strings.Unbounded.Append (Result, Current_Character);
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Escape_Regex_Lexeme;

   function Failure_Result (Errors : Tokenizer_Error_Sequence) return Tokenize_Result is
   begin
      return (Ok => False, Errors => Errors);
   end Failure_Result;

   function Format_Scalar (Point : Code_Point) return String is
      Image : String (1 .. 8);
      Value : Natural := Natural (Wide_Wide_Character'Pos (Point));
   begin
      if Wide_Wide_Character'Pos (Point) in Wide_Wide_Character'Pos (Wide_Wide_Character'Val (16#20#)) ..
        Wide_Wide_Character'Pos (Wide_Wide_Character'Val (16#7E#))
      then
         return String'(1 .. 1 => Character'Val (Wide_Wide_Character'Pos (Point)));
      end if;

      for Index in reverse Image'Range loop
         Image (Index) := Hex_Digit (Value mod 16);
         Value := Value / 16;
      end loop;
      return "\u{" & Image & "}";
   end Format_Scalar;

   function Hex_Digit (Value : Natural) return Character is
   begin
      if Value < 10 then
         return Character'Val (Character'Pos ('0') + Value);
      else
         return Character'Val (Character'Pos ('A') + Value - 10);
      end if;
   end Hex_Digit;

   function Identifier_Pattern return String is
      Shared_Exclusions : constant String :=
        Unicode_Ranges_To_Class (Whitespace_Ranges)
        & Unicode_Ranges_To_Class (Punctuation_Ranges)
        & Ascii_Punctuation_Class
        & Scalar_To_Class (Wide_Wide_Character'Val (Character'Pos ('@')));
      First_Exclusions  : constant String := Shared_Exclusions & "0-9";
   begin
      return "(@)?" & Negated_Class (First_Exclusions) & Negated_Class (Shared_Exclusions) & "*";
   end Identifier_Pattern;

   function Internal_Compile_Error
     (Error : Lovelace.Common.Regex.Regex_Error; Filename : Source.Filename_Option)
      return Tokenizer_Error_Sequence
   is
      Errors : Tokenizer_Error_Sequence := Empty_Error_Sequence;
      Origin : constant Source.Source_Position := (Byte_Index => 1, Line => 1, Column => 1);
   begin
      Append_Error
        (Errors   => Errors,
         Code     => Internal_Error,
         First    => Origin,
         Last     => Origin,
         Filename => Filename,
         Detail   => Ada.Strings.Unbounded.To_String (Error.Message));
      return Errors;
   end Internal_Compile_Error;

   function Is_Excluded_Punctuation (Point : Code_Point) return Boolean is
   begin
      if Point = '_' then
         return False;
      end if;

      if Wide_Wide_Character'Pos (Point) in Wide_Wide_Character'Pos (Wide_Wide_Character'Val (16#21#)) ..
        Wide_Wide_Character'Pos (Wide_Wide_Character'Val (16#7E#))
      then
         for Index in Ascii_Punctuation'Range loop
            if Wide_Wide_Character'Val (Character'Pos (Ascii_Punctuation (Index))) = Point then
               return True;
            end if;
         end loop;
      end if;

      return Is_In_Ranges (Point, Punctuation_Ranges);
   end Is_Excluded_Punctuation;

   function Is_Identifier_Continue (Point : Code_Point) return Boolean is
      Value : constant Natural := Wide_Wide_Character'Pos (Point);
   begin
      if Value <= 16#1F# or else Value in 16#7F# .. 16#9F# then
         return False;
      end if;

      if Is_In_Ranges (Point, Whitespace_Ranges) then
         return False;
      end if;

      if Is_In_Ranges (Point, Other_Format_Ranges) then
         return False;
      end if;

      if Point = Wide_Wide_Character'Val (Character'Pos ('@')) then
         return False;
      end if;

      return not Is_Excluded_Punctuation (Point);
   end Is_Identifier_Continue;

   function Is_Identifier_First (Point : Code_Point) return Boolean is
   begin
      if not Is_Identifier_Continue (Point) then
         return False;
      end if;

      if Wide_Wide_Character'Pos (Point) >= Wide_Wide_Character'Pos (Wide_Wide_Character'Val (16#30#))
        and then Wide_Wide_Character'Pos (Point) <= Wide_Wide_Character'Pos (Wide_Wide_Character'Val (16#39#))
      then
         return False;
      end if;

      return True;
   end Is_Identifier_First;

   function Is_In_Ranges (Point : Code_Point; Ranges : Scalar_Range_List) return Boolean is
   begin
      for Index in Ranges'Range loop
         if Point in Ranges (Index).Low .. Ranges (Index).High then
            return True;
         end if;
      end loop;
      return False;
   end Is_In_Ranges;

   function Length (Errors : Tokenizer_Error_Sequence) return Natural is
   begin
      return Natural (Errors.Items.Length);
   end Length;

   procedure Longest_Scan_Match
     (Source_Text     : String;
      Position        : Positive;
      After_Delimiter : Boolean;
      Match_Length    : out Natural;
      Kind            : out Tokens.Token_Kind)
   is
      Candidate_Length : Natural;
      Candidate        : Scan_Class;
   begin
      Match_Length := 0;
      Kind := Tokens.Identifier;

      for Index in 1 .. Natural (Scan_Classes.Length) loop
         Candidate := Scan_Classes.Element (Index);
         Candidate_Length :=
           Lovelace.Common.Regex.Match_Prefix (Candidate.The_Engine, Source_Text, Position);
         if Candidate.Kind = Tokens.Identifier
           and then Candidate_Length > 0
           and then Source_Text (Position) = '@'
           and then not After_Delimiter
         then
            Candidate_Length := 0;
         end if;
         if Candidate_Length > Match_Length
           or else
           (Candidate_Length = Match_Length
            and then Candidate_Length > 0
            and then Candidate.Kind = Tokens.Punctuation)
         then
            Match_Length := Candidate_Length;
            Kind := Candidate.Kind;
         end if;
      end loop;
   end Longest_Scan_Match;

   function Lookup_Keyword (Lexeme : String) return Keyword_Options.Option is
   begin
      for Index in Keyword_Table'Range loop
         if Ada.Strings.Unbounded.To_String (Keyword_Table (Index).Lexeme) = Lexeme then
            return Keyword_Options.From_Value (Keyword_Table (Index).Value);
         end if;
      end loop;
      return Keyword_Options.None;
   end Lookup_Keyword;

   function Lookup_Punctuation (Lexeme : String) return Punctuation_Options.Option is
   begin
      for Index in Punctuation_Table'Range loop
         if Ada.Strings.Unbounded.To_String (Punctuation_Table (Index).Lexeme) = Lexeme then
            return Punctuation_Options.From_Value (Punctuation_Table (Index).Value);
         end if;
      end loop;
      return Punctuation_Options.None;
   end Lookup_Punctuation;

   function Make_Span
     (Source_Text : String;
      Position    : Positive;
      Byte_Count  : Natural;
      Line        : Positive;
      Column      : Positive) return Source.Source_Span
   is
      Dummy_Position : Positive := Position;
      Dummy_Line     : Positive := Line;
      Dummy_Column   : Positive := Column;
      Last_Position  : Source.Source_Position;
   begin
      Advance_Bytes
        (Source_Text   => Source_Text,
         Byte_Count    => Byte_Count,
         Position      => Dummy_Position,
         Line          => Dummy_Line,
         Column        => Dummy_Column,
         Last_Position => Last_Position);
      return (First => (Byte_Index => Position, Line => Line, Column => Column), Last => Last_Position);
   end Make_Span;

   function Negated_Class (Exclusions : String) return String is
   begin
      return "[^" & Exclusions & "]";
   end Negated_Class;

   function Punctuation_Pattern return String is
      Result : Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      for Index in Punctuation_Table'Range loop
         if Index > Punctuation_Table'First then
            Ada.Strings.Unbounded.Append (Result, '|');
         end if;
         Ada.Strings.Unbounded.Append
           (Result, Escape_Regex_Lexeme (Ada.Strings.Unbounded.To_String (Punctuation_Table (Index).Lexeme)));
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Punctuation_Pattern;

   function Register_Scan_Class
     (Pattern  : String;
      Kind     : Tokens.Token_Kind;
      Filename : Source.Filename_Option) return Tokenizer_Error_Sequence
   is
      Compile_Result : constant Lovelace.Common.Regex.Regex_Result := Compile_Cached (Pattern);
   begin
      case Compile_Result.Ok is
         when False =>
            return Internal_Compile_Error (Compile_Result.Error, Filename);

         when True =>
            Scan_Classes.Append (Scan_Class'(The_Engine => Compile_Result.Value, Kind => Kind));
            return Empty_Error_Sequence;
      end case;
   end Register_Scan_Class;

   procedure Report_Invalid_Utf_8
     (Errors      : in out Tokenizer_Error_Sequence;
      Source_Text : String;
      Position    : in out Positive;
      Line        : in out Positive;
      Column      : in out Positive;
      Filename    : Source.Filename_Option)
   is
      First_Position : constant Source.Source_Position :=
        (Byte_Index => Position, Line => Line, Column => Column);
      Skip_Length    : Natural := Lovelace.Common.Utf_8.Sequence_Length (Source_Text, Position);
      Last_Position  : Source.Source_Position;
   begin
      if Skip_Length = 0 then
         Skip_Length := 1;
      end if;

      Append_Error
        (Errors   => Errors,
         Code     => Invalid_Utf_8,
         First    => First_Position,
         Last     => First_Position,
         Filename => Filename,
         Detail   => "invalid UTF-8 sequence");

      Advance_Bytes
        (Source_Text   => Source_Text,
         Byte_Count    => Skip_Length,
         Position      => Position,
         Line          => Line,
         Column        => Column,
         Last_Position => Last_Position);
   end Report_Invalid_Utf_8;

   procedure Report_Unrecognized_Symbol
     (Errors      : in out Tokenizer_Error_Sequence;
      Source_Text : String;
      Position    : in out Positive;
      Line        : in out Positive;
      Column      : in out Positive;
      Filename    : Source.Filename_Option)
   is
      Decode_Result  : constant Lovelace.Common.Utf_8.Decode_Results.Result :=
        Lovelace.Common.Utf_8.Decode (Source_Text, Position);
      First_Position : constant Source.Source_Position :=
        (Byte_Index => Position, Line => Line, Column => Column);
      Last_Position  : Source.Source_Position;
      Skip_Length    : Natural;
   begin
      case Decode_Result.Ok is
         when False =>
            Report_Invalid_Utf_8 (Errors, Source_Text, Position, Line, Column, Filename);
            return;

         when True =>
            Append_Error
              (Errors   => Errors,
               Code     => Unrecognized_Symbol,
               First    => First_Position,
               Last     => First_Position,
               Filename => Filename,
               Detail   => "unrecognized symbol '" & Format_Scalar (Decode_Result.Value) & "'");
            Skip_Length := Lovelace.Common.Utf_8.Sequence_Length (Source_Text, Position);
            if Skip_Length = 0 then
               Skip_Length := 1;
            end if;
            Advance_Bytes
              (Source_Text   => Source_Text,
               Byte_Count    => Skip_Length,
               Position      => Position,
               Line          => Line,
               Column        => Column,
               Last_Position => Last_Position);
      end case;
   end Report_Unrecognized_Symbol;

   function Scalar_To_Class (Point : Code_Point) return String is
      Hex   : String (1 .. 6);
      Value : Natural := Natural (Wide_Wide_Character'Pos (Point));
   begin
      for Index in reverse Hex'Range loop
         Hex (Index) := Hex_Digit (Value mod 16);
         Value := Value / 16;
      end loop;
      return "\u{" & Hex & "}";
   end Scalar_To_Class;

   function Success_Result (Token_List : Tokens.Token_Sequence) return Tokenize_Result is
   begin
      return (Ok => True, Tokens => Token_List);
   end Success_Result;

   function Tokenize (Source_Text : String) return Tokenize_Result is
   begin
      return Tokenize (Source_Text => Source_Text, Filename => "");
   end Tokenize;

   function Tokenize (Source_Text : String; Filename : String) return Tokenize_Result is
      File_Option    : Source.Filename_Option;
      Shared_Holder  : Source.Shared_Filename;
      Pattern_Errors : Tokenizer_Error_Sequence;
   begin
      if Filename'Length = 0 then
         File_Option := Source.Absent_Filename;
      else
         Shared_Holder := Source.From_Utf_8 (Filename);
         File_Option := Source.Some_Filename (Shared_Holder);
      end if;

      Pattern_Errors := Ensure_Patterns (File_Option);
      if Length (Pattern_Errors) > 0 then
         return Failure_Result (Pattern_Errors);
      end if;

      return Tokenize_Core (Source_Text, File_Option);
   end Tokenize;

   function Tokenize_Core
     (Source_Text : String; Filename : Source.Filename_Option) return Tokenize_Result
   is
      Token_List        : Tokens.Token_Sequence := Tokens.Empty_Sequence;
      Errors            : Tokenizer_Error_Sequence := Empty_Error_Sequence;
      Position          : Positive := 1;
      Line              : Positive := 1;
      Column            : Positive := 1;
      Whitespace_Length : Natural;
      Match_Length      : Natural;
      Kind              : Tokens.Token_Kind;
      Last_Position     : Source.Source_Position;
      Start_Position    : Positive;
      After_Delimiter   : Boolean := True;
   begin
      if Source_Text'Length = 0 then
         return Success_Result (Token_List);
      end if;

      while Position <= Source_Text'Last loop
         Start_Position := Position;
         Whitespace_Length := Lovelace.Common.Regex.Match_Prefix (Whitespace_Engine, Source_Text, Position);
         if Whitespace_Length > 0 then
            Advance_Bytes
              (Source_Text   => Source_Text,
               Byte_Count    => Whitespace_Length,
               Position      => Position,
               Line          => Line,
               Column        => Column,
               Last_Position => Last_Position);
            After_Delimiter := True;
         else
            Longest_Scan_Match
              (Source_Text     => Source_Text,
               Position        => Position,
               After_Delimiter => After_Delimiter,
               Match_Length    => Match_Length,
               Kind            => Kind);
            if Match_Length = 0 then
               Report_Unrecognized_Symbol (Errors, Source_Text, Position, Line, Column, Filename);
               After_Delimiter := False;
            else
               Append_Matched
                 (Token_List   => Token_List,
                  Errors       => Errors,
                  Source_Text  => Source_Text,
                  Position     => Position,
                  Line         => Line,
                  Column       => Column,
                  Match_Length => Match_Length,
                  Kind         => Kind,
                  Filename     => Filename);
               After_Delimiter := Kind = Tokens.Punctuation;
            end if;
         end if;

         if Position = Start_Position then
            Position := Position + 1;
         end if;
      end loop;

      if Length (Errors) > 0 then
         return Failure_Result (Errors);
      end if;

      return Success_Result (Token_List);
   end Tokenize_Core;

   function Truncate_Identifier_Length
     (Source_Text : String; From : Positive; Max_Length : Natural) return Natural
   is
      Index           : Positive := From;
      Limit           : constant Positive := From + Max_Length - 1;
      Consumed        : Natural := 0;
      After_At_Prefix : Boolean := False;
      Point           : Code_Point;
      Length          : Natural;
      Valid           : Boolean;
   begin
      if Max_Length = 0 then
         return 0;
      end if;

      if Source_Text (From) = '@' then
         if Max_Length = 1 then
            return 0;
         end if;
         After_At_Prefix := True;
         Index := From + 1;
         Consumed := 1;
      end if;

      while Index <= Limit loop
         Lovelace.Common.Utf_8.Decode
           (Source => Source_Text, Index => Index, Point => Point, Length => Length, Valid => Valid);
         exit when not Valid or else Length = 0;

         if After_At_Prefix then
            if not Is_Identifier_First (Point) then
               exit;
            end if;
            After_At_Prefix := False;
         elsif Consumed = 0 then
            if not Is_Identifier_First (Point) then
               exit;
            end if;
         else
            if not Is_Identifier_Continue (Point) then
               exit;
            end if;
         end if;

         Consumed := Consumed + Length;
         Index := Index + Length;
      end loop;

      return Consumed;
   end Truncate_Identifier_Length;

   function Unicode_Ranges_To_Class (Ranges : Scalar_Range_List) return String is
      Result : Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      for Index in Ranges'Range loop
         if Ranges (Index).Low = Ranges (Index).High then
            Ada.Strings.Unbounded.Append (Result, Scalar_To_Class (Ranges (Index).Low));
         else
            Ada.Strings.Unbounded.Append
              (Result, Scalar_To_Class (Ranges (Index).Low) & "-" & Scalar_To_Class (Ranges (Index).High));
         end if;
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Unicode_Ranges_To_Class;

   function Whitespace_Pattern return String is
   begin
      return "[" & Unicode_Ranges_To_Class (Whitespace_Ranges) & "]+";
   end Whitespace_Pattern;

end Lovelace.Compiler.Tokenizer;
