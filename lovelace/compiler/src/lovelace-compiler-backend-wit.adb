with Ada.Strings.Unbounded;

with Lovelace.Compiler.Backend.Names;

package body Lovelace.Compiler.Backend.Wit is

   function To_Wit (The_Model : Model.Component_Model) return String is
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Strings.Unbounded.Append
        (Buffer,
         "package "
         & Names.Wit_Package_Identity (Model.Module_Name (The_Model), Model.Module_Version (The_Model))
         & ";"
         & ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, "world module {" & ASCII.LF);

      if Model.Has_Wasi_Stdout (The_Model) then
         Ada.Strings.Unbounded.Append (Buffer, "  import " & Model.Wasi_Cli_Stdout_Import_Name & ";" & ASCII.LF);
      end if;

      for Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Index);
            Export_Name : constant String := Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
         begin
            if The_Export.Returns_Result then
               Ada.Strings.Unbounded.Append (Buffer, "  export " & Export_Name & ";" & ASCII.LF);
            else
               Ada.Strings.Unbounded.Append (Buffer, "  export " & Export_Name & ": func();" & ASCII.LF);
            end if;
         end;
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, "}" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end To_Wit;

end Lovelace.Compiler.Backend.Wit;
