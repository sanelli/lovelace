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
   --  @enum Program_Name_Filename_Mismatch Compilation-unit name differs from .love basename (LV00009).
   --  @enum Source_File_Io Source file missing or unreadable (LV00010).
   --  @enum Name_Clash Parser: duplicate or conflicting procedure/parameter name (LV00011).
   --  @enum Invalid_Flavor_Condition Parser: `#if`/`#elsif` flavor string is not wasi/native/web (LV00012).
   --  @enum Unterminated_String_Literal Tokenizer: opening `"` without a matching closer (LV00013).
   --  @enum Unresolved_Call IR Generator: call target is not a same-unit procedure (LV00014).
   --  @enum Invalid_Arguments IR Generator: call arity or argument/formal mismatch (LV00015).
   --  @enum Unknown_Module Unit graph: import name has no candidate .love on the search roots (LV00016).
   --  @enum Call_Without_Using IR Generator/Semantics: callee module prefix is not brought in by a using (LV00017).
   --  @enum Not_Exported IR Generator/Semantics: used procedure exists but lacks Export_Flag (LV00018).
   --  @enum Circular_Import Unit graph: using cycle among compilation units (LV00019).
   --  @enum Ambiguous_Module_Path Unit graph: two or more distinct .love files match one using (LV00020).
   --  @enum Unknown_Native_Binding Retired: old native(target, key) closed wasi set (LV00021); no longer emitted.
   --  @enum Unterminated_Comment Tokenizer: opening `{` without a matching `}` (LV00022).
   --  @enum Nested_Comment Tokenizer: `{` inside an open `{` ÃÂ¢ÃÂÃÂ¦ `}` comment (LV00023).
   --  @enum Stray_Comment_Closer Tokenizer: `}` outside a comment (LV00024).
   --  @enum Unknown_Intrinsic IR Generator: `@intrinsic` signature not in the closed intrinsic table (LV00025).
   --  @enum Use_Before_Assignment Semantics: read of a local that is not definitely assigned (LV00026).
   --  @enum Type_Mismatch Semantics: assignment or call actual is not assignable to the expected type (LV00027).
   --  @enum Unused_Variable Warning: local is never read (LV00028).
   --  @enum Unused_Assignment Warning: a store whose value is never read before overwrite/end (LV00029).
   --  @enum Invalid_Warning_Suppression CLI/build: `--no-warnings` entry is unknown or not a warning (LV00030).
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
      Source_File_Io,
      Name_Clash,
      Invalid_Flavor_Condition,
      Unterminated_String_Literal,
      Unresolved_Call,
      Invalid_Arguments,
      Unknown_Module,
      Call_Without_Using,
      Not_Exported,
      Circular_Import,
      Ambiguous_Module_Path,
      Unknown_Native_Binding,
      Unterminated_Comment,
      Nested_Comment,
      Stray_Comment_Closer,
      Unknown_Intrinsic,
      Use_Before_Assignment,
      Type_Mismatch,
      Unused_Variable,
      Unused_Assignment,
      Invalid_Warning_Suppression);

   --  Diagnostic severity for Code (warnings are Unused_Variable / Unused_Assignment).
   --  @enum Error Fatal or hard diagnostic (default for almost all codes).
   --  @enum Warning Non-fatal; may be promoted or suppressed by the build CLI.
   type Severity is (Error, Warning);

   --  Canonical LV##### label for Code.
   --  @param Code Diagnostic kind.
   --  @return Five-digit LV label such as LV00001.
   function Label (Code : Error_Code) return String;

   --  Default severity for Code before promote/suppress policy.
   --  @param Code Diagnostic kind.
   --  @return Error or Warning.
   function Default_Severity (Code : Error_Code) return Severity;

end Lovelace.Compiler.Error_Codes;
