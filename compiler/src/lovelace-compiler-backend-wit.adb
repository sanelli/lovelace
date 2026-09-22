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
            else
               Last := Last + 1;
               Buffer (Last) := '-';
            end if;
         end;
      end loop;

      if Last = 0 then
         return "module";
      end if;

      return Buffer (1 .. Last);
   end Sanitize_Package_Name;

   function To_Wit (The_Model : Model.Component_Model) return String is
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Strings.Unbounded.Append
        (Buffer, "package love:" & Sanitize_Package_Name (Model.Module_Name (The_Model)) & "@0.1.0;" & ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, "world module {" & ASCII.LF);

      for Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Index);
            Export_Name : constant String := Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
         begin
            if The_Export.Returns_Result then
               Ada.Strings.Unbounded.Append (Buffer, "  export " & Export_Name & ": func() -> result;" & ASCII.LF);
            else
               Ada.Strings.Unbounded.Append (Buffer, "  export " & Export_Name & ": func();" & ASCII.LF);
            end if;
         end;
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, "}" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end To_Wit;

end Lovelace.Compiler.Backend.Wit;
