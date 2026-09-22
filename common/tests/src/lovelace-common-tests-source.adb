with AUnit.Assertions;

with Lovelace.Common.Source;

package body Lovelace.Common.Tests.Source is

   procedure Test_Absent_Filename (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Option : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Absent_Filename;
   begin
      AUnit.Assertions.Assert (Condition => not The_Option.Present, Message => "Absent_Filename sets Present False");
   end Test_Absent_Filename;

   procedure Test_Same_Storage_Filename_Option (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Left_Absent   : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Absent_Filename;
      Right_Absent  : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Absent_Filename;
      Holder        : constant Lovelace.Common.Source.Shared_Filename :=
        Lovelace.Common.Source.From_Utf_8 ("shared.love");
      Left_Present  : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Some_Filename (Holder);
      Right_Present : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Some_Filename (Holder);
      Other_Holder  : constant Lovelace.Common.Source.Shared_Filename :=
        Lovelace.Common.Source.From_Utf_8 ("shared.love");
      Other_Present : constant Lovelace.Common.Source.Filename_Option :=
        Lovelace.Common.Source.Some_Filename (Other_Holder);
   begin
      AUnit.Assertions.Assert
        (Condition => Lovelace.Common.Source.Same_Storage (Left_Absent, Right_Absent),
         Message   => "two absent options share storage relation");
      AUnit.Assertions.Assert
        (Condition => Lovelace.Common.Source.Same_Storage (Left_Present, Right_Present),
         Message   => "options from one holder share storage");
      AUnit.Assertions.Assert
        (Condition => not Lovelace.Common.Source.Same_Storage (Left_Present, Left_Absent),
         Message   => "present and absent do not share storage");
      AUnit.Assertions.Assert
        (Condition => not Lovelace.Common.Source.Same_Storage (Left_Present, Other_Present),
         Message   => "options from distinct holders do not share storage");
   end Test_Same_Storage_Filename_Option;

   procedure Test_Same_Storage_Shared_Filename (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      First  : constant Lovelace.Common.Source.Shared_Filename := Lovelace.Common.Source.From_Utf_8 ("unit.love");
      Second : constant Lovelace.Common.Source.Shared_Filename := First;
      Third  : constant Lovelace.Common.Source.Shared_Filename := Lovelace.Common.Source.From_Utf_8 ("unit.love");
   begin
      AUnit.Assertions.Assert
        (Condition => Lovelace.Common.Source.Same_Storage (First, Second), Message => "copy of holder shares storage");
      AUnit.Assertions.Assert
        (Condition => not Lovelace.Common.Source.Same_Storage (First, Third),
         Message   => "separate From_Utf_8 calls do not share storage");
   end Test_Same_Storage_Shared_Filename;

   procedure Test_Source_Span_Fields (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      First : constant Lovelace.Common.Source.Source_Position := (Byte_Index => 1, Line => 2, Column => 3);
      Last  : constant Lovelace.Common.Source.Source_Position := (Byte_Index => 10, Line => 4, Column => 5);
      Span  : constant Lovelace.Common.Source.Source_Span := (First => First, Last => Last);
   begin
      AUnit.Assertions.Assert (Condition => Span.First.Byte_Index = 1, Message => "First.Byte_Index");
      AUnit.Assertions.Assert (Condition => Span.First.Line = 2, Message => "First.Line");
      AUnit.Assertions.Assert (Condition => Span.First.Column = 3, Message => "First.Column");
      AUnit.Assertions.Assert (Condition => Span.Last.Byte_Index = 10, Message => "Last.Byte_Index");
      AUnit.Assertions.Assert (Condition => Span.Last.Line = 4, Message => "Last.Line");
      AUnit.Assertions.Assert (Condition => Span.Last.Column = 5, Message => "Last.Column");
   end Test_Source_Span_Fields;

   procedure Test_To_Utf_8 (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Holder : constant Lovelace.Common.Source.Shared_Filename := Lovelace.Common.Source.From_Utf_8 ("path.love");
      Option : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Some_Filename (Holder);
      Absent : constant Lovelace.Common.Source.Filename_Option := Lovelace.Common.Source.Absent_Filename;
   begin
      AUnit.Assertions.Assert
        (Condition => Lovelace.Common.Source.To_Utf_8 (Holder) = "path.love", Message => "holder To_Utf_8");
      AUnit.Assertions.Assert
        (Condition => Lovelace.Common.Source.To_Utf_8 (Option) = "path.love", Message => "present option To_Utf_8");
      AUnit.Assertions.Assert
        (Condition => Lovelace.Common.Source.To_Utf_8 (Absent) = "", Message => "absent option To_Utf_8");
   end Test_To_Utf_8;

end Lovelace.Common.Tests.Source;
