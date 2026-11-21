with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces;

with Lovelace.Compiler.Intrinsics;
with Lovelace.Compiler.Literals;
with Lovelace.Compiler.Semantics.Lovelace_Types;
with Lovelace.Compiler.Semantics.Typecheck;
with Lovelace.Compiler.Types;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Ir_Generator is

   use type Ada.Strings.Unbounded.Unbounded_String;
   use type Ast.Statement_Kind;
   use type Lovelace.Compiler.Types.Type_Kind;
   use type Lovelace.Lir.Subroutines.Subroutine_Flags;
   use type Lovelace.Lir.Types.Value_Type;

   --  One flattened subroutine slot in the combined LIR module.
   type Flat_Symbol is record
      Unit_Index     : Positive;
      Local_Index    : Positive;
      Module_Name    : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
      Lir_Name       : Ada.Strings.Unbounded.Unbounded_String;
      Exported       : Boolean;
      The_Subroutine : Ast.Subroutine;
   end record;

   package Flat_Symbol_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Flat_Symbol);

   package Lovelace_Types renames Lovelace.Compiler.Semantics.Lovelace_Types;
   package Typecheck renames Lovelace.Compiler.Semantics.Typecheck;

   package Actual_Type_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Lovelace_Types.Lovelace_Type,
        "="          => Lovelace_Types."=");

   --  One name -> 1-based LIR local slot binding in a scope frame.
   type Local_Binding is record
      Name       : Ada.Strings.Unbounded.Unbounded_String;
      Index      : Positive;
      Value_Type : Lovelace_Types.Lovelace_Type;
   end record;

   package Binding_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Local_Binding);

   package Scope_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Binding_Vectors.Vector,
        "="          => Binding_Vectors."=");

   --  Scoped name->slot map; params occupy 1 .. Param_Count, then flattened locals.
   type Local_Map is record
      Scopes    : Scope_Vectors.Vector;
      Next_Slot : Positive := 1;
   end record;

   function Failure
     (Code   : Ir_Generator_Error_Code;
      Span   : Source.Source_Span;
      Detail : String) return Generate_Result;

   procedure Append_Usings_From_Block
     (The_Block : Ast.Block; Into : in out Ast.Using_Sequence);

   procedure Bind_Local
     (The_Map    : in out Local_Map;
      Name       : String;
      Index      : Positive;
      Value_Type : Lovelace_Types.Lovelace_Type);

   function Collect_Unique_Dependencies
     (The_Module : Ast.Module) return Ast.Using_Sequence;

   function Expression_Type
     (The_Expression : Ast.Expression; Locals : Local_Map)
      return Lovelace_Types.Lovelace_Type;

   function Find_Local
     (The_Map : Local_Map; Name : String; Index : out Positive) return Boolean;

   function Find_Local
     (The_Map    : Local_Map;
      Name       : String;
      Index      : out Positive;
      Value_Type : out Lovelace_Types.Lovelace_Type) return Boolean;

   function Find_Symbol
     (Callee_Name  : String;
      Symbols      : Flat_Symbol_Vectors.Vector;
      Actual_Types : Actual_Type_Vectors.Vector;
      Target_Index : out Positive;
      Callee_Ast   : out Ast.Subroutine) return Boolean;

   function Formals_Match
     (The_Subroutine : Ast.Subroutine;
      Actual_Types   : Actual_Type_Vectors.Vector) return Boolean;

   function Lower_Call
     (The_Call       : Ast.Call_Statement;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Locals         : Local_Map;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine)
      return Generate_Result;

   function Lower_Expression
     (The_Expression : Ast.Expression;
      Locals         : Local_Map;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine)
      return Generate_Result;

   function Lower_Statement_Body
     (The_Body       : Ast.Block;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Locals         : in out Local_Map;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine)
      return Generate_Result;

   function Map_Flags
     (Flags : Ast.Subroutine_Flags)
      return Lovelace.Lir.Subroutines.Subroutine_Flags;

   function Map_Parameters
     (Parameters : Ast.Parameter_Sequence)
      return Lovelace.Lir.Types.Parameter_Sequence;

   function Map_Value_Type
     (The_Type : Lovelace.Compiler.Types.Type_Expression)
      return Lovelace.Lir.Types.Value_Type;

   --  Prefer absolute Source_Path from the compilation set; else AST filename.
   function Origin_Filename
     (Unit     : Unit_Graph.Loaded_Unit;
      Fallback : Source.Filename_Option) return Source.Filename_Option;

   procedure Pop_Scope (The_Map : in out Local_Map);

   procedure Push_Scope (The_Map : in out Local_Map);

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   procedure Append_Usings_From_Block
     (The_Block : Ast.Block; Into : in out Ast.Using_Sequence)
   is
      Block_Usings : constant Ast.Using_Sequence := Ast.Usings (The_Block);
      Statements   : constant Ast.Statement_Sequence :=
        Ast.Statements (The_Block);
   begin
      for Index in 1 .. Ast.Length (Block_Usings) loop
         Ast.Append (Into, Ast.Element (Block_Usings, Index));
      end loop;

      for Index in 1 .. Ast.Length (Statements) loop
         declare
            The_Statement : constant Ast.Statement :=
              Ast.Element (Statements, Index);
         begin
            if Ast.Kind (The_Statement) = Ast.Nested_Block then
               Append_Usings_From_Block (Ast.Block_Of (The_Statement), Into);
            end if;
         end;
      end loop;
   end Append_Usings_From_Block;

   procedure Bind_Local
     (The_Map    : in out Local_Map;
      Name       : String;
      Index      : Positive;
      Value_Type : Lovelace_Types.Lovelace_Type)
   is
      Last_Index : constant Positive := The_Map.Scopes.Last_Index;
      Frame      : Binding_Vectors.Vector :=
        The_Map.Scopes.Element (Last_Index);
   begin
      Frame.Append
        (Local_Binding'
           (Name       => Ada.Strings.Unbounded.To_Unbounded_String (Name),
            Index      => Index,
            Value_Type => Value_Type));
      The_Map.Scopes.Replace_Element (Last_Index, Frame);
   end Bind_Local;

   function Collect_Unique_Dependencies
     (The_Module : Ast.Module) return Ast.Using_Sequence
   is
      All_Usings : Ast.Using_Sequence := Ast.Empty_Using_Sequence;
      Result     : Ast.Using_Sequence := Ast.Empty_Using_Sequence;
   begin
      for Index in 1 .. Ast.Using_Count (The_Module) loop
         Ast.Append (All_Usings, Ast.Get_Using (The_Module, Index));
      end loop;

      for Sub_Index in 1 .. Ast.Subroutine_Count (The_Module) loop
         Append_Usings_From_Block
           (Ast.Get_Body (Ast.Get_Subroutine (The_Module, Sub_Index)),
            All_Usings);
      end loop;

      for Index in 1 .. Ast.Length (All_Usings) loop
         declare
            Candidate : constant Ast.Using_Declaration :=
              Ast.Element (All_Usings, Index);
            Seen      : Boolean := False;
         begin
            for Prior in 1 .. Ast.Length (Result) loop
               if Ast.Element (Result, Prior).Module_Name
                 = Candidate.Module_Name
               then
                  Seen := True;
                  exit;
               end if;
            end loop;

            if not Seen then
               Ast.Append (Result, Candidate);
            end if;
         end;
      end loop;

      return Result;
   end Collect_Unique_Dependencies;

   function Expression_Type
     (The_Expression : Ast.Expression; Locals : Local_Map)
      return Lovelace_Types.Lovelace_Type
   is
      Lexeme : constant String :=
        Ada.Strings.Unbounded.To_String (The_Expression.Lexeme);
   begin
      case The_Expression.Kind is
         when Ast.Boolean_Literal | Ast.Integer_Literal =>
            declare
               Typed : constant Typecheck.Type_Result :=
                 Typecheck.Type_Of_Literal (The_Expression);
            begin
               case Typed.Ok is
                  when True  =>
                     return Typed.The_Type;

                  when False =>
                     return Lovelace_Types.Unknown_Type;
               end case;
            end;

         when Ast.Name_Reference                       =>
            declare
               Slot       : Positive;
               Value_Type : Lovelace_Types.Lovelace_Type;
            begin
               if Find_Local (Locals, Lexeme, Slot, Value_Type) then
                  return Value_Type;
               end if;
               return Lovelace_Types.Unknown_Type;
            end;
      end case;
   end Expression_Type;

   function Failure
     (Code   : Ir_Generator_Error_Code;
      Span   : Source.Source_Span;
      Detail : String) return Generate_Result is
   begin
      return
        (Ok    => False,
         Error =>
           (Code   => Code,
            Span   => Span,
            Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Failure;

   function Find_Local
     (The_Map : Local_Map; Name : String; Index : out Positive) return Boolean
   is
      Value_Type : Lovelace_Types.Lovelace_Type;
   begin
      return Find_Local (The_Map, Name, Index, Value_Type);
   end Find_Local;

   function Find_Local
     (The_Map    : Local_Map;
      Name       : String;
      Index      : out Positive;
      Value_Type : out Lovelace_Types.Lovelace_Type) return Boolean is
   begin
      Index := 1;
      Value_Type := Lovelace_Types.Unknown_Type;
      for Scope_Index in reverse 1 .. Natural (The_Map.Scopes.Length) loop
         declare
            Frame : constant Binding_Vectors.Vector :=
              The_Map.Scopes.Element (Scope_Index);
         begin
            for Binding_Index in reverse 1 .. Natural (Frame.Length) loop
               declare
                  Binding : constant Local_Binding :=
                    Frame.Element (Binding_Index);
               begin
                  if Ada.Strings.Unbounded.To_String (Binding.Name) = Name then
                     Index := Binding.Index;
                     Value_Type := Binding.Value_Type;
                     return True;
                  end if;
               end;
            end loop;
         end;
      end loop;

      return False;
   end Find_Local;

   function Find_Symbol
     (Callee_Name  : String;
      Symbols      : Flat_Symbol_Vectors.Vector;
      Actual_Types : Actual_Type_Vectors.Vector;
      Target_Index : out Positive;
      Callee_Ast   : out Ast.Subroutine) return Boolean
   is
      Module_Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
      Match_Count    : Natural := 0;
   begin
      Target_Index := 1;
      if not Split_Callee (Callee_Name, Module_Prefix, Procedure_Name) then
         return False;
      end if;

      for Index in 1 .. Natural (Symbols.Length) loop
         declare
            Symbol : constant Flat_Symbol := Symbols.Element (Index);
         begin
            if Symbol.Module_Name = Module_Prefix
              and then Symbol.Procedure_Name = Procedure_Name
              and then Formals_Match (Symbol.The_Subroutine, Actual_Types)
            then
               Match_Count := Match_Count + 1;
               Target_Index := Index;
               Callee_Ast := Symbol.The_Subroutine;
            end if;
         end;
      end loop;

      return Match_Count = 1;
   end Find_Symbol;

   function Formals_Match
     (The_Subroutine : Ast.Subroutine;
      Actual_Types   : Actual_Type_Vectors.Vector) return Boolean
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

   function Generate (The_Module : Ast.Module) return Generate_Result is
      Units : Unit_Graph.Compilation_Set;
   begin
      Units.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => The_Module,
            Source_Path => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text => Ada.Strings.Unbounded.Null_Unbounded_String));
      return Generate (Units);
   end Generate;

   function Generate
     (Units : Unit_Graph.Compilation_Set) return Generate_Result
   is
      Symbols    : Flat_Symbol_Vectors.Vector;
      Root_Unit  : Ast.Module;
      Lir_Module : Lovelace.Lir.Modules.Module;
   begin
      if Natural (Units.Length) = 0 then
         return
           Failure
             (Internal_Error,
              (First => (Byte_Index => 1, Line => 1, Column => 1),
               Last  => (Byte_Index => 1, Line => 1, Column => 1)),
              "empty compilation set");
      end if;

      Root_Unit := Units.Element (1).The_Module;
      Lir_Module := Lovelace.Lir.Modules.Create (Ast.Name (Root_Unit));
      Lovelace.Lir.Modules.Set_Origin
        (Lir_Module,
         (Name_Span => Ast.Name_Span (Root_Unit),
          Span      => Ast.Span (Root_Unit),
          Filename  =>
            Origin_Filename
              (Units.Element (1), Ast.Filename (Root_Unit))));

      declare
         Dependencies : constant Ast.Using_Sequence :=
           Collect_Unique_Dependencies (Root_Unit);
      begin
         for Index in 1 .. Ast.Length (Dependencies) loop
            declare
               The_Import : constant Ast.Using_Declaration :=
                 Ast.Element (Dependencies, Index);
            begin
               Lovelace.Lir.Modules.Append_Dependency
                 (Lir_Module,
                  Ada.Strings.Unbounded.To_String (The_Import.Module_Name));
            end;
         end loop;
      end;

      for Unit_Index in 1 .. Natural (Units.Length) loop
         declare
            Loaded : constant Unit_Graph.Loaded_Unit :=
              Units.Element (Unit_Index);
         begin
            for Local_Index in 1 .. Ast.Subroutine_Count (Loaded.The_Module)
            loop
               declare
                  Ast_Sub   : constant Ast.Subroutine :=
                    Ast.Get_Subroutine (Loaded.The_Module, Local_Index);
                  Proc_Name : constant String := Ast.Name (Ast_Sub);
                  Mod_Name  : constant String := Ast.Name (Loaded.The_Module);
               begin
                  Symbols.Append
                    (Flat_Symbol'
                       (Unit_Index     => Unit_Index,
                        Local_Index    => Local_Index,
                        Module_Name    =>
                          Ada.Strings.Unbounded.To_Unbounded_String (Mod_Name),
                        Procedure_Name =>
                          Ada.Strings.Unbounded.To_Unbounded_String
                            (Proc_Name),
                        Lir_Name       =>
                          Ada.Strings.Unbounded.Null_Unbounded_String,
                        Exported       =>
                          Ast.Has_Export (Ast.Get_Flags (Ast_Sub)),
                        The_Subroutine => Ast_Sub));
               end;
            end loop;
         end;
      end loop;

      for Symbol_Index in 1 .. Natural (Symbols.Length) loop
         declare
            Symbol    : Flat_Symbol := Symbols.Element (Symbol_Index);
            Mod_Name  : constant String :=
              Ada.Strings.Unbounded.To_String (Symbol.Module_Name);
            Proc_Name : constant String :=
              Ada.Strings.Unbounded.To_String (Symbol.Procedure_Name);
            --  Always Module.Proc (overloads share a name); Call targets are by index.
            Lir_Name  : constant String := Mod_Name & "." & Proc_Name;
         begin
            Symbol.Lir_Name :=
              Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name);
            Symbols.Replace_Element (Symbol_Index, Symbol);
         end;
      end loop;

      for Symbol_Index in 1 .. Natural (Symbols.Length) loop
         declare
            Symbol         : constant Flat_Symbol :=
              Symbols.Element (Symbol_Index);
            Parameters     : constant Lovelace.Lir.Types.Parameter_Sequence :=
              Map_Parameters (Ast.Parameters (Symbol.The_Subroutine));
            The_Signature  : constant Lovelace.Lir.Subroutines.Signature :=
              (Name        => Symbol.Lir_Name,
               Return_Type =>
                 Map_Value_Type (Ast.Return_Type (Symbol.The_Subroutine)),
               Parameters  => Parameters);
            Lir_Subroutine : Lovelace.Lir.Subroutines.Subroutine :=
              Lovelace.Lir.Subroutines.Create
                (The_Signature => The_Signature,
                 Flags         =>
                   Map_Flags (Ast.Get_Flags (Symbol.The_Subroutine)));
            Body_Result    : Generate_Result;
            Ast_Native     : constant Ast.Native_Binding_Option :=
              Ast.Native (Symbol.The_Subroutine);
         begin
            Lovelace.Lir.Subroutines.Set_Origin
              (Lir_Subroutine,
               (Name_Span => Ast.Name_Span (Symbol.The_Subroutine),
                Span      => Ast.Span (Symbol.The_Subroutine),
                Filename  =>
                  Origin_Filename
                    (Units.Element (Symbol.Unit_Index),
                     Ast.Filename (Symbol.The_Subroutine))));

            if Symbol.Unit_Index /= 1 then
               Lovelace.Lir.Subroutines.Set_From_Dependency
                 (Lir_Subroutine,
                  Ada.Strings.Unbounded.To_String (Symbol.Module_Name));
            end if;

            declare
               Sub_Flags : constant Ast.Subroutine_Flags :=
                 Ast.Get_Flags (Symbol.The_Subroutine);
            begin
               if Ast.Has_Intrinsic (Sub_Flags)
                 and then Ast.Has_Native (Sub_Flags)
               then
                  return
                    Failure
                      (Internal_Error,
                       Ast.Name_Span (Symbol.The_Subroutine),
                       "procedure cannot be both @intrinsic and @native");
               end if;

               if Ast.Has_Intrinsic (Sub_Flags) then
                  if Ast_Native.Present then
                     return
                       Failure
                         (Internal_Error,
                          Ast.Name_Span (Symbol.The_Subroutine),
                          "intrinsic procedure must not carry a native binding");
                  end if;

                  declare
                     Matched : constant Intrinsics.Intrinsic_Kind_Option :=
                       Intrinsics.Match_Intrinsic
                         (Ada.Strings.Unbounded.To_String (Symbol.Module_Name),
                          Symbol.The_Subroutine);
                  begin
                     if not Matched.Present then
                        return
                          Failure
                            (Unknown_Intrinsic,
                             Ast.Name_Span (Symbol.The_Subroutine),
                             "unknown @intrinsic signature for procedure '"
                             & Ada.Strings.Unbounded.To_String
                                 (Symbol.Procedure_Name)
                             & "'");
                     end if;
                  end;

                  Lovelace.Lir.Subroutines.Set_Intrinsic (Lir_Subroutine);

               elsif Ast.Has_Native (Sub_Flags) then
                  if not Ast_Native.Present then
                     return
                       Failure
                         (Internal_Error,
                          Ast.Name_Span (Symbol.The_Subroutine),
                          "native flag without binding on procedure '"
                          & Ada.Strings.Unbounded.To_String
                              (Symbol.Procedure_Name)
                          & "'");
                  end if;

                  Lovelace.Lir.Subroutines.Set_Native_Binding
                    (Lir_Subroutine,
                     Ada.Strings.Unbounded.To_String
                       (Ast_Native.Value.Library),
                     Ada.Strings.Unbounded.To_String
                       (Ast_Native.Value.Function_Name));

               else
                  if Ast_Native.Present then
                     return
                       Failure
                         (Internal_Error,
                          Ast.Name_Span (Symbol.The_Subroutine),
                          "native binding without flag on procedure '"
                          & Ada.Strings.Unbounded.To_String
                              (Symbol.Procedure_Name)
                          & "'");
                  end if;

                  declare
                     Locals      : Local_Map;
                     Ast_Params  : constant Ast.Parameter_Sequence :=
                       Ast.Parameters (Symbol.The_Subroutine);
                     Param_Count : constant Natural := Ast.Length (Ast_Params);
                  begin
                     Push_Scope (Locals);
                     for Param_Index in 1 .. Param_Count loop
                        declare
                           The_Parameter : constant Ast.Parameter :=
                             Ast.Element (Ast_Params, Param_Index);
                        begin
                           Bind_Local
                             (Locals,
                              Ada.Strings.Unbounded.To_String
                                (The_Parameter.Parameter_Name),
                              Param_Index,
                              Lovelace_Types.From_Expression
                                (The_Parameter.Parameter_Type));
                        end;
                     end loop;
                     Locals.Next_Slot := Param_Count + 1;

                     Body_Result :=
                       Lower_Statement_Body
                         (The_Body       =>
                            Ast.Get_Body (Symbol.The_Subroutine),
                          Symbols        => Symbols,
                          Locals         => Locals,
                          Lir_Subroutine => Lir_Subroutine);
                     case Body_Result.Ok is
                        when False =>
                           return Body_Result;

                        when True  =>
                           null;
                     end case;
                  end;
               end if;
            end;

            Lovelace.Lir.Modules.Append_Subroutine
              (Lir_Module, Lir_Subroutine);
         end;
      end loop;

      declare
         Validation : constant Lovelace.Lir.Errors.Validation_Results.Result :=
           Lovelace.Lir.Modules.Validate (Lir_Module);
      begin
         case Validation.Ok is
            when True  =>
               return (Ok => True, The_Module => Lir_Module);

            when False =>
               return
                 Failure
                   (Internal_Error,
                    Ast.Name_Span (Root_Unit),
                    "LIR Validate failed: "
                    & Lovelace.Lir.Errors.Error_Code'Image (Validation.Error));
         end case;
      end;
   end Generate;

   function Lower_Call
     (The_Call       : Ast.Call_Statement;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Locals         : Local_Map;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine)
      return Generate_Result
   is
      Callee_Text  : constant String :=
        Ada.Strings.Unbounded.To_String (The_Call.Callee_Name);
      Actual_Types : Actual_Type_Vectors.Vector;
      Target_Index : Positive;
      Callee_Ast   : Ast.Subroutine;
   begin
      for Arg_Index in 1 .. Ast.Length (The_Call.Arguments) loop
         Actual_Types.Append
           (Expression_Type
              (Ast.Element (The_Call.Arguments, Arg_Index), Locals));
      end loop;

      --  Semantics already resolved and typed this call; the lookup recovers the flat overload index.
      if not Find_Symbol
               (Callee_Text, Symbols, Actual_Types, Target_Index, Callee_Ast)
      then
         return
           Failure
             (Internal_Error,
              The_Call.Name_Span,
              "call '"
              & Callee_Text
              & "' was not resolved by semantic analysis");
      end if;
      pragma Unreferenced (Callee_Ast);

      for Arg_Index in 1 .. Ast.Length (The_Call.Arguments) loop
         declare
            Arg_Result : constant Generate_Result :=
              Lower_Expression
                (Ast.Element (The_Call.Arguments, Arg_Index),
                 Locals,
                 Lir_Subroutine);
         begin
            case Arg_Result.Ok is
               when False =>
                  return Arg_Result;

               when True  =>
                  null;
            end case;
         end;
      end loop;

      Lovelace.Lir.Subroutines.Append_Instruction
        (Lir_Subroutine,
         (Operation    => Lovelace.Lir.Opcodes.Call,
          Target_Index => Interfaces.Unsigned_32 (Target_Index)));
      return (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));
   end Lower_Call;

   function Lower_Expression
     (The_Expression : Ast.Expression;
      Locals         : Local_Map;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine)
      return Generate_Result
   is
      Lexeme : constant String :=
        Ada.Strings.Unbounded.To_String (The_Expression.Lexeme);
   begin
      case The_Expression.Kind is
         when Ast.Boolean_Literal =>
            Lovelace.Lir.Subroutines.Append_Instruction
              (Lir_Subroutine,
               (Operation     => Lovelace.Lir.Opcodes.Constant_I32,
                Immediate_I32 => (if Lexeme = "true" then 1 else 0)));
            return
              (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));

         when Ast.Integer_Literal =>
            declare
               Evaluated : constant Literals.Integer_32_Results.Result :=
                 Literals.To_Integer_32 (Lexeme);
            begin
               case Evaluated.Ok is
                  when False =>
                     return
                       Failure
                         (Internal_Error,
                          The_Expression.Span,
                          "integer literal rejected by semantic analysis: "
                          & Ada.Strings.Unbounded.To_String
                              (Evaluated.Error.Detail));

                  when True  =>
                     Lovelace.Lir.Subroutines.Append_Instruction
                       (Lir_Subroutine,
                        (Operation     => Lovelace.Lir.Opcodes.Constant_I32,
                         Immediate_I32 => Evaluated.Value));
                     return
                       (Ok         => True,
                        The_Module => Lovelace.Lir.Modules.Create (""));
               end case;
            end;

         when Ast.Name_Reference  =>
            declare
               Slot : Positive;
            begin
               if not Find_Local (Locals, Lexeme, Slot) then
                  return
                    Failure
                      (Internal_Error,
                       The_Expression.Span,
                       "identifier '"
                       & Lexeme
                       & "' was not resolved by semantic analysis");
               end if;

               Lovelace.Lir.Subroutines.Append_Instruction
                 (Lir_Subroutine,
                  (Operation   => Lovelace.Lir.Opcodes.Local_Get,
                   Local_Index => Interfaces.Unsigned_32 (Slot)));
               return
                 (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));
            end;
      end case;
   end Lower_Expression;

   function Lower_Statement_Body
     (The_Body       : Ast.Block;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Locals         : in out Local_Map;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine)
      return Generate_Result
   is
      Block_Locals : constant Ast.Local_Sequence := Ast.Locals (The_Body);
      Statements   : constant Ast.Statement_Sequence :=
        Ast.Statements (The_Body);
   begin
      Push_Scope (Locals);

      for Local_Index in 1 .. Ast.Length (Block_Locals) loop
         declare
            The_Local : constant Ast.Local_Variable :=
              Ast.Element (Block_Locals, Local_Index);
            Slot      : constant Positive := Locals.Next_Slot;
         begin
            Lovelace.Lir.Subroutines.Append_Local
              (Lir_Subroutine,
               Ada.Strings.Unbounded.To_String (The_Local.Parameter_Name),
               Map_Value_Type (The_Local.Parameter_Type));
            Bind_Local
              (Locals,
               Ada.Strings.Unbounded.To_String (The_Local.Parameter_Name),
               Slot,
               Lovelace_Types.From_Expression (The_Local.Parameter_Type));
            Locals.Next_Slot := Slot + 1;
         end;
      end loop;

      for Index in 1 .. Ast.Length (Statements) loop
         declare
            The_Statement : constant Ast.Statement :=
              Ast.Element (Statements, Index);
            Nested_Result : Generate_Result;
         begin
            case Ast.Kind (The_Statement) is
               when Ast.Call         =>
                  Nested_Result :=
                    Lower_Call
                      (The_Call       => Ast.Call_Of (The_Statement),
                       Symbols        => Symbols,
                       Locals         => Locals,
                       Lir_Subroutine => Lir_Subroutine);

               when Ast.Assignment   =>
                  declare
                     The_Assignment : constant Ast.Assignment_Statement :=
                       Ast.Assignment_Of (The_Statement);
                     Target_Name    : constant String :=
                       Ada.Strings.Unbounded.To_String
                         (The_Assignment.Target_Name);
                     Slot           : Positive;
                     Rhs_Result     : Generate_Result;
                  begin
                     if not Find_Local (Locals, Target_Name, Slot) then
                        Nested_Result :=
                          Failure
                            (Internal_Error,
                             The_Assignment.Name_Span,
                             "assignment target '"
                             & Target_Name
                             & "' was not resolved by semantic analysis");
                     else
                        Rhs_Result :=
                          Lower_Expression
                            (The_Assignment.Value, Locals, Lir_Subroutine);
                        case Rhs_Result.Ok is
                           when False =>
                              Nested_Result := Rhs_Result;

                           when True  =>
                              Lovelace.Lir.Subroutines.Append_Instruction
                                (Lir_Subroutine,
                                 (Operation   =>
                                    Lovelace.Lir.Opcodes.Local_Set,
                                  Local_Index =>
                                    Interfaces.Unsigned_32 (Slot)));
                              Nested_Result :=
                                (Ok         => True,
                                 The_Module =>
                                   Lovelace.Lir.Modules.Create (""));
                        end case;
                     end if;
                  end;

               when Ast.Nested_Block =>
                  Nested_Result :=
                    Lower_Statement_Body
                      (The_Body       => Ast.Block_Of (The_Statement),
                       Symbols        => Symbols,
                       Locals         => Locals,
                       Lir_Subroutine => Lir_Subroutine);
            end case;

            case Nested_Result.Ok is
               when False =>
                  Pop_Scope (Locals);
                  return Nested_Result;

               when True  =>
                  null;
            end case;
         end;
      end loop;

      Pop_Scope (Locals);
      return (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));
   end Lower_Statement_Body;

   function Map_Flags
     (Flags : Ast.Subroutine_Flags)
      return Lovelace.Lir.Subroutines.Subroutine_Flags
   is
      Result : Lovelace.Lir.Subroutines.Subroutine_Flags := 0;
   begin
      if Ast.Has_Export (Flags) then
         Result := Result or Lovelace.Lir.Subroutines.Export_Flag;
      end if;

      if Ast.Has_Entrypoint (Flags) then
         Result := Result or Lovelace.Lir.Subroutines.Entrypoint_Flag;
      end if;

      if Ast.Has_Native (Flags) then
         Result := Result or Lovelace.Lir.Subroutines.Native_Flag;
      end if;

      if Ast.Has_Intrinsic (Flags) then
         Result := Result or Lovelace.Lir.Subroutines.Intrinsic_Flag;
      end if;

      return Result;
   end Map_Flags;

   function Map_Parameters
     (Parameters : Ast.Parameter_Sequence)
      return Lovelace.Lir.Types.Parameter_Sequence
   is
      Result : Lovelace.Lir.Types.Parameter_Sequence :=
        Lovelace.Lir.Types.Empty_Sequence;
   begin
      for Index in 1 .. Ast.Length (Parameters) loop
         declare
            The_Parameter : constant Ast.Parameter :=
              Ast.Element (Parameters, Index);
         begin
            Lovelace.Lir.Types.Append
              (Sequence => Result,
               Name     =>
                 Ada.Strings.Unbounded.To_String
                   (The_Parameter.Parameter_Name),
               The_Type => Map_Value_Type (The_Parameter.Parameter_Type));
         end;
      end loop;

      return Result;
   end Map_Parameters;

   function Map_Value_Type
     (The_Type : Lovelace.Compiler.Types.Type_Expression)
      return Lovelace.Lir.Types.Value_Type is
   begin
      case The_Type.Kind is
         when Lovelace.Compiler.Types.Unit    =>
            return Lovelace.Lir.Types.Unit;

         when Lovelace.Compiler.Types.Boolean =>
            return Lovelace.Lir.Types.I32;

         when Lovelace.Compiler.Types.Integer =>
            case The_Type.The_Signedness is
               when Lovelace.Compiler.Types.Signed   =>
                  case The_Type.Integer_Bit_Size is
                     when Lovelace.Compiler.Types.Bits_8  =>
                        return Lovelace.Lir.Types.I8;

                     when Lovelace.Compiler.Types.Bits_16 =>
                        return Lovelace.Lir.Types.I16;

                     when Lovelace.Compiler.Types.Bits_32 =>
                        return Lovelace.Lir.Types.I32;

                     when Lovelace.Compiler.Types.Bits_64 =>
                        return Lovelace.Lir.Types.I64;
                  end case;

               when Lovelace.Compiler.Types.Unsigned =>
                  case The_Type.Integer_Bit_Size is
                     when Lovelace.Compiler.Types.Bits_8  =>
                        return Lovelace.Lir.Types.U8;

                     when Lovelace.Compiler.Types.Bits_16 =>
                        return Lovelace.Lir.Types.U16;

                     when Lovelace.Compiler.Types.Bits_32 =>
                        return Lovelace.Lir.Types.U32;

                     when Lovelace.Compiler.Types.Bits_64 =>
                        return Lovelace.Lir.Types.U64;
                  end case;
            end case;

         when Lovelace.Compiler.Types.Float   =>
            case The_Type.Float_Bit_Size is
               when Lovelace.Compiler.Types.Bits_32 =>
                  return Lovelace.Lir.Types.F32;

               when Lovelace.Compiler.Types.Bits_64 =>
                  return Lovelace.Lir.Types.F64;
            end case;
      end case;
   end Map_Value_Type;

   function Origin_Filename
     (Unit     : Unit_Graph.Loaded_Unit;
      Fallback : Source.Filename_Option) return Source.Filename_Option
   is
      Path : constant String :=
        Ada.Strings.Unbounded.To_String (Unit.Source_Path);
   begin
      if Path'Length = 0 then
         return Fallback;
      end if;

      declare
         Absolute : constant String := Ada.Directories.Full_Name (Path);
      begin
         return Source.Some_Filename (Source.From_Utf_8 (Absolute));
      end;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         return Source.Some_Filename (Source.From_Utf_8 (Path));
   end Origin_Filename;

   procedure Pop_Scope (The_Map : in out Local_Map) is
   begin
      if not The_Map.Scopes.Is_Empty then
         The_Map.Scopes.Delete_Last;
      end if;
   end Pop_Scope;

   procedure Push_Scope (The_Map : in out Local_Map) is
      Empty_Frame : Binding_Vectors.Vector;
   begin
      The_Map.Scopes.Append (Empty_Frame);
   end Push_Scope;

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

end Lovelace.Compiler.Ir_Generator;
