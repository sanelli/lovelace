with Ada.Strings;
with Ada.Strings.Fixed;

with Lovelace.Compiler.Semantics.Typecheck;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Semantics.Resolve is

   type Candidate is record
      Unit_Index       : Positive := 1;
      Subroutine_Index : Positive := 1;
      The_Subroutine   : Ast.Subroutine;
   end record;

   package Candidate_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Candidate);

   --  Simple-name renames / wrappers so gnatcov can instrument call coverage.
   function Ast_Parameter_Element
     (Sequence : Ast.Parameter_Sequence; Index : Positive) return Ast.Parameter
     renames Ast.Element;
   function From_Expression
     (Expression : Lovelace.Compiler.Types.Type_Expression) return Lovelace_Types.Lovelace_Type
     renames Lovelace_Types.From_Expression;
   function Is_Assignable
     (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Boolean
     renames Typecheck.Is_Assignable;
   function Lookup_Module
     (The_Stack : Environment.Scope_Stack; Name : String) return Environment.Lookup_Result
     renames Environment.Lookup_Module;

   function Unit_At
     (Units : Unit_Graph.Compilation_Set; Index : Positive) return Unit_Graph.Loaded_Unit;
   --  Wrapper so call sites are not dotted (gnatcov call coverage).

   function Actual_At
     (Sequence : Actual_Type_Sequence; Index : Positive) return Lovelace_Types.Lovelace_Type;
   --  Wrapper so call sites are not dotted (gnatcov call coverage).

   procedure Collect_Exported_Candidates
     (Candidate_Unit  : Ast.Module;
      Unit_Index      : Positive;
      Procedure_Text  : String;
      Actual_Types    : Actual_Type_Sequence;
      Matching        : in out Candidate_Vectors.Vector;
      Same_Name_Count : in out Natural;
      Exported_Count  : in out Natural);
   --  Scan Candidate_Unit for exported subroutines named Procedure_Text.

   procedure Collect_Local_Candidates
     (Caller_Unit    : Ast.Module;
      Unit_Index     : Positive;
      Procedure_Text : String;
      Actual_Types   : Actual_Type_Sequence;
      Matching       : in out Candidate_Vectors.Vector);
   --  Same-unit subroutines named Procedure_Text whose formals accept Actual_Types.

   function Failure (Code : Semantics_Error_Code; Detail : String) return Resolve_Result;

   function Formals_Match (The_Subroutine : Ast.Subroutine; Actual_Types : Actual_Type_Sequence) return Boolean;

   function Pick_Overload (Candidates : Candidate_Vectors.Vector; Callee_Name : String) return Resolve_Result;

   function Resolve_Imported
     (Units          : Unit_Graph.Compilation_Set;
      Prefix_Text    : String;
      Procedure_Text : String;
      Callee_Name    : String;
      Actual_Types   : Actual_Type_Sequence) return Resolve_Result;
   --  Resolve Prefix_Text.Procedure_Text among exported subroutines of Units.

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   function Actual_At
     (Sequence : Actual_Type_Sequence; Index : Positive) return Lovelace_Types.Lovelace_Type is
   begin
      return Sequence.Element (Index);
   end Actual_At;

   procedure Collect_Exported_Candidates
     (Candidate_Unit  : Ast.Module;
      Unit_Index      : Positive;
      Procedure_Text  : String;
      Actual_Types    : Actual_Type_Sequence;
      Matching        : in out Candidate_Vectors.Vector;
      Same_Name_Count : in out Natural;
      Exported_Count  : in out Natural) is
   begin
      for Candidate_Index in 1 .. Ast.Subroutine_Count (Candidate_Unit) loop
         declare
            Candidate_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (Candidate_Unit, Candidate_Index);
         begin
            if Ast.Name (Candidate_Subroutine) = Procedure_Text then
               Same_Name_Count := Same_Name_Count + 1;
               if Ast.Has_Export (Ast.Get_Flags (Candidate_Subroutine)) then
                  Exported_Count := Exported_Count + 1;
                  if Formals_Match (Candidate_Subroutine, Actual_Types) then
                     Matching.Append
                       (Candidate'
                          (Unit_Index       => Unit_Index,
                           Subroutine_Index => Candidate_Index,
                           The_Subroutine   => Candidate_Subroutine));
                  end if;
               end if;
            end if;
         end;
      end loop;
   end Collect_Exported_Candidates;

   procedure Collect_Local_Candidates
     (Caller_Unit    : Ast.Module;
      Unit_Index     : Positive;
      Procedure_Text : String;
      Actual_Types   : Actual_Type_Sequence;
      Matching       : in out Candidate_Vectors.Vector) is
   begin
      for Candidate_Index in 1 .. Ast.Subroutine_Count (Caller_Unit) loop
         declare
            Candidate_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (Caller_Unit, Candidate_Index);
         begin
            if Ast.Name (Candidate_Subroutine) = Procedure_Text
              and then Formals_Match (Candidate_Subroutine, Actual_Types)
            then
               Matching.Append
                 (Candidate'
                    (Unit_Index       => Unit_Index,
                     Subroutine_Index => Candidate_Index,
                     The_Subroutine   => Candidate_Subroutine));
            end if;
         end;
      end loop;
   end Collect_Local_Candidates;

   function Failure (Code : Semantics_Error_Code; Detail : String) return Resolve_Result is
   begin
      return (Ok => False, Code => Code, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail));
   end Failure;

   function Formals_Match (The_Subroutine : Ast.Subroutine; Actual_Types : Actual_Type_Sequence) return Boolean is
      Formals : constant Ast.Parameter_Sequence := Ast.Parameters (The_Subroutine);
   begin
      if Ast.Length (Formals) /= Natural (Actual_Types.Length) then
         return False;
      end if;

      for Index in 1 .. Ast.Length (Formals) loop
         declare
            Formal_Param : constant Ast.Parameter := Ast_Parameter_Element (Formals, Index);
            Formal_Type  : constant Lovelace_Types.Lovelace_Type := From_Expression (Formal_Param.Parameter_Type);
            Actual_Type  : constant Lovelace_Types.Lovelace_Type := Actual_At (Actual_Types, Index);
         begin
            if not Is_Assignable (Formal_Type, Actual_Type) then
               return False;
            end if;
         end;
      end loop;

      return True;
   end Formals_Match;

   function Pick_Overload (Candidates : Candidate_Vectors.Vector; Callee_Name : String) return Resolve_Result is
   begin
      case Natural (Candidates.Length) is
         when 0      =>
            return Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "': no matching overload");

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
            return Failure (Ambiguous_Call, "ambiguous call '" & Callee_Name & "'");
      end case;
   end Pick_Overload;

   function Resolve_Call
     (Units             : Unit_Graph.Compilation_Set;
      Caller_Unit_Index : Positive;
      Scope             : in out Environment.Scope_Stack;
      Callee_Name       : String;
      Actual_Types      : Actual_Type_Sequence) return Resolve_Result
   is
      Caller_Loaded  : constant Unit_Graph.Loaded_Unit := Unit_At (Units, Caller_Unit_Index);
      Caller_Unit    : constant Ast.Module := Caller_Loaded.The_Module;
      Module_Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Split_Callee (Callee_Name, Module_Prefix, Procedure_Name) then
         return Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
      end if;

      declare
         Prefix_Text    : constant String := Ada.Strings.Unbounded.To_String (Module_Prefix);
         Procedure_Text : constant String := Ada.Strings.Unbounded.To_String (Procedure_Name);
         Matching       : Candidate_Vectors.Vector;
         Module_Lookup  : constant Environment.Lookup_Result := Lookup_Module (Scope, Prefix_Text);
      begin
         if Prefix_Text = Ast.Name (Caller_Unit) then
            Collect_Local_Candidates (Caller_Unit, Caller_Unit_Index, Procedure_Text, Actual_Types, Matching);
            return Pick_Overload (Matching, Callee_Name);
         end if;

         if not Module_Lookup.Found then
            return Failure (Call_Without_Using, "call '" & Callee_Name & "' requires using " & Prefix_Text);
         end if;

         Environment.Note_Module_Used (Scope, Prefix_Text);

         return Resolve_Imported (Units, Prefix_Text, Procedure_Text, Callee_Name, Actual_Types);
      end;
   end Resolve_Call;

   function Resolve_Imported
     (Units          : Unit_Graph.Compilation_Set;
      Prefix_Text    : String;
      Procedure_Text : String;
      Callee_Name    : String;
      Actual_Types   : Actual_Type_Sequence) return Resolve_Result
   is
      Matching          : Candidate_Vectors.Vector;
      Same_Name_Count   : Natural := 0;
      Exported_Count    : Natural := 0;
      Target_Unit_Index : Natural := 0;
   begin
      for Unit_Index in 1 .. Natural (Units.Length) loop
         declare
            Loaded_Unit    : constant Unit_Graph.Loaded_Unit := Unit_At (Units, Unit_Index);
            Candidate_Unit : constant Ast.Module := Loaded_Unit.The_Module;
         begin
            if Ast.Name (Candidate_Unit) = Prefix_Text then
               Target_Unit_Index := Unit_Index;
               Collect_Exported_Candidates
                 (Candidate_Unit, Unit_Index, Procedure_Text, Actual_Types, Matching, Same_Name_Count, Exported_Count);
            end if;
         end;
      end loop;

      if Same_Name_Count = 0 or else Target_Unit_Index = 0 then
         return Failure (Unresolved_Call, "unresolved call '" & Callee_Name & "'");
      end if;

      if Exported_Count = 0 then
         return Failure (Not_Exported, "procedure '" & Callee_Name & "' is not exported");
      end if;

      return Pick_Overload (Matching, Callee_Name);
   end Resolve_Imported;

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

   function Unit_At
     (Units : Unit_Graph.Compilation_Set; Index : Positive) return Unit_Graph.Loaded_Unit is
   begin
      return Units.Element (Index);
   end Unit_At;

end Lovelace.Compiler.Semantics.Resolve;
