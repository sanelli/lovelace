with AUnit.Assertions;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Tests.Support;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Tests.Validation is

   procedure Test_Validate_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Empty_Name_Module : constant Modules.Module := Modules.Create ("");
      Dup_Module        : Modules.Module := Modules.Create ("m");
      Two_Entry         : Modules.Module := Modules.Create ("m");
      Self_Depend       : Modules.Module := Modules.Create ("m");
   begin
      Support.Assert_Validate_Error (Empty_Name_Module, Errors.Empty_Name, "empty module name");

      Modules.Append_Subroutine (Dup_Module, Support.Make_Subroutine ("S", Types.Unit));
      Modules.Append_Subroutine (Dup_Module, Support.Make_Subroutine ("S", Types.I32));
      Support.Assert_Validate_Error (Dup_Module, Errors.Duplicate_Name, "duplicate subroutine");

      Modules.Append_Subroutine
        (Two_Entry, Support.Make_Subroutine ("A", Types.Unit, Flags => Subroutines.Entrypoint_Flag));
      Modules.Append_Subroutine
        (Two_Entry, Support.Make_Subroutine ("B", Types.Unit, Flags => Subroutines.Entrypoint_Flag));
      Support.Assert_Validate_Error (Two_Entry, Errors.Duplicate_Entrypoint, "two entrypoints");

      Modules.Append_Dependency (Self_Depend, "m");
      Support.Assert_Validate_Error (Self_Depend, Errors.Self_Dependency, "self depend");

      declare
         Empty_Param  : Modules.Module := Modules.Create ("m");
         Dup_Param    : Modules.Module := Modules.Create ("m");
         Empty_Params : Types.Parameter_Sequence := Types.Empty_Sequence;
         Dup_Params   : Types.Parameter_Sequence := Types.Empty_Sequence;
         Bad_Call     : Modules.Module := Modules.Create ("m");
         Caller       : Subroutines.Subroutine := Support.Make_Subroutine ("Caller", Types.Unit);
      begin
         Types.Append (Empty_Params, "", Types.I32);
         Modules.Append_Subroutine (Empty_Param, Support.Make_Subroutine ("P", Types.Unit, Parameters => Empty_Params));
         Support.Assert_Validate_Error (Empty_Param, Errors.Empty_Name, "empty parameter name");

         Types.Append (Dup_Params, "x", Types.I32);
         Types.Append (Dup_Params, "x", Types.F32);
         Modules.Append_Subroutine (Dup_Param, Support.Make_Subroutine ("P", Types.Unit, Parameters => Dup_Params));
         Support.Assert_Validate_Error (Dup_Param, Errors.Duplicate_Name, "duplicate parameter name");

         Subroutines.Append_Instruction (Caller, (Operation => Opcodes.Call, Target_Index => 0));
         Modules.Append_Subroutine (Bad_Call, Caller);
         Support.Assert_Validate_Error (Bad_Call, Errors.Invalid_Call_Target, "call target zero");
      end;

      declare
         Dup_Local_Mod : Modules.Module := Modules.Create ("m");
         Dup_Local_Sub : Subroutines.Subroutine := Support.Make_Subroutine ("P", Types.Unit);
         Clash_Mod     : Modules.Module := Modules.Create ("m");
         Clash_Params  : Types.Parameter_Sequence := Types.Empty_Sequence;
         Clash_Sub     : Subroutines.Subroutine;
      begin
         Subroutines.Append_Local (Dup_Local_Sub, "x", Types.I32);
         Subroutines.Append_Local (Dup_Local_Sub, "x", Types.I32);
         Modules.Append_Subroutine (Dup_Local_Mod, Dup_Local_Sub);
         Support.Assert_Validate_Error (Dup_Local_Mod, Errors.Duplicate_Name, "duplicate local name");

         Types.Append (Clash_Params, "x", Types.I32);
         Clash_Sub := Support.Make_Subroutine ("P", Types.Unit, Parameters => Clash_Params);
         Subroutines.Append_Local (Clash_Sub, "x", Types.I32);
         Modules.Append_Subroutine (Clash_Mod, Clash_Sub);
         Support.Assert_Validate_Error (Clash_Mod, Errors.Duplicate_Name, "local clashes with parameter");
      end;

      declare
         Flag_Only      : Modules.Module := Modules.Create ("m");
         With_Body      : Modules.Module := Modules.Create ("m");
         With_Entry     : Modules.Module := Modules.Create ("m");
         Empty_Key      : Modules.Module := Modules.Create ("m");
         Native_Ok      : Modules.Module := Modules.Create ("m");
         Body_Sub       : Subroutines.Subroutine := Support.Make_Subroutine ("P", Types.Unit, Noop_Count => 1);
         Entry_Sub      : Subroutines.Subroutine :=
           Support.Make_Subroutine ("P", Types.Unit, Flags => Subroutines.Entrypoint_Flag);
         Empty_Key_Sub  : Subroutines.Subroutine := Support.Make_Subroutine ("P", Types.Unit);
         Ok_Sub         : Subroutines.Subroutine :=
           Support.Make_Subroutine ("P", Types.Unit, Flags => Subroutines.Export_Flag);
      begin
         Modules.Append_Subroutine
           (Flag_Only, Support.Make_Subroutine ("P", Types.Unit, Flags => Subroutines.Native_Flag));
         Support.Assert_Validate_Error (Flag_Only, Errors.Invalid_Native_Binding, "native flag without binding");

         Subroutines.Set_Native_Binding (Body_Sub, "wasi", "native-print-integer");
         Modules.Append_Subroutine (With_Body, Body_Sub);
         Support.Assert_Validate_Error (With_Body, Errors.Invalid_Native_Binding, "native with body");

         Subroutines.Set_Native_Binding (Entry_Sub, "wasi", "native-print-integer");
         Modules.Append_Subroutine (With_Entry, Entry_Sub);
         Support.Assert_Validate_Error (With_Entry, Errors.Invalid_Native_Binding, "native entrypoint");

         Subroutines.Set_Native_Binding (Empty_Key_Sub, "wasi", "");
         Modules.Append_Subroutine (Empty_Key, Empty_Key_Sub);
         Support.Assert_Validate_Error (Empty_Key, Errors.Empty_Name, "native empty key");

         Subroutines.Set_Native_Binding (Ok_Sub, "wasi", "native-print-integer");
         Modules.Append_Subroutine (Native_Ok, Ok_Sub);
         declare
            Outcome : constant Errors.Validation_Results.Result := Modules.Validate (Native_Ok);
         begin
            AUnit.Assertions.Assert (Outcome.Ok, "valid native subroutine");
         end;

         declare
            Intrinsic_Ok   : Modules.Module := Modules.Create ("m");
            Intrinsic_Body : Modules.Module := Modules.Create ("m");
            Both_Flags     : Modules.Module := Modules.Create ("m");
            Ok_Intrinsic   : Subroutines.Subroutine :=
              Support.Make_Subroutine ("P", Types.Unit, Flags => Subroutines.Export_Flag);
            Body_Intrinsic : Subroutines.Subroutine :=
              Support.Make_Subroutine ("P", Types.Unit, Noop_Count => 1);
            Mixed          : Subroutines.Subroutine := Support.Make_Subroutine ("P", Types.Unit);
         begin
            Subroutines.Set_Intrinsic (Ok_Intrinsic);
            Modules.Append_Subroutine (Intrinsic_Ok, Ok_Intrinsic);
            declare
               Outcome : constant Errors.Validation_Results.Result := Modules.Validate (Intrinsic_Ok);
            begin
               AUnit.Assertions.Assert (Outcome.Ok, "valid intrinsic subroutine");
            end;

            Subroutines.Set_Intrinsic (Body_Intrinsic);
            Modules.Append_Subroutine (Intrinsic_Body, Body_Intrinsic);
            Support.Assert_Validate_Error
              (Intrinsic_Body, Errors.Invalid_Native_Binding, "intrinsic with body");

            Subroutines.Set_Native_Binding (Mixed, "lib", "fn");
            Subroutines.Set_Intrinsic (Mixed);
            Modules.Append_Subroutine (Both_Flags, Mixed);
            declare
               Outcome : constant Errors.Validation_Results.Result := Modules.Validate (Both_Flags);
            begin
               AUnit.Assertions.Assert (Outcome.Ok, "Set_Intrinsic clears native");
            end;
         end;
      end;
   end Test_Validate_Failures;

end Lovelace.Lir.Tests.Validation;
