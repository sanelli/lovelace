with AUnit.Assertions;
with Interfaces;

with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Tests.Type_Codes is

   use type Interfaces.Unsigned_8;
   use type Types.Value_Type;

   procedure Test_Encoded_Length (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Opcodes.Immediate_Length (Opcodes.No_Operation) = 0, "immediate");
      AUnit.Assertions.Assert
        (Opcodes.Encoded_Length (Opcodes.No_Operation) = 2, "encoded");
   end Test_Encoded_Length;

   procedure Test_Type_Codes (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Expected : Interfaces.Unsigned_8 := 0;
   begin
      for The_Type in Types.Value_Type loop
         declare
            Code   : constant Interfaces.Unsigned_8 :=
              Types.To_Code (The_Type);
            Option : constant Types.Value_Type_Options.Option :=
              Types.From_Code (Code);
         begin
            AUnit.Assertions.Assert (Code = Expected, "code order");
            case Option.Present is
               when False =>
                  AUnit.Assertions.Assert (False, "from code present");

               when True  =>
                  AUnit.Assertions.Assert
                    (Option.Value = The_Type, "round type");
            end case;
            Expected := Expected + 1;
         end;
      end loop;

      declare
         Missing : constant Types.Value_Type_Options.Option :=
           Types.From_Code (16#FF#);
      begin
         AUnit.Assertions.Assert (not Missing.Present, "unknown absent");
      end;
   end Test_Type_Codes;

end Lovelace.Lir.Tests.Type_Codes;
