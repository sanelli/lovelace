with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Flavor;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokens;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Tests.Parser is

   use type Lovelace.Compiler.Ast.Expression_Kind;
   use type Lovelace.Compiler.Ast.Statement_Kind;
   use type Lovelace.Compiler.Ast.Unit_Kind;
   use type Lovelace.Compiler.Parser.Parser_Error_Code;
   use type Lovelace.Compiler.Types.Float_Size;
   use type Lovelace.Compiler.Types.Integer_Size;
   use type Lovelace.Compiler.Types.Signedness;
   use type Lovelace.Compiler.Types.Type_Kind;

   package Compiler_Parser renames Lovelace.Compiler.Parser;

   procedure Assert_Empty_Module (The_Module : Ast.Module; Expected_Name : String; Message : String);
   --  Assert Module_Unit with Expected_Name and zero subroutines.

   procedure Assert_Entrypoint_Module (The_Module : Ast.Module; Expected_Name : String; Message : String);
   --  Assert Program_Unit with one entrypoint+export subroutine named Expected_Name.

   procedure Assert_Parse_Detail
     (Source_Text     : String;
      Expected_Code   : Compiler_Parser.Parser_Error_Code;
      Expected_Detail : String;
      Message         : String);
   --  Assert Source_Text fails with exactly one error carrying Expected_Code and Expected_Detail.

   procedure Assert_Parse_Error
     (Source_Text   : String;
      Expected_Code : Compiler_Parser.Parser_Error_Code;
      Message       : String;
      Active_Flavor : Flavor.Flavor := Flavor.Default);
   --  Assert Source_Text fails with exactly one error carrying Expected_Code.

   procedure Assert_Empty_Module (The_Module : Ast.Module; Expected_Name : String; Message : String) is
   begin
      AUnit.Assertions.Assert (Ast.Kind (The_Module) = Ast.Module_Unit, Message & ": module unit");
      AUnit.Assertions.Assert (Ast.Name (The_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert (Ast.Using_Count (The_Module) = 0, Message & ": no usings");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 0, Message & ": no subroutines");
      AUnit.Assertions.Assert
        (Ast.Span (The_Module).Last.Byte_Index >= Ast.Span (The_Module).First.Byte_Index,
         Message & ": unit span bounds");
   end Assert_Empty_Module;

   procedure Assert_Entrypoint_Module (The_Module : Ast.Module; Expected_Name : String; Message : String) is
   begin
      AUnit.Assertions.Assert (Ast.Kind (The_Module) = Ast.Program_Unit, Message & ": program unit");
      AUnit.Assertions.Assert (Ast.Name (The_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert (Ast.Using_Count (The_Module) = 0, Message & ": no usings");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 1, Message & ": one subroutine");
      declare
         The_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, 1);
         Flags          : constant Ast.Subroutine_Flags := Ast.Get_Flags (The_Subroutine);
         Return_Type    : constant Types.Type_Expression := Ast.Return_Type (The_Subroutine);
      begin
         AUnit.Assertions.Assert (Ast.Name (The_Subroutine) = Expected_Name, Message & ": subroutine name");
         AUnit.Assertions.Assert
           (Ast.Full_Name (The_Subroutine) = Expected_Name & "." & Expected_Name, Message & ": full name");
         AUnit.Assertions.Assert (Return_Type.Kind = Types.Unit, Message & ": return Unit");
         AUnit.Assertions.Assert (Ast.Has_Export (Flags), Message & ": export");
         AUnit.Assertions.Assert (Ast.Has_Entrypoint (Flags), Message & ": entrypoint");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Statements (Ast.Get_Body (The_Subroutine))) = 0, Message & ": empty body");
         AUnit.Assertions.Assert
           (Ast.Span (The_Module).Last.Byte_Index >= Ast.Span (The_Module).First.Byte_Index,
            Message & ": unit span bounds");
      end;
   end Assert_Entrypoint_Module;

   procedure Assert_Parse_Detail
     (Source_Text     : String;
      Expected_Code   : Compiler_Parser.Parser_Error_Code;
      Expected_Detail : String;
      Message         : String)
   is
      Errors : constant Compiler_Parser.Parser_Error_Sequence := Support.Must_Fail_Parse (Source_Text, Message);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, Message);
      Support.Assert_Parser_Error_Code (Errors, 1, Expected_Code, Message & " code");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Compiler_Parser.Element (Errors, 1).Detail) = Expected_Detail,
         Message & ": detail");
   end Assert_Parse_Detail;

   procedure Assert_Parse_Error
     (Source_Text   : String;
      Expected_Code : Compiler_Parser.Parser_Error_Code;
      Message       : String;
      Active_Flavor : Flavor.Flavor := Flavor.Default)
   is
      Errors : constant Compiler_Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse (Source_Text, Message, Active_Flavor);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, Message);
      Support.Assert_Parser_Error_Code (Errors, 1, Expected_Code, Message & " code");
   end Assert_Parse_Error;

   procedure Test_Assignment_Statements (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text  : constant String :=
        "program P; declare X, Y : integer; F : boolean; begin X := 42; F := true; Y := X; Lib.Put(X, 7, false); end.";
      The_Module   : constant Ast.Module := Support.Must_Parse (Source_Text, "assignments");
      Missing_Rhs  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; declare X : integer; begin X := ; end.", "assignment missing rhs");
      Missing_Semi : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; declare X : integer; begin X := 1 end.", "assignment missing semicolon");
   begin
      declare
         Statements : constant Ast.Statement_Sequence :=
           Ast.Statements (Ast.Get_Body (Ast.Get_Subroutine (The_Module, 1)));
      begin
         AUnit.Assertions.Assert (Ast.Length (Statements) = 4, "assignments: statement count");
         AUnit.Assertions.Assert (Ast.Kind (Ast.Element (Statements, 1)) = Ast.Assignment, "assignments: first kind");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Assignment_Of (Ast.Element (Statements, 1)).Target_Name) = "X",
            "assignments: first target");
         AUnit.Assertions.Assert
           (Ast.Assignment_Of (Ast.Element (Statements, 1)).Value.Kind = Ast.Integer_Literal,
            "assignments: integer rhs");
         AUnit.Assertions.Assert
           (Ast.Assignment_Of (Ast.Element (Statements, 2)).Value.Kind = Ast.Boolean_Literal,
            "assignments: boolean rhs");
         AUnit.Assertions.Assert
           (Ast.Assignment_Of (Ast.Element (Statements, 3)).Value.Kind = Ast.Name_Reference, "assignments: name rhs");
         AUnit.Assertions.Assert (Ast.Kind (Ast.Element (Statements, 4)) = Ast.Call, "assignments: call kind");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Call_Of (Ast.Element (Statements, 4)).Arguments) = 3, "assignments: call args");
         AUnit.Assertions.Assert
           (Ast.Element (Ast.Call_Of (Ast.Element (Statements, 4)).Arguments, 1).Kind = Ast.Name_Reference,
            "assignments: name argument");
      end;

      Support.Assert_Parser_Error_Count (Missing_Rhs, 1, "assignment missing rhs");
      Support.Assert_Parser_Error_Code
        (Missing_Rhs, 1, Lovelace.Compiler.Parser.Unexpected_Token, "assignment missing rhs code");
      Support.Assert_Parser_Error_Count (Missing_Semi, 1, "assignment missing semicolon");
      Support.Assert_Parser_Error_Code
        (Missing_Semi, 1, Lovelace.Compiler.Parser.Unexpected_Token, "assignment missing semicolon code");
   end Test_Assignment_Statements;

   procedure Test_Bad_Type_Size (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Float_16 : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(x : float<16>); begin end; end.", "float 16");
      Int_128  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(x : integer<128>); begin end; end.", "integer 128");
   begin
      Support.Assert_Parser_Error_Count (Float_16, 1, "float 16");
      Support.Assert_Parser_Error_Code (Float_16, 1, Lovelace.Compiler.Parser.Unexpected_Token, "float 16 code");
      Support.Assert_Parser_Error_Count (Int_128, 1, "integer 128");
      Support.Assert_Parser_Error_Code (Int_128, 1, Lovelace.Compiler.Parser.Unexpected_Token, "integer 128 code");
   end Test_Bad_Type_Size;

   procedure Test_Block_Usings (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Nested_Source   : constant String :=
        "using A;"
        & ASCII.LF
        & "program P;"
        & ASCII.LF
        & "using B;"
        & ASCII.LF
        & "declare X : integer; begin"
        & ASCII.LF
        & "   using C; declare Y : integer; begin"
        & ASCII.LF
        & "      Y := 1;"
        & ASCII.LF
        & "   end;"
        & ASCII.LF
        & "end.";
      Sibling_Source  : constant String := "program P; begin using Lib; begin end; using Lib; begin end; end.";
      Proc_Source     : constant String :=
        "using A; module M; procedure Run(); using B; begin using C; begin end; end; end.";
      Nested_Module   : constant Ast.Module := Support.Must_Parse (Nested_Source, "nested using + declare");
      Sibling_Module  : constant Ast.Module := Support.Must_Parse (Sibling_Source, "sibling blocks");
      Proc_Module     : constant Ast.Module := Support.Must_Parse (Proc_Source, "procedure block usings");
      Nested_Visible  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("program P; using Lib; begin using Lib; begin end; end.", "nested using of visible module");
      Unit_Visible    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("using Lib; program P; using Lib; begin end.", "block using of unit using");
      Proc_Visible    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("using Lib; module M; procedure Run(); using Lib; begin end; end.", "procedure block using of unit using");
      Duplicate_Block : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; using Lib; using Lib; begin end.", "duplicate block using");
      Self_Block      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; using P; begin end.", "self block using");
      Local_Clash     : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; using Lib; declare Lib : integer; begin end.", "local named like using");
   begin
      declare
         Prog_Block : constant Ast.Block := Ast.Get_Body (Ast.Get_Subroutine (Nested_Module, 1));
         Inner      : constant Ast.Block := Ast.Block_Of (Ast.Element (Ast.Statements (Prog_Block), 1));
      begin
         AUnit.Assertions.Assert (Ast.Using_Count (Nested_Module) = 1, "nested: unit using count");
         AUnit.Assertions.Assert (Ast.Length (Ast.Usings (Prog_Block)) = 1, "nested: outer block using count");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Ast.Usings (Prog_Block), 1).Module_Name) = "B",
            "nested: outer block using name");
         AUnit.Assertions.Assert (Ast.Length (Ast.Locals (Prog_Block)) = 1, "nested: outer local");
         AUnit.Assertions.Assert (Ast.Length (Ast.Usings (Inner)) = 1, "nested: inner using count");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Ast.Usings (Inner), 1).Module_Name) = "C",
            "nested: inner using name");
         AUnit.Assertions.Assert (Ast.Length (Ast.Locals (Inner)) = 1, "nested: inner local");
         AUnit.Assertions.Assert (Ast.Length (Ast.Statements (Inner)) = 1, "nested: inner statement");
      end;

      declare
         Statements : constant Ast.Statement_Sequence :=
           Ast.Statements (Ast.Get_Body (Ast.Get_Subroutine (Sibling_Module, 1)));
      begin
         AUnit.Assertions.Assert (Ast.Length (Statements) = 2, "sibling: two nested blocks");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Usings (Ast.Block_Of (Ast.Element (Statements, 1)))) = 1, "sibling: first using");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Usings (Ast.Block_Of (Ast.Element (Statements, 2)))) = 1, "sibling: second using");
      end;

      AUnit.Assertions.Assert
        (Ast.Length (Ast.Usings (Ast.Get_Body (Ast.Get_Subroutine (Proc_Module, 1)))) = 1, "procedure block using");

      Support.Assert_Parser_Error_Count (Nested_Visible, 1, "nested using of visible module");
      Support.Assert_Parser_Error_Code
        (Nested_Visible, 1, Lovelace.Compiler.Parser.Name_Clash, "nested using of visible module code");
      Support.Assert_Parser_Error_Count (Unit_Visible, 1, "block using of unit using");
      Support.Assert_Parser_Error_Code
        (Unit_Visible, 1, Lovelace.Compiler.Parser.Name_Clash, "block using of unit using code");
      Support.Assert_Parser_Error_Count (Proc_Visible, 1, "procedure block using of unit using");
      Support.Assert_Parser_Error_Code
        (Proc_Visible, 1, Lovelace.Compiler.Parser.Name_Clash, "procedure block using of unit using code");
      Support.Assert_Parser_Error_Count (Duplicate_Block, 1, "duplicate block using");
      Support.Assert_Parser_Error_Code
        (Duplicate_Block, 1, Lovelace.Compiler.Parser.Name_Clash, "duplicate block using code");
      Support.Assert_Parser_Error_Count (Self_Block, 1, "self block using");
      Support.Assert_Parser_Error_Code (Self_Block, 1, Lovelace.Compiler.Parser.Name_Clash, "self block using code");
      Support.Assert_Parser_Error_Count (Local_Clash, 1, "local named like using");
      Support.Assert_Parser_Error_Code
        (Local_Clash, 1, Lovelace.Compiler.Parser.Name_Clash, "local named like using code");
   end Test_Block_Usings;

   procedure Test_Boolean_Type (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module Bools;"
        & ASCII.LF
        & "procedure Sink(Flag : boolean); begin end;"
        & ASCII.LF
        & "procedure Run();"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "   Bools.Sink(true);"
        & ASCII.LF
        & "   Bools.Sink(false);"
        & ASCII.LF
        & "end;"
        & ASCII.LF
        & "end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "boolean type");
      Signed_Bool : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(x : signed boolean); begin end; end.", "signed boolean");
      Sized_Bool  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(x : boolean<32>); begin end; end.", "boolean size");
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 2, "two procedures");
      declare
         Sink_Params : constant Ast.Parameter_Sequence := Ast.Parameters (Ast.Get_Subroutine (The_Module, 1));
         Run_Body    : constant Ast.Statement_Sequence :=
           Ast.Statements (Ast.Get_Body (Ast.Get_Subroutine (The_Module, 2)));
      begin
         AUnit.Assertions.Assert (Ast.Length (Sink_Params) = 1, "one param");
         AUnit.Assertions.Assert
           (Ast.Element (Sink_Params, 1).Parameter_Type.Kind = Types.Boolean_Kind, "boolean param");
         AUnit.Assertions.Assert (Ast.Length (Run_Body) = 2, "two calls");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Ast.Call_Of (Ast.Element (Run_Body, 1)).Arguments, 1).Lexeme)
            = "true",
            "true lexeme");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Ast.Call_Of (Ast.Element (Run_Body, 2)).Arguments, 1).Lexeme)
            = "false",
            "false lexeme");
      end;

      Support.Assert_Parser_Error_Count (Signed_Bool, 1, "signed boolean");
      Support.Assert_Parser_Error_Code
        (Signed_Bool, 1, Lovelace.Compiler.Parser.Unexpected_Token, "signed boolean code");
      Support.Assert_Parser_Error_Count (Sized_Bool, 1, "boolean size");
      Support.Assert_Parser_Error_Code (Sized_Bool, 1, Lovelace.Compiler.Parser.Unexpected_Token, "boolean size code");
   end Test_Boolean_Type;

   procedure Test_Call_Syntax_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Empty_Call : constant Ast.Module :=
        Support.Must_Parse ("program P; begin Lib.Put(); end.", "empty argument list");
   begin
      declare
         Statements : constant Ast.Statement_Sequence :=
           Ast.Statements (Ast.Get_Body (Ast.Get_Subroutine (Empty_Call, 1)));
      begin
         AUnit.Assertions.Assert (Ast.Length (Statements) = 1, "empty argument list: one call");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Call_Of (Ast.Element (Statements, 1)).Arguments) = 0, "empty argument list: no args");
      end;

      Assert_Parse_Error
        ("program P; begin Lib.Put 5; end.", Compiler_Parser.Unexpected_Token, "call missing open parenthesis");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1 2); end.", Compiler_Parser.Unexpected_Token, "call missing close parenthesis");
      Assert_Parse_Error
        ("program P; begin Lib.Put(;); end.", Compiler_Parser.Unexpected_Token, "call bad first argument");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1, ;); end.", Compiler_Parser.Unexpected_Token, "call bad later argument");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1.5); end.", Compiler_Parser.Unexpected_Token, "call float argument in program");
      Assert_Parse_Error
        ("program P; begin Sink(1); end.", Compiler_Parser.Unexpected_Token, "call target without module");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1); Sink(); end.", Compiler_Parser.Unexpected_Token, "second call without module");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1) end.", Compiler_Parser.Unexpected_Token, "call missing semicolon in program");
      Assert_Parse_Error
        ("program P; begin Lib.", Compiler_Parser.Unexpected_End_Of_Input, "call segment missing at end");
      Assert_Parse_Error
        ("program P; begin Lib.Put", Compiler_Parser.Unexpected_End_Of_Input, "call open parenthesis at end");
      Assert_Parse_Error
        ("program P; begin Lib.Put(", Compiler_Parser.Unexpected_End_Of_Input, "call argument list at end");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1", Compiler_Parser.Unexpected_End_Of_Input, "call close parenthesis at end");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1,", Compiler_Parser.Unexpected_End_Of_Input, "call argument after comma at end");
      Assert_Parse_Error
        ("program P; begin Lib.Put(1)", Compiler_Parser.Unexpected_End_Of_Input, "call semicolon at end");
   end Test_Call_Syntax_Errors;

   procedure Test_Canonical_Module (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "module Empty;" & ASCII.LF & "end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "canonical module");
   begin
      Assert_Empty_Module (The_Module, "Empty", "canonical module");
   end Test_Canonical_Module;

   procedure Test_Canonical_Multiline (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program Hello;" & ASCII.LF & "begin" & ASCII.LF & "end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "canonical");
   begin
      Assert_Entrypoint_Module (The_Module, "Hello", "canonical");
   end Test_Canonical_Multiline;

   procedure Test_Comments (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Source : constant String :=
        "{ leading }"
        & ASCII.LF
        & "program Comments;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "{ empty body }"
        & ASCII.LF
        & "end.";
      Module_Source  : constant String :=
        "module Lib;"
        & ASCII.LF
        & "{ TEMPORARY note }"
        & ASCII.LF
        & "export @native(""wasi"", ""native-print-integer"") procedure print(value : integer);"
        & ASCII.LF
        & "end.";
      Glued_Source   : constant String := "program{c}Hello;begin{}end.";
      The_Program    : constant Ast.Module := Support.Must_Parse (Program_Source, "program comments");
      The_Module     : constant Ast.Module := Support.Must_Parse (Module_Source, "module comments");
      Glued_Program  : constant Ast.Module := Support.Must_Parse (Glued_Source, "glued comments");
      Native_Sub     : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, 1);
   begin
      Assert_Entrypoint_Module (The_Program, "Comments", "program comments");
      Assert_Entrypoint_Module (Glued_Program, "Hello", "glued comments");
      AUnit.Assertions.Assert (Ast.Kind (The_Module) = Ast.Module_Unit, "module comments: unit");
      AUnit.Assertions.Assert (Ast.Name (The_Module) = "Lib", "module comments: name");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 1, "module comments: one sub");
      AUnit.Assertions.Assert (Ast.Name (Native_Sub) = "print", "module comments: print");
      AUnit.Assertions.Assert (Ast.Has_Native (Ast.Get_Flags (Native_Sub)), "module comments: native");
   end Test_Comments;

   procedure Test_Declare_Locals (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Rocket         : constant String := Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#));
      Program_Source : constant String :=
        "program Demo;"
        & ASCII.LF
        & "declare"
        & ASCII.LF
        & "   X, Y : integer;"
        & ASCII.LF
        & "   Flag : boolean;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "   declare"
        & ASCII.LF
        & "      Inner : float<32>;"
        & ASCII.LF
        & "   begin"
        & ASCII.LF
        & "   end;"
        & ASCII.LF
        & "   begin"
        & ASCII.LF
        & "   end;"
        & ASCII.LF
        & "end.";
      Module_Source  : constant String :=
        "module Lib;"
        & ASCII.LF
        & "procedure Run(Value : integer);"
        & ASCII.LF
        & "declare"
        & ASCII.LF
        & "   Tmp : integer;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end;"
        & ASCII.LF
        & "end.";
      Emoji_Program  : constant String :=
        "program "
        & Rocket
        & ";"
        & ASCII.LF
        & "declare"
        & ASCII.LF
        & "   "
        & Rocket
        & "Var : integer;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end.";
      Emoji_Module   : constant String :=
        "module "
        & Rocket
        & ";"
        & ASCII.LF
        & "procedure "
        & Rocket
        & "Go();"
        & ASCII.LF
        & "declare"
        & ASCII.LF
        & "   "
        & Rocket
        & "X : boolean;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end;"
        & ASCII.LF
        & "end.";
      The_Program    : constant Ast.Module := Support.Must_Parse (Program_Source, "declare program");
      The_Module     : constant Ast.Module := Support.Must_Parse (Module_Source, "declare module");
      Emoji_Prog     : constant Ast.Module := Support.Must_Parse (Emoji_Program, "emoji program");
      Emoji_Mod      : constant Ast.Module := Support.Must_Parse (Emoji_Module, "emoji module");
      Empty_Decl     : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; declare begin end.", "empty declare");
      Shadow         : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("program P; declare X : integer; begin declare X : boolean; begin end; end.", "shadow");
      Unit_Clash     : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program Demo; declare Demo : integer; begin end.", "unit clash");
      Proc_Clash     : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure Run(); declare Run : integer; begin end; end.", "proc clash");
      Sibling_Ok     : constant Ast.Module :=
        Support.Must_Parse
          ("program P; begin declare X : integer; begin end; declare X : boolean; begin end; end.", "sibling locals");
   begin
      declare
         Prog_Block : constant Ast.Block := Ast.Get_Body (Ast.Get_Subroutine (The_Program, 1));
         Locals     : constant Ast.Local_Sequence := Ast.Locals (Prog_Block);
         Stmts      : constant Ast.Statement_Sequence := Ast.Statements (Prog_Block);
      begin
         AUnit.Assertions.Assert (Ast.Length (Locals) = 3, "program three locals");
         AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Ast.Element (Locals, 1).Parameter_Name) = "X", "X");
         AUnit.Assertions.Assert (Ada.Strings.Unbounded.To_String (Ast.Element (Locals, 2).Parameter_Name) = "Y", "Y");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Locals, 3).Parameter_Name) = "Flag", "Flag");
         AUnit.Assertions.Assert (Ast.Length (Stmts) = 2, "two nested statements");
         AUnit.Assertions.Assert (Ast.Kind (Ast.Element (Stmts, 1)) = Ast.Nested_Block, "nested declare");
         AUnit.Assertions.Assert (Ast.Length (Ast.Locals (Ast.Block_Of (Ast.Element (Stmts, 1)))) = 1, "inner local");
         AUnit.Assertions.Assert (Ast.Kind (Ast.Element (Stmts, 2)) = Ast.Nested_Block, "bare nested");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Locals (Ast.Block_Of (Ast.Element (Stmts, 2)))) = 0, "bare no locals");
      end;

      declare
         Mod_Block : constant Ast.Block := Ast.Get_Body (Ast.Get_Subroutine (The_Module, 1));
      begin
         AUnit.Assertions.Assert (Ast.Length (Ast.Locals (Mod_Block)) = 1, "module tmp local");
      end;

      AUnit.Assertions.Assert (Ast.Name (Emoji_Prog) = Rocket, "emoji program name");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String
           (Ast.Element (Ast.Locals (Ast.Get_Body (Ast.Get_Subroutine (Emoji_Prog, 1))), 1).Parameter_Name)
         = Rocket & "Var",
         "emoji local");
      AUnit.Assertions.Assert (Ast.Name (Emoji_Mod) = Rocket, "emoji module name");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (Emoji_Mod, 1)) = Rocket & "Go", "emoji procedure");

      Support.Assert_Parser_Error_Count (Empty_Decl, 1, "empty declare");
      Support.Assert_Parser_Error_Code (Empty_Decl, 1, Lovelace.Compiler.Parser.Unexpected_Token, "empty declare code");
      Support.Assert_Parser_Error_Count (Shadow, 1, "shadow");
      Support.Assert_Parser_Error_Code (Shadow, 1, Lovelace.Compiler.Parser.Name_Clash, "shadow code");
      Support.Assert_Parser_Error_Count (Unit_Clash, 1, "unit clash");
      Support.Assert_Parser_Error_Code (Unit_Clash, 1, Lovelace.Compiler.Parser.Name_Clash, "unit clash code");
      Support.Assert_Parser_Error_Count (Proc_Clash, 1, "proc clash");
      Support.Assert_Parser_Error_Code (Proc_Clash, 1, Lovelace.Compiler.Parser.Name_Clash, "proc clash code");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Sibling_Ok) = 1, "sibling ok");
   end Test_Declare_Locals;

   procedure Test_Declare_Syntax_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Assert_Parse_Error
        ("program P; declare", Compiler_Parser.Unexpected_End_Of_Input, "declare without declarations at end");
      Assert_Parse_Error
        ("program P; declare 5 : integer; begin end.", Compiler_Parser.Unexpected_Token, "declare bad first name");
      Assert_Parse_Error
        ("program P; declare X, 5 : integer; begin end.", Compiler_Parser.Unexpected_Token, "declare bad later name");
      Assert_Parse_Error
        ("program P; declare X", Compiler_Parser.Unexpected_End_Of_Input, "declare name then end of input");
      Assert_Parse_Error
        ("program P; declare X,", Compiler_Parser.Unexpected_End_Of_Input, "declare comma then end of input");
      Assert_Parse_Error
        ("program P; declare X integer; begin end.", Compiler_Parser.Unexpected_Token, "declare missing colon");
      Assert_Parse_Error
        ("program P; declare X :", Compiler_Parser.Unexpected_End_Of_Input, "declare colon then end of input");
      Assert_Parse_Error
        ("program P; declare X : ; begin end.", Compiler_Parser.Unexpected_Token, "declare missing type");
      Assert_Parse_Error
        ("program P; declare X : integer begin end.", Compiler_Parser.Unexpected_Token, "declare missing semicolon");
      Assert_Parse_Error
        ("program P; declare X : integer", Compiler_Parser.Unexpected_End_Of_Input, "declare semicolon at end");
      Assert_Parse_Error
        ("program P; declare X : integer; Y integer; begin end.",
         Compiler_Parser.Unexpected_Token,
         "declare second declaration missing colon");
      Assert_Parse_Error
        ("program P; begin begin end end.", Compiler_Parser.Unexpected_Token, "nested block missing semicolon");
      Assert_Parse_Error
        ("program P; begin begin end", Compiler_Parser.Unexpected_End_Of_Input, "nested block semicolon at end");
      Assert_Parse_Error ("program P; begin using", Compiler_Parser.Unexpected_End_Of_Input, "block using name at end");
      Assert_Parse_Error
        ("program P; begin using Lib begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "block using missing semicolon");
   end Test_Declare_Syntax_Errors;

   procedure Test_Describe_Literal_Tokens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Expected : constant String := "expected identifier, found ";
   begin
      Assert_Parse_Detail
        ("program 5; begin end.",
         Compiler_Parser.Unexpected_Token,
         Expected & "integer literal ""5""",
         "describe integer literal");
      Assert_Parse_Detail
        ("program 1.5; begin end.",
         Compiler_Parser.Unexpected_Token,
         Expected & "float literal ""1.5""",
         "describe float literal");
      Assert_Parse_Detail
        ("program ""x""; begin end.",
         Compiler_Parser.Unexpected_Token,
         Expected & "string literal """"x""""",
         "describe string literal");
   end Test_Describe_Literal_Tokens;

   procedure Test_Dotted_Module_Name (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "module Foo.Bar; end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "dotted module");
   begin
      Assert_Empty_Module (The_Module, "Foo.Bar", "dotted module");
      AUnit.Assertions.Assert (Ast.Name_Span (The_Module).First.Byte_Index = 8, "dotted module: name span first");
      AUnit.Assertions.Assert (Ast.Name_Span (The_Module).Last.Byte_Index = 14, "dotted module: name span last");
   end Test_Dotted_Module_Name;

   procedure Test_Duplicate_Parameter (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(x : integer; x : float); begin end; end.", "dup param");
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "dup param");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Name_Clash, "dup param code");
   end Test_Duplicate_Parameter;

   procedure Test_Empty_Tokens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Token_List : constant Tokens.Token_Sequence := Tokens.Empty_Sequence;
      Result     : constant Lovelace.Compiler.Parser.Parse_Result :=
        Lovelace.Compiler.Parser.Parse ("", Token_List, Lovelace.Compiler.Flavor.Default);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert (False, "empty tokens: expected failure");

         when False =>
            Support.Assert_Parser_Error_Count (Result.Errors, 1, "empty tokens");
            Support.Assert_Parser_Error_Code
              (Result.Errors, 1, Lovelace.Compiler.Parser.Unexpected_End_Of_Input, "empty tokens code");
      end case;
   end Test_Empty_Tokens;

   procedure Test_End_Semicolon (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program Hello; begin end;", "end semicolon");
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "end semicolon");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "end semicolon code");
   end Test_End_Semicolon;

   procedure Test_Export_Procedure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Nullary_Source : constant String := "module Lib; export procedure Helper(); begin end; end.";
      Params_Source  : constant String := "module Lib; export procedure Print(Value : integer); begin end; end.";
      Flavor_Source  : constant String :=
        "module Lib;"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "export procedure WasiPrint(Value : integer); begin end;"
        & ASCII.LF
        & "#elsif flavor = ""native"""
        & ASCII.LF
        & "procedure NativeOnly(); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      Lone_Export    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module Lib; export begin end; end.", "lone export");
      Nullary_Module : constant Ast.Module := Support.Must_Parse (Nullary_Source, "export nullary");
      Params_Module  : constant Ast.Module := Support.Must_Parse (Params_Source, "export params");
      Wasi_Module    : constant Ast.Module := Support.Must_Parse (Flavor_Source, "export flavor", Flavor.Wasi);
      Native_Module  : constant Ast.Module := Support.Must_Parse (Flavor_Source, "export flavor native", Flavor.Native);
      Nullary_Sub    : constant Ast.Subroutine := Ast.Get_Subroutine (Nullary_Module, 1);
      Params_Sub     : constant Ast.Subroutine := Ast.Get_Subroutine (Params_Module, 1);
      Wasi_Sub       : constant Ast.Subroutine := Ast.Get_Subroutine (Wasi_Module, 1);
      Native_Sub     : constant Ast.Subroutine := Ast.Get_Subroutine (Native_Module, 1);
   begin
      AUnit.Assertions.Assert (Ast.Has_Export (Ast.Get_Flags (Nullary_Sub)), "nullary export");
      AUnit.Assertions.Assert (not Ast.Has_Entrypoint (Ast.Get_Flags (Nullary_Sub)), "nullary not entry");
      AUnit.Assertions.Assert (Ast.Has_Export (Ast.Get_Flags (Params_Sub)), "params export");
      AUnit.Assertions.Assert (not Ast.Has_Entrypoint (Ast.Get_Flags (Params_Sub)), "params not entry");
      AUnit.Assertions.Assert (Ast.Length (Ast.Parameters (Params_Sub)) = 1, "one param");
      AUnit.Assertions.Assert (Ast.Has_Export (Ast.Get_Flags (Wasi_Sub)), "wasi export survives");
      AUnit.Assertions.Assert (Ast.Name (Wasi_Sub) = "WasiPrint", "wasi name");
      AUnit.Assertions.Assert (not Ast.Has_Export (Ast.Get_Flags (Native_Sub)), "native not export");
      AUnit.Assertions.Assert (Ast.Name (Native_Sub) = "NativeOnly", "native name");
      Support.Assert_Parser_Error_Count (Lone_Export, 1, "lone export");
      Support.Assert_Parser_Error_Code (Lone_Export, 1, Lovelace.Compiler.Parser.Unexpected_Token, "lone export code");
   end Test_Export_Procedure;

   procedure Test_Flavor_Active_Clash (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module M;"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "procedure Dup(); begin end;"
        & ASCII.LF
        & "procedure Dup(); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      Errors      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse (Source_Text, "active clash", Flavor.Wasi);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "active clash");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Name_Clash, "active clash code");
   end Test_Flavor_Active_Clash;

   procedure Test_Flavor_Exclusive_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module M;"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "procedure Same(); begin end;"
        & ASCII.LF
        & "#else"
        & ASCII.LF
        & "procedure Same(); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "exclusive names", Flavor.Wasi);
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 1, "exclusive names: one");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (The_Module, 1)) = "Same", "exclusive names: Same");
   end Test_Flavor_Exclusive_Names;

   procedure Test_Flavor_Inactive_Syntax_Error (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module M;"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "procedure Ok(); begin end;"
        & ASCII.LF
        & "#else"
        & ASCII.LF
        & "procedure Bad(;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      Errors      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse (Source_Text, "inactive syntax", Flavor.Wasi);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "inactive syntax");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "inactive syntax code");
   end Test_Flavor_Inactive_Syntax_Error;

   procedure Test_Flavor_Invalid_Condition (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module M;"
        & ASCII.LF
        & "#if flavor = ""nope"""
        & ASCII.LF
        & "procedure P(); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      Errors      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse (Source_Text, "invalid flavor", Flavor.Wasi);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "invalid flavor");
      Support.Assert_Parser_Error_Code
        (Errors, 1, Lovelace.Compiler.Parser.Invalid_Flavor_Condition, "invalid flavor code");
   end Test_Flavor_Invalid_Condition;

   procedure Test_Flavor_Nested (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module M;"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "procedure Inner(); begin end;"
        & ASCII.LF
        & "#else"
        & ASCII.LF
        & "procedure Other(); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "nested", Flavor.Wasi);
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 1, "nested: one");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (The_Module, 1)) = "Inner", "nested: Inner");
   end Test_Flavor_Nested;

   procedure Test_Flavor_Placement_In_Procedure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module M;"
        & ASCII.LF
        & "procedure P();"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end;"
        & ASCII.LF
        & "end.";
      Errors      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse (Source_Text, "if in procedure", Flavor.Wasi);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "if in procedure");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "if in procedure code");
   end Test_Flavor_Placement_In_Procedure;

   procedure Test_Flavor_Placement_In_Program (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "program Hello;" & ASCII.LF & "#if flavor = ""wasi""" & ASCII.LF & "#end" & ASCII.LF & "begin end.";
      Errors      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse (Source_Text, "if in program", Flavor.Wasi);
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "if in program");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "if in program code");
   end Test_Flavor_Placement_In_Program;

   procedure Test_Flavor_Selection (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text   : constant String :=
        "module FlavorSelect;"
        & ASCII.LF
        & "#if flavor = ""wasi"""
        & ASCII.LF
        & "procedure WasiOnly(); begin end;"
        & ASCII.LF
        & "#elsif flavor = ""native"""
        & ASCII.LF
        & "procedure NativeOnly(); begin end;"
        & ASCII.LF
        & "#else"
        & ASCII.LF
        & "procedure WebOnly(); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      Wasi_Module   : constant Ast.Module := Support.Must_Parse (Source_Text, "wasi", Flavor.Wasi);
      Native_Module : constant Ast.Module := Support.Must_Parse (Source_Text, "native", Flavor.Native);
      Web_Module    : constant Ast.Module := Support.Must_Parse (Source_Text, "web", Flavor.Web);
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Wasi_Module) = 1, "wasi count");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (Wasi_Module, 1)) = "WasiOnly", "wasi name");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Native_Module) = 1, "native count");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (Native_Module, 1)) = "NativeOnly", "native name");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Web_Module) = 1, "web count");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (Web_Module, 1)) = "WebOnly", "web name");
   end Test_Flavor_Selection;

   procedure Test_Flavor_Syntax_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Inactive_Source : constant String :=
        "module M;"
        & ASCII.LF
        & "#if flavor = ""native"""
        & ASCII.LF
        & "@intrinsic procedure A();"
        & ASCII.LF
        & "@native(""lib"", ""fn"") procedure B(x : integer);"
        & ASCII.LF
        & "procedure C(y : float<64>); begin end;"
        & ASCII.LF
        & "#end"
        & ASCII.LF
        & "end.";
      Inactive_Wasi   : constant Ast.Module := Support.Must_Parse (Inactive_Source, "inactive arm", Flavor.Wasi);
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Inactive_Wasi) = 0, "inactive arm: nothing kept");
      Assert_Parse_Error
        ("module M; #if flavor = ""wasi"" procedure P(); begin end;",
         Compiler_Parser.Unexpected_End_Of_Input,
         "conditional missing #end at end",
         Flavor.Wasi);
      Assert_Parse_Error
        ("module M; #if flavor = ""wasi"" #else #else #end end.",
         Compiler_Parser.Unexpected_Token,
         "conditional second else",
         Flavor.Wasi);
      Assert_Parse_Error
        ("module M; #if flavor = ""wasi"" #else #elsif flavor = ""native"" #end end.",
         Compiler_Parser.Unexpected_Token,
         "conditional elsif after else",
         Flavor.Wasi);
      Assert_Parse_Error
        ("module M; #if flavor = ""wasi"" #elsif flavor = ""nope"" #end end.",
         Compiler_Parser.Invalid_Flavor_Condition,
         "conditional invalid elsif",
         Flavor.Wasi);
      Assert_Parse_Error
        ("module M; #if flavor = ""wasi"" end.",
         Compiler_Parser.Unexpected_Token,
         "conditional arm stops at end keyword",
         Flavor.Wasi);
      Assert_Parse_Error ("module M; #if", Compiler_Parser.Unexpected_End_Of_Input, "conditional name at end");
      Assert_Parse_Error
        ("module M; #if ""wasi"" #end end.", Compiler_Parser.Unexpected_Token, "conditional missing flavor name");
      Assert_Parse_Error
        ("module M; #if mode = ""wasi"" #end end.", Compiler_Parser.Unexpected_Token, "conditional wrong name");
      Assert_Parse_Error
        ("module M; #if flavor ""wasi"" #end end.", Compiler_Parser.Unexpected_Token, "conditional missing equals");
      Assert_Parse_Error ("module M; #if flavor", Compiler_Parser.Unexpected_End_Of_Input, "conditional equals at end");
      Assert_Parse_Error
        ("module M; #if flavor =", Compiler_Parser.Unexpected_End_Of_Input, "conditional string at end");
      Assert_Parse_Error
        ("module M; #if flavor = wasi #end end.", Compiler_Parser.Unexpected_Token, "conditional unquoted flavor");
      Assert_Parse_Error ("module M; #end end.", Compiler_Parser.Unexpected_Token, "stray #end");
      Assert_Parse_Error ("module M; #else end.", Compiler_Parser.Unexpected_Token, "stray #else");

      declare
         Inactive_Native : constant Ast.Module := Support.Must_Parse (Inactive_Source, "native arm", Flavor.Native);
      begin
         AUnit.Assertions.Assert (Ast.Subroutine_Count (Inactive_Native) = 3, "native arm: all kept");
         AUnit.Assertions.Assert
           (Ast.Has_Intrinsic (Ast.Get_Flags (Ast.Get_Subroutine (Inactive_Native, 1))), "native arm: intrinsic stub");
         AUnit.Assertions.Assert
           (Ast.Has_Native (Ast.Get_Flags (Ast.Get_Subroutine (Inactive_Native, 2))), "native arm: native stub");
         AUnit.Assertions.Assert
           (Ast.Length (Ast.Parameters (Ast.Get_Subroutine (Inactive_Native, 3))) = 1, "native arm: body procedure");
      end;
   end Test_Flavor_Syntax_Errors;

   procedure Test_Identifier_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe_Name   : constant String := "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Cafe_Source : constant String := "program " & Cafe_Name & "; begin end.";
      At_Foo      : constant String := "program @foo; begin end.";
      Cafe_Module : constant Ast.Module := Support.Must_Parse (Cafe_Source, "unicode name");
      At_Module   : constant Ast.Module := Support.Must_Parse (At_Foo, "@foo name");
   begin
      Assert_Entrypoint_Module (Cafe_Module, Cafe_Name, "unicode name");
      Assert_Entrypoint_Module (At_Module, "@foo", "@foo name");
   end Test_Identifier_Names;

   procedure Test_Incomplete_Input (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Assert_Parse_Error ("program", Compiler_Parser.Unexpected_End_Of_Input, "program name at end");
      Assert_Parse_Error ("program P", Compiler_Parser.Unexpected_End_Of_Input, "program semicolon at end");
      Assert_Parse_Error ("program P;", Compiler_Parser.Unexpected_End_Of_Input, "program block at end");
      Assert_Parse_Error ("program P; begin", Compiler_Parser.Unexpected_End_Of_Input, "program end at end");
      Assert_Parse_Error ("program P; begin end", Compiler_Parser.Unexpected_End_Of_Input, "program full stop at end");
      Assert_Parse_Error ("module", Compiler_Parser.Unexpected_End_Of_Input, "module name at end");
      Assert_Parse_Error ("module Foo", Compiler_Parser.Unexpected_End_Of_Input, "module semicolon at end");
      Assert_Parse_Error ("module Foo.", Compiler_Parser.Unexpected_End_Of_Input, "module name segment at end");
      Assert_Parse_Error ("module M;", Compiler_Parser.Unexpected_End_Of_Input, "module end at end");
      Assert_Parse_Error ("module M; end", Compiler_Parser.Unexpected_End_Of_Input, "module full stop at end");
      Assert_Parse_Error ("using", Compiler_Parser.Unexpected_End_Of_Input, "using name at end");
      Assert_Parse_Error ("using Foo", Compiler_Parser.Unexpected_End_Of_Input, "using semicolon at end");
      Assert_Parse_Error ("using Foo;", Compiler_Parser.Unexpected_End_Of_Input, "unit keyword at end");
      Assert_Parse_Error ("using Foo; 5", Compiler_Parser.Unexpected_Token, "unit keyword missing");
      Assert_Parse_Error ("module M; procedure", Compiler_Parser.Unexpected_End_Of_Input, "procedure name at end");
      Assert_Parse_Error ("module M; procedure P", Compiler_Parser.Unexpected_End_Of_Input, "parameters at end");
      Assert_Parse_Error ("module M; procedure P(", Compiler_Parser.Unexpected_End_Of_Input, "parameter list at end");
      Assert_Parse_Error ("module M; procedure P(x", Compiler_Parser.Unexpected_End_Of_Input, "parameter colon at end");
      Assert_Parse_Error ("module M; procedure P(x,", Compiler_Parser.Unexpected_End_Of_Input, "parameter name at end");
      Assert_Parse_Error
        ("module M; procedure P(x :", Compiler_Parser.Unexpected_End_Of_Input, "parameter type at end");
      Assert_Parse_Error
        ("module M; procedure P(x : integer", Compiler_Parser.Unexpected_End_Of_Input, "parameter close at end");
      Assert_Parse_Error
        ("module M; procedure P(x : integer;", Compiler_Parser.Unexpected_End_Of_Input, "next parameter at end");
      Assert_Parse_Error
        ("module M; procedure P()", Compiler_Parser.Unexpected_End_Of_Input, "procedure semicolon at end");
      Assert_Parse_Error
        ("module M; procedure P();", Compiler_Parser.Unexpected_End_Of_Input, "procedure block at end");
      Assert_Parse_Error
        ("module M; procedure P(); begin", Compiler_Parser.Unexpected_End_Of_Input, "procedure end at end");
      Assert_Parse_Error
        ("module M; procedure P(); begin end", Compiler_Parser.Unexpected_End_Of_Input, "procedure semicolon at end");
      Assert_Parse_Error ("module M; export", Compiler_Parser.Unexpected_End_Of_Input, "export procedure at end");
      Assert_Parse_Error
        ("module M; @intrinsic", Compiler_Parser.Unexpected_End_Of_Input, "intrinsic procedure at end");
      Assert_Parse_Error ("module M; @native", Compiler_Parser.Unexpected_End_Of_Input, "native binding at end");
      Assert_Parse_Error ("@version", Compiler_Parser.Unexpected_End_Of_Input, "version open parenthesis at end");
      Assert_Parse_Error ("@version(", Compiler_Parser.Unexpected_End_Of_Input, "version string at end");
      Assert_Parse_Error
        ("@version(""1.0.0""", Compiler_Parser.Unexpected_End_Of_Input, "version close parenthesis at end");
      Assert_Parse_Error ("@version(""1.0.0"")", Compiler_Parser.Unexpected_End_Of_Input, "version unit at end");
   end Test_Incomplete_Input;

   procedure Test_Module_Begin_Rejected (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module Foo; begin end.", "module begin");
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "module begin");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "module begin code");
   end Test_Module_Begin_Rejected;

   procedure Test_Module_Keyword_Case (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("Module Empty; end.", "Module keyword case");
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "Module keyword case");
      Support.Assert_Parser_Error_Code
        (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "Module keyword case code");
   end Test_Module_Keyword_Case;

   procedure Test_Module_Procedure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "module MyModule; procedure Whatever(x : integer; y, z : float<32>); begin end; end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "module procedure");
      The_Sub     : Ast.Subroutine;
      Params      : Ast.Parameter_Sequence;
   begin
      AUnit.Assertions.Assert (Ast.Kind (The_Module) = Ast.Module_Unit, "module unit");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 1, "one procedure");
      The_Sub := Ast.Get_Subroutine (The_Module, 1);
      AUnit.Assertions.Assert (Ast.Name (The_Sub) = "Whatever", "name");
      AUnit.Assertions.Assert (Ast.Full_Name (The_Sub) = "MyModule.Whatever", "full name");
      AUnit.Assertions.Assert (not Ast.Has_Export (Ast.Get_Flags (The_Sub)), "not export");
      Params := Ast.Parameters (The_Sub);
      AUnit.Assertions.Assert (Ast.Length (Params) = 3, "three params");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Element (Params, 1).Parameter_Name) = "x", "param x");
      AUnit.Assertions.Assert (Ast.Element (Params, 1).Parameter_Type.Kind = Types.Integer_Kind, "x integer");
      AUnit.Assertions.Assert (Ast.Element (Params, 1).Parameter_Type.Integer_Bit_Size = Types.Bits_32, "x size 32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Element (Params, 2).Parameter_Name) = "y", "param y");
      AUnit.Assertions.Assert (Ast.Element (Params, 2).Parameter_Type.Kind = Types.Float_Kind, "y float");
      AUnit.Assertions.Assert (Ast.Element (Params, 3).Parameter_Type.Float_Bit_Size = Types.Bits_32, "z float 32");
   end Test_Module_Procedure;

   procedure Test_Module_Trailing_Dot (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Errors : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module Foo.; end.", "trailing dot");
   begin
      Support.Assert_Parser_Error_Count (Errors, 1, "trailing dot");
      Support.Assert_Parser_Error_Code (Errors, 1, Lovelace.Compiler.Parser.Unexpected_Token, "trailing dot code");
   end Test_Module_Trailing_Dot;

   procedure Test_Module_Whitespace (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Glued         : constant String := "module Empty;end.";
      Spaced        : constant String := "    module   Foo.Bar   ;    end      .    ";
      Glued_Module  : constant Ast.Module := Support.Must_Parse (Glued, "glued module");
      Spaced_Module : constant Ast.Module := Support.Must_Parse (Spaced, "spaced module");
   begin
      Assert_Empty_Module (Glued_Module, "Empty", "glued module");
      Assert_Empty_Module (Spaced_Module, "Foo.Bar", "spaced module");
   end Test_Module_Whitespace;

   procedure Test_Name_Clashes (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Arity_Overload : constant Ast.Module :=
        Support.Must_Parse
          ("module M; procedure Sink(); begin end; procedure Sink(V : integer); begin end; end.", "arity overload");
      Inactive_Name  : constant Ast.Module :=
        Support.Must_Parse
          ("module M; #if flavor = ""native"" procedure M(); begin end; #end end.",
           "inactive module-named procedure",
           Flavor.Wasi);
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Arity_Overload) = 2, "arity overload: both kept");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Inactive_Name) = 0, "inactive module-named procedure: dropped");

      Assert_Parse_Error
        ("module M; procedure P(M : integer); begin end; end.",
         Compiler_Parser.Name_Clash,
         "parameter named like module");
      Assert_Parse_Error
        ("module M; procedure P(P : integer); begin end; end.",
         Compiler_Parser.Name_Clash,
         "parameter named like procedure");
      Assert_Parse_Error
        ("module M; procedure A(); begin end; procedure B(A : integer); begin end; end.",
         Compiler_Parser.Name_Clash,
         "parameter named like subroutine");
      Assert_Parse_Error
        ("module M; procedure M(); begin end; end.", Compiler_Parser.Name_Clash, "procedure named like module");
      Assert_Parse_Error
        ("module M; procedure A(); begin end; procedure B(); declare A : integer; begin end; end.",
         Compiler_Parser.Name_Clash,
         "local named like subroutine");
      Assert_Parse_Error
        ("module M; procedure P(X : integer); declare X : integer; begin end; end.",
         Compiler_Parser.Name_Clash,
         "local named like parameter");
      Assert_Parse_Error
        ("program Demo; declare Demo : integer; begin end.", Compiler_Parser.Name_Clash, "local named like program");
      Assert_Parse_Error
        ("module M; procedure Run(); declare Run : integer; begin end; end.",
         Compiler_Parser.Name_Clash,
         "local named like procedure");
      Assert_Parse_Error
        ("program P; declare X : integer; begin declare X : boolean; begin end; end.",
         Compiler_Parser.Name_Clash,
         "local shadows enclosing local");
      Assert_Parse_Error
        ("program P; declare X, X : integer; begin end.", Compiler_Parser.Name_Clash, "local duplicated in group");
      Assert_Parse_Error
        ("program P; begin using P; begin end; end.", Compiler_Parser.Name_Clash, "nested block using of program");
      Assert_Parse_Error
        ("program P; begin using Lib; using Lib; begin end; end.",
         Compiler_Parser.Name_Clash,
         "nested block duplicate using");
      Assert_Parse_Error
        ("program P; declare X : integer; begin using X; begin end; end.",
         Compiler_Parser.Name_Clash,
         "nested block using named like local");
      Assert_Parse_Error
        ("using P; program P; begin end.", Compiler_Parser.Name_Clash, "unit using named like program");
   end Test_Name_Clashes;

   procedure Test_Native_Procedure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      package U renames Ada.Strings.Unbounded;
      Exported_Source  : constant String :=
        "module Lib; export @native(""libx"", ""print_fn"") procedure print(value : integer); end.";
      Plain_Source     : constant String :=
        "module Lib; @native(""libx"", ""print_fn"") procedure print(value : integer); end.";
      Intrinsic_Source : constant String := "module Lib; export @intrinsic procedure print(value : integer); end.";
      Obsolete         : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; native(""wasi"", ""native-print-integer"") procedure print(value : integer); end.",
           "obsolete native");
      With_Body        : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; @native(""libx"", ""print_fn"") procedure print(value : integer);" & " begin end; end.",
           "native with begin");
      Intrinsic_Body   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; @intrinsic procedure print(value : integer); begin end; end.", "intrinsic with begin");
      Missing_Comma    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; @native(""libx"" ""print_fn"") procedure print(value : integer); end.", "native missing comma");
      Missing_Paren    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; @native ""libx"", ""print_fn"" procedure print(value : integer); end.", "native missing paren");
      Exported_Module  : constant Ast.Module := Support.Must_Parse (Exported_Source, "native export");
      Plain_Module     : constant Ast.Module := Support.Must_Parse (Plain_Source, "native plain");
      Intrinsic_Mod    : constant Ast.Module := Support.Must_Parse (Intrinsic_Source, "intrinsic");
      Exported_Sub     : constant Ast.Subroutine := Ast.Get_Subroutine (Exported_Module, 1);
      Plain_Sub        : constant Ast.Subroutine := Ast.Get_Subroutine (Plain_Module, 1);
      Intrinsic_Sub    : constant Ast.Subroutine := Ast.Get_Subroutine (Intrinsic_Mod, 1);
      Exported_Native  : constant Ast.Native_Binding_Option := Ast.Native (Exported_Sub);
      Plain_Native     : constant Ast.Native_Binding_Option := Ast.Native (Plain_Sub);
   begin
      AUnit.Assertions.Assert (Ast.Has_Export (Ast.Get_Flags (Exported_Sub)), "exported has export");
      AUnit.Assertions.Assert (Ast.Has_Native (Ast.Get_Flags (Exported_Sub)), "exported has native");
      AUnit.Assertions.Assert (Ast.Name (Exported_Sub) = "print", "exported name");
      AUnit.Assertions.Assert (Ast.Length (Ast.Statements (Ast.Get_Body (Exported_Sub))) = 0, "exported empty body");
      AUnit.Assertions.Assert (Exported_Native.Present, "exported binding present");
      AUnit.Assertions.Assert (U.To_String (Exported_Native.Value.Library) = "libx", "exported library");
      AUnit.Assertions.Assert (U.To_String (Exported_Native.Value.Function_Name) = "print_fn", "exported function");
      AUnit.Assertions.Assert (not Ast.Has_Export (Ast.Get_Flags (Plain_Sub)), "plain no export");
      AUnit.Assertions.Assert (Ast.Has_Native (Ast.Get_Flags (Plain_Sub)), "plain has native");
      AUnit.Assertions.Assert (Plain_Native.Present, "plain binding present");
      AUnit.Assertions.Assert (U.To_String (Plain_Native.Value.Library) = "libx", "plain library");
      AUnit.Assertions.Assert (U.To_String (Plain_Native.Value.Function_Name) = "print_fn", "plain function");
      AUnit.Assertions.Assert (Ast.Has_Export (Ast.Get_Flags (Intrinsic_Sub)), "intrinsic export");
      AUnit.Assertions.Assert (Ast.Has_Intrinsic (Ast.Get_Flags (Intrinsic_Sub)), "intrinsic flag");
      AUnit.Assertions.Assert (not Ast.Has_Native (Ast.Get_Flags (Intrinsic_Sub)), "intrinsic not native");
      AUnit.Assertions.Assert (not Ast.Native (Intrinsic_Sub).Present, "intrinsic no binding");
      Support.Assert_Parser_Error_Count (Obsolete, 1, "obsolete native");
      Support.Assert_Parser_Error_Code (Obsolete, 1, Lovelace.Compiler.Parser.Unexpected_Token, "obsolete native code");
      Support.Assert_Parser_Error_Count (With_Body, 1, "native with begin");
      Support.Assert_Parser_Error_Code
        (With_Body, 1, Lovelace.Compiler.Parser.Unexpected_Token, "native with begin code");
      Support.Assert_Parser_Error_Count (Intrinsic_Body, 1, "intrinsic with begin");
      Support.Assert_Parser_Error_Code
        (Intrinsic_Body, 1, Lovelace.Compiler.Parser.Unexpected_Token, "intrinsic with begin code");
      Support.Assert_Parser_Error_Count (Missing_Comma, 1, "native missing comma");
      Support.Assert_Parser_Error_Code
        (Missing_Comma, 1, Lovelace.Compiler.Parser.Unexpected_Token, "native missing comma code");
      Support.Assert_Parser_Error_Count (Missing_Paren, 1, "native missing paren");
      Support.Assert_Parser_Error_Code
        (Missing_Paren, 1, Lovelace.Compiler.Parser.Unexpected_Token, "native missing paren code");
   end Test_Native_Procedure;

   procedure Test_Native_Syntax_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Assert_Parse_Error
        ("module M; @native procedure P(); end.", Compiler_Parser.Unexpected_Token, "native missing binding");
      Assert_Parse_Error
        ("module M; @native(1, ""f"") procedure P(); end.",
         Compiler_Parser.Unexpected_Token,
         "native library not a string");
      Assert_Parse_Error
        ("module M; @native(""l"", 1) procedure P(); end.",
         Compiler_Parser.Unexpected_Token,
         "native function not a string");
      Assert_Parse_Error
        ("module M; @native(""l"", ""f"" procedure P(); end.",
         Compiler_Parser.Unexpected_Token,
         "native missing close parenthesis");
      Assert_Parse_Error
        ("module M; @native(", Compiler_Parser.Unexpected_End_Of_Input, "native library at end of input");
      Assert_Parse_Error
        ("module M; @native(""l""", Compiler_Parser.Unexpected_End_Of_Input, "native comma at end of input");
      Assert_Parse_Error
        ("module M; @native(""l"",", Compiler_Parser.Unexpected_End_Of_Input, "native function at end of input");
      Assert_Parse_Error
        ("module M; @native(""l"", ""f"" ", Compiler_Parser.Unexpected_End_Of_Input, "native close at end of input");
      Assert_Parse_Error
        ("module M; @native(""l"", ""f"") begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "native without procedure keyword");
      Assert_Parse_Error
        ("module M; @intrinsic end.", Compiler_Parser.Unexpected_Token, "intrinsic without procedure keyword");
      Assert_Parse_Error
        ("module M; @intrinsic @native(""l"", ""f"") procedure P(); end.",
         Compiler_Parser.Unexpected_Token,
         "intrinsic followed by native");
      Assert_Parse_Error
        ("module M; export @intrinsic procedure P(x : integer; x : integer); end.",
         Compiler_Parser.Name_Clash,
         "intrinsic duplicate parameter");
      Assert_Parse_Error
        ("module M; @intrinsic procedure P(); @intrinsic procedure P(); end.",
         Compiler_Parser.Name_Clash,
         "intrinsic duplicate signature");
   end Test_Native_Syntax_Errors;

   procedure Test_Obsolete_Import (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Unit_Leading    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("import Foo; program P; begin end.", "obsolete import unit-leading");
      Block_Preamble  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; import Foo; begin end.", "obsolete import block preamble");
      Statement_Start : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; begin import Foo; end.", "obsolete import statement start");
      Nested_Preamble : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; begin begin import Foo; begin end; end; end.", "obsolete nested");
   begin
      Support.Assert_Parser_Error_Count (Unit_Leading, 1, "obsolete import unit-leading");
      Support.Assert_Parser_Error_Code
        (Unit_Leading, 1, Lovelace.Compiler.Parser.Unexpected_Token, "obsolete import unit-leading code");
      Support.Assert_Parser_Error_Count (Block_Preamble, 1, "obsolete import block preamble");
      Support.Assert_Parser_Error_Code
        (Block_Preamble, 1, Lovelace.Compiler.Parser.Unexpected_Token, "obsolete import block preamble code");
      Support.Assert_Parser_Error_Count (Statement_Start, 1, "obsolete import statement start");
      Support.Assert_Parser_Error_Code
        (Statement_Start, 1, Lovelace.Compiler.Parser.Unexpected_Token, "obsolete import statement start code");
      Support.Assert_Parser_Error_Count (Nested_Preamble, 1, "obsolete import nested");
      Support.Assert_Parser_Error_Code
        (Nested_Preamble, 1, Lovelace.Compiler.Parser.Unexpected_Token, "obsolete import nested code");
   end Test_Obsolete_Import;

   procedure Test_Overload_Signatures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Different : constant Ast.Module :=
        Support.Must_Parse
          ("module M; procedure Sink(V : integer); begin end; " & "procedure Sink(V : boolean); begin end; end.",
           "different param types");
      Identical : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module M; procedure Sink(V : integer); begin end; " & "procedure Sink(X : integer); begin end; end.",
           "identical param types");
      Zero_Dup  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module M; procedure Sink(); begin end; procedure Sink(); begin end; end.", "duplicate nullary");
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Different) = 2, "two overloads parsed");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (Different, 1)) = "Sink", "first Sink");
      AUnit.Assertions.Assert (Ast.Name (Ast.Get_Subroutine (Different, 2)) = "Sink", "second Sink");
      Support.Assert_Parser_Error_Code (Identical, 1, Lovelace.Compiler.Parser.Name_Clash, "identical types");
      Support.Assert_Parser_Error_Code (Zero_Dup, 1, Lovelace.Compiler.Parser.Name_Clash, "duplicate nullary");
   end Test_Overload_Signatures;

   procedure Test_Procedure_Syntax_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Assert_Parse_Error
        ("module M; 5 end.", Compiler_Parser.Unexpected_Token, "declaration expected but literal found");
      Assert_Parse_Error
        ("module M; procedure begin end; end.", Compiler_Parser.Unexpected_Token, "procedure name missing");
      Assert_Parse_Error
        ("module M; procedure P begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "procedure missing open parenthesis");
      Assert_Parse_Error
        ("module M; procedure P(x : integer begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "procedure missing close parenthesis");
      Assert_Parse_Error
        ("module M; procedure P() begin end; end.", Compiler_Parser.Unexpected_Token, "procedure missing semicolon");
      Assert_Parse_Error
        ("module M; procedure P(x integer); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "parameter missing colon");
      Assert_Parse_Error
        ("module M; procedure P(5 : integer); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "parameter name is a literal");
      Assert_Parse_Error
        ("module M; procedure P(x : integer; ); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "parameter group after separator missing");
      Assert_Parse_Error
        ("module M; procedure P(x : integer; y : ); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "second parameter type missing");
      Assert_Parse_Error
        ("module M; procedure P(x, y : ); begin end; end.", Compiler_Parser.Unexpected_Token, "grouped type missing");
      Assert_Parse_Error
        ("module M; procedure P(); end; end.", Compiler_Parser.Unexpected_Token, "procedure body begin missing");
      Assert_Parse_Error
        ("module M; procedure P(); begin end end.",
         Compiler_Parser.Unexpected_Token,
         "procedure end semicolon missing");
      Assert_Parse_Error
        ("module M; procedure P(); begin Lib.Put(1); end; end",
         Compiler_Parser.Unexpected_End_Of_Input,
         "module full stop at end");
      Assert_Parse_Error
        ("module M; procedure P(); begin 5; end; end.", Compiler_Parser.Unexpected_Token, "statement is a literal");
      Assert_Parse_Error
        ("module M; procedure P(); declare begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "procedure declare without declarations");
   end Test_Procedure_Syntax_Errors;

   procedure Test_Qualified_Calls (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Module_Source  : constant String :=
        "module Calls;"
        & ASCII.LF
        & "procedure Sink(Value : integer); begin end;"
        & ASCII.LF
        & "procedure Run();"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "   Calls.Sink(42);"
        & ASCII.LF
        & "   Calls.Sink();"
        & ASCII.LF
        & "   Calls.Sink(1, 2);"
        & ASCII.LF
        & "end;"
        & ASCII.LF
        & "end.";
      Program_Source : constant String :=
        "program Hello;" & ASCII.LF & "begin" & ASCII.LF & "   augusta.std.io.print(42);" & ASCII.LF & "end.";
      The_Module     : constant Ast.Module := Support.Must_Parse (Module_Source, "module calls");
      The_Program    : constant Ast.Module := Support.Must_Parse (Program_Source, "program call");
      Unqualified    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module Calls; procedure Run(); begin Sink(42); end; end.", "unqualified call");
      Float_Arg      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module Calls; procedure Run(); begin Calls.Sink(1.5); end; end.", "float arg");
      Missing_Semi   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module Calls; procedure Run(); begin Calls.Sink(42) end; end.", "missing semicolon");
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 2, "two procedures");
      declare
         Run_Body : constant Ast.Statement_Sequence :=
           Ast.Statements (Ast.Get_Body (Ast.Get_Subroutine (The_Module, 2)));
      begin
         AUnit.Assertions.Assert (Ast.Length (Run_Body) = 3, "three statements");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Call_Of (Ast.Element (Run_Body, 1)).Callee_Name) = "Calls.Sink",
            "callee name");
         AUnit.Assertions.Assert (Ast.Length (Ast.Call_Of (Ast.Element (Run_Body, 1)).Arguments) = 1, "one arg");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Ast.Call_Of (Ast.Element (Run_Body, 1)).Arguments, 1).Lexeme)
            = "42",
            "arg lexeme");
         AUnit.Assertions.Assert (Ast.Length (Ast.Call_Of (Ast.Element (Run_Body, 2)).Arguments) = 0, "nullary");
         AUnit.Assertions.Assert (Ast.Length (Ast.Call_Of (Ast.Element (Run_Body, 3)).Arguments) = 2, "two args");
      end;

      declare
         Program_Body : constant Ast.Statement_Sequence :=
           Ast.Statements (Ast.Get_Body (Ast.Get_Subroutine (The_Program, 1)));
      begin
         AUnit.Assertions.Assert (Ast.Length (Program_Body) = 1, "program one statement");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Call_Of (Ast.Element (Program_Body, 1)).Callee_Name)
            = "augusta.std.io.print",
            "program callee");
      end;

      Support.Assert_Parser_Error_Count (Unqualified, 1, "unqualified");
      Support.Assert_Parser_Error_Code (Unqualified, 1, Lovelace.Compiler.Parser.Unexpected_Token, "unqualified code");
      Support.Assert_Parser_Error_Count (Float_Arg, 1, "float arg");
      Support.Assert_Parser_Error_Code (Float_Arg, 1, Lovelace.Compiler.Parser.Unexpected_Token, "float arg code");
      Support.Assert_Parser_Error_Count (Missing_Semi, 1, "missing semicolon");
      Support.Assert_Parser_Error_Code
        (Missing_Semi, 1, Lovelace.Compiler.Parser.Unexpected_Token, "missing semicolon code");
   end Test_Qualified_Calls;

   procedure Test_Trailing_And_Keyword_Case (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Trailing   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program Hello; begin end. begin", "trailing");
      Program_Id : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("Program Hello; begin end.", "Program keyword case");
   begin
      Support.Assert_Parser_Error_Count (Trailing, 1, "trailing");
      Support.Assert_Parser_Error_Code (Trailing, 1, Lovelace.Compiler.Parser.Unexpected_Trailing, "trailing code");
      Support.Assert_Parser_Error_Count (Program_Id, 1, "Program keyword case");
      Support.Assert_Parser_Error_Code
        (Program_Id, 1, Lovelace.Compiler.Parser.Unexpected_Token, "Program keyword case code");
   end Test_Trailing_And_Keyword_Case;

   procedure Test_Type_Syntax_Errors (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Sizes : constant Ast.Module :=
        Support.Must_Parse
          ("module M; procedure P(a : integer<8>; b : unsigned integer<16>; c : signed integer<64>; "
           & "d : float<64>; e : float; f : unsigned integer); begin end; end.",
           "integer and float sizes");
   begin
      declare
         Params : constant Ast.Parameter_Sequence := Ast.Parameters (Ast.Get_Subroutine (Sizes, 1));
      begin
         AUnit.Assertions.Assert (Ast.Length (Params) = 6, "sizes: six parameters");
         AUnit.Assertions.Assert (Ast.Element (Params, 1).Parameter_Type.Integer_Bit_Size = Types.Bits_8, "sizes: a");
         AUnit.Assertions.Assert (Ast.Element (Params, 2).Parameter_Type.Integer_Bit_Size = Types.Bits_16, "sizes: b");
         AUnit.Assertions.Assert
           (Ast.Element (Params, 2).Parameter_Type.The_Signedness = Types.Unsigned, "sizes: b unsigned");
         AUnit.Assertions.Assert (Ast.Element (Params, 3).Parameter_Type.Integer_Bit_Size = Types.Bits_64, "sizes: c");
         AUnit.Assertions.Assert
           (Ast.Element (Params, 3).Parameter_Type.The_Signedness = Types.Signed, "sizes: c signed");
         AUnit.Assertions.Assert (Ast.Element (Params, 4).Parameter_Type.Float_Bit_Size = Types.Bits_64, "sizes: d");
         AUnit.Assertions.Assert (Ast.Element (Params, 5).Parameter_Type.Float_Bit_Size = Types.Bits_32, "sizes: e");
         AUnit.Assertions.Assert (Ast.Element (Params, 6).Parameter_Type.Integer_Bit_Size = Types.Bits_32, "sizes: f");
      end;

      Assert_Parse_Detail
        ("module M; procedure P(x : float<x>); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "expected float size 32 or 64, found identifier ""x""",
         "float size not a literal");
      Assert_Parse_Detail
        ("module M; procedure P(x : float<16>); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "invalid float size ""16""; expected 32 or 64",
         "float size invalid");
      Assert_Parse_Detail
        ("module M; procedure P(x : integer<x>); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "expected integer size 8, 16, 32, or 64, found identifier ""x""",
         "integer size not a literal");
      Assert_Parse_Detail
        ("module M; procedure P(x : integer<7>); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "invalid integer size ""7""; expected 8, 16, 32, or 64",
         "integer size invalid");
      Assert_Parse_Error
        ("module M; procedure P(x : float<32; y : integer); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "float size missing close angle");
      Assert_Parse_Error
        ("module M; procedure P(x : integer<16; y : integer); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "integer size missing close angle");
      Assert_Parse_Error
        ("module M; procedure P(x : float<", Compiler_Parser.Unexpected_End_Of_Input, "float size at end of input");
      Assert_Parse_Error
        ("module M; procedure P(x : float<32", Compiler_Parser.Unexpected_End_Of_Input, "float close angle at end");
      Assert_Parse_Error
        ("module M; procedure P(x : integer<", Compiler_Parser.Unexpected_End_Of_Input, "integer size at end of input");
      Assert_Parse_Error
        ("module M; procedure P(x : integer<64", Compiler_Parser.Unexpected_End_Of_Input, "integer close angle at end");
      Assert_Parse_Error
        ("module M; procedure P(x : 5); begin end; end.", Compiler_Parser.Unexpected_Token, "type name is a literal");
      Assert_Parse_Error
        ("module M; procedure P(x : unsigned float); begin end; end.",
         Compiler_Parser.Unexpected_Token,
         "unsigned without integer");
      Assert_Parse_Error
        ("module M; procedure P(x : signed); begin end; end.", Compiler_Parser.Unexpected_Token, "signed without type");
      Assert_Parse_Error
        ("module M; procedure P(x : unsigned", Compiler_Parser.Unexpected_End_Of_Input, "unsigned at end of input");
   end Test_Type_Syntax_Errors;

   procedure Test_Using_Declarations (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Source : constant String :=
        "using augusta.std.io;"
        & ASCII.LF
        & "using Other;"
        & ASCII.LF
        & "program Hello;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end.";
      Module_Source  : constant String :=
        "using Lib.A;" & ASCII.LF & "module Host;" & ASCII.LF & "procedure P(); begin end;" & ASCII.LF & "end.";
      Program_Module : constant Ast.Module := Support.Must_Parse (Program_Source, "program usings");
      Module_Module  : constant Ast.Module := Support.Must_Parse (Module_Source, "module usings");
      Block_Using    : constant Ast.Module :=
        Support.Must_Parse ("program P; using X; begin end.", "using in program block");
      After_Module   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(); begin end; using X; end.", "using after procedure");
      In_Body        : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(); begin using X; end; end.", "using without begin");
      In_Flavor      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; #if flavor = ""wasi"" using X; #end end.", "using in flavor", Flavor.Wasi);
      Duplicate      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("using A; using A; program P; begin end.", "duplicate using");
      Self_Using     : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("using Hello; program Hello; begin end.", "self using");
      Only_Using     : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("using Foo;", "using only");
      Missing_Semi   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("using Foo.Bar program P; begin end.", "using missing semicolon");
      Trailing_Dot   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("using Foo.; program P; begin end.", "using trailing dot");
   begin
      AUnit.Assertions.Assert (Ast.Kind (Program_Module) = Ast.Program_Unit, "program usings: kind");
      AUnit.Assertions.Assert (Ast.Name (Program_Module) = "Hello", "program usings: name");
      AUnit.Assertions.Assert (Ast.Using_Count (Program_Module) = 2, "program usings: count");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Get_Using (Program_Module, 1).Module_Name) = "augusta.std.io",
         "program usings: first");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Get_Using (Program_Module, 2).Module_Name) = "Other",
         "program usings: second");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Program_Module) = 1, "program usings: entrypoint");

      AUnit.Assertions.Assert (Ast.Kind (Module_Module) = Ast.Module_Unit, "module usings: kind");
      AUnit.Assertions.Assert (Ast.Name (Module_Module) = "Host", "module usings: name");
      AUnit.Assertions.Assert (Ast.Using_Count (Module_Module) = 1, "module usings: count");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Get_Using (Module_Module, 1).Module_Name) = "Lib.A",
         "module usings: first");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Module_Module) = 1, "module usings: procedure");

      AUnit.Assertions.Assert (Ast.Using_Count (Block_Using) = 0, "block using is not unit-leading");
      AUnit.Assertions.Assert
        (Ast.Length (Ast.Usings (Ast.Get_Body (Ast.Get_Subroutine (Block_Using, 1)))) = 1, "block using: one using");
      Support.Assert_Parser_Error_Count (After_Module, 1, "using after procedure");
      Support.Assert_Parser_Error_Code
        (After_Module, 1, Lovelace.Compiler.Parser.Unexpected_Token, "using after procedure code");
      Support.Assert_Parser_Error_Count (In_Body, 1, "using without begin");
      Support.Assert_Parser_Error_Code
        (In_Body, 1, Lovelace.Compiler.Parser.Unexpected_Token, "using without begin code");
      Support.Assert_Parser_Error_Count (In_Flavor, 1, "using in flavor");
      Support.Assert_Parser_Error_Code
        (In_Flavor, 1, Lovelace.Compiler.Parser.Unexpected_Token, "using in flavor code");
      Support.Assert_Parser_Error_Count (Duplicate, 1, "duplicate using");
      Support.Assert_Parser_Error_Code (Duplicate, 1, Lovelace.Compiler.Parser.Name_Clash, "duplicate using code");
      Support.Assert_Parser_Error_Count (Self_Using, 1, "self using");
      Support.Assert_Parser_Error_Code (Self_Using, 1, Lovelace.Compiler.Parser.Name_Clash, "self using code");
      Support.Assert_Parser_Error_Count (Only_Using, 1, "using only");
      Support.Assert_Parser_Error_Code
        (Only_Using, 1, Lovelace.Compiler.Parser.Unexpected_End_Of_Input, "using only code");
      Support.Assert_Parser_Error_Count (Missing_Semi, 1, "using missing semicolon");
      Support.Assert_Parser_Error_Code
        (Missing_Semi, 1, Lovelace.Compiler.Parser.Unexpected_Token, "using missing semicolon code");
      Support.Assert_Parser_Error_Count (Trailing_Dot, 1, "using trailing dot");
      Support.Assert_Parser_Error_Code
        (Trailing_Dot, 1, Lovelace.Compiler.Parser.Unexpected_Token, "using trailing dot code");
   end Test_Using_Declarations;

   procedure Test_Version_Attribute (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Module : constant Ast.Module :=
        Support.Must_Parse ("@version(""1.2.3"") program P; begin end.", "version program");
      Module_Module  : constant Ast.Module :=
        Support.Must_Parse ("using Lib; @version(""2.0.1-preview.4"") module M; end.", "version module with using");
   begin
      AUnit.Assertions.Assert (Ast.Version_Attribute (Program_Module) = "1.2.3", "version program: text");
      AUnit.Assertions.Assert (Ast.Version_Attribute (Module_Module) = "2.0.1-preview.4", "version module: text");
      AUnit.Assertions.Assert (Ast.Using_Count (Module_Module) = 1, "version module: using kept");

      Assert_Parse_Error
        ("@version program P; begin end.", Compiler_Parser.Unexpected_Token, "version missing open parenthesis");
      Assert_Parse_Error
        ("@version(1) program P; begin end.", Compiler_Parser.Unexpected_Token, "version not a string");
      Assert_Parse_Error
        ("@version(""bogus"") program P; begin end.", Compiler_Parser.Invalid_Module_Version, "version invalid text");
      Assert_Parse_Error
        ("@version("""") program P; begin end.", Compiler_Parser.Invalid_Module_Version, "version empty text");
      Assert_Parse_Error
        ("@version(""1.0.0"" program P; begin end.",
         Compiler_Parser.Unexpected_Token,
         "version missing close parenthesis");
      Assert_Parse_Error
        ("@version(""1.0.0"") @version(""1.0.0"") program P; begin end.",
         Compiler_Parser.Unexpected_Token,
         "version repeated");
   end Test_Version_Attribute;

   procedure Test_Version_Unquoted_String (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "@version(""1.0.0"") program P; begin end.";
      Original    : constant Tokens.Token_Sequence := Support.Must_Succeed (Source_Text, "version tokens");
      Rewritten   : Tokens.Token_Sequence := Tokens.Empty_Sequence;
   begin
      --  Strip the quotes from the string token span so String_Literal_Content keeps the lexeme as is.
      for Index in 1 .. Tokens.Length (Original) loop
         declare
            Item : Tokens.Token := Tokens.Element (Original, Index);
         begin
            case Item.Kind is
               when Tokens.String_Literal =>
                  Item.Span.First.Byte_Index := Item.Span.First.Byte_Index + 1;
                  Item.Span.Last.Byte_Index := Item.Span.Last.Byte_Index - 1;

               when others                =>
                  null;
            end case;
            Tokens.Append (Rewritten, Item);
         end;
      end loop;

      declare
         Result : constant Compiler_Parser.Parse_Result :=
           Compiler_Parser.Parse (Source_Text, Rewritten, Flavor.Default);
      begin
         case Result.Ok is
            when True  =>
               AUnit.Assertions.Assert
                 (Ast.Version_Attribute (Result.The_Module) = "1.0.0", "unquoted version: text kept");

            when False =>
               AUnit.Assertions.Assert (False, "unquoted version: expected success");
         end case;
      end;
   end Test_Version_Unquoted_String;

   procedure Test_Whitespace_Variants (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Glued         : constant String := "program IDENTIFIER;begin end.";
      Spaced        : constant String := "    program         IDENTIFIER   ;    begin    end      .    ";
      Tabbed        : constant String := "program" & ASCII.HT & "IDENTIFIER;" & ASCII.LF & "begin end.";
      Glued_Module  : constant Ast.Module := Support.Must_Parse (Glued, "glued");
      Spaced_Module : constant Ast.Module := Support.Must_Parse (Spaced, "spaced");
      Tabbed_Module : constant Ast.Module := Support.Must_Parse (Tabbed, "tabbed");
   begin
      Assert_Entrypoint_Module (Glued_Module, "IDENTIFIER", "glued");
      Assert_Entrypoint_Module (Spaced_Module, "IDENTIFIER", "spaced");
      Assert_Entrypoint_Module (Tabbed_Module, "IDENTIFIER", "tabbed");
   end Test_Whitespace_Variants;

   procedure Test_Wrong_Order_And_Incomplete (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Wrong_Order : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("begin program Hello; end.", "wrong order");
      Incomplete  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program Hello; begin end", "incomplete");
   begin
      Support.Assert_Parser_Error_Count (Wrong_Order, 1, "wrong order");
      Support.Assert_Parser_Error_Code (Wrong_Order, 1, Lovelace.Compiler.Parser.Unexpected_Token, "wrong order code");
      Support.Assert_Parser_Error_Count (Incomplete, 1, "incomplete");
      Support.Assert_Parser_Error_Code
        (Incomplete, 1, Lovelace.Compiler.Parser.Unexpected_End_Of_Input, "incomplete code");
   end Test_Wrong_Order_And_Incomplete;

end Lovelace.Compiler.Tests.Parser;
