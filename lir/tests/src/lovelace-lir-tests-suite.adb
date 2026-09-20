with AUnit.Test_Caller;

with Lovelace.Lir.Tests.Binary_Format;
with Lovelace.Lir.Tests.Origins;
with Lovelace.Lir.Tests.Text_Format;
with Lovelace.Lir.Tests.Type_Codes;
with Lovelace.Lir.Tests.Validation;

package body Lovelace.Lir.Tests.Suite is

   package Binary_Caller is new AUnit.Test_Caller (Lovelace.Lir.Tests.Binary_Format.Fixture);
   package Origins_Caller is new AUnit.Test_Caller (Lovelace.Lir.Tests.Origins.Fixture);
   package Text_Caller is new AUnit.Test_Caller (Lovelace.Lir.Tests.Text_Format.Fixture);
   package Types_Caller is new AUnit.Test_Caller (Lovelace.Lir.Tests.Type_Codes.Fixture);
   package Validate_Caller is new AUnit.Test_Caller (Lovelace.Lir.Tests.Validation.Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Binary_Caller.Create
           ("empty module memory", Lovelace.Lir.Tests.Binary_Format.Test_Empty_Module_Memory'Access));
      Result.Add_Test
        (Binary_Caller.Create ("empty module file", Lovelace.Lir.Tests.Binary_Format.Test_Empty_Module_File'Access));
      Result.Add_Test
        (Binary_Caller.Create ("magic and version", Lovelace.Lir.Tests.Binary_Format.Test_Magic_And_Version'Access));
      Result.Add_Test
        (Binary_Caller.Create ("unicode names", Lovelace.Lir.Tests.Binary_Format.Test_Unicode_Names'Access));
      Result.Add_Test
        (Binary_Caller.Create
           ("subroutines and flags", Lovelace.Lir.Tests.Binary_Format.Test_Subroutines_And_Flags'Access));
      Result.Add_Test
        (Binary_Caller.Create ("noop encoding", Lovelace.Lir.Tests.Binary_Format.Test_Noop_Encoding'Access));
      Result.Add_Test
        (Binary_Caller.Create ("all value types", Lovelace.Lir.Tests.Binary_Format.Test_All_Value_Types'Access));
      Result.Add_Test
        (Binary_Caller.Create ("decode failures", Lovelace.Lir.Tests.Binary_Format.Test_Decode_Failures'Access));

      Result.Add_Test
        (Text_Caller.Create ("empty module golden", Lovelace.Lir.Tests.Text_Format.Test_Empty_Module_Golden'Access));
      Result.Add_Test
        (Text_Caller.Create ("subroutine goldens", Lovelace.Lir.Tests.Text_Format.Test_Subroutine_Goldens'Access));
      Result.Add_Test (Text_Caller.Create ("write tlir", Lovelace.Lir.Tests.Text_Format.Test_Write_Tlir'Access));

      Result.Add_Test (Types_Caller.Create ("type codes", Lovelace.Lir.Tests.Type_Codes.Test_Type_Codes'Access));
      Result.Add_Test
        (Types_Caller.Create ("encoded length", Lovelace.Lir.Tests.Type_Codes.Test_Encoded_Length'Access));

      Result.Add_Test
        (Validate_Caller.Create ("validate failures", Lovelace.Lir.Tests.Validation.Test_Validate_Failures'Access));

      Result.Add_Test (Origins_Caller.Create ("create absent", Lovelace.Lir.Tests.Origins.Test_Create_Absent'Access));
      Result.Add_Test (Origins_Caller.Create ("set origin", Lovelace.Lir.Tests.Origins.Test_Set_Origin'Access));
      Result.Add_Test
        (Origins_Caller.Create ("codecs drop origins", Lovelace.Lir.Tests.Origins.Test_Codecs_Drop_Origins'Access));

      return Result;
   end Suite;

end Lovelace.Lir.Tests.Suite;
