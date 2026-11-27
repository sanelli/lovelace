package body Lovelace.Compiler.Reporting is

   Backend_Map : constant array (Backend.Backend_Error_Code) of Error_Codes.Error_Code :=
     [Backend.Internal_Error   => Error_Codes.Internal_Error,
      Backend.Unsupported_Type => Error_Codes.Unsupported_Type,
      Backend.Invalid_Module   => Error_Codes.Invalid_Module];

   Ir_Generator_Map : constant array (Ir_Generator.Ir_Generator_Error_Code) of Error_Codes.Error_Code :=
     [Ir_Generator.Internal_Error         => Error_Codes.Internal_Error,
      Ir_Generator.Unknown_Native_Binding => Error_Codes.Unknown_Native_Binding,
      Ir_Generator.Unknown_Intrinsic      => Error_Codes.Unknown_Intrinsic];

   Semantics_Map : constant array (Semantics.Semantics_Error_Code) of Error_Codes.Error_Code :=
     [Semantics.Internal_Error        => Error_Codes.Internal_Error,
      Semantics.Unresolved_Call       => Error_Codes.Unresolved_Call,
      Semantics.Invalid_Arguments     => Error_Codes.Invalid_Arguments,
      Semantics.Call_Without_Using    => Error_Codes.Call_Without_Using,
      Semantics.Not_Exported          => Error_Codes.Not_Exported,
      Semantics.Use_Before_Assignment => Error_Codes.Use_Before_Assignment,
      Semantics.Type_Mismatch         => Error_Codes.Type_Mismatch,
      Semantics.Unresolved_Name       => Error_Codes.Unresolved_Name,
      Semantics.Ambiguous_Call        => Error_Codes.Ambiguous_Call,
      Semantics.Unused_Variable       => Error_Codes.Unused_Variable,
      Semantics.Unused_Assignment     => Error_Codes.Unused_Assignment,
      Semantics.Unused_Using          => Error_Codes.Unused_Using];

   Parser_Map : constant array (Parser.Parser_Error_Code) of Error_Codes.Error_Code :=
     [Parser.Internal_Error           => Error_Codes.Internal_Error,
      Parser.Unexpected_End_Of_Input  => Error_Codes.Unexpected_End_Of_Input,
      Parser.Unexpected_Token         => Error_Codes.Unexpected_Token,
      Parser.Unexpected_Trailing      => Error_Codes.Unexpected_Trailing,
      Parser.Name_Clash               => Error_Codes.Name_Clash,
      Parser.Invalid_Flavor_Condition => Error_Codes.Invalid_Flavor_Condition,
      Parser.Invalid_Module_Version   => Error_Codes.Invalid_Module_Version];

   Tokenizer_Map : constant array (Tokenizer.Tokenizer_Error_Code) of Error_Codes.Error_Code :=
     [Tokenizer.Internal_Error              => Error_Codes.Internal_Error,
      Tokenizer.Unrecognized_Symbol         => Error_Codes.Unrecognized_Symbol,
      Tokenizer.Invalid_Utf_8               => Error_Codes.Invalid_Utf_8,
      Tokenizer.Unterminated_String_Literal => Error_Codes.Unterminated_String_Literal,
      Tokenizer.Unterminated_Comment        => Error_Codes.Unterminated_Comment,
      Tokenizer.Nested_Comment              => Error_Codes.Nested_Comment,
      Tokenizer.Stray_Comment_Closer        => Error_Codes.Stray_Comment_Closer];

   function Love_Basename (Path : String) return String is
      Start  : Positive := Path'First;
      Finish : Natural := Path'Last;
   begin
      for Index in reverse Path'Range loop
         if Path (Index) = '/' or else Path (Index) = '\' then
            Start := Index + 1;
            exit;
         end if;
      end loop;

      if Start > Path'Last then
         return "";
      end if;

      Finish := Path'Last;
      if Finish - Start + 1 >= 5 and then Path (Finish - 4 .. Finish) = ".love" then
         Finish := Finish - 5;
      end if;

      if Finish < Start then
         return "";
      end if;
      return Path (Start .. Finish);
   end Love_Basename;

   function To_Error_Code (Code : Backend.Backend_Error_Code) return Error_Codes.Error_Code is
   begin
      return Backend_Map (Code);
   end To_Error_Code;

   function To_Error_Code (Code : Ir_Generator.Ir_Generator_Error_Code) return Error_Codes.Error_Code is
   begin
      return Ir_Generator_Map (Code);
   end To_Error_Code;

   function To_Error_Code (Code : Semantics.Semantics_Error_Code) return Error_Codes.Error_Code is
   begin
      return Semantics_Map (Code);
   end To_Error_Code;

   function To_Error_Code (Code : Parser.Parser_Error_Code) return Error_Codes.Error_Code is
   begin
      return Parser_Map (Code);
   end To_Error_Code;

   function To_Error_Code (Code : Tokenizer.Tokenizer_Error_Code) return Error_Codes.Error_Code is
   begin
      return Tokenizer_Map (Code);
   end To_Error_Code;

   function Unit_Kind_Label (The_Module : Ast.Module) return String is
   begin
      case Ast.Kind (The_Module) is
         when Ast.Program_Unit =>
            return "program";

         when Ast.Module_Unit  =>
            return "module";
      end case;
   end Unit_Kind_Label;

   function Unit_Name_Matches_File (The_Module : Ast.Module; Source_Path : String) return Boolean is
   begin
      return Ast.Name (The_Module) = Love_Basename (Source_Path);
   end Unit_Name_Matches_File;

end Lovelace.Compiler.Reporting;
