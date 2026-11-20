with AUnit.Assertions;

with Lovelace.Main.Build;

package body Lovelace.Main.Tests.Build is

   package Cli_Build renames Lovelace.Main.Build;

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
