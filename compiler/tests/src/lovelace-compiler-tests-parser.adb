with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Flavor;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Tokens;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Tests.Parser is

   use type Lovelace.Compiler.Ast.Unit_Kind;
   use type Lovelace.Compiler.Parser.Parser_Error_Code;
   use type Lovelace.Compiler.Types.Float_Size;
   use type Lovelace.Compiler.Types.Integer_Size;
   use type Lovelace.Compiler.Types.Type_Kind;

   procedure Assert_Empty_Module (The_Module : Ast.Module; Expected_Name : String; Message : String);
   --  Assert Module_Unit with Expected_Name and zero subroutines.

   procedure Assert_Entrypoint_Module (The_Module : Ast.Module; Expected_Name : String; Message : String);
   --  Assert Program_Unit with one entrypoint+export subroutine named Expected_Name.

   procedure Assert_Empty_Module (The_Module : Ast.Module; Expected_Name : String; Message : String) is
   begin
      AUnit.Assertions.Assert (Ast.Kind (The_Module) = Ast.Module_Unit, Message & ": module unit");
      AUnit.Assertions.Assert (Ast.Name (The_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert (Ast.Import_Count (The_Module) = 0, Message & ": no imports");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 0, Message & ": no subroutines");
      AUnit.Assertions.Assert
        (Ast.Span (The_Module).Last.Byte_Index >= Ast.Span (The_Module).First.Byte_Index,
         Message & ": unit span bounds");
   end Assert_Empty_Module;

   procedure Assert_Entrypoint_Module (The_Module : Ast.Module; Expected_Name : String; Message : String) is
   begin
      AUnit.Assertions.Assert (Ast.Kind (The_Module) = Ast.Program_Unit, Message & ": program unit");
      AUnit.Assertions.Assert (Ast.Name (The_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert (Ast.Import_Count (The_Module) = 0, Message & ": no imports");
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
         AUnit.Assertions.Assert (Ast.Length (Ast.Get_Body (The_Subroutine)) = 0, Message & ": empty body");
         AUnit.Assertions.Assert
           (Ast.Span (The_Module).Last.Byte_Index >= Ast.Span (The_Module).First.Byte_Index,
            Message & ": unit span bounds");
      end;
   end Assert_Entrypoint_Module;

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

   procedure Test_Import_Declarations (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Source : constant String :=
        "import augusta.std.io;"
        & ASCII.LF
        & "import Other;"
        & ASCII.LF
        & "program Hello;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end.";
      Module_Source  : constant String :=
        "import Lib.A;" & ASCII.LF & "module Host;" & ASCII.LF & "procedure P(); begin end;" & ASCII.LF & "end.";
      Program_Module : constant Ast.Module := Support.Must_Parse (Program_Source, "program imports");
      Module_Module  : constant Ast.Module := Support.Must_Parse (Module_Source, "module imports");
      After_Program  : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("program P; import X; begin end.", "import after program");
      After_Module   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(); begin end; import X; end.", "import after procedure");
      In_Body        : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("module M; procedure P(); begin import X; end; end.", "import in body");
      In_Flavor      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module M; #if flavor = ""wasi"" import X; #end end.", "import in flavor", Flavor.Wasi);
      Duplicate      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("import A; import A; program P; begin end.", "duplicate import");
      Self_Import    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("import Hello; program Hello; begin end.", "self import");
      Only_Import    : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("import Foo;", "import only");
      Missing_Semi   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("import Foo.Bar program P; begin end.", "import missing semicolon");
      Trailing_Dot   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse ("import Foo.; program P; begin end.", "import trailing dot");
   begin
      AUnit.Assertions.Assert (Ast.Kind (Program_Module) = Ast.Program_Unit, "program imports: kind");
      AUnit.Assertions.Assert (Ast.Name (Program_Module) = "Hello", "program imports: name");
      AUnit.Assertions.Assert (Ast.Import_Count (Program_Module) = 2, "program imports: count");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Get_Import (Program_Module, 1).Module_Name) = "augusta.std.io",
         "program imports: first");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Get_Import (Program_Module, 2).Module_Name) = "Other",
         "program imports: second");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Program_Module) = 1, "program imports: entrypoint");

      AUnit.Assertions.Assert (Ast.Kind (Module_Module) = Ast.Module_Unit, "module imports: kind");
      AUnit.Assertions.Assert (Ast.Name (Module_Module) = "Host", "module imports: name");
      AUnit.Assertions.Assert (Ast.Import_Count (Module_Module) = 1, "module imports: count");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Get_Import (Module_Module, 1).Module_Name) = "Lib.A",
         "module imports: first");
      AUnit.Assertions.Assert (Ast.Subroutine_Count (Module_Module) = 1, "module imports: procedure");

      Support.Assert_Parser_Error_Count (After_Program, 1, "import after program");
      Support.Assert_Parser_Error_Code
        (After_Program, 1, Lovelace.Compiler.Parser.Unexpected_Token, "import after program code");
      Support.Assert_Parser_Error_Count (After_Module, 1, "import after procedure");
      Support.Assert_Parser_Error_Code
        (After_Module, 1, Lovelace.Compiler.Parser.Unexpected_Token, "import after procedure code");
      Support.Assert_Parser_Error_Count (In_Body, 1, "import in body");
      Support.Assert_Parser_Error_Code (In_Body, 1, Lovelace.Compiler.Parser.Unexpected_Token, "import in body code");
      Support.Assert_Parser_Error_Count (In_Flavor, 1, "import in flavor");
      Support.Assert_Parser_Error_Code
        (In_Flavor, 1, Lovelace.Compiler.Parser.Unexpected_Token, "import in flavor code");
      Support.Assert_Parser_Error_Count (Duplicate, 1, "duplicate import");
      Support.Assert_Parser_Error_Code (Duplicate, 1, Lovelace.Compiler.Parser.Name_Clash, "duplicate import code");
      Support.Assert_Parser_Error_Count (Self_Import, 1, "self import");
      Support.Assert_Parser_Error_Code (Self_Import, 1, Lovelace.Compiler.Parser.Name_Clash, "self import code");
      Support.Assert_Parser_Error_Count (Only_Import, 1, "import only");
      Support.Assert_Parser_Error_Code
        (Only_Import, 1, Lovelace.Compiler.Parser.Unexpected_End_Of_Input, "import only code");
      Support.Assert_Parser_Error_Count (Missing_Semi, 1, "import missing semicolon");
      Support.Assert_Parser_Error_Code
        (Missing_Semi, 1, Lovelace.Compiler.Parser.Unexpected_Token, "import missing semicolon code");
      Support.Assert_Parser_Error_Count (Trailing_Dot, 1, "import trailing dot");
      Support.Assert_Parser_Error_Code
        (Trailing_Dot, 1, Lovelace.Compiler.Parser.Unexpected_Token, "import trailing dot code");
   end Test_Import_Declarations;

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
      AUnit.Assertions.Assert (Ast.Element (Params, 1).Parameter_Type.Kind = Types.Integer, "x integer");
      AUnit.Assertions.Assert (Ast.Element (Params, 1).Parameter_Type.Integer_Bit_Size = Types.Bits_32, "x size 32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Ast.Element (Params, 2).Parameter_Name) = "y", "param y");
      AUnit.Assertions.Assert (Ast.Element (Params, 2).Parameter_Type.Kind = Types.Float, "y float");
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

   procedure Test_Native_Procedure (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      package U renames Ada.Strings.Unbounded;
      Exported_Source : constant String :=
        "module Lib; export native(""wasi"", ""native-print-integer"") procedure print(value : integer); end.";
      Plain_Source    : constant String :=
        "module Lib; native(""wasi"", ""native-print-integer"") procedure print(value : integer); end.";
      With_Body       : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; native(""wasi"", ""native-print-integer"") procedure print(value : integer);"
           & " begin end; end.",
           "native with begin");
      Missing_Comma   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; native(""wasi"" ""native-print-integer"") procedure print(value : integer); end.",
           "native missing comma");
      Missing_Paren   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Lib; native ""wasi"", ""native-print-integer"" procedure print(value : integer); end.",
           "native missing paren");
      Exported_Module : constant Ast.Module := Support.Must_Parse (Exported_Source, "native export");
      Plain_Module    : constant Ast.Module := Support.Must_Parse (Plain_Source, "native plain");
      Exported_Sub    : constant Ast.Subroutine := Ast.Get_Subroutine (Exported_Module, 1);
      Plain_Sub       : constant Ast.Subroutine := Ast.Get_Subroutine (Plain_Module, 1);
      Exported_Native : constant Ast.Native_Binding_Option := Ast.Native (Exported_Sub);
      Plain_Native    : constant Ast.Native_Binding_Option := Ast.Native (Plain_Sub);
   begin
      AUnit.Assertions.Assert (Ast.Has_Export (Ast.Get_Flags (Exported_Sub)), "exported has export");
      AUnit.Assertions.Assert (Ast.Has_Native (Ast.Get_Flags (Exported_Sub)), "exported has native");
      AUnit.Assertions.Assert (Ast.Name (Exported_Sub) = "print", "exported name");
      AUnit.Assertions.Assert (Ast.Length (Ast.Get_Body (Exported_Sub)) = 0, "exported empty body");
      AUnit.Assertions.Assert (Exported_Native.Present, "exported binding present");
      AUnit.Assertions.Assert
        (U.To_String (Exported_Native.Value.Target) = "wasi", "exported target");
      AUnit.Assertions.Assert
        (U.To_String (Exported_Native.Value.Key) = "native-print-integer", "exported key");
      AUnit.Assertions.Assert (not Ast.Has_Export (Ast.Get_Flags (Plain_Sub)), "plain no export");
      AUnit.Assertions.Assert (Ast.Has_Native (Ast.Get_Flags (Plain_Sub)), "plain has native");
      AUnit.Assertions.Assert (Plain_Native.Present, "plain binding present");
      AUnit.Assertions.Assert (U.To_String (Plain_Native.Value.Target) = "wasi", "plain target");
      AUnit.Assertions.Assert
        (U.To_String (Plain_Native.Value.Key) = "native-print-integer", "plain key");
      Support.Assert_Parser_Error_Count (With_Body, 1, "native with begin");
      Support.Assert_Parser_Error_Code
        (With_Body, 1, Lovelace.Compiler.Parser.Unexpected_Token, "native with begin code");
      Support.Assert_Parser_Error_Count (Missing_Comma, 1, "native missing comma");
      Support.Assert_Parser_Error_Code
        (Missing_Comma, 1, Lovelace.Compiler.Parser.Unexpected_Token, "native missing comma code");
      Support.Assert_Parser_Error_Count (Missing_Paren, 1, "native missing paren");
      Support.Assert_Parser_Error_Code
        (Missing_Paren, 1, Lovelace.Compiler.Parser.Unexpected_Token, "native missing paren code");
   end Test_Native_Procedure;

   procedure Test_Qualified_Calls (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Module_Source : constant String :=
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
        Support.Must_Fail_Parse
          ("module Calls; procedure Run(); begin Sink(42); end; end.", "unqualified call");
      Float_Arg      : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Calls; procedure Run(); begin Calls.Sink(1.5); end; end.", "float arg");
      Missing_Semi   : constant Lovelace.Compiler.Parser.Parser_Error_Sequence :=
        Support.Must_Fail_Parse
          ("module Calls; procedure Run(); begin Calls.Sink(42) end; end.", "missing semicolon");
   begin
      AUnit.Assertions.Assert (Ast.Subroutine_Count (The_Module) = 2, "two procedures");
      declare
         Run_Body : constant Ast.Statement_Sequence := Ast.Get_Body (Ast.Get_Subroutine (The_Module, 2));
      begin
         AUnit.Assertions.Assert (Ast.Length (Run_Body) = 3, "three statements");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Run_Body, 1).The_Call.Callee_Name) = "Calls.Sink",
            "callee name");
         AUnit.Assertions.Assert (Ast.Length (Ast.Element (Run_Body, 1).The_Call.Arguments) = 1, "one arg");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Ast.Element (Run_Body, 1).The_Call.Arguments, 1).Lexeme)
            = "42",
            "arg lexeme");
         AUnit.Assertions.Assert (Ast.Length (Ast.Element (Run_Body, 2).The_Call.Arguments) = 0, "nullary");
         AUnit.Assertions.Assert (Ast.Length (Ast.Element (Run_Body, 3).The_Call.Arguments) = 2, "two args");
      end;

      declare
         Program_Body : constant Ast.Statement_Sequence := Ast.Get_Body (Ast.Get_Subroutine (The_Program, 1));
      begin
         AUnit.Assertions.Assert (Ast.Length (Program_Body) = 1, "program one statement");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Ast.Element (Program_Body, 1).The_Call.Callee_Name)
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
