with Ada.Text_IO;
with AUnit;

package body Lovelace.Test_Status is

   package Results renames AUnit.Test_Results;

   use type AUnit.Message_String;

   ANSI_Reset : constant String := ASCII.ESC & "[0m";
   ANSI_Green : constant String := ASCII.ESC & "[32m";
   ANSI_Red   : constant String := ASCII.ESC & "[31m";
   ANSI_Gray  : constant String := ASCII.ESC & "[90m";
   ANSI_Cyan  : constant String := ASCII.ESC & "[36m";

   Name_Width : constant := 64;

   function Display_Name (Test : Results.Test_Result) return String;
   --  Routine name when set, otherwise test name.

   function Padded_Name (Name : String) return String;
   --  Left-align Name in a fixed-width field.

   procedure Report_List
     (List : Results.Result_Lists.List; Outcome : Test_Outcome);
   --  Print one status line per entry in List.

   function Display_Name (Test : Results.Test_Result) return String is
   begin
      if Test.Routine_Name /= null then
         return Test.Routine_Name.all;
      elsif Test.Test_Name /= null then
         return Test.Test_Name.all;
      else
         return "(unnamed)";
      end if;
   end Display_Name;

   function Padded_Name (Name : String) return String is
      Buffer    : String (1 .. Name_Width) := [others => ' '];
      Copy_Last : Natural;
   begin
      if Name'Length >= Name_Width then
         Buffer := Name (Name'First .. Name'First + Name_Width - 1);
      else
         Copy_Last := Name'Length;
         Buffer (1 .. Copy_Last) := Name;
      end if;
      return Buffer;
   end Padded_Name;

   overriding
   procedure Report
     (Engine  : Silent_Reporter;
      R       : in out Results.Result'Class;
      Options : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options)
   is
      pragma Unreferenced (Engine, R, Options);
   begin
      null;
   end Report;

   overriding
   procedure Report
     (Engine  : Status_Reporter;
      R       : in out Results.Result'Class;
      Options : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options)
   is
      pragma Unreferenced (Engine, Options);
      Success_List : Results.Result_Lists.List;
      Failure_List : Results.Result_Lists.List;
      Error_List   : Results.Result_Lists.List;
   begin
      Results.Successes (Results.Result (R), Success_List);
      Results.Failures (Results.Result (R), Failure_List);
      Results.Errors (Results.Result (R), Error_List);

      Report_List (Success_List, Ok);
      Report_List (Failure_List, Fail);
      Report_List (Error_List, Fail);
   end Report;

   procedure Report_List
     (List : Results.Result_Lists.List; Outcome : Test_Outcome)
   is
      Cursor : Results.Result_Lists.Cursor :=
        Results.Result_Lists.First (List);
   begin
      while Results.Result_Lists.Has_Element (Cursor) loop
         Report_Test_Result
           (Display_Name (Results.Result_Lists.Element (Cursor)), Outcome);
         Results.Result_Lists.Next (Cursor);
      end loop;
   end Report_List;

   procedure Report_Suite_Footer is
   begin
      Ada.Text_IO.New_Line;
   end Report_Suite_Footer;

   procedure Report_Suite_Header (Name : String) is
      Middle : constant String := "== " & Name & " ==";
      Border : constant String (Middle'Range) := [others => '='];
   begin
      Ada.Text_IO.Put_Line (ANSI_Cyan & Border & ANSI_Reset);
      Ada.Text_IO.Put_Line (ANSI_Cyan & Middle & ANSI_Reset);
      Ada.Text_IO.Put_Line (ANSI_Cyan & Border & ANSI_Reset);
   end Report_Suite_Header;

   procedure Report_Test_Result (Name : String; Outcome : Test_Outcome) is
      Prefix : constant String := Padded_Name (Name);
   begin
      case Outcome is
         when Ok           =>
            Ada.Text_IO.Put_Line
              (Prefix & " [" & ANSI_Green & "OK" & ANSI_Reset & "]");

         when Fail         =>
            Ada.Text_IO.Put_Line
              (Prefix & " [" & ANSI_Red & "FAIL" & ANSI_Reset & "]");

         when Inconclusive =>
            Ada.Text_IO.Put_Line
              (Prefix & " [" & ANSI_Gray & "INCONCLUSIVE" & ANSI_Reset & "]");
      end case;
   end Report_Test_Result;

end Lovelace.Test_Status;
