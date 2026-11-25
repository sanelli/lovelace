with Ada.Characters.Handling;
with Ada.Strings.Unbounded;

package body Lovelace.Compiler.Backend.Names is

   procedure Append_Sanitized_Byte (Byte : Character; Buffer : in out String; Last : in out Natural);
   --  Map one source byte into Buffer as lowercase alnum or a single '-'.

   procedure Append_Sanitized_Segments
     (Module_Name : String; Segments : in out Ada.Strings.Unbounded.Unbounded_String; Separator : Character);
   --  Split Module_Name on '.', sanitize each part, join with Separator.

   function Trim_Dashes (Buffer : String; Last : Natural; Empty_Fallback : String) return String;
   --  Strip leading/trailing '-' from Buffer (1 .. Last); Empty_Fallback if empty.

   procedure Append_Sanitized_Byte (Byte : Character; Buffer : in out String; Last : in out Natural) is
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
   end Append_Sanitized_Byte;

   procedure Append_Sanitized_Segments
     (Module_Name : String; Segments : in out Ada.Strings.Unbounded.Unbounded_String; Separator : Character)
   is
      Start : Natural := Module_Name'First;
      First : Boolean := True;
   begin
      if Module_Name'Length = 0 then
         Ada.Strings.Unbounded.Append (Segments, Sanitize_Segment (""));
         return;
      end if;

      for Index in Module_Name'Range loop
         if Module_Name (Index) = '.' then
            declare
               Part : constant String := (if Index > Start then Module_Name (Start .. Index - 1) else "");
            begin
               if not First then
                  Ada.Strings.Unbounded.Append (Segments, Separator);
               end if;
               First := False;
               Ada.Strings.Unbounded.Append (Segments, Sanitize_Segment (Part));
            end;
            Start := Index + 1;
         end if;
      end loop;

      declare
         Part : constant String := (if Start <= Module_Name'Last then Module_Name (Start .. Module_Name'Last) else "");
      begin
         if not First then
            Ada.Strings.Unbounded.Append (Segments, Separator);
         end if;
         Ada.Strings.Unbounded.Append (Segments, Sanitize_Segment (Part));
      end;
   end Append_Sanitized_Segments;

   function Component_Identity (Module_Name : String; Version : String) return String is
      Path : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Append_Sanitized_Segments (Module_Name, Path, '/');
      return Namespace & ":" & Ada.Strings.Unbounded.To_String (Path) & "@" & Version;
   end Component_Identity;

   function Sanitize_Segment (Segment : String) return String is
      Buffer : String (1 .. Segment'Length);
      Last   : Natural := 0;
   begin
      for Index in Segment'Range loop
         Append_Sanitized_Byte (Segment (Index), Buffer, Last);
      end loop;

      return Trim_Dashes (Buffer, Last, "module");
   end Sanitize_Segment;

   function Trim_Dashes (Buffer : String; Last : Natural; Empty_Fallback : String) return String is
      First : Natural := 1;
      Stop  : Natural := Last;
   begin
      while First <= Stop and then Buffer (First) = '-' loop
         First := First + 1;
      end loop;

      while Stop >= First and then Buffer (Stop) = '-' loop
         Stop := Stop - 1;
      end loop;

      if Stop < First then
         return Empty_Fallback;
      end if;

      return Buffer (First .. Stop);
   end Trim_Dashes;

   function Wit_Package_Identity (Module_Name : String; Version : String) return String is
      Path : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Append_Sanitized_Segments (Module_Name, Path, '-');
      return Namespace & ":" & Ada.Strings.Unbounded.To_String (Path) & "@" & Version;
   end Wit_Package_Identity;

end Lovelace.Compiler.Backend.Names;
