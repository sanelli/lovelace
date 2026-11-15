with Ada.Directories;
with Ada.Environment_Variables;

package body Lovelace.Compiler.Module_Path is

   package Env renames Ada.Environment_Variables;

   use type Ada.Directories.File_Kind;

   procedure Append_Unique_Root
     (Roots : in out Path_Sequence; Candidate : String);
   function Contains_Path
     (Paths : Path_Sequence; Candidate : String) return Boolean;
   function Directory_Of (Path : String) return String;
   function Env_Nonempty (Name : String) return Boolean;
   function Expand_User_Home return String;
   function Is_Directory (Path : String) return Boolean;
   function Normalize_Existing (Path : String) return String;
   function Power_Of_Two (Exponent : Natural) return Natural;
   function Split_Segments (Name : String) return Path_Sequence;

   procedure Append_Unique_Root
     (Roots : in out Path_Sequence; Candidate : String)
   is
      Normalized : constant String := Normalize_Existing (Candidate);
   begin
      if not Is_Directory (Candidate) then
         return;
      end if;
      if not Contains_Path (Roots, Normalized) then
         Roots.Append (Normalized);
      end if;
   end Append_Unique_Root;

   function Augusta_Root return String is
   begin
      if Env_Nonempty ("AUGUSTA_HOME") then
         return Env.Value ("AUGUSTA_HOME");
      elsif Env_Nonempty ("LOVELACE_HOME") then
         return
           Join_Root
             (Join_Root (Env.Value ("LOVELACE_HOME"), "lib"), "augusta");
      else
         declare
            Home : constant String := Expand_User_Home;
         begin
            if Home'Length = 0 then
               return "";
            end if;
            return
              Join_Root
                (Join_Root (Join_Root (Home, ".lovelace"), "lib"), "augusta");
         end;
      end if;
   end Augusta_Root;

   function Contains_Path
     (Paths : Path_Sequence; Candidate : String) return Boolean is
   begin
      for Index in 1 .. Natural (Paths.Length) loop
         if Paths.Element (Index) = Candidate then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Path;

   function Default_Search_Roots
     (Root_Source_Path : String; Include_Paths : Path_Sequence)
      return Path_Sequence
   is
      Roots : Path_Sequence;
   begin
      Append_Unique_Root (Roots, Directory_Of (Root_Source_Path));
      Append_Unique_Root (Roots, Ada.Directories.Current_Directory);

      for Index in 1 .. Natural (Include_Paths.Length) loop
         Append_Unique_Root (Roots, Include_Paths.Element (Index));
      end loop;

      declare
         Augusta : constant String := Augusta_Root;
      begin
         if Augusta'Length > 0 then
            Append_Unique_Root (Roots, Augusta);
         end if;
      end;

      return Roots;
   end Default_Search_Roots;

   function Directory_Of (Path : String) return String is
   begin
      return Ada.Directories.Containing_Directory (Path);
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         return ".";
   end Directory_Of;

   function Env_Nonempty (Name : String) return Boolean is
   begin
      return Env.Exists (Name) and then Env.Value (Name)'Length > 0;
   end Env_Nonempty;

   function Expand_User_Home return String is
   begin
      if Env_Nonempty ("HOME") then
         return Env.Value ("HOME");
      elsif Env_Nonempty ("USERPROFILE") then
         return Env.Value ("USERPROFILE");
      else
         return "";
      end if;
   end Expand_User_Home;

   function Is_Directory (Path : String) return Boolean is
   begin
      return
        Path'Length > 0
        and then Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         return False;
   end Is_Directory;

   function Join_Root (Root : String; Relative : String) return String is
   begin
      if Root'Length = 0 then
         return Relative;
      end if;
      if Relative'Length = 0 then
         return Root;
      end if;

      if Root (Root'Last) = '/' or else Root (Root'Last) = '\' then
         if Relative (Relative'First) = '/'
           or else Relative (Relative'First) = '\'
         then
            return Root & Relative (Relative'First + 1 .. Relative'Last);
         end if;
         return Root & Relative;
      end if;

      if Relative (Relative'First) = '/'
        or else Relative (Relative'First) = '\'
      then
         return Root & Relative;
      end if;

      return Root & "/" & Relative;
   end Join_Root;

   function Module_To_Relative_Candidates (Name : String) return Path_Sequence
   is
      Segments   : constant Path_Sequence := Split_Segments (Name);
      Seg_Count  : constant Natural := Natural (Segments.Length);
      Candidates : Path_Sequence;
   begin
      if Seg_Count = 0 then
         return Candidates;
      end if;

      if Seg_Count = 1 then
         Candidates.Append (Segments.Element (1) & ".love");
         return Candidates;
      end if;

      declare
         Sep_Count : constant Natural := Seg_Count - 1;
         Mask_Max  : constant Natural := Power_Of_Two (Sep_Count) - 1;
      begin
         for Mask in 0 .. Mask_Max loop
            declare
               Buffer : Ada.Strings.Unbounded.Unbounded_String :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Segments.Element (1));
            begin
               for Sep_Index in 0 .. Sep_Count - 1 loop
                  declare
                     Bit_Weight : constant Natural :=
                       Power_Of_Two (Sep_Count - 1 - Sep_Index);
                     Use_Dot    : constant Boolean :=
                       (Mask / Bit_Weight) mod 2 = 1;
                  begin
                     if Use_Dot then
                        Ada.Strings.Unbounded.Append (Buffer, ".");
                     else
                        Ada.Strings.Unbounded.Append (Buffer, "/");
                     end if;
                     Ada.Strings.Unbounded.Append
                       (Buffer, Segments.Element (Sep_Index + 2));
                  end;
               end loop;
               Ada.Strings.Unbounded.Append (Buffer, ".love");
               Candidates.Append (Ada.Strings.Unbounded.To_String (Buffer));
            end;
         end loop;
      end;

      return Candidates;
   end Module_To_Relative_Candidates;

   function Normalize_Existing (Path : String) return String is
   begin
      return Ada.Directories.Full_Name (Path);
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         return Path;
   end Normalize_Existing;

   function Power_Of_Two (Exponent : Natural) return Natural is
      Result : Natural := 1;
   begin
      for Unused in 1 .. Exponent loop
         pragma Unreferenced (Unused);
         Result := Result * 2;
      end loop;
      return Result;
   end Power_Of_Two;

   function Resolve_Module_File
     (Name : String; Roots : Path_Sequence) return Resolve_Result
   is
      Candidates : constant Path_Sequence :=
        Module_To_Relative_Candidates (Name);
      Matches    : Path_Sequence;
   begin
      for Root_Index in 1 .. Natural (Roots.Length) loop
         declare
            Root : constant String := Roots.Element (Root_Index);
         begin
            for Cand_Index in 1 .. Natural (Candidates.Length) loop
               declare
                  Relative : constant String :=
                    Candidates.Element (Cand_Index);
                  Full     : constant String := Join_Root (Root, Relative);
               begin
                  if Ada.Directories.Exists (Full)
                    and then Ada.Directories.Kind (Full)
                             = Ada.Directories.Ordinary_File
                  then
                     declare
                        Normalized : constant String :=
                          Normalize_Existing (Full);
                     begin
                        if not Contains_Path (Matches, Normalized) then
                           Matches.Append (Normalized);
                        end if;
                     end;
                  end if;
               exception
                  when Ada.Directories.Use_Error | Ada.Directories.Name_Error
                  =>
                     null;
               end;
            end loop;
         end;
      end loop;

      case Natural (Matches.Length) is
         when 0      =>
            return (Status => Not_Found);

         when 1      =>
            return
              (Status => Unique,
               Path   =>
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Matches.Element (1)));

         when others =>
            return (Status => Ambiguous, Matches => Matches);
      end case;
   end Resolve_Module_File;

   function Split_Segments (Name : String) return Path_Sequence is
      Segments : Path_Sequence;
      Start    : Positive := Name'First;
   begin
      if Name'Length = 0 then
         return Segments;
      end if;

      for Index in Name'Range loop
         if Name (Index) = '.' then
            if Index > Start then
               Segments.Append (Name (Start .. Index - 1));
            else
               Segments.Append ("");
            end if;
            Start := Index + 1;
         end if;
      end loop;

      if Start <= Name'Last then
         Segments.Append (Name (Start .. Name'Last));
      elsif Name (Name'Last) = '.' then
         Segments.Append ("");
      end if;

      return Segments;
   end Split_Segments;

end Lovelace.Compiler.Module_Path;
