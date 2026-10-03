with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
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
      begin
         Types.Append (Empty_Params, "", Types.I32);
         Modules.Append_Subroutine (Empty_Param, Support.Make_Subroutine ("P", Types.Unit, Parameters => Empty_Params));
         Support.Assert_Validate_Error (Empty_Param, Errors.Empty_Name, "empty parameter name");

         Types.Append (Dup_Params, "x", Types.I32);
         Types.Append (Dup_Params, "x", Types.F32);
         Modules.Append_Subroutine (Dup_Param, Support.Make_Subroutine ("P", Types.Unit, Parameters => Dup_Params));
         Support.Assert_Validate_Error (Dup_Param, Errors.Duplicate_Name, "duplicate parameter name");
      end;
   end Test_Validate_Failures;

end Lovelace.Lir.Tests.Validation;
