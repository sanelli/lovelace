with AUnit.Test_Caller;

with Lovelace.Main.Tests.Arguments;
with Lovelace.Main.Tests.Build;
with Lovelace.Main.Tests.Help;
with Lovelace.Main.Tests.Reporting;
with Lovelace.Main.Tests.Version;

package body Lovelace.Main.Tests.Suite is

   package Arguments_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Tests.Arguments.Fixture);
   package Build_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Tests.Build.Fixture);
   package Help_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Tests.Help.Fixture);
   package Reporting_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Tests.Reporting.Fixture);
   package Version_Caller is new
     AUnit.Test_Caller (Lovelace.Main.Tests.Version.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Arguments_Caller.Create
           ("globals before command",
            Lovelace.Main.Tests.Arguments.Test_Globals_Before_Command'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("global after command is argument",
            Lovelace
              .Main
              .Tests
              .Arguments
              .Test_Global_After_Command_Is_Argument'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("unknown global",
            Lovelace.Main.Tests.Arguments.Test_Unknown_Global'Access));
      Result.Add_Test
        (Arguments_Caller.Create
           ("no command",
            Lovelace.Main.Tests.Arguments.Test_No_Command'Access));

      Result.Add_Test
        (Build_Caller.Create
           ("output format values",
            Lovelace.Main.Tests.Build.Test_Output_Format_Values'Access));
      Result.Add_Test
        (Build_Caller.Create
           ("output format invalid",
            Lovelace.Main.Tests.Build.Test_Output_Format_Invalid'Access));

      Result.Add_Test
        (Help_Caller.Create
           ("help build topic",
            Lovelace.Main.Tests.Help.Test_Help_Build_Topic'Access));
      Result.Add_Test
        (Help_Caller.Create
           ("help mentions build",
            Lovelace.Main.Tests.Help.Test_Help_Mentions_Build'Access));

      Result.Add_Test
        (Version_Caller.Create
           ("version prefix",
            Lovelace.Main.Tests.Version.Test_Version_Prefix'Access));

      Result.Add_Test
        (Reporting_Caller.Create
           ("love basename",
            Lovelace.Main.Tests.Reporting.Test_Love_Basename'Access));

      return Result;
   end Suite;

end Lovelace.Main.Tests.Suite;
