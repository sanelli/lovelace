package body Lovelace.Compiler.Reporting is

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
      case Code is
         when Backend.Internal_Error   =>
            return Error_Codes.Internal_Error;

         when Backend.Unsupported_Type =>
            return Error_Codes.Unsupported_Type;

         when Backend.Invalid_Module   =>
            return Error_Codes.Invalid_Module;
      end case;
   end To_Error_Code;

   function To_Error_Code (Code : Ir_Generator.Ir_Generator_Error_Code) return Error_Codes.Error_Code is
   begin
      case Code is
         when Ir_Generator.Internal_Error         =>
            return Error_Codes.Internal_Error;

         when Ir_Generator.Unknown_Native_Binding =>
            return Error_Codes.Unknown_Native_Binding;

         when Ir_Generator.Unknown_Intrinsic      =>
            return Error_Codes.Unknown_Intrinsic;
      end case;
   end To_Error_Code;

   function To_Error_Code (Code : Semantics.Semantics_Error_Code) return Error_Codes.Error_Code is
   begin
      case Code is
         when Semantics.Internal_Error        =>
            return Error_Codes.Internal_Error;

         when Semantics.Unresolved_Call       =>
            return Error_Codes.Unresolved_Call;

         when Semantics.Invalid_Arguments     =>
            return Error_Codes.Invalid_Arguments;

         when Semantics.Call_Without_Using    =>
            return Error_Codes.Call_Without_Using;

         when Semantics.Not_Exported          =>
            return Error_Codes.Not_Exported;

         when Semantics.Use_Before_Assignment =>
            return Error_Codes.Use_Before_Assignment;

         when Semantics.Type_Mismatch         =>
            return Error_Codes.Type_Mismatch;

         when Semantics.Unresolved_Name       =>
            return Error_Codes.Unresolved_Name;

         when Semantics.Unused_Variable       =>
            return Error_Codes.Unused_Variable;

         when Semantics.Unused_Assignment     =>
            return Error_Codes.Unused_Assignment;
      end case;
   end To_Error_Code;

   function To_Error_Code (Code : Parser.Parser_Error_Code) return Error_Codes.Error_Code is
   begin
      case Code is
         when Parser.Internal_Error           =>
            return Error_Codes.Internal_Error;

         when Parser.Unexpected_End_Of_Input  =>
            return Error_Codes.Unexpected_End_Of_Input;

         when Parser.Unexpected_Token         =>
            return Error_Codes.Unexpected_Token;

         when Parser.Unexpected_Trailing      =>
            return Error_Codes.Unexpected_Trailing;

         when Parser.Name_Clash               =>
            return Error_Codes.Name_Clash;

         when Parser.Invalid_Flavor_Condition =>
            return Error_Codes.Invalid_Flavor_Condition;

      end case;
   end To_Error_Code;

   function To_Error_Code (Code : Tokenizer.Tokenizer_Error_Code) return Error_Codes.Error_Code is
   begin
      case Code is
         when Tokenizer.Internal_Error              =>
            return Error_Codes.Internal_Error;

         when Tokenizer.Unrecognized_Symbol         =>
            return Error_Codes.Unrecognized_Symbol;

         when Tokenizer.Invalid_Utf_8               =>
            return Error_Codes.Invalid_Utf_8;

         when Tokenizer.Unterminated_String_Literal =>
            return Error_Codes.Unterminated_String_Literal;

         when Tokenizer.Unterminated_Comment        =>
            return Error_Codes.Unterminated_Comment;

         when Tokenizer.Nested_Comment              =>
            return Error_Codes.Nested_Comment;

         when Tokenizer.Stray_Comment_Closer        =>
            return Error_Codes.Stray_Comment_Closer;
      end case;
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
