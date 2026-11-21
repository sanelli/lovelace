with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Compiler.Diagnostics;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Main.Build;

package body Lovelace.Main.Tests.Build is

   package Cli_Build renames Lovelace.Main.Build;
   package Diagnostics renames Lovelace.Compiler.Diagnostics;
   package Error_Codes renames Lovelace.Compiler.Error_Codes;

   use type Error_Codes.Error_Code;

   procedure Test_No_Warnings_List (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Policy : Diagnostics.Policy := Diagnostics.Default_Policy;
      Detail     : Ada.Strings.Unbounded.Unbounded_String;
      Code       : Error_Codes.Error_Code;
   begin
      AUnit.Assertions.Assert
        (Cli_Build.Try_Apply_No_Warnings
           ("LV00028,LV00029", The_Policy, Detail),
         "apply both warnings");
      AUnit.Assertions.Assert
        (Diagnostics.Is_Suppressed (The_Policy, Error_Codes.Unused_Variable),
         "LV00028 suppressed");
      AUnit.Assertions.Assert
        (Diagnostics.Is_Suppressed (The_Policy, Error_Codes.Unused_Assignment),
         "LV00029 suppressed");

      The_Policy := Diagnostics.Default_Policy;
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("", The_Policy, Detail),
         "reject empty");
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("LV99999", The_Policy, Detail),
         "reject unknown");
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("LV00027", The_Policy, Detail),
         "reject non-warning");
      AUnit.Assertions.Assert
        (not Cli_Build.Try_Apply_No_Warnings ("LV00028,", The_Policy, Detail),
         "reject trailing comma");

      AUnit.Assertions.Assert
        (Error_Codes.Try_From_Label ("LV00028", Code), "from label");
      AUnit.Assertions.Assert
        (Code = Error_Codes.Unused_Variable, "label maps to unused variable");
      declare
         Ignored  : Error_Codes.Error_Code;
         Rejected : constant Boolean :=
           not Error_Codes.Try_From_Label ("lv00028", Ignored);
      begin
         pragma Unreferenced (Ignored);
         AUnit.Assertions.Assert (Rejected, "case-sensitive");
      end;
   end Test_No_Warnings_List;

   procedure Test_Output_Format_Invalid (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Format_Set_A : Cli_Build.Output_Format_Set;
      Format_Set_B : Cli_Build.Output_Format_Set;
      Rejected_A   : constant Boolean :=
        not Cli_Build.Try_Parse_Output_Format ("wasmwat", Format_Set_A);
      Rejected_B   : constant Boolean :=
        not Cli_Build.Try_Parse_Output_Format ("", Format_Set_B);
   begin
      pragma Unreferenced (Format_Set_A, Format_Set_B);
      AUnit.Assertions.Assert (Rejected_A, "reject");
      AUnit.Assertions.Assert (Rejected_B, "empty");
   end Test_Output_Format_Invalid;

   procedure Test_Output_Format_Values (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Format_Set : Cli_Build.Output_Format_Set;
   begin
      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wasm", Format_Set), "wasm ok");
      AUnit.Assertions.Assert
        (Format_Set.Want_Wasm and then not Format_Set.Want_Wat, "wasm only");

      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wat", Format_Set), "wat ok");
      AUnit.Assertions.Assert
        (not Format_Set.Want_Wasm and then Format_Set.Want_Wat, "wat only");

      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wasm,wat", Format_Set),
         "wasm,wat ok");
      AUnit.Assertions.Assert
        (Format_Set.Want_Wasm and then Format_Set.Want_Wat, "both A");

      AUnit.Assertions.Assert
        (Cli_Build.Try_Parse_Output_Format ("wat,wasm", Format_Set),
         "wat,wasm ok");
      AUnit.Assertions.Assert
        (Format_Set.Want_Wasm and then Format_Set.Want_Wat, "both B");
   end Test_Output_Format_Values;

end Lovelace.Main.Tests.Build;
