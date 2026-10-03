with AUnit.Test_Caller;

with Lovelace.Lir.Tests.Binary_Format;
with Lovelace.Lir.Tests.Origins;
with Lovelace.Lir.Tests.Text_Format;
with Lovelace.Lir.Tests.Type_Codes;
with Lovelace.Lir.Tests.Validation;

package body Lovelace.Lir.Tests.Suite is

   package Binary_Caller is new
     AUnit.Test_Caller (Lovelace.Lir.Tests.Binary_Format.Fixture);
   package Origins_Caller is new
     AUnit.Test_Caller (Lovelace.Lir.Tests.Origins.Fixture);
   package Text_Caller is new
     AUnit.Test_Caller (Lovelace.Lir.Tests.Text_Format.Fixture);
   package Types_Caller is new
     AUnit.Test_Caller (Lovelace.Lir.Tests.Type_Codes.Fixture);
   package Validate_Caller is new
     AUnit.Test_Caller (Lovelace.Lir.Tests.Validation.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: empty module in memory",
            Lovelace.Lir.Tests.Binary_Format.Test_Empty_Module_Memory'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: empty module file round-trip",
            Lovelace.Lir.Tests.Binary_Format.Test_Empty_Module_File'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: magic and version",
            Lovelace.Lir.Tests.Binary_Format.Test_Magic_And_Version'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: unicode names",
            Lovelace.Lir.Tests.Binary_Format.Test_Unicode_Names'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: subroutines and flags",
            Lovelace
              .Lir
              .Tests
              .Binary_Format
              .Test_Subroutines_And_Flags'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: noop encoding",
            Lovelace.Lir.Tests.Binary_Format.Test_Noop_Encoding'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: all value types",
            Lovelace.Lir.Tests.Binary_Format.Test_All_Value_Types'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("binary .lir: decode failures",
            Lovelace.Lir.Tests.Binary_Format.Test_Decode_Failures'Access));

      Result.Add_Test
        (Text_Caller.Create
           ("text .tlir: empty module golden",
            Lovelace.Lir.Tests.Text_Format.Test_Empty_Module_Golden'Access));
      Result.Add_Test
        (Text_Caller.Create
           ("text .tlir: subroutine goldens",
            Lovelace.Lir.Tests.Text_Format.Test_Subroutine_Goldens'Access));
      Result.Add_Test
        (Text_Caller.Create
           ("text .tlir: write file",
            Lovelace.Lir.Tests.Text_Format.Test_Write_Tlir'Access));

      Result.Add_Test
        (Types_Caller.Create
           ("type codes: round-trip",
            Lovelace.Lir.Tests.Type_Codes.Test_Type_Codes'Access));
      Result.Add_Test
        (Types_Caller.Create
           ("type codes: encoded length",
            Lovelace.Lir.Tests.Type_Codes.Test_Encoded_Length'Access));

      Result.Add_Test
        (Validate_Caller.Create
           ("validation: reject invalid modules",
            Lovelace.Lir.Tests.Validation.Test_Validate_Failures'Access));

      Result.Add_Test
        (Origins_Caller.Create
           ("origins: create absent",
            Lovelace.Lir.Tests.Origins.Test_Create_Absent'Access));
      Result.Add_Test
        (Origins_Caller.Create
           ("origins: set origin",
            Lovelace.Lir.Tests.Origins.Test_Set_Origin'Access));
      Result.Add_Test
        (Origins_Caller.Create
           ("origins: codecs preserve origins",
            Lovelace.Lir.Tests.Origins.Test_Codecs_Preserve_Origins'Access));

      return Result;
   end Suite;

end Lovelace.Lir.Tests.Suite;
