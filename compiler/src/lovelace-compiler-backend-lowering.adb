with Ada.Characters.Handling;
with Ada.Strings.Unbounded;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Backend.Lowering is

   package Errors renames Lovelace.Lir.Errors;
   package Instructions renames Lovelace.Lir.Instructions;
   package Modules renames Lovelace.Lir.Modules;
   package Opcodes renames Lovelace.Lir.Opcodes;
   package Subroutines renames Lovelace.Lir.Subroutines;
   package Types renames Lovelace.Lir.Types;

   use type Types.Value_Type;

   function Failure
     (Code : Backend_Error_Code; Detail : String) return Lower_Result;
   --  Build a Lower_Result failure.

   function Kebab_Export_Name (Name : String) return String;
   --  Component/WIT extern name: ASCII letters/digits lowercased; other bytes become '-'.

   procedure Lower_Instruction_Body
     (The_Instructions : Instructions.Instruction_Sequence;
      Body_Out         : out Model.Instruction_Sequence;
      Outcome          : out Lower_Result);
   --  Fill Body_Out from The_Instructions; Outcome.Ok False on failure.

   function Signature_Is_Supported
     (The_Signature : Subroutines.Signature) return Boolean;
   --  True when return is Unit and there are no parameters.

   function Failure
     (Code : Backend_Error_Code; Detail : String) return Lower_Result is
   begin
      return (Ok => False, Error => Make_Error (Code, Detail));
   end Failure;

   function Kebab_Export_Name (Name : String) return String is
      Buffer : String (1 .. Name'Length);
      Last   : Natural := 0;
   begin
      for Index in Name'Range loop
         declare
            Byte : constant Character := Name (Index);
         begin
            if Byte in 'A' .. 'Z' then
               Last := Last + 1;
               Buffer (Last) := Ada.Characters.Handling.To_Lower (Byte);
            elsif Byte in 'a' .. 'z' or else Byte in '0' .. '9' then
               Last := Last + 1;
               Buffer (Last) := Byte;
            else
               Last := Last + 1;
               Buffer (Last) := '-';
            end if;
         end;
      end loop;

      if Last = 0 then
         return "export";
      end if;

      return Buffer (1 .. Last);
   end Kebab_Export_Name;

   function Lower
     (The_Module : Lovelace.Lir.Modules.Module) return Lower_Result
   is
      Validation : constant Errors.Validation_Results.Result :=
        Modules.Validate (The_Module);
   begin
      case Validation.Ok is
         when False =>
            return
              Failure
                (Invalid_Module,
                 "LIR Validate failed: "
                 & Errors.Error_Code'Image (Validation.Error));

         when True  =>
            null;
      end case;

      declare
         The_Model        : Model.Component_Model :=
           Model.Create (Modules.Name (The_Module));
         Entrypoint_Index : Natural := 0;
         Entrypoint_Found : Boolean := False;
      begin
         for Subroutine_Index in 1 .. Modules.Subroutine_Count (The_Module)
         loop
            declare
               The_Subroutine : constant Subroutines.Subroutine :=
                 Modules.Get_Subroutine (The_Module, Subroutine_Index);
               The_Signature  : constant Subroutines.Signature :=
                 Subroutines.Get_Signature (The_Subroutine);
               The_Flags      : constant Subroutines.Subroutine_Flags :=
                 Subroutines.Get_Flags (The_Subroutine);
               Body_Out       : Model.Instruction_Sequence;
               Body_Outcome   : Lower_Result;
               Core_Exported  : constant Boolean :=
                 Subroutines.Has_Export (The_Flags);
            begin
               if not Signature_Is_Supported (The_Signature) then
                  return
                    Failure
                      (Unsupported_Type,
                       "backend this slice supports only Unit return and no parameters; got subroutine "
                       & Ada.Strings.Unbounded.To_String (The_Signature.Name));
               end if;

               Lower_Instruction_Body
                 (The_Instructions =>
                    Subroutines.Get_Instructions (The_Subroutine),
                  Body_Out         => Body_Out,
                  Outcome          => Body_Outcome);

               case Body_Outcome.Ok is
                  when False =>
                     return Body_Outcome;

                  when True  =>
                     null;
               end case;

               Model.Append_Function
                 (The_Model,
                  (Name          => The_Signature.Name,
                   Result_Is_I32 => False,
                   Instructions  => Body_Out,
                   Core_Exported => Core_Exported));

               if Subroutines.Has_Export (The_Flags) then
                  declare
                     Source_Name : constant String :=
                       Ada.Strings.Unbounded.To_String (The_Signature.Name);
                  begin
                     Model.Append_Export
                       (The_Model,
                        (Export_Name         =>
                           Ada.Strings.Unbounded.To_Unbounded_String
                             (Kebab_Export_Name (Source_Name)),
                         Core_Function_Index => Subroutine_Index,
                         Returns_Result      => False));
                  end;
               end if;

               if Subroutines.Has_Entrypoint (The_Flags) then
                  if Entrypoint_Found then
                     return
                       Failure
                         (Internal_Error,
                          "duplicate entrypoint after Validate");
                  end if;

                  Entrypoint_Found := True;
                  Entrypoint_Index := Subroutine_Index;
               end if;
            end;
         end loop;

         if Entrypoint_Found then
            declare
               Start_Body  : Model.Instruction_Sequence :=
                 Model.Empty_Instructions;
               Start_Index : constant Positive :=
                 Model.Function_Count (The_Model) + 1;
            begin
               Model.Append
                 (Start_Body,
                  (Kind         => Model.Call_Function,
                   Target_Index => Positive (Entrypoint_Index)));
               Model.Append
                 (Start_Body, (Kind => Model.I32_Constant, Value => 0));

               Model.Append_Function
                 (The_Model,
                  (Name          =>
                     Ada.Strings.Unbounded.To_Unbounded_String ("_start"),
                   Result_Is_I32 => True,
                   Instructions  => Start_Body,
                   Core_Exported => True));

               Model.Append_Export
                 (The_Model,
                  (Export_Name         =>
                     Ada.Strings.Unbounded.To_Unbounded_String
                       (Model.Wasi_Cli_Run_Export_Name),
                   Core_Function_Index => Start_Index,
                   Returns_Result      => True));
            end;
         end if;

         return (Ok => True, The_Model => The_Model);
      end;
   end Lower;

   procedure Lower_Instruction_Body
     (The_Instructions : Instructions.Instruction_Sequence;
      Body_Out         : out Model.Instruction_Sequence;
      Outcome          : out Lower_Result) is
   begin
      Body_Out := Model.Empty_Instructions;
      Outcome := (Ok => True, The_Model => Model.Create (""));

      for Index in 1 .. Instructions.Length (The_Instructions) loop
         declare
            Item : constant Instructions.Instruction :=
              Instructions.Element (The_Instructions, Index);
         begin
            case Item.Operation is
               when Opcodes.No_Operation =>
                  null;
            end case;
         end;
      end loop;
   end Lower_Instruction_Body;

   function Signature_Is_Supported
     (The_Signature : Subroutines.Signature) return Boolean is
   begin
      return
        The_Signature.Return_Type = Types.Unit
        and then Types.Length (The_Signature.Parameter_Types) = 0;
   end Signature_Is_Supported;

end Lovelace.Compiler.Backend.Lowering;
