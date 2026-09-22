with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Backend;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Ir_Generator;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Tokenizer;

--  Map stage-local error enums to stable LV Error_Codes and semantic checks.

package Lovelace.Compiler.Reporting is

   --  Map a tokenizer error code to an LV Error_Code.
   --  @param Code Tokenizer stage code.
   --  @return Corresponding LV kind.
   function To_Error_Code (Code : Tokenizer.Tokenizer_Error_Code) return Error_Codes.Error_Code;

   --  Map a parser error code to an LV Error_Code.
   --  @param Code Parser stage code.
   --  @return Corresponding LV kind.
   function To_Error_Code (Code : Parser.Parser_Error_Code) return Error_Codes.Error_Code;

   --  Map an IR Generator error code to an LV Error_Code.
   --  @param Code IR Generator stage code.
   --  @return Corresponding LV kind.
   function To_Error_Code (Code : Ir_Generator.Ir_Generator_Error_Code) return Error_Codes.Error_Code;

   --  Map a backend error code to an LV Error_Code.
   --  @param Code Backend stage code.
   --  @return Corresponding LV kind.
   function To_Error_Code (Code : Backend.Backend_Error_Code) return Error_Codes.Error_Code;

   --  Basename of Path without directories; strips a final .love suffix when present.
   --  @param Path UTF-8 filesystem path or file name.
   --  @return Stem used for program-name comparison.
   function Love_Basename (Path : String) return String;

   --  True when Ast.Name (The_Module) equals Love_Basename (Source_Path).
   --  @param The_Module Parsed compilation unit.
   --  @param Source_Path Path of the .love file being compiled.
   --  @return True when the program identifier matches the file stem.
   function Program_Name_Matches_File (The_Module : Ast.Module; Source_Path : String) return Boolean;

end Lovelace.Compiler.Reporting;
