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

   function Program_Name_Matches_File (The_Module : Ast.Module; Source_Path : String) return Boolean is
   begin
      return Ast.Name (The_Module) = Love_Basename (Source_Path);
   end Program_Name_Matches_File;

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
         when Ir_Generator.Internal_Error =>
            return Error_Codes.Internal_Error;
      end case;
   end To_Error_Code;

   function To_Error_Code (Code : Parser.Parser_Error_Code) return Error_Codes.Error_Code is
   begin
      case Code is
         when Parser.Internal_Error          =>
            return Error_Codes.Internal_Error;

         when Parser.Unexpected_End_Of_Input =>
            return Error_Codes.Unexpected_End_Of_Input;

         when Parser.Unexpected_Token        =>
            return Error_Codes.Unexpected_Token;

         when Parser.Unexpected_Trailing     =>
            return Error_Codes.Unexpected_Trailing;
      end case;
   end To_Error_Code;

   function To_Error_Code (Code : Tokenizer.Tokenizer_Error_Code) return Error_Codes.Error_Code is
   begin
      case Code is
         when Tokenizer.Internal_Error      =>
            return Error_Codes.Internal_Error;

         when Tokenizer.Unrecognized_Symbol =>
            return Error_Codes.Unrecognized_Symbol;

         when Tokenizer.Invalid_Utf_8       =>
            return Error_Codes.Invalid_Utf_8;
      end case;
   end To_Error_Code;

end Lovelace.Compiler.Reporting;
