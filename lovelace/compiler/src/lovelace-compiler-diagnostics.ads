with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Error_Codes;

--  Format located compiler diagnostics for stderr (no colour).

package Lovelace.Compiler.Diagnostics is

   package Source renames Lovelace.Common.Source;

   --  Render one diagnostic block (filename, line, caret, LV code).
   --  @param Filename UTF-8 path shown in the [err] header.
   --  @param Span Source span (row/column from First; caret covers First..Last).
   --  @param Source_Text Full UTF-8 source buffer used to extract the line.
   --  @param Code Stable LV error kind.
   --  @param Description UTF-8 human-readable message after the LV label.
   --  @return Multi-line UTF-8 text ending with a newline.
   function Format
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String) return String;

   --  Same as Format, returning an unbounded string.
   --  @param Filename UTF-8 path shown in the [err] header.
   --  @param Span Source span.
   --  @param Source_Text Full UTF-8 source buffer.
   --  @param Code Stable LV error kind.
   --  @param Description UTF-8 message after the LV label.
   --  @return Multi-line UTF-8 text ending with a newline.
   function Format_Unbounded
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String) return Ada.Strings.Unbounded.Unbounded_String;

end Lovelace.Compiler.Diagnostics;
