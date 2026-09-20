with AUnit.Assertions;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokens;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Tests.Parser is

   use type Lovelace.Compiler.Parser.Parser_Error_Code;

   procedure Assert_Entrypoint_Module (The_Module : Ast.Module; Expected_Name : String; Message : String);

   procedure Assert_Entrypoint_Module (The_Module : Ast.Module; Expected_Name : String; Message : String) is
   begin
      AUnit.Assertions.Assert (Ast.Name (The_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 1, Message & ": one subroutine");
      declare
         The_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, 1);
         Flags          : constant Ast.Subroutine_Flags := Ast.Get_Flags (The_Subroutine);
         Return_Type    : constant Types.Type_Expression (Types.Unit) := Ast.Return_Type (The_Subroutine);
         pragma Unreferenced (Return_Type);
      begin
         AUnit.Assertions.Assert (Ast.Name (The_Subroutine) = Expected_Name, Message & ": subroutine name");
         AUnit.Assertions.Assert (Ast.Has_Export (Flags), Message & ": export");
         AUnit.Assertions.Assert (Ast.Has_Entrypoint (Flags), Message & ": entrypoint");
         AUnit.Assertions.Assert (Ast.Length (Ast.Get_Body (The_Subroutine)) = 0, Message & ": empty body");
         AUnit.Assertions.Assert
           (Ast.Span (The_Module).Last.Byte_Index >= Ast.Span (The_Module).First.Byte_Index,
            Message & ": unit span bounds");
      end;
   end Assert_Entrypoint_Module;

   procedure Test_Canonical_Multiline (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String := "program Hello;" & ASCII.LF & "begin" & ASCII.LF & "end.";
      The_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "canonical");
   begin
      Assert_Entrypoint_Module (The_Module, "Hello", "canonical");
   end Test_Canonical_Multiline;

   procedure Test_Empty_Tokens (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Token_List : constant Tokens.Token_Sequence := Tokens.Empty_Sequence;
      Result     : constant Lovelace.Compiler.Parser.Parse_Result := Lovelace.Compiler.Parser.Parse ("", Token_List);
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
