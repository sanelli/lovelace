with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces;

with Lovelace.Compiler.Literals;
with Lovelace.Compiler.Types;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Ir_Generator is

   use type Interfaces.Integer_32;
   use type Lovelace.Lir.Subroutines.Subroutine_Flags;
   use type Lovelace.Lir.Types.Value_Type;

   function Failure (Code : Ir_Generator_Error_Code; Span : Source.Source_Span; Detail : String) return Generate_Result;
   --  Build a Generate_Result failure.

   function Find_Same_Unit_Callee
     (The_Module : Ast.Module; Callee_Name : String; Target_Index : out Positive) return Boolean;
   --  True when Callee_Name is UnitName.Procedure and Procedure exists locally.

   function Formal_Accepts_I32_Constant (Formal_Type : Lovelace.Lir.Types.Value_Type) return Boolean;
   --  True when a Constant_I32 argument can lower to this formal (core i32 widen).

   function Lower_Call
     (The_Module     : Ast.Module;
      The_Call       : Ast.Call_Statement;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result;
   --  Resolve The_Call and append Constant_I32 / Call instructions.

   function Lower_Statement_Body
     (The_Module     : Ast.Module;
      The_Body       : Ast.Statement_Sequence;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result;
   --  Lower each statement in The_Body onto Lir_Subroutine.

   function Map_Flags (Flags : Ast.Subroutine_Flags) return Lovelace.Lir.Subroutines.Subroutine_Flags;
   --  Rebuild LIR flag bits from frontend Has_Export / Has_Entrypoint.

   function Map_Parameters (Parameters : Ast.Parameter_Sequence) return Lovelace.Lir.Types.Parameter_Sequence;
   --  Map frontend parameters to named LIR parameters.

   function Map_Value_Type (The_Type : Lovelace.Compiler.Types.Type_Expression) return Lovelace.Lir.Types.Value_Type;
   --  Map a frontend type expression to a LIR Value_Type (exhaustive).

   function Split_Callee
     (Callee_Name    : String;
      Module_Prefix  : out Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   --  Split MODULE.SUBROUTINE on the last '.'; False when no dot.

   function Failure (Code : Ir_Generator_Error_Code; Span : Source.Source_Span; Detail : String) return Generate_Result
   is
   begin
      return
        (Ok    => False,
         Error => (Code => Code, Span => Span, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Failure;

   function Find_Same_Unit_Callee
     (The_Module : Ast.Module; Callee_Name : String; Target_Index : out Positive) return Boolean
   is
      Module_Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      Procedure_Name : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Target_Index := 1;
      if not Split_Callee (Callee_Name, Module_Prefix, Procedure_Name) then
         return False;
      end if;

      if Ada.Strings.Unbounded.To_String (Module_Prefix) /= Ast.Name (The_Module) then
         return False;
      end if;

      for Index in 1 .. Ast.Subroutine_Count (The_Module) loop
         if Ast.Name (Ast.Get_Subroutine (The_Module, Index)) = Ada.Strings.Unbounded.To_String (Procedure_Name) then
            Target_Index := Index;
            return True;
         end if;
      end loop;

      return False;
   end Find_Same_Unit_Callee;

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
      Lir_Module : Lovelace.Lir.Modules.Module := Lovelace.Lir.Modules.Create (Ast.Name (The_Module));
   begin
      Lovelace.Lir.Modules.Set_Origin
        (Lir_Module,
         (Name_Span => Ast.Name_Span (The_Module),
          Span      => Ast.Span (The_Module),
          Filename  => Ast.Filename (The_Module)));

      for Index in 1 .. Ast.Import_Count (The_Module) loop
         declare
            The_Import : constant Ast.Import_Declaration := Ast.Get_Import (The_Module, Index);
         begin
            Lovelace.Lir.Modules.Append_Dependency
              (Lir_Module, Ada.Strings.Unbounded.To_String (The_Import.Module_Name));
         end;
      end loop;

      for Index in 1 .. Ast.Subroutine_Count (The_Module) loop
         declare
            Ast_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, Index);
            Parameters     : constant Lovelace.Lir.Types.Parameter_Sequence :=
              Map_Parameters (Ast.Parameters (Ast_Subroutine));
            The_Signature  : constant Lovelace.Lir.Subroutines.Signature :=
              (Name        => Ada.Strings.Unbounded.To_Unbounded_String (Ast.Name (Ast_Subroutine)),
               Return_Type => Map_Value_Type (Ast.Return_Type (Ast_Subroutine)),
               Parameters  => Parameters);
            Lir_Subroutine : Lovelace.Lir.Subroutines.Subroutine :=
              Lovelace.Lir.Subroutines.Create
                (The_Signature => The_Signature, Flags => Map_Flags (Ast.Get_Flags (Ast_Subroutine)));
            Body_Result    : Generate_Result;
         begin
            Lovelace.Lir.Subroutines.Set_Origin
              (Lir_Subroutine,
               (Name_Span => Ast.Name_Span (Ast_Subroutine), Filename => Ast.Filename (Ast_Subroutine)));

            Body_Result :=
              Lower_Statement_Body
                (The_Module => The_Module, The_Body => Ast.Get_Body (Ast_Subroutine), Lir_Subroutine => Lir_Subroutine);
            case Body_Result.Ok is
               when False =>
                  return Body_Result;

               when True  =>
                  null;
            end case;

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
                    Ast.Name_Span (The_Module),
                    "LIR Validate failed: " & Lovelace.Lir.Errors.Error_Code'Image (Validation.Error));
         end case;
      end;
   end Generate;

   function Lower_Call
     (The_Module     : Ast.Module;
      The_Call       : Ast.Call_Statement;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result
   is
      Callee_Text  : constant String := Ada.Strings.Unbounded.To_String (The_Call.Callee_Name);
      Target_Index : Positive;
      Callee_Ast   : Ast.Subroutine;
      Formal_Count : Natural;
      Actual_Count : constant Natural := Ast.Length (The_Call.Arguments);
   begin
      if not Find_Same_Unit_Callee (The_Module, Callee_Text, Target_Index) then
         return
           Failure
             (Unresolved_Call,
              The_Call.Name_Span,
              "unresolved call '" & Callee_Text & "' (same-unit MODULE.SUBROUTINE only in this slice)");
      end if;

      Callee_Ast := Ast.Get_Subroutine (The_Module, Target_Index);
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
            The_Argument : constant Ast.Call_Argument := Ast.Element (The_Call.Arguments, Arg_Index);
            Formal       : constant Ast.Parameter := Ast.Element (Ast.Parameters (Callee_Ast), Arg_Index);
            Formal_Lir   : constant Lovelace.Lir.Types.Value_Type := Map_Value_Type (Formal.Parameter_Type);
            Lexeme       : constant String := Ada.Strings.Unbounded.To_String (The_Argument.Lexeme);
            Evaluated    : constant Literals.Integer_32_Results.Result := Literals.To_Integer_32 (Lexeme);
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
                       "invalid integer literal argument: " & Ada.Strings.Unbounded.To_String (Evaluated.Error.Detail));

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
      end loop;

      Lovelace.Lir.Subroutines.Append_Instruction
        (Lir_Subroutine,
         (Operation => Lovelace.Lir.Opcodes.Call, Target_Index => Interfaces.Unsigned_32 (Target_Index)));
      return (Ok => True, The_Module => Lovelace.Lir.Modules.Create (""));
   end Lower_Call;

   function Lower_Statement_Body
     (The_Module     : Ast.Module;
      The_Body       : Ast.Statement_Sequence;
      Lir_Subroutine : in out Lovelace.Lir.Subroutines.Subroutine) return Generate_Result is
   begin
      for Index in 1 .. Ast.Length (The_Body) loop
         declare
            The_Statement : constant Ast.Statement := Ast.Element (The_Body, Index);
            Call_Result   : Generate_Result;
         begin
            case The_Statement.Kind is
               when Ast.Call =>
                  Call_Result :=
                    Lower_Call
                      (The_Module => The_Module, The_Call => The_Statement.The_Call, Lir_Subroutine => Lir_Subroutine);
                  case Call_Result.Ok is
                     when False =>
                        return Call_Result;

                     when True  =>
                        null;
                  end case;
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
