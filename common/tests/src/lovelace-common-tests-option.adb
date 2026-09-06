with AUnit.Assertions;

with Lovelace.Common.Option;

package body Lovelace.Common.Tests.Option is

   package Integer_Options is new Lovelace.Common.Option (Element_Type => Integer);

   procedure Test_From_Value (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Option : constant Integer_Options.Option := Integer_Options.From_Value (42);
   begin
      AUnit.Assertions.Assert
        (Condition => The_Option.Present, Message => "From_Value sets Present True");
      AUnit.Assertions.Assert
        (Condition => The_Option.Value = 42, Message => "From_Value stores Value");
   end Test_From_Value;

   procedure Test_None (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Option : constant Integer_Options.Option := Integer_Options.None;
   begin
      AUnit.Assertions.Assert
        (Condition => not The_Option.Present, Message => "None sets Present False");
   end Test_None;

   procedure Test_Present_Discriminant (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Present_Option : constant Integer_Options.Option := Integer_Options.From_Value (7);
      Absent_Option  : constant Integer_Options.Option := Integer_Options.None;
   begin
      case Present_Option.Present is
         when True =>
            AUnit.Assertions.Assert
              (Condition => Present_Option.Value = 7, Message => "present arm reads Value");

         when False =>
            AUnit.Assertions.Assert (Condition => False, Message => "From_Value option must be present");
      end case;

      case Absent_Option.Present is
         when True =>
            AUnit.Assertions.Assert (Condition => False, Message => "None option must not expose Value");

         when False =>
            null;
      end case;
   end Test_Present_Discriminant;

end Lovelace.Common.Tests.Option;
