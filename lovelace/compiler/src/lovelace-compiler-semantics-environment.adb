package body Lovelace.Compiler.Semantics.Environment is

   use type Ada.Strings.Unbounded.Unbounded_String;

   function Scope_At (The_Stack : Scope_Stack; Index : Positive) return Entity_Vectors.Vector;
   --  Wrapper so call sites are not dotted (gnatcov call coverage).

   function Entity_At (Scope : Entity_Vectors.Vector; Index : Positive) return Entity;
   --  Wrapper so call sites are not dotted (gnatcov call coverage).

   function Scope_Length (Scope : Entity_Vectors.Vector) return Ada.Containers.Count_Type
     renames Entity_Vectors.Length;

   procedure Declare_Entity (The_Stack : in out Scope_Stack; The_Entity : Entity) is
   begin
      if The_Stack.Scopes.Is_Empty then
         Push_Scope (The_Stack);
      end if;

      declare
         Last_Index : constant Positive := The_Stack.Scopes.Last_Index;
         Innermost  : Entity_Vectors.Vector := The_Stack.Scopes.Element (Last_Index);
      begin
         Innermost.Append (The_Entity);
         The_Stack.Scopes.Replace_Element (Last_Index, Innermost);
      end;
   end Declare_Entity;

   function Depth (The_Stack : Scope_Stack) return Natural is
   begin
      return Natural (The_Stack.Scopes.Length);
   end Depth;

   function Entity_At (Scope : Entity_Vectors.Vector; Index : Positive) return Entity is
   begin
      return Scope.Element (Index);
   end Entity_At;

   function Innermost_Element (The_Stack : Scope_Stack; Index : Positive) return Entity is
      Last_Index : constant Positive := The_Stack.Scopes.Last_Index;
      Innermost  : constant Entity_Vectors.Vector := Scope_At (The_Stack, Last_Index);
   begin
      return Entity_At (Innermost, Index);
   end Innermost_Element;

   function Innermost_Length (The_Stack : Scope_Stack) return Natural is
      Last_Index : Positive;
      Innermost  : Entity_Vectors.Vector;
   begin
      if The_Stack.Scopes.Is_Empty then
         return 0;
      end if;
      Last_Index := The_Stack.Scopes.Last_Index;
      Innermost := Scope_At (The_Stack, Last_Index);
      return Natural (Scope_Length (Innermost));
   end Innermost_Length;

   function Lookup (The_Stack : Scope_Stack; Name : String; Kinds : Kind_Set) return Lookup_Result is
      Wanted : constant Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.To_Unbounded_String (Name);
   begin
      for Scope_Index in reverse 1 .. Natural (The_Stack.Scopes.Length) loop
         declare
            Scope : constant Entity_Vectors.Vector := The_Stack.Scopes.Element (Scope_Index);
         begin
            for Entity_Index in reverse 1 .. Natural (Scope.Length) loop
               declare
                  Candidate : constant Entity := Scope.Element (Entity_Index);
               begin
                  if Kinds (Candidate.Kind) and then Candidate.Name = Wanted then
                     return (Found => True, Value => Candidate);
                  end if;
               end;
            end loop;
         end;
      end loop;

      return (Found => False);
   end Lookup;

   function Lookup_Module (The_Stack : Scope_Stack; Name : String) return Lookup_Result is
   begin
      return Lookup (The_Stack, Name, Module_Kinds);
   end Lookup_Module;

   function Lookup_Subroutine (The_Stack : Scope_Stack; Name : String) return Lookup_Result is
   begin
      return Lookup (The_Stack, Name, Subroutine_Kinds);
   end Lookup_Subroutine;

   function Lookup_Variable (The_Stack : Scope_Stack; Name : String) return Lookup_Result is
   begin
      return Lookup (The_Stack, Name, Variable_Kinds);
   end Lookup_Variable;

   procedure Note_Module_Used (The_Stack : in out Scope_Stack; Name : String) is
      Wanted : constant Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.To_Unbounded_String (Name);
   begin
      for Scope_Index in reverse 1 .. Natural (The_Stack.Scopes.Length) loop
         declare
            Scope : Entity_Vectors.Vector := The_Stack.Scopes.Element (Scope_Index);
         begin
            for Entity_Index in reverse 1 .. Natural (Scope.Length) loop
               declare
                  Candidate : Entity := Scope.Element (Entity_Index);
               begin
                  if Candidate.Kind = Module_Entity and then Candidate.Name = Wanted then
                     Candidate.Used := True;
                     Scope.Replace_Element (Entity_Index, Candidate);
                     The_Stack.Scopes.Replace_Element (Scope_Index, Scope);
                     return;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Note_Module_Used;

   procedure Pop_Scope (The_Stack : in out Scope_Stack) is
   begin
      if not The_Stack.Scopes.Is_Empty then
         The_Stack.Scopes.Delete_Last;
      end if;
   end Pop_Scope;

   procedure Push_Scope (The_Stack : in out Scope_Stack) is
      Empty_Scope : Entity_Vectors.Vector;
   begin
      The_Stack.Scopes.Append (Empty_Scope);
   end Push_Scope;

   function Scope_At (The_Stack : Scope_Stack; Index : Positive) return Entity_Vectors.Vector is
   begin
      return The_Stack.Scopes.Element (Index);
   end Scope_At;

end Lovelace.Compiler.Semantics.Environment;
