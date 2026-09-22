--  Stable Lovelace compiler diagnostic codes (LV##### labels).

package Lovelace.Compiler.Error_Codes is

   --  User-facing compiler diagnostic kinds (map to LV##### labels).
   --  @enum Internal_Error Compiler bug or impossible state (LV00001).
   --  @enum Unrecognized_Symbol Tokenizer: valid scalar that does not start a token (LV00002).
   --  @enum Invalid_Utf_8 Tokenizer: bytes that are not valid UTF-8 (LV00003).
   --  @enum Unexpected_End_Of_Input Parser: fewer tokens than the grammar requires (LV00004).
   --  @enum Unexpected_Token Parser: wrong token kind at the cursor (LV00005).
   --  @enum Unexpected_Trailing Parser: extra tokens after a complete unit (LV00006).
   --  @enum Unsupported_Type Backend: LIR signature type this slice cannot lower (LV00007).
   --  @enum Invalid_Module Backend or LIR validate failure surfaced to the user (LV00008).
   --  @enum Program_Name_Filename_Mismatch Program identifier differs from .love basename (LV00009).
   --  @enum Source_File_Io Source file missing or unreadable (LV00010).
   type Error_Code is
     (Internal_Error,
      Unrecognized_Symbol,
      Invalid_Utf_8,
      Unexpected_End_Of_Input,
      Unexpected_Token,
      Unexpected_Trailing,
      Unsupported_Type,
      Invalid_Module,
      Program_Name_Filename_Mismatch,
      Source_File_Io);

   --  Canonical LV##### label for Code.
   --  @param Code Diagnostic kind.
   --  @return Five-digit LV label such as LV00001.
   function Label (Code : Error_Code) return String;

end Lovelace.Compiler.Error_Codes;
