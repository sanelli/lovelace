with Ada.Directories;
with GNAT.OS_Lib;

with Lovelace.Compiler.Tokenizer;
with Lovelace.Compiler.Tokens;

package body Lovelace.Compiler.Versioning is

   use type Ada.Directories.File_Kind;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Tokens.Punctuation_Subtype;
   use type Tokens.Token_Kind;

   --  Simple-name rename so gnatcov can instrument call coverage (no dotted callees).
   function Token_At
     (Sequence : Tokens.Token_Sequence; Index : Positive) return Tokens.Token
     renames Tokens.Element;

   function Consume_Dot (Text : String; Index : in out Natural; Last : Natural) return Boolean;
   --  Consume a '.' at Text (Index) when present.

   function Has_Version_Shape (Source_Text : String; Seq : Tokens.Token_Sequence) return Boolean;
   --  True when Seq is exactly @version ( "..." ).

   function Is_Ascii_Digit (C : Character) return Boolean;

   function Is_Preview_Name_Char (C : Character) return Boolean;

   function Is_Punctuation (The_Token : Tokens.Token; Value : Tokens.Punctuation_Subtype) return Boolean;

   function Is_Regular_File (Path : String) return Boolean;

   function Parse_Core (Text : String; Index : in out Natural; Last : Natural) return Boolean;
   --  Consume MAJOR.MINOR.BUILD.

   procedure Parse_Loveversion_Source
     (Path        : String;
      Source_Text : String;
      Version     : out Version_Option;
      Ok          : out Boolean;
      Detail      : out Ada.Strings.Unbounded.Unbounded_String);

   function Parse_Numeric (Text : String; Index : in out Natural; Last : Natural) return Boolean;
   --  Consume one MAJOR/MINOR/BUILD/preview-number at Text (Index .. Last).

   function Parse_Preview (Text : String; Index : in out Natural; Last : Natural) return Boolean;
   --  Consume -preview-name[.preview-number] through Last.

   function Parse_Preview_Name (Text : String; Index : in out Natural; Last : Natural) return Boolean;
   --  Consume a non-empty preview-name of Is_Preview_Name_Char characters.

   function Read_Entire_File (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   procedure Set_Failure (Ok : out Boolean; Detail : out Ada.Strings.Unbounded.Unbounded_String; Message : String);

   function String_Literal_Content (Source_Text : String; The_Token : Tokens.Token) return String;

   function Consume_Dot (Text : String; Index : in out Natural; Last : Natural) return Boolean is
   begin
      if Index <= Last and then Text (Index) = '.' then
         Index := Index + 1;
         return True;
      end if;
      return False;
   end Consume_Dot;

   function Has_Version_Shape (Source_Text : String; Seq : Tokens.Token_Sequence) return Boolean is
   begin
      if Tokens.Length (Seq) /= 4 then
         return False;
      end if;

      declare
         T0 : constant Tokens.Token := Token_At (Seq, 1);
         T1 : constant Tokens.Token := Token_At (Seq, 2);
         T2 : constant Tokens.Token := Token_At (Seq, 3);
         T3 : constant Tokens.Token := Token_At (Seq, 4);
      begin
         return
           T0.Kind = Tokens.Identifier
           and then Tokens.Lexeme (Source_Text, T0) = "@version"
           and then Is_Punctuation (T1, Tokens.Left_Parenthesis)
           and then T2.Kind = Tokens.String_Literal
           and then Is_Punctuation (T3, Tokens.Right_Parenthesis);
      end;
   end Has_Version_Shape;

   function Is_Ascii_Digit (C : Character) return Boolean is
   begin
      return C in '0' .. '9';
   end Is_Ascii_Digit;

   function Is_Preview_Name_Char (C : Character) return Boolean is
   begin
      return C in 'A' .. 'Z' or else C in 'a' .. 'z' or else C in '0' .. '9' or else C = '-';
   end Is_Preview_Name_Char;

   function Is_Punctuation (The_Token : Tokens.Token; Value : Tokens.Punctuation_Subtype) return Boolean is
   begin
      return The_Token.Kind = Tokens.Punctuation and then The_Token.Punctuation_Value = Value;
   end Is_Punctuation;

   function Is_Regular_File (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path) and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
   end Is_Regular_File;

   function Is_Valid_Version (Text : String) return Boolean is
      Index : Natural := Text'First;
      Last  : constant Natural := Text'Last;
   begin
      if Text'Length = 0 or else not Parse_Core (Text, Index, Last) then
         return False;
      end if;

      return Index > Last or else Parse_Preview (Text, Index, Last);
   end Is_Valid_Version;

   function Library_Root_For (Source_Path : String; Roots : Module_Path.Path_Sequence) return String is
      Best     : Ada.Strings.Unbounded.Unbounded_String;
      Best_Len : Natural := 0;
   begin
      declare
         Abs_Source : constant String := Ada.Directories.Full_Name (Source_Path);
      begin
         for Index in 1 .. Natural (Roots.Length) loop
            declare
               Root     : constant String := Roots.Element (Index);
               Abs_Root : constant String := Ada.Directories.Full_Name (Root);
            begin
               if Abs_Source'Length >= Abs_Root'Length
                 and then Abs_Source (Abs_Source'First .. Abs_Source'First + Abs_Root'Length - 1) = Abs_Root
                 and then (Abs_Source'Length = Abs_Root'Length
                           or else Abs_Source (Abs_Source'First + Abs_Root'Length) = '/'
                           or else Abs_Source (Abs_Source'First + Abs_Root'Length) = '\')
                 and then Abs_Root'Length > Best_Len
               then
                  Best_Len := Abs_Root'Length;
                  Best := Ada.Strings.Unbounded.To_Unbounded_String (Abs_Root);
               end if;
            exception
               when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
                  null;
            end;
         end loop;
      end;

      return Ada.Strings.Unbounded.To_String (Best);
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         return "";
   end Library_Root_For;

   function Parse_Core (Text : String; Index : in out Natural; Last : Natural) return Boolean is
   begin
      return
        Parse_Numeric (Text, Index, Last)
        and then Consume_Dot (Text, Index, Last)
        and then Parse_Numeric (Text, Index, Last)
        and then Consume_Dot (Text, Index, Last)
        and then Parse_Numeric (Text, Index, Last);
   end Parse_Core;

   procedure Parse_Loveversion_Source
     (Path        : String;
      Source_Text : String;
      Version     : out Version_Option;
      Ok          : out Boolean;
      Detail      : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Token_Result : constant Tokenizer.Tokenize_Result := Tokenizer.Tokenize (Source_Text, Path);
   begin
      Version := (Present => False);

      if not Token_Result.Ok then
         Set_Failure (Ok, Detail, "invalid .loveversion at " & Path);
         return;
      end if;

      if not Has_Version_Shape (Source_Text, Token_Result.Tokens) then
         Set_Failure (Ok, Detail, ".loveversion must be exactly @version(""..."") in " & Path);
         return;
      end if;

      declare
         Text : constant String := String_Literal_Content (Source_Text, Tokens.Element (Token_Result.Tokens, 3));
      begin
         if not Is_Valid_Version (Text) then
            Set_Failure (Ok, Detail, "invalid module version '" & Text & "' in " & Path);
            return;
         end if;

         Version := (Present => True, Value => Ada.Strings.Unbounded.To_Unbounded_String (Text));
         Ok := True;
         Detail := Ada.Strings.Unbounded.Null_Unbounded_String;
      end;
   end Parse_Loveversion_Source;

   function Parse_Numeric (Text : String; Index : in out Natural; Last : Natural) return Boolean is
      Start : Natural;
   begin
      if Index > Last or else not Is_Ascii_Digit (Text (Index)) then
         return False;
      end if;

      Start := Index;
      if Text (Index) = '0' then
         Index := Index + 1;
         if Index <= Last and then Is_Ascii_Digit (Text (Index)) then
            return False;
         end if;
         return True;
      end if;

      while Index <= Last and then Is_Ascii_Digit (Text (Index)) loop
         Index := Index + 1;
      end loop;

      return Index > Start;
   end Parse_Numeric;

   function Parse_Preview (Text : String; Index : in out Natural; Last : Natural) return Boolean is
   begin
      if Text (Index) /= '-' then
         return False;
      end if;
      Index := Index + 1;
      if not Parse_Preview_Name (Text, Index, Last) then
         return False;
      end if;

      if Index > Last then
         return True;
      end if;

      return Consume_Dot (Text, Index, Last) and then Parse_Numeric (Text, Index, Last) and then Index > Last;
   end Parse_Preview;

   function Parse_Preview_Name (Text : String; Index : in out Natural; Last : Natural) return Boolean is
   begin
      if Index > Last or else not Is_Preview_Name_Char (Text (Index)) then
         return False;
      end if;
      while Index <= Last and then Is_Preview_Name_Char (Text (Index)) loop
         Index := Index + 1;
      end loop;
      return True;
   end Parse_Preview_Name;

   function Read_Entire_File (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      Contents := Ada.Strings.Unbounded.Null_Unbounded_String;
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      declare
         Length : constant Natural := Natural (GNAT.OS_Lib.File_Length (Descriptor));
         Buffer : String (1 .. Length);
         Got    : Integer;
      begin
         Got := GNAT.OS_Lib.Read (Descriptor, Buffer'Address, Length);
         GNAT.OS_Lib.Close (Descriptor);
         if Got /= Integer (Length) then
            return False;
         end if;
         Contents := Ada.Strings.Unbounded.To_Unbounded_String (Buffer);
         return True;
      end;
   end Read_Entire_File;

   procedure Resolve_Version
     (File_Version : Version_Option;
      Library_Root : String;
      Cli_Version  : Version_Option;
      Version      : out Ada.Strings.Unbounded.Unbounded_String;
      Ok           : out Boolean;
      Detail       : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Love_Version : Version_Option;
      Love_Ok      : Boolean;
   begin
      Detail := Ada.Strings.Unbounded.Null_Unbounded_String;

      case File_Version.Present is
         when True  =>
            Version := File_Version.Value;
            Ok := True;
            return;

         when False =>
            null;
      end case;

      Try_Read_Loveversion (Library_Root => Library_Root, Version => Love_Version, Ok => Love_Ok, Detail => Detail);
      if not Love_Ok then
         Version := Ada.Strings.Unbounded.Null_Unbounded_String;
         Ok := False;
         return;
      end if;

      case Love_Version.Present is
         when True  =>
            Version := Love_Version.Value;
            Ok := True;
            return;

         when False =>
            null;
      end case;

      case Cli_Version.Present is
         when True  =>
            Version := Cli_Version.Value;
            Ok := True;
            return;

         when False =>
            null;
      end case;

      Version := Ada.Strings.Unbounded.To_Unbounded_String (Default_Version);
      Ok := True;
   end Resolve_Version;

   procedure Set_Failure (Ok : out Boolean; Detail : out Ada.Strings.Unbounded.Unbounded_String; Message : String) is
   begin
      Ok := False;
      Detail := Ada.Strings.Unbounded.To_Unbounded_String (Message);
   end Set_Failure;

   function String_Literal_Content (Source_Text : String; The_Token : Tokens.Token) return String is
      Lexeme : constant String := Tokens.Lexeme (Source_Text, The_Token);
   begin
      if Lexeme'Length >= 2 and then Lexeme (Lexeme'First) = '"' and then Lexeme (Lexeme'Last) = '"' then
         return Lexeme (Lexeme'First + 1 .. Lexeme'Last - 1);
      end if;

      return Lexeme;
   end String_Literal_Content;

   procedure Try_Read_Loveversion
     (Library_Root : String;
      Version      : out Version_Option;
      Ok           : out Boolean;
      Detail       : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Version := (Present => False);
      Detail := Ada.Strings.Unbounded.Null_Unbounded_String;
      Ok := True;

      if Library_Root'Length = 0 then
         return;
      end if;

      declare
         Path     : constant String := Ada.Directories.Compose (Library_Root, Loveversion_Filename);
         Contents : Ada.Strings.Unbounded.Unbounded_String;
      begin
         if not Is_Regular_File (Path) then
            return;
         end if;

         if not Read_Entire_File (Path, Contents) then
            Set_Failure (Ok, Detail, "cannot read " & Path);
            return;
         end if;

         Parse_Loveversion_Source
           (Path        => Path,
            Source_Text => Ada.Strings.Unbounded.To_String (Contents),
            Version     => Version,
            Ok          => Ok,
            Detail      => Detail);
      end;
   end Try_Read_Loveversion;

end Lovelace.Compiler.Versioning;
