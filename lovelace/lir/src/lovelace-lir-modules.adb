with Interfaces;

with Lovelace.Common.Utf_8;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Modules is

   package Types renames Lovelace.Lir.Types;

   use type Interfaces.Unsigned_32;

   procedure Append_Dependency
     (The_Module         : in out Module;
      Dependency_Name    : String;
      Dependency_Version : String := Default_Module_Version)
   is
   begin
      The_Module.Dependencies.Append
        (Dependency'
           (Name    =>
              Ada.Strings.Unbounded.To_Unbounded_String (Dependency_Name),
            Version =>
              Ada.Strings.Unbounded.To_Unbounded_String
                (Dependency_Version)));
   end Append_Dependency;

   procedure Append_Subroutine
     (The_Module : in out Module; The_Subroutine : Subroutines.Subroutine) is
   begin
      The_Module.Subroutines.Append (The_Subroutine);
   end Append_Subroutine;

   function Create (Name : String) return Module is
   begin
      return
        (Module_Name           => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Module_Version_Value  =>
           Ada.Strings.Unbounded.To_Unbounded_String (Default_Module_Version),
         Flags_Value           => 0,
         Origin_Value          => (Present => False),
         Dependencies          => Dependency_Vectors.Empty_Vector,
         Subroutines           => Subroutine_Vectors.Empty_Vector);
   end Create;

   function Dependency_Count (The_Module : Module) return Natural is
   begin
      return Natural (The_Module.Dependencies.Length);
   end Dependency_Count;

   function Dependency_Name
     (The_Module : Module; Index : Positive) return String is
   begin
      return
        Ada.Strings.Unbounded.To_String
          (The_Module.Dependencies.Element (Index).Name);
   end Dependency_Name;

   function Dependency_Version
     (The_Module : Module; Index : Positive) return String is
   begin
      return
        Ada.Strings.Unbounded.To_String
          (The_Module.Dependencies.Element (Index).Version);
   end Dependency_Version;

   function Flags (The_Module : Module) return Module_Flags is
   begin
      return The_Module.Flags_Value;
   end Flags;

   function Get_Subroutine
     (The_Module : Module; Index : Positive) return Subroutines.Subroutine is
   begin
      return The_Module.Subroutines.Element (Index);
   end Get_Subroutine;

   function Module_Version (The_Module : Module) return String is
   begin
      return
        Ada.Strings.Unbounded.To_String (The_Module.Module_Version_Value);
   end Module_Version;

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

   procedure Set_Module_Version
     (The_Module : in out Module; Version : String)
   is
   begin
      The_Module.Module_Version_Value :=
        Ada.Strings.Unbounded.To_Unbounded_String (Version);
   end Set_Module_Version;

   procedure Set_Origin
     (The_Module : in out Module; The_Origin : Module_Origin) is
   begin
      The_Module.Origin_Value := (Present => True, Value => The_Origin);
   end Set_Origin;

   function Subroutine_Count (The_Module : Module) return Natural is
   begin
      return Natural (The_Module.Subroutines.Length);
   end Subroutine_Count;

   function Validate
     (The_Module : Module) return Errors.Validation_Results.Result
   is
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
                 (Source => Source,
                  Index  => Index,
                  Point  => Point,
                  Length => Length,
                  Valid  => Valid);

               if not Valid or else Length = 0 then
                  return False;
               end if;

               Index := Index + Length;
            end;
         end loop;

         return True;
      end Is_Valid_Utf_8;

      Module_Name_Text : constant String := Name (The_Module);
      Version_Text     : constant String := Module_Version (The_Module);
      Entrypoint_Count : Natural := 0;
   begin
      if Module_Name_Text'Length = 0 then
         return Errors.Validation_Results.From_Failure (Errors.Empty_Name);
      end if;

      if not Is_Valid_Utf_8 (Module_Name_Text) then
         return Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
      end if;

      if Version_Text'Length = 0 then
         return Errors.Validation_Results.From_Failure (Errors.Empty_Name);
      end if;

      if not Is_Valid_Utf_8 (Version_Text) then
         return Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
      end if;

      for Dependency_Index in 1 .. Dependency_Count (The_Module) loop
         declare
            Depend_Text  : constant String :=
              Dependency_Name (The_Module, Dependency_Index);
            Version_Text : constant String :=
              Dependency_Version (The_Module, Dependency_Index);
         begin
            if Depend_Text'Length = 0 or else Version_Text'Length = 0 then
               return
                 Errors.Validation_Results.From_Failure (Errors.Empty_Name);
            end if;

            if not Is_Valid_Utf_8 (Depend_Text)
              or else not Is_Valid_Utf_8 (Version_Text)
            then
               return
                 Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
            end if;

            if Depend_Text = Module_Name_Text then
               return
                 Errors.Validation_Results.From_Failure
                   (Errors.Self_Dependency);
            end if;

            for Prior_Index in 1 .. Dependency_Index - 1 loop
               if Dependency_Name (The_Module, Prior_Index) = Depend_Text then
                  return
                    Errors.Validation_Results.From_Failure
                      (Errors.Duplicate_Name);
               end if;
            end loop;
         end;
      end loop;

      for Subroutine_Index in 1 .. Subroutine_Count (The_Module) loop
         declare
            The_Subroutine       : constant Subroutines.Subroutine :=
              Get_Subroutine (The_Module, Subroutine_Index);
            The_Signature        : constant Subroutines.Signature :=
              Subroutines.Get_Signature (The_Subroutine);
            Subroutine_Name_Text : constant String :=
              Ada.Strings.Unbounded.To_String (The_Signature.Name);
         begin
            if Subroutine_Name_Text'Length = 0 then
               return
                 Errors.Validation_Results.From_Failure (Errors.Empty_Name);
            end if;

            if not Is_Valid_Utf_8 (Subroutine_Name_Text) then
               return
                 Errors.Validation_Results.From_Failure (Errors.Invalid_Utf_8);
            end if;

            declare
               From_Dep : constant Subroutines.From_Dependency_Option :=
                 Subroutines.From_Dependency (The_Subroutine);
            begin
               case From_Dep.Present is
                  when False =>
                     null;

                  when True  =>
                     declare
                        Dep_Name : constant String :=
                          Ada.Strings.Unbounded.To_String
                            (From_Dep.Module_Name);
                     begin
                        if Dep_Name'Length = 0 then
                           return
                             Errors.Validation_Results.From_Failure
                               (Errors.Empty_Name);
                        end if;
                        if not Is_Valid_Utf_8 (Dep_Name) then
                           return
                             Errors.Validation_Results.From_Failure
                               (Errors.Invalid_Utf_8);
                        end if;
                     end;
               end case;
            end;

            --  Duplicate subroutine names are allowed (overloads); Call uses index.

            for Parameter_Index in 1 .. Types.Length (The_Signature.Parameters)
            loop
               declare
                  The_Parameter       : constant Types.Parameter :=
                    Types.Element (The_Signature.Parameters, Parameter_Index);
                  Parameter_Name_Text : constant String :=
                    Ada.Strings.Unbounded.To_String (The_Parameter.Name);
               begin
                  if Parameter_Name_Text'Length = 0 then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Empty_Name);
                  end if;

                  if not Is_Valid_Utf_8 (Parameter_Name_Text) then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Utf_8);
                  end if;

                  for Prior_Parameter_Index in 1 .. Parameter_Index - 1 loop
                     declare
                        Prior_Parameter : constant Types.Parameter :=
                          Types.Element
                            (The_Signature.Parameters, Prior_Parameter_Index);
                     begin
                        if Ada.Strings.Unbounded.To_String
                             (Prior_Parameter.Name)
                          = Parameter_Name_Text
                        then
                           return
                             Errors.Validation_Results.From_Failure
                               (Errors.Duplicate_Name);
                        end if;
                     end;
                  end loop;
               end;
            end loop;

            declare
               Locals : constant Types.Parameter_Sequence :=
                 Subroutines.Get_Locals (The_Subroutine);
            begin
               for Local_Index in 1 .. Types.Length (Locals) loop
                  declare
                     The_Local       : constant Types.Parameter :=
                       Types.Element (Locals, Local_Index);
                     Local_Name_Text : constant String :=
                       Ada.Strings.Unbounded.To_String (The_Local.Name);
                  begin
                     if Local_Name_Text'Length = 0 then
                        return
                          Errors.Validation_Results.From_Failure
                            (Errors.Empty_Name);
                     end if;

                     if not Is_Valid_Utf_8 (Local_Name_Text) then
                        return
                          Errors.Validation_Results.From_Failure
                            (Errors.Invalid_Utf_8);
                     end if;

                     for Prior_Local_Index in 1 .. Local_Index - 1 loop
                        declare
                           Prior_Local : constant Types.Parameter :=
                             Types.Element (Locals, Prior_Local_Index);
                        begin
                           if Ada.Strings.Unbounded.To_String
                                (Prior_Local.Name)
                             = Local_Name_Text
                           then
                              return
                                Errors.Validation_Results.From_Failure
                                  (Errors.Duplicate_Name);
                           end if;
                        end;
                     end loop;

                     for Parameter_Index in
                       1 .. Types.Length (The_Signature.Parameters)
                     loop
                        declare
                           The_Parameter : constant Types.Parameter :=
                             Types.Element
                               (The_Signature.Parameters, Parameter_Index);
                        begin
                           if Ada.Strings.Unbounded.To_String
                                (The_Parameter.Name)
                             = Local_Name_Text
                           then
                              return
                                Errors.Validation_Results.From_Failure
                                  (Errors.Duplicate_Name);
                           end if;
                        end;
                     end loop;
                  end;
               end loop;
            end;

            declare
               The_Flags   : constant Subroutines.Subroutine_Flags :=
                 Subroutines.Get_Flags (The_Subroutine);
               The_Native  : constant Subroutines.Native_Binding_Option :=
                 Subroutines.Native (The_Subroutine);
               Body_Instrs : constant Instructions.Instruction_Sequence :=
                 Subroutines.Get_Instructions (The_Subroutine);
               Local_Count : constant Natural :=
                 Types.Length (Subroutines.Get_Locals (The_Subroutine));
            begin
               if Subroutines.Has_Entrypoint (The_Flags) then
                  Entrypoint_Count := Entrypoint_Count + 1;
               end if;

               if Subroutines.Has_Native (The_Flags) /= The_Native.Present then
                  return
                    Errors.Validation_Results.From_Failure
                      (Errors.Invalid_Native_Binding);
               end if;

               if Subroutines.Has_Intrinsic (The_Flags)
                 and then Subroutines.Has_Native (The_Flags)
               then
                  return
                    Errors.Validation_Results.From_Failure
                      (Errors.Invalid_Native_Binding);
               end if;

               if Subroutines.Has_Intrinsic (The_Flags) then
                  if Subroutines.Has_Entrypoint (The_Flags) then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Native_Binding);
                  end if;

                  if Instructions.Length (Body_Instrs) /= 0 then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Native_Binding);
                  end if;

                  if Local_Count /= 0 then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Native_Binding);
                  end if;
               end if;

               if The_Native.Present then
                  declare
                     Library_Text  : constant String :=
                       Ada.Strings.Unbounded.To_String
                         (The_Native.Value.Library);
                     Function_Text : constant String :=
                       Ada.Strings.Unbounded.To_String
                         (The_Native.Value.Function_Name);
                  begin
                     if Library_Text'Length = 0
                       or else Function_Text'Length = 0
                     then
                        return
                          Errors.Validation_Results.From_Failure
                            (Errors.Empty_Name);
                     end if;

                     if not Is_Valid_Utf_8 (Library_Text)
                       or else not Is_Valid_Utf_8 (Function_Text)
                     then
                        return
                          Errors.Validation_Results.From_Failure
                            (Errors.Invalid_Utf_8);
                     end if;
                  end;

                  if Subroutines.Has_Entrypoint (The_Flags) then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Native_Binding);
                  end if;

                  if Instructions.Length (Body_Instrs) /= 0 then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Native_Binding);
                  end if;

                  if Local_Count /= 0 then
                     return
                       Errors.Validation_Results.From_Failure
                         (Errors.Invalid_Native_Binding);
                  end if;
               end if;

               declare
                  Param_Count : constant Natural :=
                    Types.Length (The_Signature.Parameters);
                  Slot_Limit  : constant Natural := Param_Count + Local_Count;
               begin
                  for Instruction_Index in
                    1 .. Instructions.Length (Body_Instrs)
                  loop
                     declare
                        Item : constant Instructions.Instruction :=
                          Instructions.Element
                            (Body_Instrs, Instruction_Index);
                     begin
                        case Item.Operation is
                           when Opcodes.No_Operation | Opcodes.Constant_I32 =>
                              null;

                           when Opcodes.Call                                =>
                              if Item.Target_Index = 0
                                or else Natural (Item.Target_Index)
                                        > Subroutine_Count (The_Module)
                              then
                                 return
                                   Errors.Validation_Results.From_Failure
                                     (Errors.Invalid_Call_Target);
                              end if;

                           when Opcodes.Local_Get | Opcodes.Local_Set       =>
                              if Item.Local_Index = 0
                                or else Natural (Item.Local_Index) > Slot_Limit
                              then
                                 return
                                   Errors.Validation_Results.From_Failure
                                     (Errors.Invalid_Local_Index);
                              end if;
                        end case;
                     end;
                  end loop;
               end;
            end;
         end;
      end loop;

      if Entrypoint_Count > 1 then
         return
           Errors.Validation_Results.From_Failure
             (Errors.Duplicate_Entrypoint);
      end if;

      return Errors.Validation_Results.From_Success ((null record));
   end Validate;

end Lovelace.Lir.Modules;
