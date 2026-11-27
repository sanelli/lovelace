with Ada.Command_Line;
with Ada.Strings.Unbounded;

with Lovelace.Main.Compile;
with Lovelace.Main.Help;
with Lovelace.Main.Terminal;
with Lovelace.Main.Version;

package body Lovelace.Main.Dispatch is

   procedure Run (Parsed : Arguments.Parsed_Arguments) is
      Success : Boolean := False;
   begin
      case Parsed.Ok is
         when False =>
            Terminal.Set_Colour_Enabled (True);
            Report_Error ("command line", Ada.Strings.Unbounded.To_String (Parsed.Error_Message));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            return;

         when True  =>
            Terminal.Set_Colour_Enabled (Parsed.Colour_Enabled);
            if Parsed.Show_Logo then
               Terminal.Put_Logo;
            end if;

            case Parsed.Command is
               when Arguments.None    =>
                  declare
                     Ignored : constant Boolean := Help.Run (Parsed.Command_Arguments, To_Standard_Error => True);
                     pragma Unreferenced (Ignored);
                  begin
                     Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                     return;
                  end;

               when Arguments.Help    =>
                  Success := Help.Run (Parsed.Command_Arguments);

               when Arguments.Version =>
                  Version.Run;
                  Success := True;

               when Arguments.Compile =>
                  Success := Compile.Run (Parsed.Command_Arguments);
            end case;

            if Success then
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
            else
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end if;
      end case;
   end Run;

end Lovelace.Main.Dispatch;
