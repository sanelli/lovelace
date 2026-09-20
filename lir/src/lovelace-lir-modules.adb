with Lovelace.Common.Utf_8;

package body Lovelace.Lir.Modules is

   procedure Append_Dependency (The_Module : in out Module; Dependency_Name : String) is
   begin
      The_Module.Dependencies.Append (Ada.Strings.Unbounded.To_Unbounded_String (Dependency_Name));
   end Append_Dependency;

   procedure Append_Subroutine (The_Module : in out Module; The_Subroutine : Subroutines.Subroutine) is
   begin
      The_Module.Subroutines.Append (The_Subroutine);
   end Append_Subroutine;

   function Create (Name : String) return Module is
   begin
      return
        (Module_Name  => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Flags_Value  => 0,
         Origin_Value => (Present => False),
         Dependencies => Dependency_Vectors.Empty_Vector,
         Subroutines  => Subroutine_Vectors.Empty_Vector);
   end Create;

   function Dependency_Count (The_Module : Module) return Natural is
   begin
      return Natural (The_Module.Dependencies.Length);
   end Dependency_Count;

   function Dependency_Name (The_Module : Module; Index : Positive) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Module.Dependencies.Element (Index));
   end Dependency_Name;

   function Flags (The_Module : Module) return Module_Flags is
   begin
      return The_Module.Flags_Value;
   end Flags;

   function Get_Subroutine (The_Module : Module; Index : Positive) return Subroutines.Subroutine is
   begin
      return The_Module.Subroutines.Element (Index);
   end Get_Subroutine;

   function Name (The_Module : Module) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Module.Module_Name);
   end Name;

   function Origin (The_Module : Module) return Origin_Option is
   begin
      return The_Module.Origin_Value;
   end Origin;

   procedure Set_Flags (The_Module : in out Module; Flags : Module_Flags) is
   begin
      The_Module.Flags_Value := Flags;
   end Set_Flags;

   procedure Set_Origin (The_Module : in out Module; The_Origin : Module_Origin) is
   begin
      The_Module.Origin_Value := (Present => True, Value => The_Origin);
   end Set_Origin;

   function Subroutine_Count (The_Module : Module) return Natural is
   begin
      return Natural (The_Module.Subroutines.Length);
   end Subroutine_Count;

   function Validate (The_Module : Module) return Errors.Validation_Results.Result is
      function Is_Valid_Utf_8 (Source : String) return Boolean;
      --  True when Source is empty or every byte sequence is valid UTF-8.

      function Is_Valid_Utf_8 (Source : String) return Boolean is
         Index : Natural := Source'First;
      begin
         if Source'Length = 0 then
            return True;
         end if;

         while Index <= Source'Last loop
            declare
               Point  : Lovelace.Common.Utf_8.Code_Point;
               Length : Natural;
               Valid  : Boolean;
            begin
               Lovelace.Common.Utf_8.Decode
                 (Source => Source, Index => Index, Point => Point, Length => Length, Valid => Valid);

               if not Valid or else Length = 0 then
                  return False;
               end if;

               Index := Index + Length;
            end;
         end loop;

         return True;
      end Is_Valid_Utf_8;

      Module_Name_Text : constant String := Name (The_Module);
      Entrypoint_Count : Natural := 0;
   begin
      if Module_Name_Text'Length = 0 then
         return Errors.Validation_Results.From_Failure (Errors.Empty_Name);
      end if;

      if not Is_Valid_Utf_8 (Module_Name_Text) then
         return Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
      end if;

      for Dependency_Index in 1 .. Dependency_Count (The_Module) loop
         declare
            Depend_Text : constant String := Dependency_Name (The_Module, Dependency_Index);
         begin
            if Depend_Text'Length = 0 then
               return Errors.Validation_Results.From_Failure (Errors.Empty_Name);
            end if;

            if not Is_Valid_Utf_8 (Depend_Text) then
               return Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
            end if;

            if Depend_Text = Module_Name_Text then
               return Errors.Validation_Results.From_Failure (Errors.Self_Dependency);
            end if;

            for Prior_Index in 1 .. Dependency_Index - 1 loop
               if Dependency_Name (The_Module, Prior_Index) = Depend_Text then
                  return Errors.Validation_Results.From_Failure (Errors.Duplicate_Name);
               end if;
            end loop;
         end;
      end loop;

      for Subroutine_Index in 1 .. Subroutine_Count (The_Module) loop
         declare
            The_Subroutine       : constant Subroutines.Subroutine := Get_Subroutine (The_Module, Subroutine_Index);
            The_Signature        : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
            Subroutine_Name_Text : constant String := Ada.Strings.Unbounded.To_String (The_Signature.Name);
         begin
            if Subroutine_Name_Text'Length = 0 then
               return Errors.Validation_Results.From_Failure (Errors.Empty_Name);
            end if;

            if not Is_Valid_Utf_8 (Subroutine_Name_Text) then
               return Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
            end if;

            for Prior_Index in 1 .. Subroutine_Index - 1 loop
               declare
                  Prior_Signature : constant Subroutines.Signature :=
                    Subroutines.Get_Signature (Get_Subroutine (The_Module, Prior_Index));
               begin
                  if Ada.Strings.Unbounded.To_String (Prior_Signature.Name) = Subroutine_Name_Text then
                     return Errors.Validation_Results.From_Failure (Errors.Duplicate_Name);
                  end if;
               end;
            end loop;

            if Subroutines.Has_Entrypoint (Subroutines.Get_Flags (The_Subroutine)) then
               Entrypoint_Count := Entrypoint_Count + 1;
            end if;
         end;
      end loop;

      if Entrypoint_Count > 1 then
         return Errors.Validation_Results.From_Failure (Errors.Duplicate_Entrypoint);
      end if;

      return Errors.Validation_Results.From_Success ((null record));
   end Validate;

end Lovelace.Lir.Modules;
