package body Lovelace.Compiler.Error_Codes is

   function Default_Severity (Code : Error_Code) return Severity is
   begin
      case Code is
         when Unused_Variable | Unused_Assignment | Unused_Using =>
            return Warning;

         when others                                             =>
            return Error;
      end case;
   end Default_Severity;

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

         when Name_Clash                     =>
            return "LV00011";

         when Invalid_Flavor_Condition       =>
            return "LV00012";

         when Unterminated_String_Literal    =>
            return "LV00013";

         when Unresolved_Call                =>
            return "LV00014";

         when Invalid_Arguments              =>
            return "LV00015";

         when Unknown_Module                 =>
            return "LV00016";

         when Call_Without_Using             =>
            return "LV00017";

         when Not_Exported                   =>
            return "LV00018";

         when Circular_Import                =>
            return "LV00019";

         when Ambiguous_Module_Path          =>
            return "LV00020";

         when Unknown_Native_Binding         =>
            return "LV00021";

         when Unterminated_Comment           =>
            return "LV00022";

         when Nested_Comment                 =>
            return "LV00023";

         when Stray_Comment_Closer           =>
            return "LV00024";

         when Unknown_Intrinsic              =>
            return "LV00025";

         when Use_Before_Assignment          =>
            return "LV00026";

         when Type_Mismatch                  =>
            return "LV00027";

         when Unused_Variable                =>
            return "LV00028";

         when Unused_Assignment              =>
            return "LV00029";

         when Invalid_Warning_Suppression    =>
            return "LV00030";

         when Unresolved_Name                =>
            return "LV00031";

         when Unused_Using                   =>
            return "LV00032";

         when Ambiguous_Call                 =>
            return "LV00033";
      end case;
   end Label;

   function Try_From_Label
     (Text : String; Code : out Error_Code) return Boolean is
   begin
      for Candidate in Error_Code loop
         if Label (Candidate) = Text then
            Code := Candidate;
            return True;
         end if;
      end loop;

      Code := Internal_Error;
      return False;
   end Try_From_Label;

end Lovelace.Compiler.Error_Codes;
