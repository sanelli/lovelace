with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Error_Codes;

--  Format located compiler diagnostics for stderr (no colour).
--  Supports Error/Warning severity, warning promotion, and suppression.

package Lovelace.Compiler.Diagnostics is

   package Source renames Lovelace.Common.Source;

   --  Policy for formatting and filtering diagnostics.
   --  @field Promote_Warnings When True, warnings print and count as errors.
   --  @field Suppressions Warning codes that are dropped (not printed / not promoted).
   type Policy is private;

   --  Default policy: no promotion, no suppressions.
   --  @return Empty policy.
   function Default_Policy return Policy;

   --  True when Code is currently suppressed under The_Policy.
   --  @param The_Policy Policy to query.
   --  @param Code Diagnostic kind.
   --  @return True iff Code is in the suppression set.
   function Is_Suppressed (The_Policy : Policy; Code : Error_Codes.Error_Code) return Boolean;

   --  Add Code to the suppression set. Fails when Code is not a warning.
   --  @param The_Policy Policy to update.
   --  @param Code Warning code to suppress.
   --  @param Ok Set True on success; False when Code is not a warning.
   procedure Suppress_Warning (The_Policy : in out Policy; Code : Error_Codes.Error_Code; Ok : out Boolean);

   --  Enable or disable promotion of warnings to errors.
   --  @param The_Policy Policy to update.
   --  @param Enabled True to promote warnings.
   procedure Set_Promote_Warnings (The_Policy : in out Policy; Enabled : Boolean);

   --  True when The_Policy promotes warnings to errors.
   --  @param The_Policy Policy to query.
   --  @return Promote_Warnings flag.
   function Promote_Warnings (The_Policy : Policy) return Boolean;

   --  Effective severity after promote policy (suppression is separate).
   --  @param Code Diagnostic kind.
   --  @param The_Policy Formatting policy.
   --  @return Error when default is Error, or when a Warning is promoted.
   function Effective_Severity (Code : Error_Codes.Error_Code; The_Policy : Policy) return Error_Codes.Severity;

   --  Render one diagnostic block (filename, line, caret, LV code).
   --  Header is `[error]` or `[warning]` from Effective_Severity.
   --  @param Filename UTF-8 path shown in the header.
   --  @param Span Source span (row/column from First; caret covers First..Last).
   --  @param Source_Text Full UTF-8 source buffer used to extract the line.
   --  @param Code Stable LV error kind.
   --  @param Description UTF-8 human-readable message after the LV label.
   --  @param The_Policy Promote/suppress policy (suppressed codes still format if called).
   --  @return Multi-line UTF-8 text ending with a newline.
   function Format
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String;
      The_Policy  : Policy := Default_Policy) return String;

   --  Same as Format, returning an unbounded string.
   --  @param Filename UTF-8 path shown in the header.
   --  @param Span Source span.
   --  @param Source_Text Full UTF-8 source buffer.
   --  @param Code Stable LV error kind.
   --  @param Description UTF-8 message after the LV label.
   --  @param The_Policy Promote/suppress policy.
   --  @return Multi-line UTF-8 text ending with a newline.
   function Format_Unbounded
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String;
      The_Policy  : Policy := Default_Policy) return Ada.Strings.Unbounded.Unbounded_String;

private

   use type Error_Codes.Error_Code;

   package Code_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Error_Codes.Error_Code);

   type Policy is record
      Promote_Warnings_Value : Boolean := False;
      Suppressions           : Code_Vectors.Vector;
   end record;

end Lovelace.Compiler.Diagnostics;
