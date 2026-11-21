with Ada.Strings;
with Ada.Strings.Fixed;

package body Lovelace.Compiler.Semantics.Resolve is

   function Failure (Code : Semantics_Error_Code; Detail : String) return Resolve_Result;

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   function Failure (Code : Semantics_Error_Code; Detail : String) return Resolve_Result is
   begin
      return (Ok => False, Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail));
   end Failure;

   function Resolve_Call
     (Units             : Unit_Graph.Compilation_Set;
      Caller_Unit_Index : Positive;
      Scope             : Environment.Scope_Stack;
      Callee_Name       : String) return Resolve_Result
   is
      Caller_Unit    : constant Ast.Module := Units.Element (Caller_Unit_Index).The_Module;
      Module_Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Split_Callee (Callee_Name, Module_Prefix, Procedure_Name) then
         return Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
      end if;

      declare
         Prefix_Text    : constant String := Ada.Strings.Unbounded.To_String (Module_Prefix);
         Procedure_Text : constant String := Ada.Strings.Unbounded.To_String (Procedure_Name);
      begin
         if Prefix_Text = Ast.Name (Caller_Unit) then
            declare
               Local : constant Environment.Lookup_Result := Environment.Lookup_Subroutine (Scope, Procedure_Text);
            begin
               if not Local.Found then
                  return Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
               end if;

               return
                 (Ok     => True,
                  Callee =>
                    (Unit_Index       => Caller_Unit_Index,
                     Subroutine_Index => Local.Value.Subroutine_Index,
                     The_Subroutine   => Ast.Get_Subroutine (Caller_Unit, Local.Value.Subroutine_Index)));
            end;
         end if;

         if not Environment.Lookup_Module (Scope, Prefix_Text).Found then
            return Failure (Call_Without_Using, "call '" & Callee_Name & "' requires using " & Prefix_Text);
         end if;

         for Unit_Index in 1 .. Natural (Units.Length) loop
            declare
               Candidate : constant Ast.Module := Units.Element (Unit_Index).The_Module;
            begin
               if Ast.Name (Candidate) = Prefix_Text then
                  for Candidate_Index in 1 .. Ast.Subroutine_Count (Candidate) loop
                     declare
                        Candidate_Subroutine : constant Ast.Subroutine :=
                          Ast.Get_Subroutine (Candidate, Candidate_Index);
                     begin
                        if Ast.Name (Candidate_Subroutine) = Procedure_Text then
                           if not Ast.Has_Export (Ast.Get_Flags (Candidate_Subroutine)) then
                              return Failure (Not_Exported, "procedure '" & Callee_Name & "' is not exported");
                           end if;

                           return
                             (Ok     => True,
                              Callee =>
                                (Unit_Index       => Unit_Index,
                                 Subroutine_Index => Candidate_Index,
                                 The_Subroutine   => Candidate_Subroutine));
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end loop;

         return Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
      end;
   end Resolve_Call;

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String) return Boolean
   is
      Dot : Natural;
   begin
      Module_Prefix := Ada.Strings.Unbounded.Null_Unbounded_String;
      Procedure_Name := Ada.Strings.Unbounded.Null_Unbounded_String;
      Dot := Ada.Strings.Fixed.Index (Callee_Name, ".", Going => Ada.Strings.Backward);
      if Dot = 0 or else Dot = Callee_Name'First or else Dot = Callee_Name'Last then
         return False;
      end if;
      Module_Prefix := Ada.Strings.Unbounded.To_Unbounded_String (Callee_Name (Callee_Name'First .. Dot - 1));
      Procedure_Name := Ada.Strings.Unbounded.To_Unbounded_String (Callee_Name (Dot + 1 .. Callee_Name'Last));
      return True;
   end Split_Callee;

end Lovelace.Compiler.Semantics.Resolve;
