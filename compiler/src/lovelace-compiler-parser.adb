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

   --  Parsed compilation-unit name and kind before AST construction.
   type Unit_Parse is record
      Module_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span := Origin_Span;
      Filename    : Source.Filename_Option := Source.Absent_Filename;
      Kind        : Ast.Unit_Kind := Ast.Program_Unit;
      Stop_Span   : Source.Source_Span := Origin_Span;
      Subroutines : Ast.Subroutine_Sequence := Ast.Empty_Subroutine_Sequence;
   end record;

   --  Identifier collected in a parameter group before its type is known.
   type Pending_Name is record
      Name      : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span : Source.Source_Span := Origin_Span;
      Filename  : Source.Filename_Option := Source.Absent_Filename;
   end record;

   package Pending_Name_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Pending_Name);

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
   function Is_Keyword (The_Token : Tokens.Token; Expected : Tokens.Keyword_Subtype) return Boolean;
   function Is_Punctuation (The_Token : Tokens.Token; Expected : Tokens.Punctuation_Subtype) return Boolean;
   function Make_Failure
     (Code : Parser_Error_Code; Span : Source.Source_Span; Filename : Source.Filename_Option; Detail : String)
      return Step_Result;
   function Parameter_Name_Exists (Parameters : Ast.Parameter_Sequence; Name : String) return Boolean;
   function Parse_Block (The_Cursor : in out Cursor; Source_Text : String) return Step_Result;
   function Parse_Compilation_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result;
   function Parse_Float_Type
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result;
   function Parse_Integer_Type
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result;
   function Parse_Module_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result;
   function Parse_Parameter_Group
     (The_Cursor     : in out Cursor;
      Source_Text    : String;
      Module_Name    : String;
      Procedure_Name : String;
      Subroutines    : Ast.Subroutine_Sequence;
      Parameters     : in out Ast.Parameter_Sequence) return Step_Result;
   function Parse_Parameter_List
     (The_Cursor     : in out Cursor;
      Source_Text    : String;
      Module_Name    : String;
      Procedure_Name : String;
      Subroutines    : Ast.Subroutine_Sequence;
      Parameters     : out Ast.Parameter_Sequence) return Step_Result;
   function Parse_Procedure_Declaration
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse) return Step_Result;
   function Parse_Program_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result;
   function Parse_Qualified_Identifier
     (The_Cursor  : in out Cursor;
      Source_Text : String;
      Module_Name : out Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : out Source.Source_Span;
      Filename    : out Source.Filename_Option) return Step_Result;
   function Parse_Type_Name
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result;
   function Peek (The_Cursor : Cursor) return Tokens.Token;
   function Step_End_Of_Input (The_Cursor : Cursor; Detail : String) return Step_Result;
   function Subroutine_Name_Exists (Subroutines : Ast.Subroutine_Sequence; Name : String) return Boolean;
   function To_Parse_Result (First_Span : Source.Source_Span; The_Unit : Unit_Parse) return Parse_Result;

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
         when Tokens.Keyword         =>
            case The_Token.Keyword_Value is
               when Tokens.Program_Keyword   =>
                  return "keyword ""program""";

               when Tokens.Module_Keyword    =>
                  return "keyword ""module""";

               when Tokens.Begin_Keyword     =>
                  return "keyword ""begin""";

               when Tokens.End_Keyword       =>
                  return "keyword ""end""";

               when Tokens.Procedure_Keyword =>
                  return "keyword ""procedure""";

               when Tokens.Integer_Keyword   =>
                  return "keyword ""integer""";

               when Tokens.Float_Keyword     =>
                  return "keyword ""float""";

               when Tokens.Signed_Keyword    =>
                  return "keyword ""signed""";

               when Tokens.Unsigned_Keyword  =>
                  return "keyword ""unsigned""";
            end case;

         when Tokens.Identifier      =>
            return "identifier """ & Tokens.Lexeme (Source_Text, The_Token) & '"';

         when Tokens.Punctuation     =>
            case The_Token.Punctuation_Value is
               when Tokens.Semicolon         =>
                  return "punctuation "";""";

               when Tokens.Full_Stop         =>
                  return "punctuation "".""";

               when Tokens.Left_Parenthesis  =>
                  return "punctuation ""(""";

               when Tokens.Right_Parenthesis =>
                  return "punctuation "")""";

               when Tokens.Comma             =>
                  return "punctuation "",""";

               when Tokens.Colon             =>
                  return "punctuation "":""";

               when Tokens.Less_Than         =>
                  return "punctuation ""<""";

               when Tokens.Greater_Than      =>
                  return "punctuation "">""";
            end case;

         when Tokens.Integer_Literal =>
            return "integer literal """ & Tokens.Lexeme (Source_Text, The_Token) & '"';

         when Tokens.Float_Literal   =>
            return "float literal """ & Tokens.Lexeme (Source_Text, The_Token) & '"';
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
         Current : constant Tokens.Token := Peek (The_Cursor);
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
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin
         if not Is_Keyword (Current, Expected) then
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
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin
         if not Is_Punctuation (Current, Expected) then
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

   function Is_Keyword (The_Token : Tokens.Token; Expected : Tokens.Keyword_Subtype) return Boolean is
   begin
      return The_Token.Kind = Tokens.Keyword and then The_Token.Keyword_Value = Expected;
   end Is_Keyword;

   function Is_Punctuation (The_Token : Tokens.Token; Expected : Tokens.Punctuation_Subtype) return Boolean is
   begin
      return The_Token.Kind = Tokens.Punctuation and then The_Token.Punctuation_Value = Expected;
   end Is_Punctuation;

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

   function Parameter_Name_Exists (Parameters : Ast.Parameter_Sequence; Name : String) return Boolean is
   begin
      for Index in 1 .. Ast.Length (Parameters) loop
         if Ada.Strings.Unbounded.To_String (Ast.Element (Parameters, Index).Parameter_Name) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Parameter_Name_Exists;

   function Parse (Source_Text : String; Token_List : Tokens.Token_Sequence) return Parse_Result is
      The_Cursor : Cursor :=
        (Token_List             => Token_List,
         Next_Index             => 1,
         Has_Consumed           => False,
         First_Span             => Origin_Span,
         Last_Consumed_Span     => Origin_Span,
         Last_Consumed_Filename => Source.Absent_Filename);
      The_Unit   : Unit_Parse;
      Step       : Step_Result;
   begin
      Step := Parse_Compilation_Unit (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Unit => The_Unit);

      case Step.Ok is
         when False =>
            return Failure_From_Step (Step);

         when True  =>
            if not At_End (The_Cursor) then
               declare
                  Extra : constant Tokens.Token := Peek (The_Cursor);
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

            return To_Parse_Result (First_Span => The_Cursor.First_Span, The_Unit => The_Unit);
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
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result is
   begin
      The_Unit :=
        (Module_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
         Name_Span   => Origin_Span,
         Filename    => Source.Absent_Filename,
         Kind        => Ast.Program_Unit,
         Stop_Span   => Origin_Span,
         Subroutines => Ast.Empty_Subroutine_Sequence);

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected keyword ""program"" or ""module"", found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin
         if Current.Kind /= Tokens.Keyword then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   =>
                   "expected keyword ""program"" or ""module"", found " & Describe_Token (Source_Text, Current));
         end if;

         case Current.Keyword_Value is
            when Tokens.Program_Keyword  =>
               return Parse_Program_Unit (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Unit => The_Unit);

            when Tokens.Module_Keyword   =>
               return Parse_Module_Unit (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Unit => The_Unit);

            when Tokens.Begin_Keyword
               | Tokens.End_Keyword
               | Tokens.Procedure_Keyword
               | Tokens.Integer_Keyword
               | Tokens.Float_Keyword
               | Tokens.Signed_Keyword
               | Tokens.Unsigned_Keyword =>
               return
                 Make_Failure
                   (Code     => Unexpected_Token,
                    Span     => Current.Span,
                    Filename => Current.Filename,
                    Detail   =>
                      "expected keyword ""program"" or ""module"", found " & Describe_Token (Source_Text, Current));
         end case;
      end;
   end Parse_Compilation_Unit;

   function Parse_Float_Type
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result
   is
      Step     : Step_Result;
      The_Size : Types.Float_Size := Types.Bits_32;
   begin
      The_Type := Types.Float_Type (Types.Bits_32);

      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Float_Keyword, Label => "float");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if At_End (The_Cursor) or else not Is_Punctuation (Peek (The_Cursor), Tokens.Less_Than) then
         The_Type := Types.Float_Type (Types.Bits_32);
         return (Ok => True);
      end if;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Less_Than, Label => "<");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected float size 32 or 64, found end of input");
      end if;

      declare
         Size_Token : constant Tokens.Token := Peek (The_Cursor);
      begin
         if Size_Token.Kind /= Tokens.Integer_Literal then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Size_Token.Span,
                 Filename => Size_Token.Filename,
                 Detail   => "expected float size 32 or 64, found " & Describe_Token (Source_Text, Size_Token));
         end if;

         declare
            Lexeme : constant String := Tokens.Lexeme (Source_Text, Size_Token);
         begin
            if Lexeme = "32" then
               The_Size := Types.Bits_32;
            elsif Lexeme = "64" then
               The_Size := Types.Bits_64;
            else
               return
                 Make_Failure
                   (Code     => Unexpected_Token,
                    Span     => Size_Token.Span,
                    Filename => Size_Token.Filename,
                    Detail   => "invalid float size """ & Lexeme & """; expected 32 or 64");
            end if;
         end;

         Advance (The_Cursor);
      end;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Greater_Than, Label => ">");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            The_Type := Types.Float_Type (The_Size);
            return (Ok => True);
      end case;
   end Parse_Float_Type;

   function Parse_Integer_Type
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result
   is
      Step           : Step_Result;
      The_Signedness : Types.Signedness := Types.Signed;
      The_Size       : Types.Integer_Size := Types.Bits_32;
   begin
      The_Type := Types.Integer_Type (Types.Signed, Types.Bits_32);

      if not At_End (The_Cursor) then
         declare
            Current : constant Tokens.Token := Peek (The_Cursor);
         begin
            if Is_Keyword (Current, Tokens.Signed_Keyword) then
               Advance (The_Cursor);
               The_Signedness := Types.Signed;
            elsif Is_Keyword (Current, Tokens.Unsigned_Keyword) then
               Advance (The_Cursor);
               The_Signedness := Types.Unsigned;
            end if;
         end;
      end if;

      Step :=
        Expect_Keyword
          (The_Cursor  => The_Cursor,
           Source_Text => Source_Text,
           Expected    => Tokens.Integer_Keyword,
           Label       => "integer");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if At_End (The_Cursor) or else not Is_Punctuation (Peek (The_Cursor), Tokens.Less_Than) then
         The_Type := Types.Integer_Type (The_Signedness, Types.Bits_32);
         return (Ok => True);
      end if;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Less_Than, Label => "<");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected integer size 8, 16, 32, or 64, found end of input");
      end if;

      declare
         Size_Token : constant Tokens.Token := Peek (The_Cursor);
      begin
         if Size_Token.Kind /= Tokens.Integer_Literal then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Size_Token.Span,
                 Filename => Size_Token.Filename,
                 Detail   =>
                   "expected integer size 8, 16, 32, or 64, found " & Describe_Token (Source_Text, Size_Token));
         end if;

         declare
            Lexeme : constant String := Tokens.Lexeme (Source_Text, Size_Token);
         begin
            if Lexeme = "8" then
               The_Size := Types.Bits_8;
            elsif Lexeme = "16" then
               The_Size := Types.Bits_16;
            elsif Lexeme = "32" then
               The_Size := Types.Bits_32;
            elsif Lexeme = "64" then
               The_Size := Types.Bits_64;
            else
               return
                 Make_Failure
                   (Code     => Unexpected_Token,
                    Span     => Size_Token.Span,
                    Filename => Size_Token.Filename,
                    Detail   => "invalid integer size """ & Lexeme & """; expected 8, 16, 32, or 64");
            end if;
         end;

         Advance (The_Cursor);
      end;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Greater_Than, Label => ">");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            The_Type := Types.Integer_Type (The_Signedness, The_Size);
            return (Ok => True);
      end case;
   end Parse_Integer_Type;

   function Parse_Module_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result
   is
      Step : Step_Result;
   begin
      The_Unit :=
        (Module_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
         Name_Span   => Origin_Span,
         Filename    => Source.Absent_Filename,
         Kind        => Ast.Module_Unit,
         Stop_Span   => Origin_Span,
         Subroutines => Ast.Empty_Subroutine_Sequence);

      --  module_unit = "module" , qualified_identifier , ";" , { procedure_declaration } , "end" , "."
      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Module_Keyword, Label => "module");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step :=
        Parse_Qualified_Identifier
          (The_Cursor  => The_Cursor,
           Source_Text => Source_Text,
           Module_Name => The_Unit.Module_Name,
           Name_Span   => The_Unit.Name_Span,
           Filename    => The_Unit.Filename);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      loop
         if At_End (The_Cursor) then
            exit;
         end if;

         if not Is_Keyword (Peek (The_Cursor), Tokens.Procedure_Keyword) then
            exit;
         end if;

         Step :=
           Parse_Procedure_Declaration (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Unit => The_Unit);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end loop;

      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.End_Keyword, Label => "end");
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
            The_Unit.Kind := Ast.Module_Unit;
            The_Unit.Stop_Span := The_Cursor.Last_Consumed_Span;
            return (Ok => True);
      end case;
   end Parse_Module_Unit;

   function Parse_Parameter_Group
     (The_Cursor     : in out Cursor;
      Source_Text    : String;
      Module_Name    : String;
      Procedure_Name : String;
      Subroutines    : Ast.Subroutine_Sequence;
      Parameters     : in out Ast.Parameter_Sequence) return Step_Result
   is
      Names      : Pending_Name_Vectors.Vector;
      Name_Token : Tokens.Token := Dummy_Identifier;
      Step       : Step_Result;
      The_Type   : Types.Type_Expression;
   begin
      --  parameter_group = identifier , { "," , identifier } , ":" , type_name
      Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Name_Token);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            Names.Append
              (Pending_Name'
                 (Name      => Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Name_Token)),
                  Name_Span => Name_Token.Span,
                  Filename  => Name_Token.Filename));
      end case;

      loop
         if At_End (The_Cursor) or else not Is_Punctuation (Peek (The_Cursor), Tokens.Comma) then
            exit;
         end if;

         Advance (The_Cursor);

         Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Name_Token);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               Names.Append
                 (Pending_Name'
                    (Name      => Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Name_Token)),
                     Name_Span => Name_Token.Span,
                     Filename  => Name_Token.Filename));
         end case;
      end loop;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Colon, Label => ":");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step := Parse_Type_Name (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Type => The_Type);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      for Index in Names.First_Index .. Names.Last_Index loop
         declare
            Pending : constant Pending_Name := Names.Element (Index);
            Name    : constant String := Ada.Strings.Unbounded.To_String (Pending.Name);
         begin
            if Parameter_Name_Exists (Parameters, Name) then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Pending.Name_Span,
                    Filename => Pending.Filename,
                    Detail   => "parameter name """ & Name & """ is duplicated in this procedure");
            end if;

            if Name = Module_Name then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Pending.Name_Span,
                    Filename => Pending.Filename,
                    Detail   => "parameter name """ & Name & """ conflicts with the module name");
            end if;

            if Name = Procedure_Name then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Pending.Name_Span,
                    Filename => Pending.Filename,
                    Detail   =>
                      "parameter name """ & Name & """ conflicts with procedure name """ & Procedure_Name & '"');
            end if;

            if Subroutine_Name_Exists (Subroutines, Name) then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Pending.Name_Span,
                    Filename => Pending.Filename,
                    Detail   => "parameter name """ & Name & """ conflicts with subroutine name """ & Name & '"');
            end if;

            Ast.Append
              (Sequence      => Parameters,
               The_Parameter =>
                 (Parameter_Name => Pending.Name,
                  Name_Span      => Pending.Name_Span,
                  Filename       => Pending.Filename,
                  Parameter_Type => The_Type));
         end;
      end loop;

      return (Ok => True);
   end Parse_Parameter_Group;

   function Parse_Parameter_List
     (The_Cursor     : in out Cursor;
      Source_Text    : String;
      Module_Name    : String;
      Procedure_Name : String;
      Subroutines    : Ast.Subroutine_Sequence;
      Parameters     : out Ast.Parameter_Sequence) return Step_Result
   is
      Step : Step_Result;
   begin
      Parameters := Ast.Empty_Parameter_Sequence;

      --  parameter_list = parameter_group , { ";" , parameter_group }
      Step :=
        Parse_Parameter_Group
          (The_Cursor     => The_Cursor,
           Source_Text    => Source_Text,
           Module_Name    => Module_Name,
           Procedure_Name => Procedure_Name,
           Subroutines    => Subroutines,
           Parameters     => Parameters);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      loop
         if At_End (The_Cursor) or else not Is_Punctuation (Peek (The_Cursor), Tokens.Semicolon) then
            return (Ok => True);
         end if;

         Advance (The_Cursor);

         Step :=
           Parse_Parameter_Group
             (The_Cursor     => The_Cursor,
              Source_Text    => Source_Text,
              Module_Name    => Module_Name,
              Procedure_Name => Procedure_Name,
              Subroutines    => Subroutines,
              Parameters     => Parameters);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end loop;
   end Parse_Parameter_List;

   function Parse_Procedure_Declaration
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse) return Step_Result
   is
      Name_Token     : Tokens.Token := Dummy_Identifier;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
      Module_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Unit.Module_Name);
      Parameters     : Ast.Parameter_Sequence := Ast.Empty_Parameter_Sequence;
      Step           : Step_Result;
      The_Subroutine : Ast.Subroutine;
   begin
      --  procedure_declaration = procedure_header , "begin" , "end" , ";"
      --  procedure_header = "procedure" , identifier , "(" , [ parameter_list ] , ")" , ";"
      Step :=
        Expect_Keyword
          (The_Cursor  => The_Cursor,
           Source_Text => Source_Text,
           Expected    => Tokens.Procedure_Keyword,
           Label       => "procedure");
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

      Procedure_Name := Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Name_Token));

      declare
         Name : constant String := Ada.Strings.Unbounded.To_String (Procedure_Name);
      begin
         if Name = Module_Name then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Token.Span,
                 Filename => Name_Token.Filename,
                 Detail   => "procedure name """ & Name & """ conflicts with the module name");
         end if;

         if Subroutine_Name_Exists (The_Unit.Subroutines, Name) then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Token.Span,
                 Filename => Name_Token.Filename,
                 Detail   => "procedure name """ & Name & """ is duplicated in this module");
         end if;
      end;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Left_Parenthesis, Label => "(");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected parameter list or punctuation "")"", found end of input");
      end if;

      if not Is_Punctuation (Peek (The_Cursor), Tokens.Right_Parenthesis) then
         Step :=
           Parse_Parameter_List
             (The_Cursor     => The_Cursor,
              Source_Text    => Source_Text,
              Module_Name    => Module_Name,
              Procedure_Name => Ada.Strings.Unbounded.To_String (Procedure_Name),
              Subroutines    => The_Unit.Subroutines,
              Parameters     => Parameters);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end if;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Right_Parenthesis, Label => ")");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
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
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      The_Subroutine :=
        Ast.Create_Subroutine
          (Name        => Ada.Strings.Unbounded.To_String (Procedure_Name),
           Module_Name => Module_Name,
           Name_Span   => Name_Token.Span,
           Filename    => Name_Token.Filename,
           Flags       => 0,
           Return_Type => Types.Unit_Type,
           Parameters  => Parameters,
           The_Body    => Ast.Empty_Body);
      Ast.Append (Sequence => The_Unit.Subroutines, The_Subroutine => The_Subroutine);
      return (Ok => True);
   end Parse_Procedure_Declaration;

   function Parse_Program_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result
   is
      Name_Token : Tokens.Token := Dummy_Identifier;
      Step       : Step_Result;
   begin
      The_Unit :=
        (Module_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
         Name_Span   => Origin_Span,
         Filename    => Source.Absent_Filename,
         Kind        => Ast.Program_Unit,
         Stop_Span   => Origin_Span,
         Subroutines => Ast.Empty_Subroutine_Sequence);

      --  program_unit = "program" , identifier , ";" , "begin" , "end" , "."
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

      The_Unit.Module_Name := Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Name_Token));
      The_Unit.Name_Span := Name_Token.Span;
      The_Unit.Filename := Name_Token.Filename;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
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
            The_Unit.Kind := Ast.Program_Unit;
            The_Unit.Stop_Span := The_Cursor.Last_Consumed_Span;
            return (Ok => True);
      end case;
   end Parse_Program_Unit;

   function Parse_Qualified_Identifier
     (The_Cursor  : in out Cursor;
      Source_Text : String;
      Module_Name : out Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : out Source.Source_Span;
      Filename    : out Source.Filename_Option) return Step_Result
   is
      First_Token : Tokens.Token := Dummy_Identifier;
      Step        : Step_Result;
   begin
      Module_Name := Ada.Strings.Unbounded.Null_Unbounded_String;
      Name_Span := Origin_Span;
      Filename := Source.Absent_Filename;

      Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => First_Token);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Module_Name := Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, First_Token));
      Name_Span := First_Token.Span;
      Filename := First_Token.Filename;

      loop
         if At_End (The_Cursor) then
            return (Ok => True);
         end if;

         declare
            Current : constant Tokens.Token := Peek (The_Cursor);
         begin
            if not Is_Punctuation (Current, Tokens.Full_Stop) then
               return (Ok => True);
            end if;

            Advance (The_Cursor);

            declare
               Segment_Token : Tokens.Token := Dummy_Identifier;
            begin
               Step :=
                 Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Segment_Token);
               case Step.Ok is
                  when False =>
                     return Step;

                  when True  =>
                     Ada.Strings.Unbounded.Append (Module_Name, ".");
                     Ada.Strings.Unbounded.Append (Module_Name, Tokens.Lexeme (Source_Text, Segment_Token));
                     Name_Span.Last := Segment_Token.Span.Last;
               end case;
            end;
         end;
      end loop;
   end Parse_Qualified_Identifier;

   function Parse_Type_Name
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result is
   begin
      The_Type := Types.Unit_Type;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected type name (""integer"" or ""float""), found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin
         if Is_Keyword (Current, Tokens.Float_Keyword) then
            return Parse_Float_Type (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Type => The_Type);
         end if;

         if Is_Keyword (Current, Tokens.Integer_Keyword)
           or else Is_Keyword (Current, Tokens.Signed_Keyword)
           or else Is_Keyword (Current, Tokens.Unsigned_Keyword)
         then
            return Parse_Integer_Type (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Type => The_Type);
         end if;

         return
           Make_Failure
             (Code     => Unexpected_Token,
              Span     => Current.Span,
              Filename => Current.Filename,
              Detail   =>
                "expected type name (""integer"" or ""float""), found " & Describe_Token (Source_Text, Current));
      end;
   end Parse_Type_Name;

   function Peek (The_Cursor : Cursor) return Tokens.Token is
   begin
      return Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
   end Peek;

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

   function Subroutine_Name_Exists (Subroutines : Ast.Subroutine_Sequence; Name : String) return Boolean is
   begin
      for Index in 1 .. Ast.Length (Subroutines) loop
         if Ast.Name (Ast.Element (Subroutines, Index)) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Subroutine_Name_Exists;

   function To_Parse_Result (First_Span : Source.Source_Span; The_Unit : Unit_Parse) return Parse_Result is
      Unit_Span   : constant Source.Source_Span := (First => First_Span.First, Last => The_Unit.Stop_Span.Last);
      Module_Name : constant String := Ada.Strings.Unbounded.To_String (The_Unit.Module_Name);
   begin
      case The_Unit.Kind is
         when Ast.Program_Unit =>
            declare
               Subroutines    : Ast.Subroutine_Sequence := Ast.Empty_Subroutine_Sequence;
               The_Subroutine : constant Ast.Subroutine :=
                 Ast.Create_Subroutine
                   (Name        => Module_Name,
                    Module_Name => Module_Name,
                    Name_Span   => The_Unit.Name_Span,
                    Filename    => The_Unit.Filename,
                    Flags       => Ast.Export_Flag or Ast.Entrypoint_Flag,
                    Return_Type => Types.Unit_Type,
                    Parameters  => Ast.Empty_Parameter_Sequence,
                    The_Body    => Ast.Empty_Body);
               The_Module     : Ast.Module;
            begin
               Ast.Append (Sequence => Subroutines, The_Subroutine => The_Subroutine);
               The_Module :=
                 Ast.Create_Module
                   (Name        => Module_Name,
                    Name_Span   => The_Unit.Name_Span,
                    Filename    => The_Unit.Filename,
                    Span        => Unit_Span,
                    Kind        => Ast.Program_Unit,
                    Subroutines => Subroutines);
               return (Ok => True, The_Module => The_Module);
            end;

         when Ast.Module_Unit  =>
            return
              (Ok         => True,
               The_Module =>
                 Ast.Create_Module
                   (Name        => Module_Name,
                    Name_Span   => The_Unit.Name_Span,
                    Filename    => The_Unit.Filename,
                    Span        => Unit_Span,
                    Kind        => Ast.Module_Unit,
                    Subroutines => The_Unit.Subroutines));
      end case;
   end To_Parse_Result;

end Lovelace.Compiler.Parser;
