with Ada.Command_Line;

package body Lovelace.Main.Arguments is

   function Command_Of (Token : String) return Command_Kind;

   function Failure (Message : String) return Parsed_Arguments;

   function Is_Long_Option (Token : String) return Boolean;

   procedure Leading_Globals
     (Tokens         : String_Vectors.Vector;
      Index          : in out Positive;
      Show_Logo      : in out Boolean;
      Colour_Enabled : in out Boolean;
      Error          : out Ada.Strings.Unbounded.Unbounded_String);

   --  Map a command token to its kind; None when unrecognised.
   function Command_Of (Token : String) return Command_Kind is
   begin
      if Token = "compile" then
         return Compile;
      elsif Token = "help" then
         return Help;
      elsif Token = "version" then
         return Version;
      else
         return None;
      end if;
   end Command_Of;

   --  Build a failed parse result carrying Message.
   function Failure (Message : String) return Parsed_Arguments
   is (Ok            => False,
       Error_Message => Ada.Strings.Unbounded.To_Unbounded_String (Message));

   --  True when Token starts with "--".
   function Is_Long_Option (Token : String) return Boolean
   is (Token'Length >= 2
       and then Token (Token'First .. Token'First + 1) = "--");

   --  Consume leading global options starting at Index. Stops at the first
   --  non-option token. Error is non-empty when an unknown option is found.
   procedure Leading_Globals
     (Tokens         : String_Vectors.Vector;
      Index          : in out Positive;
      Show_Logo      : in out Boolean;
      Colour_Enabled : in out Boolean;
      Error          : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Argument_Count : constant Natural := Natural (Tokens.Length);
   begin
      Error := Ada.Strings.Unbounded.Null_Unbounded_String;

      while Index <= Argument_Count loop
         declare
            Token : constant String := Tokens.Element (Index);
         begin
            if Token = "--no-logo" then
               Show_Logo := False;
            elsif Token = "--no-colour" then
               Colour_Enabled := False;
            elsif Is_Long_Option (Token) then
               Error :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ("unknown global option '"
                    & Token
                    & "' (globals must appear before the command)");
               return;
            else
               return;
            end if;
            Index := Index + 1;
         end;
      end loop;
   end Leading_Globals;

   function Parse (Tokens : String_Vectors.Vector) return Parsed_Arguments is
      Show_Logo      : Boolean := True;
      Colour_Enabled : Boolean := True;
      Index          : Positive := 1;
      Argument_Count : constant Natural := Natural (Tokens.Length);
      Error          : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Leading_Globals (Tokens, Index, Show_Logo, Colour_Enabled, Error);
      if Ada.Strings.Unbounded.Length (Error) > 0 then
         return (Ok => False, Error_Message => Error);
      end if;

      if Index > Argument_Count then
         return
           (Ok                => True,
            Show_Logo         => Show_Logo,
            Colour_Enabled    => Colour_Enabled,
            Command           => None,
            Command_Arguments => String_Vectors.Empty_Vector);
      end if;

      declare
         Command_Token : constant String := Tokens.Element (Index);
         Command       : constant Command_Kind := Command_Of (Command_Token);
         Rest          : String_Vectors.Vector;
      begin
         if Command = None then
            if Is_Long_Option (Command_Token) then
               return
                 Failure
                   ("expected a command after global options, found '"
                    & Command_Token
                    & "'");
            end if;
            return
              Failure
                ("unknown command '"
                 & Command_Token
                 & "'; try 'lovelace help'");
         end if;

         for Rest_Index in Index + 1 .. Argument_Count loop
            Rest.Append (Tokens.Element (Rest_Index));
         end loop;

         return
           (Ok                => True,
            Show_Logo         => Show_Logo,
            Colour_Enabled    => Colour_Enabled,
            Command           => Command,
            Command_Arguments => Rest);
      end;
   end Parse;

   function Parse return Parsed_Arguments is
      Tokens : String_Vectors.Vector;
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         Tokens.Append (Ada.Command_Line.Argument (Index));
      end loop;
      return Parse (Tokens);
   end Parse;

end Lovelace.Main.Arguments;
