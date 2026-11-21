with Ada.Containers.Vectors;
with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces;

with Lovelace.Compiler.Intrinsics;
with Lovelace.Compiler.Literals;
with Lovelace.Compiler.Types;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Ir_Generator is

   use type Interfaces.Integer_32;
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

   package Flat_Symbol_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Flat_Symbol);

   function Failure (Code : Ir_Generator_Error_Code; Span : Source.Source_Span; Detail : String) return Generate_Result;

   function Formal_Accepts_I32_Constant (Formal_Type : Lovelace.Lir.Types.Value_Type) return Boolean;

   function Import_Allows (Caller : Ast.Module; Module_Name : String) return Boolean;

   function Lower_Call
     (Caller_Unit    : Ast.Module;
      The_Call       : Ast.Call_Statement;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result;

   function Lower_Statement_Body
     (Caller_Unit    : Ast.Module;
      The_Body       : Ast.Block;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result;

   function Map_Flags (Flags : Ast.Subroutine_Flags) return Lovelace.Lir.Subroutines.Subroutine_Flags;

   function Map_Parameters (Parameters : Ast.Parameter_Sequence) return Lovelace.Lir.Types.Parameter_Sequence;

   function Map_Value_Type (The_Type : Lovelace.Compiler.Types.Type_Expression) return Lovelace.Lir.Types.Value_Type;

   function Resolve_Callee
     (Caller_Unit  : Ast.Module;
      Callee_Name  : String;
      Symbols      : Flat_Symbol_Vectors.Vector;
      Target_Index : out Positive;
      Callee_Ast   : out Ast.Subroutine;
      Error_Code   : out Ir_Generator_Error_Code;
      Error_Detail : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   function Failure (Code : Ir_Generator_Error_Code; Span : Source.Source_Span; Detail : String) return Generate_Result
   is
   begin
      return
        (Ok    => False,
         Error => (Code => Code, Span => Span, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Failure;

   function Formal_Accepts_I32_Constant (Formal_Type : Lovelace.Lir.Types.Value_Type) return Boolean is
   begin
      case Formal_Type is
         when Lovelace.Lir.Types.I8
            | Lovelace.Lir.Types.I16
            | Lovelace.Lir.Types.I32
            | Lovelace.Lir.Types.U8
            | Lovelace.Lir.Types.U16
            | Lovelace.Lir.Types.U32 =>
            return True;

         when others                 =>
            return False;
      end case;
   end Formal_Accepts_I32_Constant;

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

   function Generate (Units : Unit_Graph.Compilation_Set) return Generate_Result is
      Symbols    : Flat_Symbol_Vectors.Vector;
      Root_Unit  : Ast.Module;
      Lir_Module : Lovelace.Lir.Modules.Module;
   begin
      if Natural (Units.Length) = 0 then
         return
           Failure
             (Internal_Error,
              (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1)),
              "empty compilation set");
      end if;

      Root_Unit := Units.Element (1).The_Module;
      Lir_Module := Lovelace.Lir.Modules.Create (Ast.Name (Root_Unit));
      Lovelace.Lir.Modules.Set_Origin
        (Lir_Module,
         (Name_Span => Ast.Name_Span (Root_Unit), Span => Ast.Span (Root_Unit), Filename => Ast.Filename (Root_Unit)));

      for Index in 1 .. Ast.Using_Count (Root_Unit) loop
         declare
            The_Import : constant Ast.Using_Declaration := Ast.Get_Using (Root_Unit, Index);
         begin
            Lovelace.Lir.Modules.Append_Dependency
              (Lir_Module, Ada.Strings.Unbounded.To_String (The_Import.Module_Name));
         end;
      end loop;

      for Unit_Index in 1 .. Natural (Units.Length) loop
         declare
            Loaded  : constant Unit_Graph.Loaded_Unit := Units.Element (Unit_Index);
            Is_Root : constant Boolean := Unit_Index = 1;
         begin
            for Local_Index in 1 .. Ast.Subroutine_Count (Loaded.The_Module) loop
               declare
                  Ast_Sub   : constant Ast.Subroutine := Ast.Get_Subroutine (Loaded.The_Module, Local_Index);
                  Proc_Name : constant String := Ast.Name (Ast_Sub);
                  Mod_Name  : constant String := Ast.Name (Loaded.The_Module);
                  Lir_Name  : constant String := (if Is_Root then Proc_Name else Mod_Name & "." & Proc_Name);
               begin
                  Symbols.Append
                    (Flat_Symbol'
                       (Unit_Index     => Unit_Index,
                        Local_Index    => Local_Index,
                        Module_Name    => Ada.Strings.Unbounded.To_Unbounded_String (Mod_Name),
                        Procedure_Name => Ada.Strings.Unbounded.To_Unbounded_String (Proc_Name),
                        Lir_Name       => Ada.Strings.Unbounded.To_Unbounded_String (Lir_Name),
                        Exported       => Ast.Has_Export (Ast.Get_Flags (Ast_Sub)),
                        The_Subroutine => Ast_Sub));
               end;
            end loop;
         end;
      end loop;

      for Symbol_Index in 1 .. Natural (Symbols.Length) loop
         declare
            Symbol         : constant Flat_Symbol := Symbols.Element (Symbol_Index);
            Caller_Unit    : constant Ast.Module := Units.Element (Symbol.Unit_Index).The_Module;
            Parameters     : constant Lovelace.Lir.Types.Parameter_Sequence :=
              Map_Parameters (Ast.Parameters (Symbol.The_Subroutine));
            The_Signature  : constant Lovelace.Lir.Subroutines.Signature :=
              (Name        => Symbol.Lir_Name,
               Return_Type => Map_Value_Type (Ast.Return_Type (Symbol.The_Subroutine)),
               Parameters  => Parameters);
            Lir_Subroutine : Lovelace.Lir.Subroutines.Subroutine :=
              Lovelace.Lir.Subroutines.Create
                (The_Signature => The_Signature, Flags => Map_Flags (Ast.Get_Flags (Symbol.The_Subroutine)));
            Body_Result    : Generate_Result;
            Ast_Native     : constant Ast.Native_Binding_Option := Ast.Native (Symbol.The_Subroutine);
         begin
            Lovelace.Lir.Subroutines.Set_Origin
              (Lir_Subroutine,
               (Name_Span => Ast.Name_Span (Symbol.The_Subroutine), Filename => Ast.Filename (Symbol.The_Subroutine)));

            declare
               Sub_Flags : constant Ast.Subroutine_Flags := Ast.Get_Flags (Symbol.The_Subroutine);
            begin
               if Ast.Has_Intrinsic (Sub_Flags) and then Ast.Has_Native (Sub_Flags) then
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
                         (Ada.Strings.Unbounded.To_String (Symbol.Module_Name), Symbol.The_Subroutine);
                  begin
                     if not Matched.Present then
                        return
                          Failure
                            (Unknown_Intrinsic,
                             Ast.Name_Span (Symbol.The_Subroutine),
                             "unknown @intrinsic signature for procedure '"
                             & Ada.Strings.Unbounded.To_String (Symbol.Procedure_Name)
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
                          & Ada.Strings.Unbounded.To_String (Symbol.Procedure_Name)
                          & "'");
                  end if;

                  Lovelace.Lir.Subroutines.Set_Native_Binding
                    (Lir_Subroutine,
                     Ada.Strings.Unbounded.To_String (Ast_Native.Value.Library),
                     Ada.Strings.Unbounded.To_String (Ast_Native.Value.Function_Name));

               else
                  if Ast_Native.Present then
                     return
                       Failure
                         (Internal_Error,
                          Ast.Name_Span (Symbol.The_Subroutine),
                          "native binding without flag on procedure '"
                          & Ada.Strings.Unbounded.To_String (Symbol.Procedure_Name)
                          & "'");
                  end if;

                  Body_Result :=
                    Lower_Statement_Body
                      (Caller_Unit    => Caller_Unit,
                       The_Body       => Ast.Get_Body (Symbol.The_Subroutine),
                       Symbols        => Symbols,
                       Lir_Subroutine => Lir_Subroutine);
                  case Body_Result.Ok is
                     when False =>
                        return Body_Result;

                     when True  =>
                        null;
                  end case;
               end if;
            end;

            Lovelace.Lir.Modules.Append_Subroutine (Lir_Module, Lir_Subroutine);
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
                    "LIR Validate failed: " & Lovelace.Lir.Errors.Error_Code'Image (Validation.Error));
         end case;
      end;
   end Generate;

   function Import_Allows (Caller : Ast.Module; Module_Name : String) return Boolean is
   begin
      for Index in 1 .. Ast.Using_Count (Caller) loop
         if Ada.Strings.Unbounded.To_String (Ast.Get_Using (Caller, Index).Module_Name) = Module_Name then
            return True;
         end if;
      end loop;
      return False;
   end Import_Allows;

   function Lower_Call
     (Caller_Unit    : Ast.Module;
      The_Call       : Ast.Call_Statement;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result
   is
      Callee_Text  : constant String := Ada.Strings.Unbounded.To_String (The_Call.Callee_Name);
      Target_Index : Positive;
      Callee_Ast   : Ast.Subroutine;
      Error_Code   : Ir_Generator_Error_Code;
      Error_Detail : Ada.Strings.Unbounded.Unbounded_String;
      Formal_Count : Natural;
      Actual_Count : constant Natural := Ast.Length (The_Call.Arguments);
   begin
      if not Resolve_Callee (Caller_Unit, Callee_Text, Symbols, Target_Index, Callee_Ast, Error_Code, Error_Detail) then
         return Failure (Error_Code, The_Call.Name_Span, Ada.Strings.Unbounded.To_String (Error_Detail));
      end if;

      Formal_Count := Ast.Length (Ast.Parameters (Callee_Ast));
      if Actual_Count /= Formal_Count then
         return
           Failure
             (Invalid_Arguments,
              The_Call.Name_Span,
              "call '"
              & Callee_Text
              & "' expects "
              & Natural'Image (Formal_Count)
              & " argument(s), found "
              & Natural'Image (Actual_Count));
      end if;

      for Arg_Index in 1 .. Actual_Count loop
         declare
            The_Argument : constant Ast.Expression := Ast.Element (The_Call.Arguments, Arg_Index);
            Formal       : constant Ast.Parameter := Ast.Element (Ast.Parameters (Callee_Ast), Arg_Index);
            Formal_Lir   : constant Lovelace.Lir.Types.Value_Type := Map_Value_Type (Formal.Parameter_Type);
            Lexeme       : constant String := Ada.Strings.Unbounded.To_String (The_Argument.Lexeme);
         begin
            case Formal.Parameter_Type.Kind is
               when Lovelace.Compiler.Types.Boolean                              =>
                  if Lexeme = "true" then
                     Lovelace.Lir.Subroutines.Append_Instruction
                       (Lir_Subroutine, (Operation => Lovelace.Lir.Opcodes.Constant_I32, Immediate_I32 => 1));
                  elsif Lexeme = "false" then
                     Lovelace.Lir.Subroutines.Append_Instruction
                       (Lir_Subroutine, (Operation => Lovelace.Lir.Opcodes.Constant_I32, Immediate_I32 => 0));
                  else
                     return
                       Failure
                         (Invalid_Arguments,
                          The_Argument.Span,
                          "argument "
                          & Natural'Image (Arg_Index)
                          & " of '"
                          & Callee_Text
                          & "' expects true or false for a boolean parameter");
                  end if;

               when Lovelace.Compiler.Types.Integer                              =>
                  declare
                     Evaluated : constant Literals.Integer_32_Results.Result := Literals.To_Integer_32 (Lexeme);
                  begin
                     if not Formal_Accepts_I32_Constant (Formal_Lir) then
                        return
                          Failure
                            (Invalid_Arguments,
                             The_Argument.Span,
                             "argument "
                             & Natural'Image (Arg_Index)
                             & " of '"
                             & Callee_Text
                             & "' has a formal type that cannot take an i32 constant in this slice");
                     end if;

                     case Evaluated.Ok is
                        when False =>
                           return
                             Failure
                               (Invalid_Arguments,
                                The_Argument.Span,
                                "invalid integer literal argument: "
                                & Ada.Strings.Unbounded.To_String (Evaluated.Error.Detail));

                        when True  =>
                           if Formal_Lir in Lovelace.Lir.Types.U8 | Lovelace.Lir.Types.U16 | Lovelace.Lir.Types.U32
                             and then Evaluated.Value < 0
                           then
                              return
                                Failure
                                  (Invalid_Arguments,
                                   The_Argument.Span,
                                   "negative literal cannot be passed to an unsigned parameter");
                           end if;

                           Lovelace.Lir.Subroutines.Append_Instruction
                             (Lir_Subroutine,
                              (Operation => Lovelace.Lir.Opcodes.Constant_I32, Immediate_I32 => Evaluated.Value));
                     end case;
                  end;

               when Lovelace.Compiler.Types.Unit | Lovelace.Compiler.Types.Float =>
                  return
                    Failure
                      (Invalid_Arguments,
                       The_Argument.Span,
                       "argument "
                       & Natural'Image (Arg_Index)
                       & " of '"
                       & Callee_Text
                       & "' has a formal type that cannot take a literal argument in this slice");
            end case;
         end;
      end loop;

      Lovelace.Lir.Subroutines.Append_Instruction
        (Lir_Subroutine,
         (Operation => Lovelace.Lir.Opcodes.Call, Target_Index => Interfaces.Unsigned_32 (Target_Index)));
      return (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));
   end Lower_Call;

   function Lower_Statement_Body
     (Caller_Unit    : Ast.Module;
      The_Body       : Ast.Block;
      Symbols        : Flat_Symbol_Vectors.Vector;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result
   is
      Locals     : constant Ast.Local_Sequence := Ast.Locals (The_Body);
      Statements : constant Ast.Statement_Sequence := Ast.Statements (The_Body);
   begin
      for Local_Index in 1 .. Ast.Length (Locals) loop
         declare
            The_Local : constant Ast.Local_Variable := Ast.Element (Locals, Local_Index);
         begin
            Lovelace.Lir.Subroutines.Append_Local
              (Lir_Subroutine,
               Ada.Strings.Unbounded.To_String (The_Local.Parameter_Name),
               Map_Value_Type (The_Local.Parameter_Type));
         end;
      end loop;

      for Index in 1 .. Ast.Length (Statements) loop
         declare
            The_Statement : constant Ast.Statement := Ast.Element (Statements, Index);
            Nested_Result : Generate_Result;
         begin
            case Ast.Kind (The_Statement) is
               when Ast.Call         =>
                  Nested_Result :=
                    Lower_Call
                      (Caller_Unit    => Caller_Unit,
                       The_Call       => Ast.Call_Of (The_Statement),
                       Symbols        => Symbols,
                       Lir_Subroutine => Lir_Subroutine);

               when Ast.Assignment   =>
                  --  Assignment lowering lands in a later plan step (Local_Set).
                  Nested_Result :=
                    Failure
                      (Internal_Error,
                       Ast.Assignment_Of (The_Statement).Name_Span,
                       "assignment statements are not lowered yet");

               when Ast.Nested_Block =>
                  Nested_Result :=
                    Lower_Statement_Body
                      (Caller_Unit    => Caller_Unit,
                       The_Body       => Ast.Block_Of (The_Statement),
                       Symbols        => Symbols,
                       Lir_Subroutine => Lir_Subroutine);
            end case;

            case Nested_Result.Ok is
               when False =>
                  return Nested_Result;

               when True  =>
                  null;
            end case;
         end;
      end loop;

      return (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));
   end Lower_Statement_Body;

   function Map_Flags (Flags : Ast.Subroutine_Flags) return Lovelace.Lir.Subroutines.Subroutine_Flags is
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

   function Map_Parameters (Parameters : Ast.Parameter_Sequence) return Lovelace.Lir.Types.Parameter_Sequence is
      Result : Lovelace.Lir.Types.Parameter_Sequence := Lovelace.Lir.Types.Empty_Sequence;
   begin
      for Index in 1 .. Ast.Length (Parameters) loop
         declare
            The_Parameter : constant Ast.Parameter := Ast.Element (Parameters, Index);
         begin
            Lovelace.Lir.Types.Append
              (Sequence => Result,
               Name     => Ada.Strings.Unbounded.To_String (The_Parameter.Parameter_Name),
               The_Type => Map_Value_Type (The_Parameter.Parameter_Type));
         end;
      end loop;

      return Result;
   end Map_Parameters;

   function Map_Value_Type (The_Type : Lovelace.Compiler.Types.Type_Expression) return Lovelace.Lir.Types.Value_Type is
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

   function Resolve_Callee
     (Caller_Unit  : Ast.Module;
      Callee_Name  : String;
      Symbols      : Flat_Symbol_Vectors.Vector;
      Target_Index : out Positive;
      Callee_Ast   : out Ast.Subroutine;
      Error_Code   : out Ir_Generator_Error_Code;
      Error_Detail : out Ada.Strings.Unbounded.Unbounded_String) return Boolean
   is
      Module_Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
      Prefix_Text    : Ada.Strings.Unbounded.Unbounded_String;
      Proc_Text      : Ada.Strings.Unbounded.Unbounded_String;
      Found_Index    : Natural := 0;
      Found_Export   : Boolean := False;
      Found_Ast      : Ast.Subroutine;
   begin
      Target_Index := 1;
      Error_Code := Unresolved_Call;
      Error_Detail := Ada.Strings.Unbounded.Null_Unbounded_String;
      --  Placeholder; overwritten on success. Caller always has at least one
      --  subroutine when lowering a body.
      Callee_Ast := Ast.Get_Subroutine (Caller_Unit, 1);

      if not Split_Callee (Callee_Name, Module_Prefix, Procedure_Name) then
         Error_Detail := Ada.Strings.Unbounded.To_Unbounded_String ("unresolved call '" & Callee_Name & "'");
         return False;
      end if;

      Prefix_Text := Module_Prefix;
      Proc_Text := Procedure_Name;

      if Ada.Strings.Unbounded.To_String (Prefix_Text) = Ast.Name (Caller_Unit) then
         for Index in 1 .. Natural (Symbols.Length) loop
            declare
               Symbol : constant Flat_Symbol := Symbols.Element (Index);
            begin
               if Ada.Strings.Unbounded.To_String (Symbol.Module_Name) = Ast.Name (Caller_Unit)
                 and then Ada.Strings.Unbounded.To_String (Symbol.Procedure_Name)
                          = Ada.Strings.Unbounded.To_String (Proc_Text)
               then
                  Target_Index := Index;
                  Callee_Ast := Symbol.The_Subroutine;
                  return True;
               end if;
            end;
         end loop;
         Error_Detail := Ada.Strings.Unbounded.To_Unbounded_String ("unresolved call '" & Callee_Name & "'");
         return False;
      end if;

      if not Import_Allows (Caller_Unit, Ada.Strings.Unbounded.To_String (Prefix_Text)) then
         Error_Code := Call_Without_Using;
         Error_Detail :=
           Ada.Strings.Unbounded.To_Unbounded_String
             ("call '" & Callee_Name & "' requires using " & Ada.Strings.Unbounded.To_String (Prefix_Text));
         return False;
      end if;

      for Index in 1 .. Natural (Symbols.Length) loop
         declare
            Symbol : constant Flat_Symbol := Symbols.Element (Index);
         begin
            if Ada.Strings.Unbounded.To_String (Symbol.Module_Name) = Ada.Strings.Unbounded.To_String (Prefix_Text)
              and then Ada.Strings.Unbounded.To_String (Symbol.Procedure_Name)
                       = Ada.Strings.Unbounded.To_String (Proc_Text)
            then
               Found_Index := Index;
               Found_Export := Symbol.Exported;
               Found_Ast := Symbol.The_Subroutine;
               exit;
            end if;
         end;
      end loop;

      if Found_Index = 0 then
         Error_Detail := Ada.Strings.Unbounded.To_Unbounded_String ("unresolved call '" & Callee_Name & "'");
         return False;
      end if;

      if not Found_Export then
         Error_Code := Not_Exported;
         Error_Detail := Ada.Strings.Unbounded.To_Unbounded_String ("procedure '" & Callee_Name & "' is not exported");
         return False;
      end if;

      Target_Index := Found_Index;
      Callee_Ast := Found_Ast;
      return True;
   end Resolve_Callee;

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

end Lovelace.Compiler.Ir_Generator;
