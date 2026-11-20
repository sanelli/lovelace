with Ada.Text_IO;

with Lovelace.Main.Version;

package body Lovelace.Main.Terminal is

   Colour_Is_Enabled : Boolean := True;

   Ansi_Green : constant String := ASCII.ESC & "[32m";
   Ansi_Red   : constant String := ASCII.ESC & "[31m";
   Ansi_Reset : constant String := ASCII.ESC & "[0m";

   function Colour_Enabled return Boolean is
   begin
      return Colour_Is_Enabled;
   end Colour_Enabled;

   procedure Put_Error_Text (Text : String) is
      Start : Positive := Text'First;
   begin
      for Index in Text'Range loop
         if Text (Index) = ASCII.LF then
            declare
               Line : constant String := Text (Start .. Index - 1);
            begin
               if Colour_Is_Enabled
                 and then (Line'Length >= 5
                           and then Line (Line'First .. Line'First + 4)
                                    = "[err]")
               then
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error, Ansi_Red & Line & Ansi_Reset);
               elsif Colour_Is_Enabled
                 and then (Line'Length >= 3
                           and then Line (Line'First) = '['
                           and then Line (Line'First + 1) = 'L'
                           and then Line (Line'First + 2) = 'V')
               then
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error, Ansi_Red & Line & Ansi_Reset);
               else
                  Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Line);
               end if;
            end;
            Start := Index + 1;
         end if;
      end loop;

      if Start <= Text'Last then
         declare
            Line : constant String := Text (Start .. Text'Last);
         begin
            if Colour_Is_Enabled
              and then (Line'Length >= 5
                        and then Line (Line'First .. Line'First + 4) = "[err]")
            then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, Ansi_Red & Line & Ansi_Reset);
            elsif Colour_Is_Enabled
              and then (Line'Length >= 3
                        and then Line (Line'First) = '['
                        and then Line (Line'First + 1) = 'L'
                        and then Line (Line'First + 2) = 'V')
            then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, Ansi_Red & Line & Ansi_Reset);
            else
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Line);
            end if;
         end;
      end if;
   end Put_Error_Text;

   procedure Put_Info (Message : String) is
   begin
      if Colour_Is_Enabled then
         Ada.Text_IO.Put_Line
           (Ansi_Green & "[info]" & Ansi_Reset & " " & Message);
      else
         Ada.Text_IO.Put_Line ("[info] " & Message);
      end if;
   end Put_Info;

   procedure Put_Logo is
   begin
      --  Ada string literals do not escape '\'; a single backslash is one character.
      --  FIGlet-small "Lovelace" (capital L; distinct c vs final e).
      Ada.Text_IO.Put_Line (" _                  _");
      Ada.Text_IO.Put_Line ("| |    _____ _____ | | __ _  ___ ___");
      Ada.Text_IO.Put_Line ("| |__ / _ \ V / -_)| |/ _` |/ __/ -_)");
      Ada.Text_IO.Put_Line ("|____|\___/\_/\___||_|\__,_|\___\___|");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line
        (" Lovelace compiler toolchain " & Version.Product_Version);
      Ada.Text_IO.Put_Line ("");
   end Put_Logo;

   procedure Set_Colour_Enabled (Enabled : Boolean) is
   begin
      Colour_Is_Enabled := Enabled;
   end Set_Colour_Enabled;

end Lovelace.Main.Terminal;
