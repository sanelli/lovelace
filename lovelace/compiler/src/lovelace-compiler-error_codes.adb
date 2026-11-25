package body Lovelace.Compiler.Error_Codes is

   --  Canonical LV##### labels (fixed width; every label is seven characters).
   Labels : constant array (Error_Code) of String (1 .. 7) :=
     [Internal_Error                 => "LV00001",
      Unrecognized_Symbol            => "LV00002",
      Invalid_Utf_8                  => "LV00003",
      Unexpected_End_Of_Input        => "LV00004",
      Unexpected_Token               => "LV00005",
      Unexpected_Trailing            => "LV00006",
      Unsupported_Type               => "LV00007",
      Invalid_Module                 => "LV00008",
      Program_Name_Filename_Mismatch => "LV00009",
      Source_File_Io                 => "LV00010",
      Name_Clash                     => "LV00011",
      Invalid_Flavor_Condition       => "LV00012",
      Unterminated_String_Literal    => "LV00013",
      Unresolved_Call                => "LV00014",
      Invalid_Arguments              => "LV00015",
      Unknown_Module                 => "LV00016",
      Call_Without_Using             => "LV00017",
      Not_Exported                   => "LV00018",
      Circular_Import                => "LV00019",
      Ambiguous_Module_Path          => "LV00020",
      Unknown_Native_Binding         => "LV00021",
      Unterminated_Comment           => "LV00022",
      Nested_Comment                 => "LV00023",
      Stray_Comment_Closer           => "LV00024",
      Unknown_Intrinsic              => "LV00025",
      Use_Before_Assignment          => "LV00026",
      Type_Mismatch                  => "LV00027",
      Unused_Variable                => "LV00028",
      Unused_Assignment              => "LV00029",
      Invalid_Warning_Suppression    => "LV00030",
      Unresolved_Name                => "LV00031",
      Unused_Using                   => "LV00032",
      Ambiguous_Call                 => "LV00033",
      Invalid_Module_Version         => "LV00034"];

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
      return Labels (Code);
   end Label;

   function Try_From_Label (Text : String; Code : out Error_Code) return Boolean is
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
