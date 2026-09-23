package body Lovelace.Compiler.Error_Codes is

   function Label (Code : Error_Code) return String is
   begin
      case Code is
         when Internal_Error                 =>
            return "LV00001";

         when Unrecognized_Symbol            =>
            return "LV00002";

         when Invalid_Utf_8                  =>
            return "LV00003";

         when Unexpected_End_Of_Input        =>
            return "LV00004";

         when Unexpected_Token               =>
            return "LV00005";

         when Unexpected_Trailing            =>
            return "LV00006";

         when Unsupported_Type               =>
            return "LV00007";

         when Invalid_Module                 =>
            return "LV00008";

         when Program_Name_Filename_Mismatch =>
            return "LV00009";

         when Source_File_Io                 =>
            return "LV00010";
      end case;
   end Label;

end Lovelace.Compiler.Error_Codes;
