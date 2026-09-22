with Ada.Command_Line;

package body Lovelace.Main.Arguments is

   function Parse return Parsed_Arguments is
      Show_Logo      : Boolean := True;
      Colour_Enabled : Boolean := True;
      Index          : Positive := 1;
      Argument_Count : constant Natural := Ada.Command_Line.Argument_Count;
   begin
      while Index <= Argument_Count loop
         declare
            Token : constant String := Ada.Command_Line.Argument (Index);
         begin
            if Token = "--no-logo" then
               Show_Logo := False;
               Index := Index + 1;
            elsif Token = "--no-colour" then
               Colour_Enabled := False;
               Index := Index + 1;
            elsif Token'Length >= 2 and then Token (Token'First .. Token'First + 1) = "--" then
               return
                 (Ok            => False,
                  Error_Message =>
                    Ada.Strings.Unbounded.To_Unbounded_String
                      ("unknown global option '" & Token & "' (globals must appear before the command)"));
            else
               exit;
            end if;
         end;
      end loop;

      if Index > Argument_Count then
         return
           (Ok                => True,
            Show_Logo         => Show_Logo,
            Colour_Enabled    => Colour_Enabled,
            Command           => None,
            Command_Arguments => String_Vectors.Empty_Vector);
      end if;

      declare
         Command_Token : constant String := Ada.Command_Line.Argument (Index);
         Command       : Command_Kind;
         Rest          : String_Vectors.Vector;
      begin
         if Command_Token = "build" then
            Command := Build;
         elsif Command_Token = "help" then
            Command := Help;
         elsif Command_Token = "version" then
            Command := Version;
         elsif Command_Token'Length >= 2 and then Command_Token (Command_Token'First .. Command_Token'First + 1) = "--"
         then
            return
              (Ok            => False,
               Error_Message =>
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ("expected a command after global options, found '" & Command_Token & "'"));
         else
            return
              (Ok            => False,
               Error_Message =>
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ("unknown command '" & Command_Token & "'; try 'lovelace help'"));
         end if;

         Index := Index + 1;
         while Index <= Argument_Count loop
            Rest.Append (Ada.Command_Line.Argument (Index));
            Index := Index + 1;
         end loop;

         return
           (Ok                => True,
            Show_Logo         => Show_Logo,
            Colour_Enabled    => Colour_Enabled,
            Command           => Command,
            Command_Arguments => Rest);
      end;
   end Parse;

end Lovelace.Main.Arguments;
