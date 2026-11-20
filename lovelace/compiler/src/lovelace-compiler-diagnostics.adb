with Lovelace.Common.Utf_8;

package body Lovelace.Compiler.Diagnostics is

   function Line_Bounds
     (Source_Text : String;
      Line_Number : Positive;
      First       : out Positive;
      Last        : out Natural) return Boolean;
   --  Set First..Last to the UTF-8 byte range of Line_Number (1-based), excluding the
   --  line ending. Return False when Line_Number is past the end of Source_Text.

   function Caret_Line (Span : Source.Source_Span) return String;
   --  Spaces to Column, then ^ or a run of carets for a multi-column span.

   function Caret_Line (Span : Source.Source_Span) return String is
      Start_Column : constant Positive := Span.First.Column;
      End_Column   : Positive := Span.Last.Column;
      Width        : Positive;
   begin
      if End_Column < Start_Column then
         End_Column := Start_Column;
      end if;
      Width := End_Column - Start_Column + 1;
      declare
         Padding : constant String (1 .. Start_Column - 1) := [others => ' '];
         Marks   : constant String (1 .. Width) := [others => '^'];
      begin
         return Padding & Marks;
      end;
   end Caret_Line;

   function Format
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String) return String
   is
      Line_First : Positive;
      Line_Last  : Natural;
      Have_Line  : constant Boolean :=
        Line_Bounds (Source_Text, Span.First.Line, Line_First, Line_Last);
   begin
      declare
         Header      : constant String :=
           "[err] "
           & Filename
           & ":"
           & Positive'Image (Span.First.Line)
               (2 .. Positive'Image (Span.First.Line)'Last)
           & ","
           & Positive'Image (Span.First.Column)
               (2 .. Positive'Image (Span.First.Column)'Last);
         Source_Line : constant String :=
           (if Have_Line then Source_Text (Line_First .. Line_Last) else "");
         Footer      : constant String :=
           "[" & Error_Codes.Label (Code) & "] " & Description;
      begin
         return
           Header
           & ASCII.LF
           & Source_Line
           & ASCII.LF
           & Caret_Line (Span)
           & ASCII.LF
           & Footer
           & ASCII.LF;
      end;
   end Format;

   function Format_Unbounded
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String) return Ada.Strings.Unbounded.Unbounded_String is
   begin
      return
        Ada.Strings.Unbounded.To_Unbounded_String
          (Format (Filename, Span, Source_Text, Code, Description));
   end Format_Unbounded;

   function Line_Bounds
     (Source_Text : String;
      Line_Number : Positive;
      First       : out Positive;
      Last        : out Natural) return Boolean
   is
      Current_Line : Positive := 1;
      Index        : Positive := Source_Text'First;
   begin
      First := Source_Text'First;
      Last := Source_Text'First - 1;

      if Source_Text'Length = 0 then
         return Line_Number = 1;
      end if;

      while Index <= Source_Text'Last loop
         if Current_Line = Line_Number then
            First := Index;
            while Index <= Source_Text'Last
              and then Source_Text (Index) /= ASCII.LF
              and then Source_Text (Index) /= ASCII.CR
            loop
               Index := Index + 1;
            end loop;
            Last := Index - 1;
            return True;
         end if;

         if Source_Text (Index) = ASCII.CR then
            Index := Index + 1;
            if Index <= Source_Text'Last
              and then Source_Text (Index) = ASCII.LF
            then
               Index := Index + 1;
            end if;
            Current_Line := Current_Line + 1;
         elsif Source_Text (Index) = ASCII.LF then
            Index := Index + 1;
            Current_Line := Current_Line + 1;
         else
            declare
               Point  : Lovelace.Common.Utf_8.Code_Point;
               Length : Natural;
               Valid  : Boolean;
            begin
               Lovelace.Common.Utf_8.Decode
                 (Source_Text, Index, Point, Length, Valid);
               if Valid and then Length > 0 then
                  Index := Index + Length;
               else
                  Index := Index + 1;
               end if;
            end;
         end if;
      end loop;

      if Current_Line = Line_Number then
         First := Source_Text'Last + 1;
         Last := Source_Text'Last;
         return True;
      end if;
      return False;
   end Line_Bounds;

end Lovelace.Compiler.Diagnostics;
