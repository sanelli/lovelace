with Lovelace.Compiler.Types;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Ir_Generator is

   use type Lovelace.Lir.Subroutines.Subroutine_Flags;

   function Failure (Detail : String) return Generate_Result;
   --  Build a Generate_Result failure with Internal_Error and Detail.

   function Map_Flags (Flags : Ast.Subroutine_Flags) return Lovelace.Lir.Subroutines.Subroutine_Flags;
   --  Rebuild LIR flag bits from frontend Has_Export / Has_Entrypoint.

   function Map_Return_Type
     (Return_Type : Lovelace.Compiler.Types.Type_Expression) return Lovelace.Lir.Types.Value_Type;
   --  Map frontend Unit to LIR Unit (exhaustive on Type_Kind).

   function Failure (Detail : String) return Generate_Result is
   begin
      return
        (Ok => False, Error => (Code => Internal_Error, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail)));
   end Failure;

   function Generate (The_Module : Ast.Module) return Generate_Result is
      Lir_Module : Lovelace.Lir.Modules.Module := Lovelace.Lir.Modules.Create (Ast.Name (The_Module));
   begin
      Lovelace.Lir.Modules.Set_Origin
        (Lir_Module,
         (Name_Span => Ast.Name_Span (The_Module),
          Span      => Ast.Span (The_Module),
          Filename  => Ast.Filename (The_Module)));

      for Index in 1 .. Ast.Subroutine_Count (The_Module) loop
         declare
            Ast_Subroutine : constant Ast.Subroutine := Ast.Get_Subroutine (The_Module, Index);
            The_Signature  : constant Lovelace.Lir.Subroutines.Signature :=
              (Name            => Ada.Strings.Unbounded.To_Unbounded_String (Ast.Name (Ast_Subroutine)),
               Return_Type     => Map_Return_Type (Ast.Return_Type (Ast_Subroutine)),
               Parameter_Types => Lovelace.Lir.Types.Empty_Sequence);
            Lir_Subroutine : Lovelace.Lir.Subroutines.Subroutine :=
              Lovelace.Lir.Subroutines.Create
                (The_Signature => The_Signature, Flags => Map_Flags (Ast.Get_Flags (Ast_Subroutine)));
         begin
            Lovelace.Lir.Subroutines.Set_Origin
              (Lir_Subroutine,
               (Name_Span => Ast.Name_Span (Ast_Subroutine), Filename => Ast.Filename (Ast_Subroutine)));
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
               return Failure ("LIR Validate failed: " & Lovelace.Lir.Errors.Error_Code'Image (Validation.Error));
         end case;
      end;
   end Generate;

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

   function Map_Return_Type (Return_Type : Lovelace.Compiler.Types.Type_Expression) return Lovelace.Lir.Types.Value_Type
   is
   begin
      case Return_Type.Kind is
         when Lovelace.Compiler.Types.Unit =>
            return Lovelace.Lir.Types.Unit;
      end case;
   end Map_Return_Type;

end Lovelace.Compiler.Ir_Generator;
