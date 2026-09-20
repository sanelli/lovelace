with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Parser is

   use type Ast.Subroutine_Flags;
   use type Tokens.Keyword_Subtype;
   use type Tokens.Punctuation_Subtype;
   use type Tokens.Token_Kind;

   Origin_Span : constant Source.Source_Span :=
     (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1));

   Dummy_Identifier : constant Tokens.Token :=
     (Kind => Tokens.Identifier, Span => Origin_Span, Filename => Source.Absent_Filename);

   --  Cursor over Token_List; Next_Index is the next token to read (1-based).
   type Cursor is record
      Token_List             : Tokens.Token_Sequence;
      Next_Index             : Natural := 1;
      Has_Consumed           : Boolean := False;
      First_Span             : Source.Source_Span := Origin_Span;
      Last_Consumed_Span     : Source.Source_Span := Origin_Span;
      Last_Consumed_Filename : Source.Filename_Option := Source.Absent_Filename;
   end record;

   --  Step result without carrying an Ast.Module on success.
   type Step_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            null;

         when False =>
            Code     : Parser_Error_Code;
            Span     : Source.Source_Span;
            Filename : Source.Filename_Option;
            Detail   : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   procedure Advance (The_Cursor : in out Cursor);
   function At_End (The_Cursor : Cursor) return Boolean;
   function Describe_Token (Source_Text : String; The_Token : Tokens.Token) return String;
   function Expect_Identifier
     (The_Cursor : in out Cursor; Source_Text : String; The_Token : out Tokens.Token) return Step_Result;
   function Expect_Keyword
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Keyword_Subtype; Label : String)
      return Step_Result;
   function Expect_Punctuation
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Punctuation_Subtype; Label : String)
      return Step_Result;
   function Failure_From_Step (Step : Step_Result) return Parse_Result;
   function Make_Failure
     (Code : Parser_Error_Code; Span : Source.Source_Span; Filename : Source.Filename_Option; Detail : String)
      return Step_Result;
   function Parse_Block (The_Cursor : in out Cursor; Source_Text : String) return Step_Result;
   function Parse_Compilation_Unit
     (The_Cursor  : in out Cursor;
      Source_Text : String;
      Name_Token  : out Tokens.Token;
      Stop_Span   : out Source.Source_Span) return Step_Result;
   function Parse_Program_Header
     (The_Cursor : in out Cursor; Source_Text : String; Name_Token : out Tokens.Token) return Step_Result;
   function Step_End_Of_Input (The_Cursor : Cursor; Detail : String) return Step_Result;
   function To_Parse_Result
     (Source_Text : String; Name_Token : Tokens.Token; First_Span : Source.Source_Span; Stop_Span : Source.Source_Span)
      return Parse_Result;

   procedure Advance (The_Cursor : in out Cursor) is
      The_Token : constant Tokens.Token := Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
   begin
      if not The_Cursor.Has_Consumed then
         The_Cursor.First_Span := The_Token.Span;
         The_Cursor.Has_Consumed := True;
      end if;
      The_Cursor.Last_Consumed_Span := The_Token.Span;
      The_Cursor.Last_Consumed_Filename := The_Token.Filename;
      The_Cursor.Next_Index := The_Cursor.Next_Index + 1;
   end Advance;

   function At_End (The_Cursor : Cursor) return Boolean is
   begin
      return The_Cursor.Next_Index > Tokens.Length (The_Cursor.Token_List);
   end At_End;

   function Describe_Token (Source_Text : String; The_Token : Tokens.Token) return String is
   begin
      case The_Token.Kind is
         when Tokens.Keyword     =>
            case The_Token.Keyword_Value is
               when Tokens.Program_Keyword =>
                  return "keyword ""program""";

               when Tokens.Begin_Keyword   =>
                  return "keyword ""begin""";

               when Tokens.End_Keyword     =>
                  return "keyword ""end""";
            end case;

         when Tokens.Identifier  =>
            return "identifier """ & Tokens.Lexeme (Source_Text, The_Token) & '"';

         when Tokens.Punctuation =>
            case The_Token.Punctuation_Value is
               when Tokens.Semicolon =>
                  return "punctuation "";""";

               when Tokens.Full_Stop =>
                  return "punctuation "".""";
            end case;
      end case;
   end Describe_Token;

   function Element (Errors : Parser_Error_Sequence; Index : Positive) return Parser_Error is
   begin
      return Errors.Items.Element (Index);
   end Element;

   function Empty_Error_Sequence return Parser_Error_Sequence is
   begin
      return (Items => Error_Vectors.Empty_Vector);
   end Empty_Error_Sequence;

   function Expect_Identifier
     (The_Cursor : in out Cursor; Source_Text : String; The_Token : out Tokens.Token) return Step_Result is
   begin
      The_Token := Dummy_Identifier;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected identifier, found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
      begin
         if Current.Kind /= Tokens.Identifier then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   => "expected identifier, found " & Describe_Token (Source_Text, Current));
         end if;

         The_Token := Current;
         Advance (The_Cursor);
         return (Ok => True);
      end;
   end Expect_Identifier;

   function Expect_Keyword
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Keyword_Subtype; Label : String)
      return Step_Result is
   begin
      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected keyword """ & Label & """, found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
      begin
         if Current.Kind /= Tokens.Keyword or else Current.Keyword_Value /= Expected then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   => "expected keyword """ & Label & """, found " & Describe_Token (Source_Text, Current));
         end if;

         Advance (The_Cursor);
         return (Ok => True);
      end;
   end Expect_Keyword;

   function Expect_Punctuation
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Punctuation_Subtype; Label : String)
      return Step_Result is
   begin
      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected punctuation """ & Label & """, found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
      begin
         if Current.Kind /= Tokens.Punctuation or else Current.Punctuation_Value /= Expected then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   => "expected punctuation """ & Label & """, found " & Describe_Token (Source_Text, Current));
         end if;

         Advance (The_Cursor);
         return (Ok => True);
      end;
   end Expect_Punctuation;

   function Failure_From_Step (Step : Step_Result) return Parse_Result is
      Errors : Parser_Error_Sequence := Empty_Error_Sequence;
      Item   : Parser_Error;
   begin
      case Step.Ok is
         when True  =>
            Item :=
              (Code     => Internal_Error,
               Span     => Origin_Span,
               Filename => Source.Absent_Filename,
               Detail   => Ada.Strings.Unbounded.To_Unbounded_String ("Failure_From_Step called on a successful step"));
            Errors.Items.Append (Item);
            return (Ok => False, Errors => Errors);

         when False =>
            Item := (Code => Step.Code, Span => Step.Span, Filename => Step.Filename, Detail => Step.Detail);
            Errors.Items.Append (Item);
            return (Ok => False, Errors => Errors);
      end case;
   end Failure_From_Step;

   function Length (Errors : Parser_Error_Sequence) return Natural is
   begin
      return Natural (Errors.Items.Length);
   end Length;

   function Make_Failure
     (Code : Parser_Error_Code; Span : Source.Source_Span; Filename : Source.Filename_Option; Detail : String)
      return Step_Result is
   begin
      return
        (Ok       => False,
         Code     => Code,
         Span     => Span,
         Filename => Filename,
         Detail   => Ada.Strings.Unbounded.To_Unbounded_String (Detail));
   end Make_Failure;

   function Parse (Source_Text : String; Token_List : Tokens.Token_Sequence) return Parse_Result is
      The_Cursor : Cursor :=
        (Token_List             => Token_List,
         Next_Index             => 1,
         Has_Consumed           => False,
         First_Span             => Origin_Span,
         Last_Consumed_Span     => Origin_Span,
         Last_Consumed_Filename => Source.Absent_Filename);
      Name_Token : Tokens.Token := Dummy_Identifier;
      Stop_Span  : Source.Source_Span := Origin_Span;
      Step       : Step_Result;
   begin
      Step :=
        Parse_Compilation_Unit
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Name_Token => Name_Token, Stop_Span => Stop_Span);

      case Step.Ok is
         when False =>
            return Failure_From_Step (Step);

         when True  =>
            if not At_End (The_Cursor) then
               declare
                  Extra : constant Tokens.Token := Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
               begin
                  return
                    Failure_From_Step
                      (Make_Failure
                         (Code     => Unexpected_Trailing,
                          Span     => Extra.Span,
                          Filename => Extra.Filename,
                          Detail   =>
                            "unexpected trailing token "
                            & Describe_Token (Source_Text, Extra)
                            & " after compilation unit"));
               end;
            end if;

            return
              To_Parse_Result
                (Source_Text => Source_Text,
                 Name_Token  => Name_Token,
                 First_Span  => The_Cursor.First_Span,
                 Stop_Span   => Stop_Span);
      end case;
   end Parse;

   function Parse_Block (The_Cursor : in out Cursor; Source_Text : String) return Step_Result is
      Step : Step_Result;
   begin
      --  block = "begin" , "end"
      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Begin_Keyword, Label => "begin");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      return
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.End_Keyword, Label => "end");
   end Parse_Block;

   function Parse_Compilation_Unit
     (The_Cursor  : in out Cursor;
      Source_Text : String;
      Name_Token  : out Tokens.Token;
      Stop_Span   : out Source.Source_Span) return Step_Result
   is
      Step : Step_Result;
   begin
      Name_Token := Dummy_Identifier;
      Stop_Span := Origin_Span;

      --  compilation_unit = program_header , block , "."
      Step := Parse_Program_Header (The_Cursor => The_Cursor, Source_Text => Source_Text, Name_Token => Name_Token);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step := Parse_Block (The_Cursor => The_Cursor, Source_Text => Source_Text);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Full_Stop, Label => ".");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            Stop_Span := The_Cursor.Last_Consumed_Span;
            return (Ok => True);
      end case;
   end Parse_Compilation_Unit;

   function Parse_Program_Header
     (The_Cursor : in out Cursor; Source_Text : String; Name_Token : out Tokens.Token) return Step_Result
   is
      Step : Step_Result;
   begin
      Name_Token := Dummy_Identifier;

      --  program_header = "program" , identifier , ";"
      Step :=
        Expect_Keyword
          (The_Cursor  => The_Cursor,
           Source_Text => Source_Text,
           Expected    => Tokens.Program_Keyword,
           Label       => "program");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Name_Token);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      return
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
   end Parse_Program_Header;

   function Step_End_Of_Input (The_Cursor : Cursor; Detail : String) return Step_Result is
   begin
      if The_Cursor.Has_Consumed then
         return
           Make_Failure
             (Code     => Unexpected_End_Of_Input,
              Span     => The_Cursor.Last_Consumed_Span,
              Filename => The_Cursor.Last_Consumed_Filename,
              Detail   => Detail);
      end if;

      return
        Make_Failure
          (Code => Unexpected_End_Of_Input, Span => Origin_Span, Filename => Source.Absent_Filename, Detail => Detail);
   end Step_End_Of_Input;

   function To_Parse_Result
     (Source_Text : String; Name_Token : Tokens.Token; First_Span : Source.Source_Span; Stop_Span : Source.Source_Span)
      return Parse_Result
   is
      Module_Name    : constant String := Tokens.Lexeme (Source_Text, Name_Token);
      Unit_Span      : constant Source.Source_Span := (First => First_Span.First, Last => Stop_Span.Last);
      The_Subroutine : constant Ast.Subroutine :=
        Ast.Create_Subroutine
          (Name        => Module_Name,
           Name_Span   => Name_Token.Span,
           Filename    => Name_Token.Filename,
           Flags       => Ast.Export_Flag or Ast.Entrypoint_Flag,
           Return_Type => Types.Unit_Type,
           The_Body    => Ast.Empty_Body);
      The_Module     : constant Ast.Module :=
        Ast.Create_Module
          (Name           => Module_Name,
           Name_Span      => Name_Token.Span,
           Filename       => Name_Token.Filename,
           Span           => Unit_Span,
           The_Subroutine => The_Subroutine);
   begin
      return (Ok => True, The_Module => The_Module);
   end To_Parse_Result;

end Lovelace.Compiler.Parser;
