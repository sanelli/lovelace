with Interfaces;

with Lovelace.Common.Utf_8;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Modules is

   package Types renames Lovelace.Lir.Types;

   use type Interfaces.Unsigned_32;

   package Results renames Errors.Validation_Results;

   Ok_Result : constant Results.Result := Results.From_Success ((null record));

   --  Simple-name renames so gnatcov can instrument call coverage (no dotted callees).
   function Parameter_Length
     (Sequence : Types.Parameter_Sequence) return Natural renames Types.Length;
   function Parameter_At
     (Sequence : Types.Parameter_Sequence; Index : Positive) return Types.Parameter
     renames Types.Element;
   function Instruction_Length
     (Sequence : Instructions.Instruction_Sequence) return Natural
     renames Instructions.Length;
   function Instruction_At
     (Sequence : Instructions.Instruction_Sequence; Index : Positive)
      return Instructions.Instruction renames Instructions.Element;
   function Unbounded_Text
     (Source : Ada.Strings.Unbounded.Unbounded_String) return String
     renames Ada.Strings.Unbounded.To_String;
   function Get_Instructions
     (The_Subroutine : Subroutines.Subroutine) return Instructions.Instruction_Sequence
     renames Subroutines.Get_Instructions;
   function Get_Locals
     (The_Subroutine : Subroutines.Subroutine) return Types.Parameter_Sequence
     renames Subroutines.Get_Locals;
   function Get_Signature
     (The_Subroutine : Subroutines.Subroutine) return Subroutines.Signature
     renames Subroutines.Get_Signature;
   function Get_Flags
     (The_Subroutine : Subroutines.Subroutine) return Subroutines.Subroutine_Flags
     renames Subroutines.Get_Flags;
   function Has_Entrypoint
     (Flags : Subroutines.Subroutine_Flags) return Boolean
     renames Subroutines.Has_Entrypoint;

   function Dependency_At (The_Module : Module; Index : Positive) return Dependency;
   --  Wrapper so call sites are not dotted (gnatcov call coverage).

   function Check_All_Subroutines (The_Module : Module) return Results.Result;
   function Check_Dependencies (The_Module : Module) return Results.Result;
   function Check_Dependency (The_Module : Module; Index : Positive) return Results.Result;
   function Check_Entrypoints (The_Module : Module) return Results.Result;
   function Check_Flags (The_Subroutine : Subroutines.Subroutine) return Results.Result;
   function Check_Header_Names (The_Subroutine : Subroutines.Subroutine) return Results.Result;
   function Check_Identity (The_Module : Module) return Results.Result;
   function Check_Instruction
     (The_Module : Module; Slot_Limit : Natural; Item : Instructions.Instruction) return Results.Result;
   function Check_Instructions (The_Module : Module; The_Subroutine : Subroutines.Subroutine) return Results.Result;
   function Check_Local_Names
     (Parameters : Types.Parameter_Sequence; Locals : Types.Parameter_Sequence) return Results.Result;
   function Check_Name (Text : String) return Results.Result;
   function Check_Names (First : String; Second : String) return Results.Result;
   function Check_Native_Names (Binding : Subroutines.Native_Binding) return Results.Result;
   function Check_No_Body (The_Subroutine : Subroutines.Subroutine) return Results.Result;
   function Check_One_Subroutine (The_Module : Module; The_Subroutine : Subroutines.Subroutine) return Results.Result;
   function Check_Parameter_Names (Parameters : Types.Parameter_Sequence) return Results.Result;
   function Check_Slot_Names (The_Subroutine : Subroutines.Subroutine) return Results.Result;
   function Has_Name_Before (Sequence : Types.Parameter_Sequence; Limit : Natural; Text : String) return Boolean;
   function Is_Valid_Utf_8 (Source : String) return Boolean;
   --  True when Source is empty or every byte sequence is valid UTF-8.

   procedure Append_Dependency
     (The_Module : in out Module; Dependency_Name : String; Dependency_Version : String := Default_Module_Version) is
   begin
      The_Module.Dependencies.Append
        (Dependency'
           (Name    => Ada.Strings.Unbounded.To_Unbounded_String (Dependency_Name),
            Version => Ada.Strings.Unbounded.To_Unbounded_String (Dependency_Version)));
   end Append_Dependency;

   procedure Append_Subroutine (The_Module : in out Module; The_Subroutine : Subroutines.Subroutine) is
   begin
      The_Module.Subroutines.Append (The_Subroutine);
   end Append_Subroutine;

   function Check_All_Subroutines (The_Module : Module) return Results.Result is
   begin
      for Subroutine_Index in 1 .. Subroutine_Count (The_Module) loop
         declare
            Check : constant Results.Result :=
              Check_One_Subroutine (The_Module, Get_Subroutine (The_Module, Subroutine_Index));
         begin
            if not Check.Ok then
               return Check;
            end if;
         end;
      end loop;
      return Ok_Result;
   end Check_All_Subroutines;

   function Check_Dependencies (The_Module : Module) return Results.Result is
   begin
      for Dependency_Index in 1 .. Dependency_Count (The_Module) loop
         declare
            Check : constant Results.Result := Check_Dependency (The_Module, Dependency_Index);
         begin
            if not Check.Ok then
               return Check;
            end if;
         end;
      end loop;
      return Ok_Result;
   end Check_Dependencies;

   function Check_Dependency (The_Module : Module; Index : Positive) return Results.Result is
      Depend_Text  : constant String := Dependency_Name (The_Module, Index);
      Version_Text : constant String := Dependency_Version (The_Module, Index);
      Check        : constant Results.Result := Check_Names (Depend_Text, Version_Text);
   begin
      if not Check.Ok then
         return Check;
      end if;
      if Depend_Text = Name (The_Module) then
         return Results.From_Failure (Errors.Self_Dependency);
      end if;
      for Prior_Index in 1 .. Index - 1 loop
         if Dependency_Name (The_Module, Prior_Index) = Depend_Text then
            return Results.From_Failure (Errors.Duplicate_Name);
         end if;
      end loop;
      return Ok_Result;
   end Check_Dependency;

   function Check_Entrypoints (The_Module : Module) return Results.Result is
      Entrypoint_Count : Natural := 0;
   begin
      for Subroutine_Index in 1 .. Subroutine_Count (The_Module) loop
         if Subroutines.Has_Entrypoint (Subroutines.Get_Flags (Get_Subroutine (The_Module, Subroutine_Index))) then
            Entrypoint_Count := Entrypoint_Count + 1;
         end if;
      end loop;
      if Entrypoint_Count > 1 then
         return Results.From_Failure (Errors.Duplicate_Entrypoint);
      end if;
      return Ok_Result;
   end Check_Entrypoints;

   function Check_Flags (The_Subroutine : Subroutines.Subroutine) return Results.Result is
      The_Flags  : constant Subroutines.Subroutine_Flags := Subroutines.Get_Flags (The_Subroutine);
      The_Native : constant Subroutines.Native_Binding_Option := Subroutines.Native (The_Subroutine);
   begin
      if Subroutines.Has_Native (The_Flags) /= The_Native.Present
        or else (Subroutines.Has_Intrinsic (The_Flags) and then Subroutines.Has_Native (The_Flags))
      then
         return Results.From_Failure (Errors.Invalid_Native_Binding);
      end if;

      if The_Native.Present then
         declare
            Check : constant Results.Result := Check_Native_Names (The_Native.Value);
         begin
            if not Check.Ok then
               return Check;
            end if;
         end;
      end if;

      if Subroutines.Has_Intrinsic (The_Flags) or else The_Native.Present then
         return Check_No_Body (The_Subroutine);
      end if;
      return Ok_Result;
   end Check_Flags;

   function Check_Header_Names (The_Subroutine : Subroutines.Subroutine) return Results.Result is
      The_Signature : constant Subroutines.Signature := Subroutines.Get_Signature (The_Subroutine);
      From_Dep      : constant Subroutines.From_Dependency_Option := Subroutines.From_Dependency (The_Subroutine);
      Check         : constant Results.Result := Check_Name (Unbounded_Text (The_Signature.Name));
   begin
      if not Check.Ok then
         return Check;
      end if;
      if From_Dep.Present then
         return Check_Name (Unbounded_Text (From_Dep.Module_Name));
      end if;
      return Ok_Result;
   end Check_Header_Names;

   function Check_Identity (The_Module : Module) return Results.Result is
      Check : constant Results.Result := Check_Name (Name (The_Module));
   begin
      if not Check.Ok then
         return Check;
      end if;
      return Check_Name (Module_Version (The_Module));
   end Check_Identity;

   function Check_Instruction
     (The_Module : Module; Slot_Limit : Natural; Item : Instructions.Instruction) return Results.Result is
   begin
      case Item.Operation is
         when Opcodes.No_Operation | Opcodes.Constant_I32 =>
            null;

         when Opcodes.Call                                =>
            if Item.Target_Index = 0 or else Natural (Item.Target_Index) > Subroutine_Count (The_Module) then
               return Results.From_Failure (Errors.Invalid_Call_Target);
            end if;

         when Opcodes.Local_Get | Opcodes.Local_Set       =>
            if Item.Local_Index = 0 or else Natural (Item.Local_Index) > Slot_Limit then
               return Results.From_Failure (Errors.Invalid_Local_Index);
            end if;
      end case;
      return Ok_Result;
   end Check_Instruction;

   function Check_Instructions (The_Module : Module; The_Subroutine : Subroutines.Subroutine) return Results.Result is
      Body_Instrs   : constant Instructions.Instruction_Sequence := Get_Instructions (The_Subroutine);
      The_Signature : constant Subroutines.Signature := Get_Signature (The_Subroutine);
      Slot_Limit    : constant Natural :=
        Parameter_Length (The_Signature.Parameters) + Parameter_Length (Get_Locals (The_Subroutine));
   begin
      for Instruction_Index in 1 .. Instruction_Length (Body_Instrs) loop
         declare
            Check : constant Results.Result :=
              Check_Instruction
                (The_Module, Slot_Limit, Instruction_At (Body_Instrs, Instruction_Index));
         begin
            if not Check.Ok then
               return Check;
            end if;
         end;
      end loop;
      return Ok_Result;
   end Check_Instructions;

   function Check_Local_Names
     (Parameters : Types.Parameter_Sequence; Locals : Types.Parameter_Sequence) return Results.Result is
   begin
      for Local_Index in 1 .. Parameter_Length (Locals) loop
         declare
            Local_Param     : constant Types.Parameter := Parameter_At (Locals, Local_Index);
            Local_Name_Text : constant String := Unbounded_Text (Local_Param.Name);
            Check           : constant Results.Result := Check_Name (Local_Name_Text);
         begin
            if not Check.Ok then
               return Check;
            end if;
            if Has_Name_Before (Locals, Local_Index - 1, Local_Name_Text)
              or else Has_Name_Before
                        (Parameters, Parameter_Length (Parameters), Local_Name_Text)
            then
               return Results.From_Failure (Errors.Duplicate_Name);
            end if;
         end;
      end loop;
      return Ok_Result;
   end Check_Local_Names;

   function Check_Name (Text : String) return Results.Result is
   begin
      if Text'Length = 0 then
         return Results.From_Failure (Errors.Empty_Name);
      end if;
      if not Is_Valid_Utf_8 (Text) then
         return Results.From_Failure (Errors.Invalid_Utf_8);
      end if;
      return Ok_Result;
   end Check_Name;

   function Check_Names (First : String; Second : String) return Results.Result is
   begin
      if First'Length = 0 or else Second'Length = 0 then
         return Results.From_Failure (Errors.Empty_Name);
      end if;
      if not Is_Valid_Utf_8 (First) or else not Is_Valid_Utf_8 (Second) then
         return Results.From_Failure (Errors.Invalid_Utf_8);
      end if;
      return Ok_Result;
   end Check_Names;

   function Check_Native_Names (Binding : Subroutines.Native_Binding) return Results.Result is
   begin
      return
        Check_Names
          (Unbounded_Text (Binding.Library), Unbounded_Text (Binding.Function_Name));
   end Check_Native_Names;

   function Check_No_Body (The_Subroutine : Subroutines.Subroutine) return Results.Result is
   begin
      if Has_Entrypoint (Get_Flags (The_Subroutine))
        or else Instruction_Length (Get_Instructions (The_Subroutine)) /= 0
        or else Parameter_Length (Get_Locals (The_Subroutine)) /= 0
      then
         return Results.From_Failure (Errors.Invalid_Native_Binding);
      end if;
      return Ok_Result;
   end Check_No_Body;

   function Check_One_Subroutine (The_Module : Module; The_Subroutine : Subroutines.Subroutine) return Results.Result is
      Check : Results.Result := Check_Header_Names (The_Subroutine);
   begin
      if not Check.Ok then
         return Check;
      end if;
      Check := Check_Slot_Names (The_Subroutine);
      if not Check.Ok then
         return Check;
      end if;
      Check := Check_Flags (The_Subroutine);
      if not Check.Ok then
         return Check;
      end if;
      return Check_Instructions (The_Module, The_Subroutine);
   end Check_One_Subroutine;

   function Check_Parameter_Names (Parameters : Types.Parameter_Sequence) return Results.Result is
   begin
      for Parameter_Index in 1 .. Parameter_Length (Parameters) loop
         declare
            The_Parameter       : constant Types.Parameter := Parameter_At (Parameters, Parameter_Index);
            Parameter_Name_Text : constant String := Unbounded_Text (The_Parameter.Name);
            Check               : constant Results.Result := Check_Name (Parameter_Name_Text);
         begin
            if not Check.Ok then
               return Check;
            end if;
            if Has_Name_Before (Parameters, Parameter_Index - 1, Parameter_Name_Text) then
               return Results.From_Failure (Errors.Duplicate_Name);
            end if;
         end;
      end loop;
      return Ok_Result;
   end Check_Parameter_Names;

   function Check_Slot_Names (The_Subroutine : Subroutines.Subroutine) return Results.Result is
      The_Signature : constant Subroutines.Signature := Get_Signature (The_Subroutine);
      Parameters    : constant Types.Parameter_Sequence := The_Signature.Parameters;
      Check         : constant Results.Result := Check_Parameter_Names (Parameters);
   begin
      if not Check.Ok then
         return Check;
      end if;
      return Check_Local_Names (Parameters, Get_Locals (The_Subroutine));
   end Check_Slot_Names;

   function Create (Name : String) return Module is
   begin
      return
        (Module_Name          => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Module_Version_Value => Ada.Strings.Unbounded.To_Unbounded_String (Default_Module_Version),
         Flags_Value          => 0,
         Origin_Value         => (Present => False),
         Dependencies         => Dependency_Vectors.Empty_Vector,
         Subroutines          => Subroutine_Vectors.Empty_Vector);
   end Create;

   function Dependency_At (The_Module : Module; Index : Positive) return Dependency is
   begin
      return The_Module.Dependencies.Element (Index);
   end Dependency_At;

   function Dependency_Count (The_Module : Module) return Natural is
   begin
      return Natural (The_Module.Dependencies.Length);
   end Dependency_Count;

   function Dependency_Name (The_Module : Module; Index : Positive) return String is
      Dep : constant Dependency := Dependency_At (The_Module, Index);
   begin
      return Unbounded_Text (Dep.Name);
   end Dependency_Name;

   function Dependency_Version (The_Module : Module; Index : Positive) return String is
      Dep : constant Dependency := Dependency_At (The_Module, Index);
   begin
      return Unbounded_Text (Dep.Version);
   end Dependency_Version;

   function Flags (The_Module : Module) return Module_Flags is
   begin
      return The_Module.Flags_Value;
   end Flags;

   function Get_Subroutine (The_Module : Module; Index : Positive) return Subroutines.Subroutine is
   begin
      return The_Module.Subroutines.Element (Index);
   end Get_Subroutine;

   function Has_Name_Before (Sequence : Types.Parameter_Sequence; Limit : Natural; Text : String) return Boolean is
   begin
      for Index in 1 .. Limit loop
         declare
            The_Parameter : constant Types.Parameter := Parameter_At (Sequence, Index);
         begin
            if Unbounded_Text (The_Parameter.Name) = Text then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Has_Name_Before;

   function Is_Valid_Utf_8 (Source : String) return Boolean is
      Index : Natural := Source'First;
   begin
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

   function Module_Version (The_Module : Module) return String is
   begin
      return Unbounded_Text (The_Module.Module_Version_Value);
   end Module_Version;

   function Name (The_Module : Module) return String is
   begin
      return Unbounded_Text (The_Module.Module_Name);
   end Name;

   function Origin (The_Module : Module) return Origin_Option is
   begin
      return The_Module.Origin_Value;
   end Origin;

   procedure Set_Flags (The_Module : in out Module; Flags : Module_Flags) is
   begin
      The_Module.Flags_Value := Flags;
   end Set_Flags;

   procedure Set_Module_Version (The_Module : in out Module; Version : String) is
   begin
      The_Module.Module_Version_Value := Ada.Strings.Unbounded.To_Unbounded_String (Version);
   end Set_Module_Version;

   procedure Set_Origin (The_Module : in out Module; The_Origin : Module_Origin) is
   begin
      The_Module.Origin_Value := (Present => True, Value => The_Origin);
   end Set_Origin;

   function Subroutine_Count (The_Module : Module) return Natural is
   begin
      return Natural (The_Module.Subroutines.Length);
   end Subroutine_Count;

   function Validate (The_Module : Module) return Errors.Validation_Results.Result is
      Check : Results.Result := Check_Identity (The_Module);
   begin
      if not Check.Ok then
         return Check;
      end if;
      Check := Check_Dependencies (The_Module);
      if not Check.Ok then
         return Check;
      end if;
      Check := Check_All_Subroutines (The_Module);
      if not Check.Ok then
         return Check;
      end if;
      return Check_Entrypoints (The_Module);
   end Validate;

end Lovelace.Lir.Modules;
