with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Fixed;

with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Parser is

   use type Ast.Subroutine_Flags;
   use type Flavor.Flavor;
   use type Tokens.Directive_Subtype;
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
      Active_Flavor          : Flavor.Flavor := Flavor.Wasi;
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
      Module_Name  : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span    : Source.Source_Span := Origin_Span;
      Filename     : Source.Filename_Option := Source.Absent_Filename;
      Kind         : Ast.Unit_Kind := Ast.Program_Unit;
      Stop_Span    : Source.Source_Span := Origin_Span;
      Usings       : Ast.Using_Sequence := Ast.Empty_Using_Sequence;
      Subroutines  : Ast.Subroutine_Sequence := Ast.Empty_Subroutine_Sequence;
      Program_Body : Ast.Block := Ast.Empty_Block;
   end record;

   --  Identifier collected in a parameter group before its type is known.
   type Pending_Name is record
      Name      : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span : Source.Source_Span := Origin_Span;
      Filename  : Source.Filename_Option := Source.Absent_Filename;
   end record;

   package Pending_Name_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Pending_Name);

   package Bound_Name_Vectors is new Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => String);

   package Frame_Size_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Natural);

   type Scope_Stack is record
      Names       : Bound_Name_Vectors.Vector;
      Frame_Sizes : Frame_Size_Vectors.Vector;
   end record;

   procedure Advance (The_Cursor : in out Cursor);
   function At_End (The_Cursor : Cursor) return Boolean;
   function Describe_Token (Source_Text : String; The_Token : Tokens.Token) return String;
   function Expect_Directive
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Directive_Subtype; Label : String)
      return Step_Result;
   function Expect_Identifier
     (The_Cursor : in out Cursor; Source_Text : String; The_Token : out Tokens.Token) return Step_Result;
   function Expect_Keyword
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Keyword_Subtype; Label : String)
      return Step_Result;
   function Expect_Punctuation
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Punctuation_Subtype; Label : String)
      return Step_Result;
   function Failure_From_Step (Step : Step_Result) return Parse_Result;
   procedure Bind_Unit_Usings (Stack : in out Scope_Stack; Usings : Ast.Using_Sequence);
   function Is_Directive (The_Token : Tokens.Token; Expected : Tokens.Directive_Subtype) return Boolean;
   function Is_Identifier_Lexeme (Source_Text : String; The_Token : Tokens.Token; Lexeme : String) return Boolean;
   function Is_Keyword (The_Token : Tokens.Token; Expected : Tokens.Keyword_Subtype) return Boolean;
   function Is_Punctuation (The_Token : Tokens.Token; Expected : Tokens.Punctuation_Subtype) return Boolean;
   function Make_Failure
     (Code : Parser_Error_Code; Span : Source.Source_Span; Filename : Source.Filename_Option; Detail : String)
      return Step_Result;
   function Parameter_Name_Exists (Parameters : Ast.Parameter_Sequence; Name : String) return Boolean;
   function Peek_At (The_Cursor : Cursor; Offset : Natural) return Tokens.Token;
   procedure Scope_Push (Stack : in out Scope_Stack);
   procedure Scope_Pop (Stack : in out Scope_Stack);
   procedure Scope_Bind (Stack : in out Scope_Stack; Name : String);
   function Scope_Is_Bound (Stack : Scope_Stack; Name : String) return Boolean;
   function Unit_Entity_Exists
     (Unit_Name : String; Subroutines : Ast.Subroutine_Sequence; Name : String) return Boolean;
   function Using_Name_Exists (Usings : Ast.Using_Sequence; Name : String) return Boolean;
   function Parse_Argument_List
     (The_Cursor : in out Cursor; Source_Text : String; Arguments : out Ast.Expression_Sequence) return Step_Result;
   function Parse_Assignment_Statement
     (The_Cursor : in out Cursor; Source_Text : String; The_Statement : out Ast.Statement) return Step_Result;
   function Parse_Block
     (The_Cursor     : in out Cursor;
      Source_Text    : String;
      Unit_Name      : String;
      Procedure_Name : String;
      Subroutines    : Ast.Subroutine_Sequence;
      Scope          : in out Scope_Stack;
      The_Body       : out Ast.Block) return Step_Result;
   function Parse_Call_Statement
     (The_Cursor : in out Cursor; Source_Text : String; The_Statement : out Ast.Statement) return Step_Result;
   function Parse_Compilation_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result;
   function Parse_Expression
     (The_Cursor : in out Cursor; Source_Text : String; The_Expression : out Ast.Expression) return Step_Result;
   function Parse_Flavor_Condition
     (The_Cursor : in out Cursor; Source_Text : String; Condition_Flavor : out Flavor.Flavor) return Step_Result;
   function Parse_Flavor_Conditional
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse; Keep_Declarations : Boolean)
      return Step_Result;
   function Parse_Float_Type
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result;
   function Parse_Integer_Type
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result;
   function Parse_Module_Declaration
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse; Keep_Declarations : Boolean)
      return Step_Result;
   function Parse_Module_Declaration_List
     (The_Cursor        : in out Cursor;
      Source_Text       : String;
      The_Unit          : in out Unit_Parse;
      Keep_Declarations : Boolean;
      Stop_At_Arm_End   : Boolean) return Step_Result;
   function Parse_Module_Unit
     (The_Cursor : in out Cursor; Source_Text : String; Unit_Usings : Ast.Using_Sequence; The_Unit : out Unit_Parse)
      return Step_Result;
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
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse; Keep_Declarations : Boolean)
      return Step_Result;
   function Parse_Program_Unit
     (The_Cursor : in out Cursor; Source_Text : String; Unit_Usings : Ast.Using_Sequence; The_Unit : out Unit_Parse)
      return Step_Result;
   function Parse_Qualified_Identifier
     (The_Cursor  : in out Cursor;
      Source_Text : String;
      Module_Name : out Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : out Source.Source_Span;
      Filename    : out Source.Filename_Option) return Step_Result;
   function Parse_Type_Name
     (The_Cursor : in out Cursor; Source_Text : String; The_Type : out Types.Type_Expression) return Step_Result;
   function Parse_Using_Declaration
     (The_Cursor : in out Cursor; Source_Text : String; Usings : in out Ast.Using_Sequence) return Step_Result;
   function Parse_Using_List
     (The_Cursor : in out Cursor; Source_Text : String; Usings : out Ast.Using_Sequence) return Step_Result;
   function Peek (The_Cursor : Cursor) return Tokens.Token;
   function Reject_Self_Usings (The_Unit : Unit_Parse) return Step_Result;
   function Step_End_Of_Input (The_Cursor : Cursor; Detail : String) return Step_Result;
   function String_Literal_Content (Source_Text : String; The_Token : Tokens.Token) return String;
   function Subroutine_Name_Exists (Subroutines : Ast.Subroutine_Sequence; Name : String) return Boolean;
   function Subroutine_Signature_Exists
     (Subroutines : Ast.Subroutine_Sequence; Name : String; Parameters : Ast.Parameter_Sequence) return Boolean;
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

               when Tokens.Export_Keyword    =>
                  return "keyword ""export""";

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

               when Tokens.Boolean_Keyword   =>
                  return "keyword ""boolean""";

               when Tokens.True_Keyword      =>
                  return "keyword ""true""";

               when Tokens.False_Keyword     =>
                  return "keyword ""false""";

               when Tokens.Declare_Keyword   =>
                  return "keyword ""declare""";

               when Tokens.Using_Keyword     =>
                  return "keyword ""using""";
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

               when Tokens.Colon_Equals      =>
                  return "punctuation "":=""";

               when Tokens.Colon             =>
                  return "punctuation "":""";

               when Tokens.Less_Than         =>
                  return "punctuation ""<""";

               when Tokens.Greater_Than      =>
                  return "punctuation "">""";

               when Tokens.Equals            =>
                  return "punctuation ""=""";
            end case;

         when Tokens.Integer_Literal =>
            return "integer literal """ & Tokens.Lexeme (Source_Text, The_Token) & '"';

         when Tokens.Float_Literal   =>
            return "float literal """ & Tokens.Lexeme (Source_Text, The_Token) & '"';

         when Tokens.Directive       =>
            case The_Token.Directive_Value is
               when Tokens.If_Directive    =>
                  return "directive ""#if""";

               when Tokens.Elsif_Directive =>
                  return "directive ""#elsif""";

               when Tokens.Else_Directive  =>
                  return "directive ""#else""";

               when Tokens.End_Directive   =>
                  return "directive ""#end""";
            end case;

         when Tokens.String_Literal  =>
            return "string literal """ & Tokens.Lexeme (Source_Text, The_Token) & '"';
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

   function Expect_Directive
     (The_Cursor : in out Cursor; Source_Text : String; Expected : Tokens.Directive_Subtype; Label : String)
      return Step_Result is
   begin
      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected directive """ & Label & """, found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin
         if not Is_Directive (Current, Expected) then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   => "expected directive """ & Label & """, found " & Describe_Token (Source_Text, Current));
         end if;

         Advance (The_Cursor);
         return (Ok => True);
      end;
   end Expect_Directive;

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

   function Is_Directive (The_Token : Tokens.Token; Expected : Tokens.Directive_Subtype) return Boolean is
   begin
      return The_Token.Kind = Tokens.Directive and then The_Token.Directive_Value = Expected;
   end Is_Directive;

   function Is_Identifier_Lexeme (Source_Text : String; The_Token : Tokens.Token; Lexeme : String) return Boolean is
   begin
      return The_Token.Kind = Tokens.Identifier and then Tokens.Lexeme (Source_Text, The_Token) = Lexeme;
   end Is_Identifier_Lexeme;

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

   function Parse
     (Source_Text : String; Token_List : Tokens.Token_Sequence; Active_Flavor : Flavor.Flavor) return Parse_Result
   is
      The_Cursor : Cursor :=
        (Token_List             => Token_List,
         Next_Index             => 1,
         Has_Consumed           => False,
         First_Span             => Origin_Span,
         Last_Consumed_Span     => Origin_Span,
         Last_Consumed_Filename => Source.Absent_Filename,
         Active_Flavor          => Active_Flavor);
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

   function Parse_Argument_List
     (The_Cursor : in out Cursor; Source_Text : String; Arguments : out Ast.Expression_Sequence) return Step_Result
   is
      Step : Step_Result;
   begin
      Arguments := Ast.Empty_Expression_Sequence;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected argument list or "")"", found end of input");
      end if;

      if Is_Punctuation (Peek (The_Cursor), Tokens.Right_Parenthesis) then
         return (Ok => True);
      end if;

      loop
         declare
            The_Expression : Ast.Expression;
         begin
            Step := Parse_Expression (The_Cursor, Source_Text, The_Expression);
            case Step.Ok is
               when False =>
                  return Step;

               when True  =>
                  Ast.Append (Sequence => Arguments, The_Expression => The_Expression);
            end case;
         end;

         if At_End (The_Cursor) or else not Is_Punctuation (Peek (The_Cursor), Tokens.Comma) then
            return (Ok => True);
         end if;

         Step :=
           Expect_Punctuation
             (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Comma, Label => ",");
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end loop;
   end Parse_Argument_List;

   pragma Style_Checks (Off);

   procedure Bind_Unit_Usings (Stack : in out Scope_Stack; Usings : Ast.Using_Sequence) is
   begin
      for Index in 1 .. Ast.Length (Usings) loop
         Scope_Bind (Stack, Ada.Strings.Unbounded.To_String (Ast.Element (Usings, Index).Module_Name));
      end loop;
   end Bind_Unit_Usings;

   function Has_Token_At (The_Cursor : Cursor; Offset : Natural) return Boolean is
   begin
      return The_Cursor.Next_Index + Offset <= Tokens.Length (The_Cursor.Token_List);
   end Has_Token_At;

   function Using_Name_Exists (Usings : Ast.Using_Sequence; Name : String) return Boolean is
   begin
      for Index in 1 .. Ast.Length (Usings) loop
         if Ada.Strings.Unbounded.To_String (Ast.Element (Usings, Index).Module_Name) = Name then
            return True;
         end if;
      end loop;
      return False;
   end Using_Name_Exists;

   function Parse_Expression
     (The_Cursor : in out Cursor; Source_Text : String; The_Expression : out Ast.Expression) return Step_Result
   is
      Expected : constant String := "expected integer literal, true/false, or identifier";
   begin
      The_Expression :=
        (Kind     => Ast.Integer_Literal,
         Lexeme   => Ada.Strings.Unbounded.Null_Unbounded_String,
         Span     => Origin_Span,
         Filename => Source.Absent_Filename);

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, Expected & ", found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
         Kind    : Ast.Expression_Kind;
      begin
         if Current.Kind = Tokens.Integer_Literal then
            Kind := Ast.Integer_Literal;
         elsif Is_Keyword (Current, Tokens.True_Keyword) or else Is_Keyword (Current, Tokens.False_Keyword) then
            Kind := Ast.Boolean_Literal;
         elsif Current.Kind = Tokens.Identifier then
            Kind := Ast.Name_Reference;
         else
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   => Expected & ", found " & Describe_Token (Source_Text, Current));
         end if;

         Advance (The_Cursor);
         The_Expression :=
           (Kind     => Kind,
            Lexeme   => Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Current)),
            Span     => Current.Span,
            Filename => Current.Filename);
         return (Ok => True);
      end;
   end Parse_Expression;

   function Parse_Assignment_Statement
     (The_Cursor : in out Cursor; Source_Text : String; The_Statement : out Ast.Statement) return Step_Result
   is
      Name_Token     : Tokens.Token := Dummy_Identifier;
      The_Expression : Ast.Expression;
      Step           : Step_Result;
   begin
      The_Statement :=
        Ast.Make_Call_Statement
          ((Callee_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
            Name_Span   => Origin_Span,
            Filename    => Source.Absent_Filename,
            Arguments   => Ast.Empty_Expression_Sequence));

      --  assignment_statement = identifier , ":=" , expression , ";"
      Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Name_Token);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Colon_Equals, Label => ":=");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step := Parse_Expression (The_Cursor, Source_Text, The_Expression);
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
            The_Statement :=
              Ast.Make_Assignment_Statement
                ((Target_Name => Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Name_Token)),
                  Name_Span   => Name_Token.Span,
                  Filename    => Name_Token.Filename,
                  Value       => The_Expression));
            return (Ok => True);
      end case;
   end Parse_Assignment_Statement;

   function Parse_Using_Declaration
     (The_Cursor : in out Cursor; Source_Text : String; Usings : in out Ast.Using_Sequence) return Step_Result
   is
      Step        : Step_Result;
      Module_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span := Origin_Span;
      Filename    : Source.Filename_Option := Source.Absent_Filename;
   begin
      --  using_declaration = "using" , qualified_identifier , ";"
      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Using_Keyword, Label => "using");
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
           Module_Name => Module_Name,
           Name_Span   => Name_Span,
           Filename    => Filename);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      declare
         Name_Text : constant String := Ada.Strings.Unbounded.To_String (Module_Name);
      begin
         if Using_Name_Exists (Usings, Name_Text) then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Span,
                 Filename => Filename,
                 Detail   => "duplicate using """ & Name_Text & '"');
         end if;
      end;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            Ast.Append
              (Sequence  => Usings,
               The_Using => (Module_Name => Module_Name, Name_Span => Name_Span, Filename => Filename));
            return (Ok => True);
      end case;
   end Parse_Using_Declaration;

   function Parse_Using_List
     (The_Cursor : in out Cursor; Source_Text : String; Usings : out Ast.Using_Sequence) return Step_Result
   is
      Step : Step_Result;
   begin
      Usings := Ast.Empty_Using_Sequence;

      while not At_End (The_Cursor) and then Is_Keyword (Peek (The_Cursor), Tokens.Using_Keyword) loop
         Step := Parse_Using_Declaration (The_Cursor => The_Cursor, Source_Text => Source_Text, Usings => Usings);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end loop;

      return (Ok => True);
   end Parse_Using_List;

   procedure Scope_Push (Stack : in out Scope_Stack) is
   begin
      Stack.Frame_Sizes.Append (Natural (Stack.Names.Length));
   end Scope_Push;

   procedure Scope_Pop (Stack : in out Scope_Stack) is
      Mark : constant Natural := Stack.Frame_Sizes.Last_Element;
   begin
      Stack.Frame_Sizes.Delete_Last;
      while Natural (Stack.Names.Length) > Mark loop
         Stack.Names.Delete_Last;
      end loop;
   end Scope_Pop;

   procedure Scope_Bind (Stack : in out Scope_Stack; Name : String) is
   begin
      Stack.Names.Append (Name);
   end Scope_Bind;

   function Scope_Is_Bound (Stack : Scope_Stack; Name : String) return Boolean is
   begin
      for Index in 1 .. Natural (Stack.Names.Length) loop
         if Stack.Names.Element (Index) = Name then
            return True;
         end if;
      end loop;
      return False;
   end Scope_Is_Bound;

   function Unit_Entity_Exists (Unit_Name : String; Subroutines : Ast.Subroutine_Sequence; Name : String) return Boolean
   is
   begin
      if Name = Unit_Name then
         return True;
      end if;
      return Subroutine_Name_Exists (Subroutines, Name);
   end Unit_Entity_Exists;

   function Parse_Block
     (The_Cursor     : in out Cursor;
      Source_Text    : String;
      Unit_Name      : String;
      Procedure_Name : String;
      Subroutines    : Ast.Subroutine_Sequence;
      Scope          : in out Scope_Stack;
      The_Body       : out Ast.Block) return Step_Result
   is
      Locals     : Ast.Local_Sequence := Ast.Empty_Local_Sequence;
      Usings     : Ast.Using_Sequence := Ast.Empty_Using_Sequence;
      Statements : Ast.Statement_Sequence := Ast.Empty_Body;
      Step       : Step_Result;

      function Bind_Local_Name
        (Name : String; Name_Span : Source.Source_Span; Filename : Source.Filename_Option) return Step_Result is
      begin
         if Unit_Entity_Exists (Unit_Name, Subroutines, Name) then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Span,
                 Filename => Filename,
                 Detail   => "local name """ & Name & """ conflicts with a unit-level entity");
         end if;
         if Procedure_Name'Length > 0 and then Name = Procedure_Name then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Span,
                 Filename => Filename,
                 Detail   => "local name """ & Name & """ conflicts with procedure name """ & Procedure_Name & '"');
         end if;
         if Scope_Is_Bound (Scope, Name) then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Span,
                 Filename => Filename,
                 Detail   => "local name """ & Name & """ conflicts with an enclosing binding");
         end if;
         Scope_Bind (Scope, Name);
         return (Ok => True);
      end Bind_Local_Name;

      function Parse_Variable_Declaration return Step_Result is
         Names    : Pending_Name_Vectors.Vector;
         The_Type : Types.Type_Expression;
         Name_Tok : Tokens.Token := Dummy_Identifier;
      begin
         loop
            Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Name_Tok);
            case Step.Ok is
               when False =>
                  return Step;

               when True  =>
                  Pending_Name_Vectors.Append
                    (Names,
                     Pending_Name'
                       (Name      => Ada.Strings.Unbounded.To_Unbounded_String (Tokens.Lexeme (Source_Text, Name_Tok)),
                        Name_Span => Name_Tok.Span,
                        Filename  => Name_Tok.Filename));
            end case;
            if At_End (The_Cursor) then
               return
                 Step_End_Of_Input (The_Cursor, "expected "","" or "":"" in variable declaration, found end of input");
            end if;
            if Is_Punctuation (Peek (The_Cursor), Tokens.Comma) then
               Advance (The_Cursor);
            else
               exit;
            end if;
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

         Step :=
           Expect_Punctuation
             (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
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
               Step := Bind_Local_Name (Name, Pending.Name_Span, Pending.Filename);
               case Step.Ok is
                  when False =>
                     return Step;

                  when True  =>
                     Ast.Append
                       (Sequence      => Locals,
                        The_Parameter =>
                          (Parameter_Name => Pending.Name,
                           Name_Span      => Pending.Name_Span,
                           Filename       => Pending.Filename,
                           Parameter_Type => The_Type));
               end case;
            end;
         end loop;
         return (Ok => True);
      end Parse_Variable_Declaration;

      function Parse_Block_Using return Step_Result is
         Module_Name : Ada.Strings.Unbounded.Unbounded_String;
         Name_Span   : Source.Source_Span := Origin_Span;
         Filename    : Source.Filename_Option := Source.Absent_Filename;
         Inner       : Step_Result;
      begin
         Inner :=
           Expect_Keyword
             (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Using_Keyword, Label => "using");
         case Inner.Ok is
            when False =>
               return Inner;

            when True  =>
               null;
         end case;

         Inner :=
           Parse_Qualified_Identifier
             (The_Cursor  => The_Cursor,
              Source_Text => Source_Text,
              Module_Name => Module_Name,
              Name_Span   => Name_Span,
              Filename    => Filename);
         case Inner.Ok is
            when False =>
               return Inner;

            when True  =>
               null;
         end case;

         declare
            Name_Text : constant String := Ada.Strings.Unbounded.To_String (Module_Name);
         begin
            if Name_Text = Unit_Name then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Name_Span,
                    Filename => Filename,
                    Detail   => "module cannot use itself """ & Name_Text & '"');
            end if;

            if Using_Name_Exists (Usings, Name_Text) then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Name_Span,
                    Filename => Filename,
                    Detail   => "duplicate using """ & Name_Text & '"');
            end if;

            if Scope_Is_Bound (Scope, Name_Text) then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Name_Span,
                    Filename => Filename,
                    Detail   => "using """ & Name_Text & """ conflicts with an enclosing binding or using");
            end if;

            Inner :=
              Expect_Punctuation
                (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
            case Inner.Ok is
               when False =>
                  return Inner;

               when True  =>
                  null;
            end case;

            Scope_Bind (Scope, Name_Text);
            Ast.Append
              (Sequence  => Usings,
               The_Using => (Module_Name => Module_Name, Name_Span => Name_Span, Filename => Filename));
            return (Ok => True);
         end;
      end Parse_Block_Using;

      function Parse_Statement (The_Statement : out Ast.Statement) return Step_Result is
         Nested : Ast.Block;
      begin
         The_Statement :=
           Ast.Make_Call_Statement
             ((Callee_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
               Name_Span   => Origin_Span,
               Filename    => Source.Absent_Filename,
               Arguments   => Ast.Empty_Expression_Sequence));

         if At_End (The_Cursor) then
            return
              Parse_Call_Statement
                (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Statement => The_Statement);
         end if;

         declare
            Current : constant Tokens.Token := Peek (The_Cursor);
         begin
            if Is_Keyword (Current, Tokens.Using_Keyword)
              or else Is_Keyword (Current, Tokens.Declare_Keyword)
              or else Is_Keyword (Current, Tokens.Begin_Keyword)
            then
               Step :=
                 Parse_Block
                   (The_Cursor     => The_Cursor,
                    Source_Text    => Source_Text,
                    Unit_Name      => Unit_Name,
                    Procedure_Name => Procedure_Name,
                    Subroutines    => Subroutines,
                    Scope          => Scope,
                    The_Body       => Nested);
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
                     The_Statement := Ast.Make_Nested_Block_Statement (Nested);
                     return (Ok => True);
               end case;
            end if;

            if Current.Kind = Tokens.Identifier
              and then Has_Token_At (The_Cursor, 1)
              and then Is_Punctuation (Peek_At (The_Cursor, 1), Tokens.Colon_Equals)
            then
               return
                 Parse_Assignment_Statement
                   (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Statement => The_Statement);
            end if;
         end;

         return
           Parse_Call_Statement (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Statement => The_Statement);
      end Parse_Statement;

   begin
      The_Body := Ast.Empty_Block;
      Scope_Push (Scope);

      --  block = { using } , [ "declare" , variable_declaration , { variable_declaration } ] , "begin" , ...
      while not At_End (The_Cursor) and then Is_Keyword (Peek (The_Cursor), Tokens.Using_Keyword) loop
         Step := Parse_Block_Using;
         case Step.Ok is
            when False =>
               Scope_Pop (Scope);
               return Step;

            when True  =>
               null;
         end case;
      end loop;

      if not At_End (The_Cursor) and then Is_Keyword (Peek (The_Cursor), Tokens.Declare_Keyword) then
         Advance (The_Cursor);

         if At_End (The_Cursor) then
            Scope_Pop (Scope);
            return
              Step_End_Of_Input (The_Cursor, "expected variable declaration after ""declare"", found end of input");
         end if;

         if Is_Keyword (Peek (The_Cursor), Tokens.Begin_Keyword) then
            Scope_Pop (Scope);
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Peek (The_Cursor).Span,
                 Filename => Peek (The_Cursor).Filename,
                 Detail   => "declare requires at least one variable declaration");
         end if;

         loop
            Step := Parse_Variable_Declaration;
            case Step.Ok is
               when False =>
                  Scope_Pop (Scope);
                  return Step;

               when True  =>
                  null;
            end case;
            exit when At_End (The_Cursor) or else Is_Keyword (Peek (The_Cursor), Tokens.Begin_Keyword);
         end loop;
      end if;

      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Begin_Keyword, Label => "begin");
      case Step.Ok is
         when False =>
            Scope_Pop (Scope);
            return Step;

         when True  =>
            null;
      end case;

      while not At_End (The_Cursor) and then not Is_Keyword (Peek (The_Cursor), Tokens.End_Keyword) loop
         declare
            The_Statement : Ast.Statement;
         begin
            Step := Parse_Statement (The_Statement);
            case Step.Ok is
               when False =>
                  Scope_Pop (Scope);
                  return Step;

               when True  =>
                  Ast.Append (Sequence => Statements, The_Statement => The_Statement);
            end case;
         end;
      end loop;

      Step :=
        Expect_Keyword
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.End_Keyword, Label => "end");
      Scope_Pop (Scope);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            The_Body := Ast.Create_Block (Usings => Usings, Locals => Locals, Statements => Statements);
            return (Ok => True);
      end case;
   end Parse_Block;

   pragma Style_Checks (On);

   function Parse_Call_Statement
     (The_Cursor : in out Cursor; Source_Text : String; The_Statement : out Ast.Statement) return Step_Result
   is
      Callee_Name : Ada.Strings.Unbounded.Unbounded_String;
      Name_Span   : Source.Source_Span := Origin_Span;
      Filename    : Source.Filename_Option := Source.Absent_Filename;
      Arguments   : Ast.Expression_Sequence;
      Step        : Step_Result;
   begin
      The_Statement :=
        Ast.Make_Call_Statement
          ((Callee_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
            Name_Span   => Origin_Span,
            Filename    => Source.Absent_Filename,
            Arguments   => Ast.Empty_Expression_Sequence));

      --  call_statement = callee_name , "(" , [ argument_list ] , ")" , ";"
      --  callee_name requires at least one '.' (MODULE.SUBROUTINE).
      Step :=
        Parse_Qualified_Identifier
          (The_Cursor  => The_Cursor,
           Source_Text => Source_Text,
           Module_Name => Callee_Name,
           Name_Span   => Name_Span,
           Filename    => Filename);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Callee_Name), ".") = 0 then
         return
           Make_Failure
             (Code     => Unexpected_Token,
              Span     => Name_Span,
              Filename => Filename,
              Detail   =>
                "call target must be MODULE.SUBROUTINE (dotted name), found """
                & Ada.Strings.Unbounded.To_String (Callee_Name)
                & """");
      end if;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Left_Parenthesis, Label => "(");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step := Parse_Argument_List (The_Cursor => The_Cursor, Source_Text => Source_Text, Arguments => Arguments);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

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
            The_Statement :=
              Ast.Make_Call_Statement
                ((Callee_Name => Callee_Name, Name_Span => Name_Span, Filename => Filename, Arguments => Arguments));
            return (Ok => True);
      end case;
   end Parse_Call_Statement;

   function Parse_Compilation_Unit
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : out Unit_Parse) return Step_Result
   is
      Usings : Ast.Using_Sequence;
      Step   : Step_Result;
   begin
      The_Unit :=
        (Module_Name  => Ada.Strings.Unbounded.Null_Unbounded_String,
         Name_Span    => Origin_Span,
         Filename     => Source.Absent_Filename,
         Kind         => Ast.Program_Unit,
         Stop_Span    => Origin_Span,
         Usings       => Ast.Empty_Using_Sequence,
         Subroutines  => Ast.Empty_Subroutine_Sequence,
         Program_Body => Ast.Empty_Block);

      Step := Parse_Using_List (The_Cursor => The_Cursor, Source_Text => Source_Text, Usings => Usings);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

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
            when Tokens.Program_Keyword =>
               Step :=
                 Parse_Program_Unit
                   (The_Cursor => The_Cursor, Source_Text => Source_Text, Unit_Usings => Usings, The_Unit => The_Unit);

            when Tokens.Module_Keyword  =>
               Step :=
                 Parse_Module_Unit
                   (The_Cursor => The_Cursor, Source_Text => Source_Text, Unit_Usings => Usings, The_Unit => The_Unit);

            when Tokens.Begin_Keyword
               | Tokens.End_Keyword
               | Tokens.Export_Keyword
               | Tokens.Procedure_Keyword
               | Tokens.Integer_Keyword
               | Tokens.Float_Keyword
               | Tokens.Signed_Keyword
               | Tokens.Unsigned_Keyword
               | Tokens.Boolean_Keyword
               | Tokens.True_Keyword
               | Tokens.False_Keyword
               | Tokens.Declare_Keyword
               | Tokens.Using_Keyword   =>
               return
                 Make_Failure
                   (Code     => Unexpected_Token,
                    Span     => Current.Span,
                    Filename => Current.Filename,
                    Detail   =>
                      "expected keyword ""program"" or ""module"", found " & Describe_Token (Source_Text, Current));
         end case;
      end;

      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            return Reject_Self_Usings (The_Unit);
      end case;
   end Parse_Compilation_Unit;

   function Parse_Flavor_Condition
     (The_Cursor : in out Cursor; Source_Text : String; Condition_Flavor : out Flavor.Flavor) return Step_Result
   is
      Flavor_Token : Tokens.Token := Dummy_Identifier;
      String_Token : Tokens.Token :=
        (Kind => Tokens.String_Literal, Span => Origin_Span, Filename => Source.Absent_Filename);
      Step         : Step_Result;
      Content      : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Condition_Flavor := Flavor.Wasi;

      --  flavor_condition = "flavor" , "=" , string_literal
      Step := Expect_Identifier (The_Cursor => The_Cursor, Source_Text => Source_Text, The_Token => Flavor_Token);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if Tokens.Lexeme (Source_Text, Flavor_Token) /= "flavor" then
         return
           Make_Failure
             (Code     => Unexpected_Token,
              Span     => Flavor_Token.Span,
              Filename => Flavor_Token.Filename,
              Detail   => "expected identifier ""flavor"", found " & Describe_Token (Source_Text, Flavor_Token));
      end if;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Equals, Label => "=");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      if At_End (The_Cursor) then
         return Step_End_Of_Input (The_Cursor, "expected string literal, found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin
         if Current.Kind /= Tokens.String_Literal then
            return
              Make_Failure
                (Code     => Unexpected_Token,
                 Span     => Current.Span,
                 Filename => Current.Filename,
                 Detail   => "expected string literal, found " & Describe_Token (Source_Text, Current));
         end if;

         String_Token := Current;
         Advance (The_Cursor);
      end;

      Content := Ada.Strings.Unbounded.To_Unbounded_String (String_Literal_Content (Source_Text, String_Token));
      if not Flavor.Try_Parse_Name (Ada.Strings.Unbounded.To_String (Content), Condition_Flavor) then
         return
           Make_Failure
             (Code     => Invalid_Flavor_Condition,
              Span     => String_Token.Span,
              Filename => String_Token.Filename,
              Detail   =>
                "invalid flavor """
                & Ada.Strings.Unbounded.To_String (Content)
                & """; expected ""wasi"", ""native"", or ""web""");
      end if;

      return (Ok => True);
   end Parse_Flavor_Condition;

   function Parse_Flavor_Conditional
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse; Keep_Declarations : Boolean)
      return Step_Result
   is
      Step             : Step_Result;
      Condition_Flavor : Flavor.Flavor;
      Matched          : Boolean := False;
      Arm_Keep         : Boolean;
   begin
      --  flavor_conditional = "#if" , flavor_condition , { module_declaration } ,
      --    { "#elsif" , flavor_condition , { module_declaration } } ,
      --    [ "#else" , { module_declaration } ] , "#end"
      Step :=
        Expect_Directive
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.If_Directive, Label => "#if");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Step :=
        Parse_Flavor_Condition
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Condition_Flavor => Condition_Flavor);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Arm_Keep := Keep_Declarations and then Condition_Flavor = The_Cursor.Active_Flavor;
      if Arm_Keep then
         Matched := True;
      end if;

      Step :=
        Parse_Module_Declaration_List
          (The_Cursor        => The_Cursor,
           Source_Text       => Source_Text,
           The_Unit          => The_Unit,
           Keep_Declarations => Arm_Keep,
           Stop_At_Arm_End   => True);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      while not At_End (The_Cursor) and then Is_Directive (Peek (The_Cursor), Tokens.Elsif_Directive) loop
         Advance (The_Cursor);

         Step :=
           Parse_Flavor_Condition
             (The_Cursor => The_Cursor, Source_Text => Source_Text, Condition_Flavor => Condition_Flavor);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;

         Arm_Keep := Keep_Declarations and then not Matched and then Condition_Flavor = The_Cursor.Active_Flavor;
         if Arm_Keep then
            Matched := True;
         end if;

         Step :=
           Parse_Module_Declaration_List
             (The_Cursor        => The_Cursor,
              Source_Text       => Source_Text,
              The_Unit          => The_Unit,
              Keep_Declarations => Arm_Keep,
              Stop_At_Arm_End   => True);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end loop;

      if not At_End (The_Cursor) and then Is_Directive (Peek (The_Cursor), Tokens.Else_Directive) then
         Advance (The_Cursor);

         Arm_Keep := Keep_Declarations and then not Matched;

         Step :=
           Parse_Module_Declaration_List
             (The_Cursor        => The_Cursor,
              Source_Text       => Source_Text,
              The_Unit          => The_Unit,
              Keep_Declarations => Arm_Keep,
              Stop_At_Arm_End   => True);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end if;

      return
        Expect_Directive
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.End_Directive, Label => "#end");
   end Parse_Flavor_Conditional;

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

   function Parse_Module_Declaration
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse; Keep_Declarations : Boolean)
      return Step_Result is
   begin
      if At_End (The_Cursor) then
         return
           Step_End_Of_Input
             (The_Cursor,
              "expected ""export"", ""@intrinsic"", ""@native"", procedure, or ""#if"", found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
      begin

         if Is_Directive (Current, Tokens.If_Directive) then
            return
              Parse_Flavor_Conditional
                (The_Cursor        => The_Cursor,
                 Source_Text       => Source_Text,
                 The_Unit          => The_Unit,
                 Keep_Declarations => Keep_Declarations);
         end if;

         if Is_Keyword (Current, Tokens.Export_Keyword)
           or else Is_Keyword (Current, Tokens.Procedure_Keyword)
           or else Is_Identifier_Lexeme (Source_Text, Current, "@intrinsic")
           or else Is_Identifier_Lexeme (Source_Text, Current, "@native")
         then
            return
              Parse_Procedure_Declaration
                (The_Cursor        => The_Cursor,
                 Source_Text       => Source_Text,
                 The_Unit          => The_Unit,
                 Keep_Declarations => Keep_Declarations);
         end if;

         return
           Make_Failure
             (Code     => Unexpected_Token,
              Span     => Current.Span,
              Filename => Current.Filename,
              Detail   =>
                "expected ""export"", ""@intrinsic"", ""@native"", procedure, or ""#if"", found "
                & Describe_Token (Source_Text, Current));
      end;
   end Parse_Module_Declaration;

   function Parse_Module_Declaration_List
     (The_Cursor        : in out Cursor;
      Source_Text       : String;
      The_Unit          : in out Unit_Parse;
      Keep_Declarations : Boolean;
      Stop_At_Arm_End   : Boolean) return Step_Result
   is
      Step : Step_Result;
   begin
      loop
         if At_End (The_Cursor) then
            return (Ok => True);
         end if;

         declare
            Current : constant Tokens.Token := Peek (The_Cursor);
         begin
            if Stop_At_Arm_End
              and then (Is_Directive (Current, Tokens.Elsif_Directive)
                        or else Is_Directive (Current, Tokens.Else_Directive)
                        or else Is_Directive (Current, Tokens.End_Directive))
            then
               return (Ok => True);
            end if;

            if not Stop_At_Arm_End and then Is_Keyword (Current, Tokens.End_Keyword) then
               return (Ok => True);
            end if;
         end;

         Step :=
           Parse_Module_Declaration
             (The_Cursor        => The_Cursor,
              Source_Text       => Source_Text,
              The_Unit          => The_Unit,
              Keep_Declarations => Keep_Declarations);
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end loop;
   end Parse_Module_Declaration_List;

   function Parse_Module_Unit
     (The_Cursor : in out Cursor; Source_Text : String; Unit_Usings : Ast.Using_Sequence; The_Unit : out Unit_Parse)
      return Step_Result
   is
      Step : Step_Result;
   begin
      The_Unit :=
        (Module_Name  => Ada.Strings.Unbounded.Null_Unbounded_String,
         Name_Span    => Origin_Span,
         Filename     => Source.Absent_Filename,
         Kind         => Ast.Module_Unit,
         Stop_Span    => Origin_Span,
         Usings       => Unit_Usings,
         Subroutines  => Ast.Empty_Subroutine_Sequence,
         Program_Body => Ast.Empty_Block);

      --  module_unit = "module" , qualified_identifier , ";" , { module_declaration } , "end" , "."
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

      Step :=
        Parse_Module_Declaration_List
          (The_Cursor        => The_Cursor,
           Source_Text       => Source_Text,
           The_Unit          => The_Unit,
           Keep_Declarations => True,
           Stop_At_Arm_End   => False);
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

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
     (The_Cursor : in out Cursor; Source_Text : String; The_Unit : in out Unit_Parse; Keep_Declarations : Boolean)
      return Step_Result
   is
      Name_Token      : Tokens.Token := Dummy_Identifier;
      Procedure_Name  : Ada.Strings.Unbounded.Unbounded_String;
      Module_Name     : constant String := Ada.Strings.Unbounded.To_String (The_Unit.Module_Name);
      Parameters      : Ast.Parameter_Sequence := Ast.Empty_Parameter_Sequence;
      Flags           : Ast.Subroutine_Flags := 0;
      Is_Intrinsic    : Boolean := False;
      Is_Native       : Boolean := False;
      Native_Library  : Ada.Strings.Unbounded.Unbounded_String;
      Native_Function : Ada.Strings.Unbounded.Unbounded_String;
      Step            : Step_Result;
      The_Subroutine  : Ast.Subroutine;
      Decl_First      : Source.Source_Position := Origin_Span.First;
      Decl_Span       : Source.Source_Span := Origin_Span;
      Library_Token   : Tokens.Token :=
        (Kind => Tokens.String_Literal, Span => Origin_Span, Filename => Source.Absent_Filename);
      Function_Token  : Tokens.Token :=
        (Kind => Tokens.String_Literal, Span => Origin_Span, Filename => Source.Absent_Filename);
   begin
      --  ordinary:   [ export ] procedure … ; begin … end ;
      --  intrinsic:  [ export ] @intrinsic procedure … ;
      --  native FFI: [ export ] @native ( string , string ) procedure … ;
      if not At_End (The_Cursor) then
         Decl_First := Peek (The_Cursor).Span.First;
      end if;

      if not At_End (The_Cursor) and then Is_Keyword (Peek (The_Cursor), Tokens.Export_Keyword) then
         Step :=
           Expect_Keyword
             (The_Cursor  => The_Cursor,
              Source_Text => Source_Text,
              Expected    => Tokens.Export_Keyword,
              Label       => "export");
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               Flags := Ast.Export_Flag;
         end case;
      end if;

      if not At_End (The_Cursor) and then Is_Identifier_Lexeme (Source_Text, Peek (The_Cursor), "@intrinsic") then
         Advance (The_Cursor);
         Is_Intrinsic := True;
         Flags := Flags or Ast.Intrinsic_Flag;
      elsif not At_End (The_Cursor) and then Is_Identifier_Lexeme (Source_Text, Peek (The_Cursor), "@native") then
         Advance (The_Cursor);
         Is_Native := True;
         Flags := Flags or Ast.Native_Flag;

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
            return Step_End_Of_Input (The_Cursor, "expected string literal, found end of input");
         end if;

         declare
            Current : constant Tokens.Token := Peek (The_Cursor);
         begin
            if Current.Kind /= Tokens.String_Literal then
               return
                 Make_Failure
                   (Code     => Unexpected_Token,
                    Span     => Current.Span,
                    Filename => Current.Filename,
                    Detail   => "expected string literal, found " & Describe_Token (Source_Text, Current));
            end if;
         end;

         Library_Token := Peek (The_Cursor);
         Advance (The_Cursor);
         Native_Library :=
           Ada.Strings.Unbounded.To_Unbounded_String (String_Literal_Content (Source_Text, Library_Token));

         Step :=
           Expect_Punctuation
             (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Comma, Label => ",");
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;

         if At_End (The_Cursor) then
            return Step_End_Of_Input (The_Cursor, "expected string literal, found end of input");
         end if;

         declare
            Current : constant Tokens.Token := Peek (The_Cursor);
         begin
            if Current.Kind /= Tokens.String_Literal then
               return
                 Make_Failure
                   (Code     => Unexpected_Token,
                    Span     => Current.Span,
                    Filename => Current.Filename,
                    Detail   => "expected string literal, found " & Describe_Token (Source_Text, Current));
            end if;
         end;

         Function_Token := Peek (The_Cursor);
         Advance (The_Cursor);
         Native_Function :=
           Ada.Strings.Unbounded.To_Unbounded_String (String_Literal_Content (Source_Text, Function_Token));

         Step :=
           Expect_Punctuation
             (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Right_Parenthesis, Label => ")");
         case Step.Ok is
            when False =>
               return Step;

            when True  =>
               null;
         end case;
      end if;

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
         if Keep_Declarations and then Name = Module_Name then
            return
              Make_Failure
                (Code     => Name_Clash,
                 Span     => Name_Token.Span,
                 Filename => Name_Token.Filename,
                 Detail   => "procedure name """ & Name & """ conflicts with the module name");
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
         if Keep_Declarations then
            Step :=
              Parse_Parameter_List
                (The_Cursor     => The_Cursor,
                 Source_Text    => Source_Text,
                 Module_Name    => Module_Name,
                 Procedure_Name => Ada.Strings.Unbounded.To_String (Procedure_Name),
                 Subroutines    => The_Unit.Subroutines,
                 Parameters     => Parameters);
         else
            Step :=
              Parse_Parameter_List
                (The_Cursor     => The_Cursor,
                 Source_Text    => Source_Text,
                 Module_Name    => "",
                 Procedure_Name => Ada.Strings.Unbounded.To_String (Procedure_Name),
                 Subroutines    => Ast.Empty_Subroutine_Sequence,
                 Parameters     => Parameters);
         end if;
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

      if Keep_Declarations then
         declare
            Name : constant String := Ada.Strings.Unbounded.To_String (Procedure_Name);
         begin
            if Subroutine_Signature_Exists (The_Unit.Subroutines, Name, Parameters) then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => Name_Token.Span,
                    Filename => Name_Token.Filename,
                    Detail   =>
                      "procedure """ & Name & """ with this parameter type sequence is duplicated in this module");
            end if;
         end;
      end if;

      Step :=
        Expect_Punctuation
          (The_Cursor => The_Cursor, Source_Text => Source_Text, Expected => Tokens.Semicolon, Label => ";");
      case Step.Ok is
         when False =>
            return Step;

         when True  =>
            null;
      end case;

      Decl_Span :=
        (First => Decl_First, Last => The_Cursor.Last_Consumed_Span.Last);

      if Is_Intrinsic or else Is_Native then
         if Keep_Declarations then
            if Is_Native then
               The_Subroutine :=
                 Ast.Create_Subroutine
                   (Name        => Ada.Strings.Unbounded.To_String (Procedure_Name),
                    Module_Name => Module_Name,
                    Name_Span   => Name_Token.Span,
                    Filename    => Name_Token.Filename,
                    Span        => Decl_Span,
                    Flags       => Flags,
                    Return_Type => Types.Unit_Type,
                    Parameters  => Parameters,
                    The_Body    => Ast.Empty_Block,
                    Native      =>
                      (Present => True, Value => (Library => Native_Library, Function_Name => Native_Function)));
            else
               The_Subroutine :=
                 Ast.Create_Subroutine
                   (Name        => Ada.Strings.Unbounded.To_String (Procedure_Name),
                    Module_Name => Module_Name,
                    Name_Span   => Name_Token.Span,
                    Filename    => Name_Token.Filename,
                    Span        => Decl_Span,
                    Flags       => Flags,
                    Return_Type => Types.Unit_Type,
                    Parameters  => Parameters,
                    The_Body    => Ast.Empty_Block,
                    Native      => (Present => False));
            end if;
            Ast.Append (Sequence => The_Unit.Subroutines, The_Subroutine => The_Subroutine);
         end if;
         return (Ok => True);
      end if;

      declare
         The_Body : Ast.Block;
         Scope    : Scope_Stack;
      begin
         Scope_Push (Scope);
         Bind_Unit_Usings (Scope, The_Unit.Usings);
         for Param_Index in 1 .. Ast.Length (Parameters) loop
            Scope_Bind (Scope, Ada.Strings.Unbounded.To_String (Ast.Element (Parameters, Param_Index).Parameter_Name));
         end loop;

         Step :=
           Parse_Block
             (The_Cursor     => The_Cursor,
              Source_Text    => Source_Text,
              Unit_Name      => Module_Name,
              Procedure_Name => Ada.Strings.Unbounded.To_String (Procedure_Name),
              Subroutines    => The_Unit.Subroutines,
              Scope          => Scope,
              The_Body       => The_Body);
         Scope_Pop (Scope);
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

         if Keep_Declarations then
            Decl_Span :=
              (First => Decl_First, Last => The_Cursor.Last_Consumed_Span.Last);
            The_Subroutine :=
              Ast.Create_Subroutine
                (Name        => Ada.Strings.Unbounded.To_String (Procedure_Name),
                 Module_Name => Module_Name,
                 Name_Span   => Name_Token.Span,
                 Filename    => Name_Token.Filename,
                 Span        => Decl_Span,
                 Flags       => Flags,
                 Return_Type => Types.Unit_Type,
                 Parameters  => Parameters,
                 The_Body    => The_Body,
                 Native      => (Present => False));
            Ast.Append (Sequence => The_Unit.Subroutines, The_Subroutine => The_Subroutine);
         end if;
         return (Ok => True);
      end;
   end Parse_Procedure_Declaration;

   function Parse_Program_Unit
     (The_Cursor : in out Cursor; Source_Text : String; Unit_Usings : Ast.Using_Sequence; The_Unit : out Unit_Parse)
      return Step_Result
   is
      Name_Token : Tokens.Token := Dummy_Identifier;
      Step       : Step_Result;
   begin
      The_Unit :=
        (Module_Name  => Ada.Strings.Unbounded.Null_Unbounded_String,
         Name_Span    => Origin_Span,
         Filename     => Source.Absent_Filename,
         Kind         => Ast.Program_Unit,
         Stop_Span    => Origin_Span,
         Usings       => Unit_Usings,
         Subroutines  => Ast.Empty_Subroutine_Sequence,
         Program_Body => Ast.Empty_Block);

      --  program_unit = "program" , identifier , ";" , block , "."
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

      declare
         Scope : Scope_Stack;
      begin
         Bind_Unit_Usings (Scope, Unit_Usings);
         Step :=
           Parse_Block
             (The_Cursor     => The_Cursor,
              Source_Text    => Source_Text,
              Unit_Name      => Ada.Strings.Unbounded.To_String (The_Unit.Module_Name),
              Procedure_Name => "",
              Subroutines    => Ast.Empty_Subroutine_Sequence,
              Scope          => Scope,
              The_Body       => The_Unit.Program_Body);
      end;
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
         return
           Step_End_Of_Input
             (The_Cursor, "expected type name (""integer"", ""float"", or ""boolean""), found end of input");
      end if;

      declare
         Current : constant Tokens.Token := Peek (The_Cursor);
         Step    : Step_Result;
      begin
         if Is_Keyword (Current, Tokens.Boolean_Keyword) then
            Step :=
              Expect_Keyword
                (The_Cursor  => The_Cursor,
                 Source_Text => Source_Text,
                 Expected    => Tokens.Boolean_Keyword,
                 Label       => "boolean");
            case Step.Ok is
               when False =>
                  return Step;

               when True  =>
                  The_Type := Types.Boolean_Type;
                  return (Ok => True);
            end case;
         end if;

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
                "expected type name (""integer"", ""float"", or ""boolean""), found "
                & Describe_Token (Source_Text, Current));
      end;
   end Parse_Type_Name;

   function Peek (The_Cursor : Cursor) return Tokens.Token is
   begin
      return Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index);
   end Peek;

   function Peek_At (The_Cursor : Cursor; Offset : Natural) return Tokens.Token is
   begin
      return Tokens.Element (The_Cursor.Token_List, The_Cursor.Next_Index + Offset);
   end Peek_At;

   function Reject_Self_Usings (The_Unit : Unit_Parse) return Step_Result is
      Unit_Name : constant String := Ada.Strings.Unbounded.To_String (The_Unit.Module_Name);
   begin
      for Index in 1 .. Ast.Length (The_Unit.Usings) loop
         declare
            The_Using  : constant Ast.Using_Declaration := Ast.Element (The_Unit.Usings, Index);
            Using_Name : constant String := Ada.Strings.Unbounded.To_String (The_Using.Module_Name);
         begin
            if Using_Name = Unit_Name then
               return
                 Make_Failure
                   (Code     => Name_Clash,
                    Span     => The_Using.Name_Span,
                    Filename => The_Using.Filename,
                    Detail   => "module cannot use itself """ & Using_Name & '"');
            end if;
         end;
      end loop;

      return (Ok => True);
   end Reject_Self_Usings;

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

   function String_Literal_Content (Source_Text : String; The_Token : Tokens.Token) return String is
      Lexeme : constant String := Tokens.Lexeme (Source_Text, The_Token);
   begin
      if Lexeme'Length >= 2 and then Lexeme (Lexeme'First) = '"' and then Lexeme (Lexeme'Last) = '"' then
         return Lexeme (Lexeme'First + 1 .. Lexeme'Last - 1);
      end if;

      return Lexeme;
   end String_Literal_Content;

   function Subroutine_Name_Exists (Subroutines : Ast.Subroutine_Sequence; Name : String) return Boolean is
   begin
      for Index in 1 .. Ast.Length (Subroutines) loop
         if Ast.Name (Ast.Element (Subroutines, Index)) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Subroutine_Name_Exists;

   function Subroutine_Signature_Exists
     (Subroutines : Ast.Subroutine_Sequence; Name : String; Parameters : Ast.Parameter_Sequence) return Boolean
   is
      use type Types.Type_Expression;
   begin
      for Index in 1 .. Ast.Length (Subroutines) loop
         declare
            Existing : constant Ast.Subroutine := Ast.Element (Subroutines, Index);
            Formals  : constant Ast.Parameter_Sequence := Ast.Parameters (Existing);
         begin
            if Ast.Name (Existing) = Name and then Ast.Length (Formals) = Ast.Length (Parameters) then
               declare
                  Same_Types : Boolean := True;
               begin
                  for Param_Index in 1 .. Ast.Length (Parameters) loop
                     if Ast.Element (Formals, Param_Index).Parameter_Type
                       /= Ast.Element (Parameters, Param_Index).Parameter_Type
                     then
                        Same_Types := False;
                        exit;
                     end if;
                  end loop;

                  if Same_Types then
                     return True;
                  end if;
               end;
            end if;
         end;
      end loop;

      return False;
   end Subroutine_Signature_Exists;

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
                    Span        => Unit_Span,
                    Flags       => Ast.Export_Flag or Ast.Entrypoint_Flag,
                    Return_Type => Types.Unit_Type,
                    Parameters  => Ast.Empty_Parameter_Sequence,
                    The_Body    => The_Unit.Program_Body,
                    Native      => (Present => False));
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
                    Usings      => The_Unit.Usings,
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
                    Usings      => The_Unit.Usings,
                    Subroutines => The_Unit.Subroutines));
      end case;
   end To_Parse_Result;

end Lovelace.Compiler.Parser;
