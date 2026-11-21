with Ada.Characters.Handling;
with Ada.Strings.Unbounded;

package body Lovelace.Compiler.Backend.Wit is

   function Sanitize_Package_Name (Name : String) return String;
   --  Lowercase ASCII letters/digits; map every other byte to '-'; empty becomes "module".

   function Sanitize_Package_Name (Name : String) return String is
      Buffer : String (1 .. Name'Length);
      Last   : Natural := 0;
   begin
      for Index in Name'Range loop
         declare
            Byte : constant Character := Name (Index);
         begin
            if Byte in 'A' .. 'Z' then
               Last := Last + 1;
               Buffer (Last) := Ada.Characters.Handling.To_Lower (Byte);
            elsif Byte in 'a' .. 'z' or else Byte in '0' .. '9' then
               Last := Last + 1;
               Buffer (Last) := Byte;
            elsif Last = 0 or else Buffer (Last) /= '-' then
               Last := Last + 1;
               Buffer (Last) := '-';
            end if;
         end;
      end loop;

      declare
         First : Natural := 1;
      begin
         while First <= Last and then Buffer (First) = '-' loop
            First := First + 1;
         end loop;

         while Last >= First and then Buffer (Last) = '-' loop
            Last := Last - 1;
         end loop;

         if Last < First then
            return "module";
         end if;

         return Buffer (First .. Last);
      end;
   end Sanitize_Package_Name;

   function To_Wit (The_Model : Model.Component_Model) return String is
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Strings.Unbounded.Append
        (Buffer,
         "package love:"
         & Sanitize_Package_Name (Model.Module_Name (The_Model))
         & "@"
         & Model.Module_Version (The_Model)
         & ";"
         & ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, "world module {" & ASCII.LF);

      if Model.Has_Wasi_Stdout (The_Model) then
         Ada.Strings.Unbounded.Append (Buffer, "  import " & Model.Wasi_Cli_Stdout_Import_Name & ";" & ASCII.LF);
      end if;

      for Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export :=
              Model.Get_Export (The_Model, Index);
            Export_Name : constant String :=
              Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
         begin
            if The_Export.Returns_Result then
               Ada.Strings.Unbounded.Append
                 (Buffer, "  export " & Export_Name & ";" & ASCII.LF);
            else
               Ada.Strings.Unbounded.Append
                 (Buffer, "  export " & Export_Name & ": func();" & ASCII.LF);
            end if;
         end;
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, "}" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end To_Wit;

end Lovelace.Compiler.Backend.Wit;
