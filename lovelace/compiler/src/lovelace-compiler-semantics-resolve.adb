with Ada.Strings;
with Ada.Strings.Fixed;

with Lovelace.Compiler.Semantics.Typecheck;

package body Lovelace.Compiler.Semantics.Resolve is

   type Candidate is record
      Unit_Index       : Positive := 1;
      Subroutine_Index : Positive := 1;
      The_Subroutine   : Ast.Subroutine;
   end record;

   package Candidate_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Candidate);

   function Failure
     (Code : Semantics_Error_Code; Detail : String) return Resolve_Result;

   function Formals_Match
     (The_Subroutine : Ast.Subroutine; Actual_Types : Actual_Type_Sequence)
      return Boolean;

   function Pick_Overload
     (Candidates : Candidate_Vectors.Vector; Callee_Name : String)
      return Resolve_Result;

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   function Failure
     (Code : Semantics_Error_Code; Detail : String) return Resolve_Result is
   begin
      return
        (Ok     => False,
         Code   => Code,
         Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail));
   end Failure;

   function Formals_Match
     (The_Subroutine : Ast.Subroutine; Actual_Types : Actual_Type_Sequence)
      return Boolean
   is
      Formals : constant Ast.Parameter_Sequence :=
        Ast.Parameters (The_Subroutine);
   begin
      if Ast.Length (Formals) /= Natural (Actual_Types.Length) then
         return False;
      end if;

      for Index in 1 .. Ast.Length (Formals) loop
         declare
            Formal_Type : constant Lovelace_Types.Lovelace_Type :=
              Lovelace_Types.From_Expression
                (Ast.Element (Formals, Index).Parameter_Type);
         begin
            if not Typecheck.Is_Assignable
                     (Formal_Type, Actual_Types.Element (Index))
            then
               return False;
            end if;
         end;
      end loop;

      return True;
   end Formals_Match;

   function Pick_Overload
     (Candidates : Candidate_Vectors.Vector; Callee_Name : String)
      return Resolve_Result is
   begin
      case Natural (Candidates.Length) is
         when 0      =>
            return
              Failure
                (Unresolved_Call,
                 "unresolved call '"
                 & Callee_Name
                 & "': no matching overload");

         when 1      =>
            declare
               Chosen : constant Candidate := Candidates.Element (1);
            begin
               return
                 (Ok     => True,
                  Callee =>
                    (Unit_Index       => Chosen.Unit_Index,
                     Subroutine_Index => Chosen.Subroutine_Index,
                     The_Subroutine   => Chosen.The_Subroutine));
            end;

         when others =>
            return
              Failure (Ambiguous_Call, "ambiguous call '" & Callee_Name & "'");
      end case;
   end Pick_Overload;

   function Resolve_Call
     (Units             : Unit_Graph.Compilation_Set;
      Caller_Unit_Index : Positive;
      Scope             : in out Environment.Scope_Stack;
      Callee_Name       : String;
      Actual_Types      : Actual_Type_Sequence) return Resolve_Result
   is
      Caller_Unit    : constant Ast.Module :=
        Units.Element (Caller_Unit_Index).The_Module;
      Module_Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Split_Callee (Callee_Name, Module_Prefix, Procedure_Name) then
         return
           Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
      end if;

      declare
         Prefix_Text    : constant String :=
           Ada.Strings.Unbounded.To_String (Module_Prefix);
         Procedure_Text : constant String :=
           Ada.Strings.Unbounded.To_String (Procedure_Name);
         Matching       : Candidate_Vectors.Vector;
      begin
         if Prefix_Text = Ast.Name (Caller_Unit) then
            for Candidate_Index in 1 .. Ast.Subroutine_Count (Caller_Unit) loop
               declare
                  Candidate_Subroutine : constant Ast.Subroutine :=
                    Ast.Get_Subroutine (Caller_Unit, Candidate_Index);
               begin
                  if Ast.Name (Candidate_Subroutine) = Procedure_Text
                    and then Formals_Match (Candidate_Subroutine, Actual_Types)
                  then
                     Matching.Append
                       (Candidate'
                          (Unit_Index       => Caller_Unit_Index,
                           Subroutine_Index => Candidate_Index,
                           The_Subroutine   => Candidate_Subroutine));
                  end if;
               end;
            end loop;

            return Pick_Overload (Matching, Callee_Name);
         end if;

         if not Environment.Lookup_Module (Scope, Prefix_Text).Found then
            return
              Failure
                (Call_Without_Using,
                 "call '" & Callee_Name & "' requires using " & Prefix_Text);
         end if;

         Environment.Note_Module_Used (Scope, Prefix_Text);

         declare
            Same_Name_Count   : Natural := 0;
            Exported_Count    : Natural := 0;
            Target_Unit_Index : Natural := 0;
         begin
            for Unit_Index in 1 .. Natural (Units.Length) loop
               declare
                  Candidate_Unit : constant Ast.Module :=
                    Units.Element (Unit_Index).The_Module;
               begin
                  if Ast.Name (Candidate_Unit) = Prefix_Text then
                     Target_Unit_Index := Unit_Index;
                     for Candidate_Index in
                       1 .. Ast.Subroutine_Count (Candidate_Unit)
                     loop
                        declare
                           Candidate_Subroutine : constant Ast.Subroutine :=
                             Ast.Get_Subroutine
                               (Candidate_Unit, Candidate_Index);
                        begin
                           if Ast.Name (Candidate_Subroutine) = Procedure_Text
                           then
                              Same_Name_Count := Same_Name_Count + 1;
                              if Ast.Has_Export
                                   (Ast.Get_Flags (Candidate_Subroutine))
                              then
                                 Exported_Count := Exported_Count + 1;
                                 if Formals_Match
                                      (Candidate_Subroutine, Actual_Types)
                                 then
                                    Matching.Append
                                      (Candidate'
                                         (Unit_Index       => Unit_Index,
                                          Subroutine_Index => Candidate_Index,
                                          The_Subroutine   =>
                                            Candidate_Subroutine));
                                 end if;
                              end if;
                           end if;
                        end;
                     end loop;
                  end if;
               end;
            end loop;

            if Same_Name_Count = 0 or else Target_Unit_Index = 0 then
               return
                 Failure
                   (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
            end if;

            if Exported_Count = 0 then
               return
                 Failure
                   (Not_Exported,
                    "procedure '" & Callee_Name & "' is not exported");
            end if;

            return Pick_Overload (Matching, Callee_Name);
         end;
      end;
   end Resolve_Call;

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean
   is
      Dot : Natural;
   begin
      Module_Prefix := Ada.Strings.Unbounded.Null_Unbounded_String;
      Procedure_Name := Ada.Strings.Unbounded.Null_Unbounded_String;
      Dot :=
        Ada.Strings.Fixed.Index
          (Callee_Name, ".", Going => Ada.Strings.Backward);
      if Dot = 0 or else Dot = Callee_Name'First or else Dot = Callee_Name'Last
      then
         return False;
      end if;
      Module_Prefix :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Callee_Name (Callee_Name'First .. Dot - 1));
      Procedure_Name :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Callee_Name (Dot + 1 .. Callee_Name'Last));
      return True;
   end Split_Callee;

end Lovelace.Compiler.Semantics.Resolve;
