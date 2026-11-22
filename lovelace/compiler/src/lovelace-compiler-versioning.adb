with Ada.Directories;
with GNAT.OS_Lib;

with Lovelace.Compiler.Tokenizer;
with Lovelace.Compiler.Tokens;

package body Lovelace.Compiler.Versioning is

   use type Ada.Directories.File_Kind;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Tokens.Punctuation_Subtype;
   use type Tokens.Token_Kind;

   function Is_Ascii_Digit (C : Character) return Boolean;
   function Is_Preview_Name_Char (C : Character) return Boolean;
   function Parse_Numeric
     (Text : String; Index : in out Natural; Last : Natural) return Boolean;
   --  Consume one MAJOR/MINOR/BUILD/preview-number at Text (Index .. Last).

   function Read_Entire_File
     (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   function String_Literal_Content
     (Source_Text : String; The_Token : Tokens.Token) return String;

   function Is_Ascii_Digit (C : Character) return Boolean is
   begin
      return C in '0' .. '9';
   end Is_Ascii_Digit;

   function Is_Preview_Name_Char (C : Character) return Boolean is
   begin
      return
        C in 'A' .. 'Z'
        or else C in 'a' .. 'z'
        or else C in '0' .. '9'
        or else C = '-';
   end Is_Preview_Name_Char;

   function Is_Valid_Version (Text : String) return Boolean is
      Index : Natural := Text'First;
      Last  : constant Natural := Text'Last;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      --  MAJOR.MINOR.BUILD
      if not Parse_Numeric (Text, Index, Last) then
         return False;
      end if;
      if Index > Last or else Text (Index) /= '.' then
         return False;
      end if;
      Index := Index + 1;
      if not Parse_Numeric (Text, Index, Last) then
         return False;
      end if;
      if Index > Last or else Text (Index) /= '.' then
         return False;
      end if;
      Index := Index + 1;
      if not Parse_Numeric (Text, Index, Last) then
         return False;
      end if;

      if Index > Last then
         return True;
      end if;

      --  -preview-name[.preview-number]
      if Text (Index) /= '-' then
         return False;
      end if;
      Index := Index + 1;
      if Index > Last or else not Is_Preview_Name_Char (Text (Index)) then
         return False;
      end if;
      while Index <= Last and then Is_Preview_Name_Char (Text (Index)) loop
         Index := Index + 1;
      end loop;

      if Index > Last then
         return True;
      end if;

      if Text (Index) /= '.' then
         return False;
      end if;
      Index := Index + 1;
      if not Parse_Numeric (Text, Index, Last) then
         return False;
      end if;

      return Index > Last;
   end Is_Valid_Version;

   function Library_Root_For
     (Source_Path : String; Roots : Module_Path.Path_Sequence) return String
   is
      Best     : Ada.Strings.Unbounded.Unbounded_String;
      Best_Len : Natural := 0;
   begin
      declare
         Abs_Source : constant String :=
           Ada.Directories.Full_Name (Source_Path);
      begin
         for Index in 1 .. Natural (Roots.Length) loop
            declare
               Root     : constant String := Roots.Element (Index);
               Abs_Root : constant String := Ada.Directories.Full_Name (Root);
            begin
               if Abs_Source'Length >= Abs_Root'Length
                 and then Abs_Source
                            (Abs_Source'First
                             .. Abs_Source'First + Abs_Root'Length - 1)
                          = Abs_Root
                 and then
                 (Abs_Source'Length = Abs_Root'Length
                  or else Abs_Source (Abs_Source'First + Abs_Root'Length) =
                            '/'
                  or else Abs_Source (Abs_Source'First + Abs_Root'Length) =
                            '\')
                 and then Abs_Root'Length > Best_Len
               then
                  Best_Len := Abs_Root'Length;
                  Best :=
                    Ada.Strings.Unbounded.To_Unbounded_String (Abs_Root);
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

   function Parse_Numeric
     (Text : String; Index : in out Natural; Last : Natural) return Boolean
   is
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

   function Read_Entire_File
     (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean
   is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      Contents := Ada.Strings.Unbounded.Null_Unbounded_String;
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      declare
         Length : constant Natural :=
           Natural (GNAT.OS_Lib.File_Length (Descriptor));
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
         when True =>
            Version := File_Version.Value;
            Ok := True;
            return;

         when False =>
            null;
      end case;

      Try_Read_Loveversion
        (Library_Root => Library_Root,
         Version      => Love_Version,
         Ok           => Love_Ok,
         Detail       => Detail);
      if not Love_Ok then
         Version := Ada.Strings.Unbounded.Null_Unbounded_String;
         Ok := False;
         return;
      end if;

      case Love_Version.Present is
         when True =>
            Version := Love_Version.Value;
            Ok := True;
            return;

         when False =>
            null;
      end case;

      case Cli_Version.Present is
         when True =>
            Version := Cli_Version.Value;
            Ok := True;
            return;

         when False =>
            null;
      end case;

      Version :=
        Ada.Strings.Unbounded.To_Unbounded_String (Default_Version);
      Ok := True;
   end Resolve_Version;

   function String_Literal_Content
     (Source_Text : String; The_Token : Tokens.Token) return String
   is
      Lexeme : constant String := Tokens.Lexeme (Source_Text, The_Token);
   begin
      if Lexeme'Length >= 2
        and then Lexeme (Lexeme'First) = '"'
        and then Lexeme (Lexeme'Last) = '"'
      then
         return Lexeme (Lexeme'First + 1 .. Lexeme'Last - 1);
      end if;

      return Lexeme;
   end String_Literal_Content;

   procedure Try_Read_Loveversion
     (Library_Root : String;
      Version      : out Version_Option;
      Ok           : out Boolean;
      Detail       : out Ada.Strings.Unbounded.Unbounded_String)
   is
   begin
      Version := (Present => False);
      Detail := Ada.Strings.Unbounded.Null_Unbounded_String;
      Ok := True;

      if Library_Root'Length = 0 then
         return;
      end if;

      declare
         Path : constant String :=
           Ada.Directories.Compose (Library_Root, Loveversion_Filename);
      begin
         if not Ada.Directories.Exists (Path)
           or else Ada.Directories.Kind (Path)
                   /= Ada.Directories.Ordinary_File
         then
            return;
         end if;

         declare
            Contents : Ada.Strings.Unbounded.Unbounded_String;
         begin
            if not Read_Entire_File (Path, Contents) then
               Ok := False;
               Detail :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ("cannot read " & Path);
               return;
            end if;

            declare
               Source_Text  : constant String :=
                 Ada.Strings.Unbounded.To_String (Contents);
               Token_Result : constant Tokenizer.Tokenize_Result :=
                 Tokenizer.Tokenize (Source_Text, Path);
            begin
               if not Token_Result.Ok then
                  Ok := False;
                  Detail :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      ("invalid .loveversion at " & Path);
                  return;
               end if;

               declare
                  Seq   : constant Tokens.Token_Sequence :=
                    Token_Result.Tokens;
                  Count : constant Natural := Tokens.Length (Seq);
               begin
                  if Count /= 4 then
                     Ok := False;
                     Detail :=
                       Ada.Strings.Unbounded.To_Unbounded_String
                         (".loveversion must be exactly @version(""..."") in "
                          & Path);
                     return;
                  end if;

                  declare
                     T0 : constant Tokens.Token := Tokens.Element (Seq, 1);
                     T1 : constant Tokens.Token := Tokens.Element (Seq, 2);
                     T2 : constant Tokens.Token := Tokens.Element (Seq, 3);
                     T3 : constant Tokens.Token := Tokens.Element (Seq, 4);
                  begin
                     if T0.Kind /= Tokens.Identifier
                       or else Tokens.Lexeme (Source_Text, T0) /= "@version"
                       or else not
                       (T1.Kind = Tokens.Punctuation
                        and then T1.Punctuation_Value = Tokens.Left_Parenthesis)
                       or else T2.Kind /= Tokens.String_Literal
                       or else not
                       (T3.Kind = Tokens.Punctuation
                        and then T3.Punctuation_Value = Tokens.Right_Parenthesis)
                     then
                        Ok := False;
                        Detail :=
                          Ada.Strings.Unbounded.To_Unbounded_String
                            (".loveversion must be exactly "
                             & "@version(""..."") in "
                             & Path);
                        return;
                     end if;

                     declare
                        Text : constant String :=
                          String_Literal_Content (Source_Text, T2);
                     begin
                        if not Is_Valid_Version (Text) then
                           Ok := False;
                           Detail :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               ("invalid module version '"
                                & Text
                                & "' in "
                                & Path);
                           return;
                        end if;

                        Version :=
                          (Present => True,
                           Value   =>
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Text));
                        Ok := True;
                     end;
                  end;
               end;
            end;
         end;
      end;
   end Try_Read_Loveversion;

end Lovelace.Compiler.Versioning;
