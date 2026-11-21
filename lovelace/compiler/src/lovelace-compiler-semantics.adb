with Ada.Strings;
with Ada.Strings.Fixed;

with Lovelace.Compiler.Semantics.Definite_Assignment;
with Lovelace.Compiler.Semantics.Environment;
with Lovelace.Compiler.Semantics.Lovelace_Types;
with Lovelace.Compiler.Semantics.Resolve;
with Lovelace.Compiler.Semantics.Typecheck;
with Lovelace.Compiler.Semantics.Unused;

package body Lovelace.Compiler.Semantics is

   package Type_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Lovelace_Types.Lovelace_Type,
        "="          => Lovelace_Types."=");

   package Id_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Positive);

   --  Mutable state threaded through one Analyze run.
   type Context is record
      Units      : Unit_Graph.Compilation_Set;
      Unit_Index : Positive := 1;
      Scope      : Environment.Scope_Stack;
      Assigned   : Definite_Assignment.Tracker;
      Usage      : Unused.Tracker;
      Result     : Analysis_Result;
   end record;

   procedure Add_Error
     (The_Context : in out Context; Code : Semantics_Error_Code; Span : Source.Source_Span; Detail : String);

   procedure Analyze_Assignment (The_Context : in out Context; The_Assignment : Ast.Assignment_Statement);

   procedure Analyze_Block (The_Context : in out Context; The_Block : Ast.Block);

   procedure Analyze_Call (The_Context : in out Context; The_Call : Ast.Call_Statement);

   procedure Analyze_Expression
     (The_Context : in out Context; The_Expression : Ast.Expression; The_Type : out Lovelace_Types.Lovelace_Type);

   procedure Analyze_Subroutine (The_Context : in out Context; Subroutine_Index : Positive);

   procedure Analyze_Unit (The_Context : in out Context; Unit_Index : Positive);

   function Image (Value : Natural) return String;

   procedure Add_Error
     (The_Context : in out Context; Code : Semantics_Error_Code; Span : Source.Source_Span; Detail : String)
   is
      Item : constant Diagnostic :=
        (Code       => Code,
         Span       => Span,
         Detail     => Ada.Strings.Unbounded.To_Unbounded_String (Detail),
         Unit_Index => The_Context.Unit_Index);
   begin
      if Is_Warning (Code) then
         The_Context.Result.Warnings.Append (Item);
      else
         The_Context.Result.Errors.Append (Item);
      end if;
   end Add_Error;

   function Analyze (Units : Unit_Graph.Compilation_Set) return Analysis_Result is
      The_Context : Context;
   begin
      The_Context.Units := Units;
      for Unit_Index in 1 .. Natural (Units.Length) loop
         Analyze_Unit (The_Context, Unit_Index);
      end loop;
      return The_Context.Result;
   end Analyze;

   function Analyze (The_Module : Ast.Module) return Analysis_Result is
      Units : Unit_Graph.Compilation_Set;
   begin
      Units.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => The_Module,
            Source_Path => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text => Ada.Strings.Unbounded.Null_Unbounded_String));
      return Analyze (Units);
   end Analyze;

   procedure Analyze_Assignment (The_Context : in out Context; The_Assignment : Ast.Assignment_Statement) is
      Target_Name : constant String := Ada.Strings.Unbounded.To_String (The_Assignment.Target_Name);
      Value_Type  : Lovelace_Types.Lovelace_Type;
   begin
      --  Right-hand side is evaluated (and counted as reads) before the store.
      Analyze_Expression (The_Context, The_Assignment.Value, Value_Type);

      declare
         Target : constant Environment.Lookup_Result := Environment.Lookup_Variable (The_Context.Scope, Target_Name);
      begin
         if not Target.Found then
            Add_Error
              (The_Context,
               Unresolved_Name,
               The_Assignment.Name_Span,
               "'" & Target_Name & "' does not name a visible local or parameter");
            return;
         end if;

         declare
            Check : constant Typecheck.Assign_Result :=
              Typecheck.Check_Assignable (Target.Value.Value_Type, Value_Type);
         begin
            if not Check.Ok then
               Add_Error
                 (The_Context,
                  Type_Mismatch,
                  The_Assignment.Value.Span,
                  "assignment to '" & Target_Name & "': " & Ada.Strings.Unbounded.To_String (Check.Detail));
            end if;
         end;

         --  Assigned even after a mismatch so one error does not cascade into DA errors.
         Definite_Assignment.Mark_Assigned (The_Context.Assigned, Target.Value.Variable_Id);
         Unused.Note_Store (The_Context.Usage, Target.Value.Variable_Id, The_Assignment.Name_Span);
      end;
   end Analyze_Assignment;

   procedure Analyze_Block (The_Context : in out Context; The_Block : Ast.Block) is
      Block_Usings : constant Ast.Using_Sequence := Ast.Usings (The_Block);
      Block_Locals : constant Ast.Local_Sequence := Ast.Locals (The_Block);
      Body_Items   : constant Ast.Statement_Sequence := Ast.Statements (The_Block);
      Local_Ids    : Id_Vectors.Vector;
   begin
      Environment.Push_Scope (The_Context.Scope);

      for Index in 1 .. Ast.Length (Block_Usings) loop
         declare
            The_Using : constant Ast.Using_Declaration := Ast.Element (Block_Usings, Index);
         begin
            Environment.Declare_Entity
              (The_Context.Scope,
               (Kind             => Environment.Module_Entity,
                Name             => The_Using.Module_Name,
                Span             => The_Using.Name_Span,
                Value_Type       => Lovelace_Types.Unknown_Type,
                Variable_Id      => 0,
                Unit_Index       => 0,
                Subroutine_Index => 0));
         end;
      end loop;

      for Index in 1 .. Ast.Length (Block_Locals) loop
         declare
            The_Local : constant Ast.Local_Variable := Ast.Element (Block_Locals, Index);
            Id        : Positive;
            Dummy     : Positive;
         begin
            Definite_Assignment.Declare_Variable (The_Context.Assigned, Assigned => False, Id => Id);
            Unused.Declare_Variable
              (The_Context.Usage,
               Ada.Strings.Unbounded.To_String (The_Local.Parameter_Name),
               The_Local.Name_Span,
               Is_Parameter => False,
               Id           => Dummy);
            Local_Ids.Append (Id);
            Environment.Declare_Entity
              (The_Context.Scope,
               (Kind             => Environment.Local_Entity,
                Name             => The_Local.Parameter_Name,
                Span             => The_Local.Name_Span,
                Value_Type       => Lovelace_Types.From_Expression (The_Local.Parameter_Type),
                Variable_Id      => Id,
                Unit_Index       => 0,
                Subroutine_Index => 0));
         end;
      end loop;

      for Index in 1 .. Ast.Length (Body_Items) loop
         declare
            The_Statement : constant Ast.Statement := Ast.Element (Body_Items, Index);
         begin
            case Ast.Kind (The_Statement) is
               when Ast.Call         =>
                  Analyze_Call (The_Context, Ast.Call_Of (The_Statement));

               when Ast.Assignment   =>
                  Analyze_Assignment (The_Context, Ast.Assignment_Of (The_Statement));

               when Ast.Nested_Block =>
                  Analyze_Block (The_Context, Ast.Block_Of (The_Statement));
            end case;
         end;
      end loop;

      for Index in 1 .. Natural (Local_Ids.Length) loop
         Unused.End_Of_Life (The_Context.Usage, Local_Ids.Element (Index));
      end loop;

      Environment.Pop_Scope (The_Context.Scope);
   end Analyze_Block;

   procedure Analyze_Call (The_Context : in out Context; The_Call : Ast.Call_Statement) is
      Callee_Text  : constant String := Ada.Strings.Unbounded.To_String (The_Call.Callee_Name);
      Actual_Count : constant Natural := Ast.Length (The_Call.Arguments);
      Actual_Types : Type_Vectors.Vector;
      Resolved     : constant Resolve.Resolve_Result :=
        Resolve.Resolve_Call (The_Context.Units, The_Context.Unit_Index, The_Context.Scope, Callee_Text);
   begin
      --  Actuals are always analysed so reads / definite assignment are still checked.
      for Index in 1 .. Actual_Count loop
         declare
            Actual_Type : Lovelace_Types.Lovelace_Type;
         begin
            Analyze_Expression (The_Context, Ast.Element (The_Call.Arguments, Index), Actual_Type);
            Actual_Types.Append (Actual_Type);
         end;
      end loop;

      case Resolved.Ok is
         when False =>
            Add_Error
              (The_Context, Resolved.Code, The_Call.Name_Span, Ada.Strings.Unbounded.To_String (Resolved.Detail));

         when True  =>
            declare
               Formals      : constant Ast.Parameter_Sequence := Ast.Parameters (Resolved.Callee.The_Subroutine);
               Formal_Count : constant Natural := Ast.Length (Formals);
            begin
               if Actual_Count /= Formal_Count then
                  Add_Error
                    (The_Context,
                     Invalid_Arguments,
                     The_Call.Name_Span,
                     "call '"
                     & Callee_Text
                     & "' expects "
                     & Image (Formal_Count)
                     & " argument(s), found "
                     & Image (Actual_Count));
                  return;
               end if;

               for Index in 1 .. Actual_Count loop
                  declare
                     Formal_Type : constant Lovelace_Types.Lovelace_Type :=
                       Lovelace_Types.From_Expression (Ast.Element (Formals, Index).Parameter_Type);
                     Check       : constant Typecheck.Assign_Result :=
                       Typecheck.Check_Assignable (Formal_Type, Actual_Types.Element (Index));
                  begin
                     if not Check.Ok then
                        Add_Error
                          (The_Context,
                           Type_Mismatch,
                           Ast.Element (The_Call.Arguments, Index).Span,
                           "argument "
                           & Image (Index)
                           & " of '"
                           & Callee_Text
                           & "': "
                           & Ada.Strings.Unbounded.To_String (Check.Detail));
                     end if;
                  end;
               end loop;
            end;
      end case;
   end Analyze_Call;

   procedure Analyze_Expression
     (The_Context : in out Context; The_Expression : Ast.Expression; The_Type : out Lovelace_Types.Lovelace_Type) is
   begin
      The_Type := Lovelace_Types.Unknown_Type;

      case The_Expression.Kind is
         when Ast.Integer_Literal | Ast.Boolean_Literal =>
            declare
               Literal_Type : constant Typecheck.Type_Result := Typecheck.Type_Of_Literal (The_Expression);
            begin
               case Literal_Type.Ok is
                  when True  =>
                     The_Type := Literal_Type.The_Type;

                  when False =>
                     Add_Error
                       (The_Context,
                        Type_Mismatch,
                        The_Expression.Span,
                        Ada.Strings.Unbounded.To_String (Literal_Type.Detail));
               end case;
            end;

         when Ast.Name_Reference                        =>
            declare
               Name   : constant String := Ada.Strings.Unbounded.To_String (The_Expression.Lexeme);
               Entity : constant Environment.Lookup_Result := Environment.Lookup_Variable (The_Context.Scope, Name);
            begin
               if not Entity.Found then
                  Add_Error
                    (The_Context,
                     Unresolved_Name,
                     The_Expression.Span,
                     "'" & Name & "' does not name a visible local or parameter");
                  return;
               end if;

               Unused.Note_Read (The_Context.Usage, Entity.Value.Variable_Id);
               if not Definite_Assignment.Is_Assigned (The_Context.Assigned, Entity.Value.Variable_Id) then
                  Add_Error
                    (The_Context,
                     Use_Before_Assignment,
                     The_Expression.Span,
                     "local '" & Name & "' is read before it is assigned");
               end if;
               The_Type := Entity.Value.Value_Type;
            end;
      end case;
   end Analyze_Expression;

   procedure Analyze_Subroutine (The_Context : in out Context; Subroutine_Index : Positive) is
      The_Module     : constant Ast.Module := The_Context.Units.Element (The_Context.Unit_Index).The_Module;
      The_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, Subroutine_Index);
      Formals        : constant Ast.Parameter_Sequence := Ast.Parameters (The_Subroutine);
      Errors_Before  : constant Natural := Natural (The_Context.Result.Errors.Length);
   begin
      Definite_Assignment.Reset (The_Context.Assigned);
      Unused.Reset (The_Context.Usage);
      Environment.Push_Scope (The_Context.Scope);

      for Index in 1 .. Ast.Length (Formals) loop
         declare
            Formal : constant Ast.Parameter := Ast.Element (Formals, Index);
            Id     : Positive;
            Dummy  : Positive;
         begin
            Definite_Assignment.Declare_Variable (The_Context.Assigned, Assigned => True, Id => Id);
            Unused.Declare_Variable
              (The_Context.Usage,
               Ada.Strings.Unbounded.To_String (Formal.Parameter_Name),
               Formal.Name_Span,
               Is_Parameter => True,
               Id           => Dummy);
            Environment.Declare_Entity
              (The_Context.Scope,
               (Kind             => Environment.Parameter_Entity,
                Name             => Formal.Parameter_Name,
                Span             => Formal.Name_Span,
                Value_Type       => Lovelace_Types.From_Expression (Formal.Parameter_Type),
                Variable_Id      => Id,
                Unit_Index       => 0,
                Subroutine_Index => 0));
         end;
      end loop;

      Analyze_Block (The_Context, Ast.Get_Body (The_Subroutine));
      Environment.Pop_Scope (The_Context.Scope);

      --  Unused warnings only run once resolve / DA / types were clean for this subroutine.
      if Natural (The_Context.Result.Errors.Length) = Errors_Before then
         Unused.Collect_Warnings (The_Context.Usage, The_Context.Unit_Index, The_Context.Result.Warnings);
      end if;
   end Analyze_Subroutine;

   procedure Analyze_Unit (The_Context : in out Context; Unit_Index : Positive) is
      The_Module  : constant Ast.Module := The_Context.Units.Element (Unit_Index).The_Module;
      Empty_Scope : Environment.Scope_Stack;
   begin
      The_Context.Unit_Index := Unit_Index;
      The_Context.Scope := Empty_Scope;
      Environment.Push_Scope (The_Context.Scope);

      for Index in 1 .. Ast.Using_Count (The_Module) loop
         declare
            The_Using : constant Ast.Using_Declaration := Ast.Get_Using (The_Module, Index);
         begin
            Environment.Declare_Entity
              (The_Context.Scope,
               (Kind             => Environment.Module_Entity,
                Name             => The_Using.Module_Name,
                Span             => The_Using.Name_Span,
                Value_Type       => Lovelace_Types.Unknown_Type,
                Variable_Id      => 0,
                Unit_Index       => 0,
                Subroutine_Index => 0));
         end;
      end loop;

      for Index in 1 .. Ast.Subroutine_Count (The_Module) loop
         declare
            The_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, Index);
         begin
            Environment.Declare_Entity
              (The_Context.Scope,
               (Kind             => Environment.Subroutine_Entity,
                Name             => Ada.Strings.Unbounded.To_Unbounded_String (Ast.Name (The_Subroutine)),
                Span             => Ast.Name_Span (The_Subroutine),
                Value_Type       => Lovelace_Types.From_Expression (Ast.Return_Type (The_Subroutine)),
                Variable_Id      => 0,
                Unit_Index       => Unit_Index,
                Subroutine_Index => Index));
         end;
      end loop;

      for Index in 1 .. Ast.Subroutine_Count (The_Module) loop
         Analyze_Subroutine (The_Context, Index);
      end loop;
   end Analyze_Unit;

   function Image (Value : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both);
   end Image;

   function Is_Warning (Code : Semantics_Error_Code) return Boolean is
   begin
      return Code in Warning_Code;
   end Is_Warning;

   function Succeeded (Result : Analysis_Result) return Boolean is
   begin
      return Result.Errors.Is_Empty;
   end Succeeded;

end Lovelace.Compiler.Semantics;
