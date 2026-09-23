with Ada.Strings.Unbounded;
with AUnit.Assertions;

with Lovelace.Common.Source;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Text;
with Lovelace.Lir.Tests.Support;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Tests.Origins is

   use type Subroutines.Subroutine_Flags;

   procedure Test_Codecs_Preserve_Origins (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Name_Span      : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 5, Line => 1, Column => 5));
      Unit_Span      : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 20, Line => 2, Column => 1));
      Holder         : constant Lovelace.Common.Source.Shared_Filename :=
        Lovelace.Common.Source.From_Utf_8 ("origins.love");
      File_Opt       : constant Lovelace.Common.Source.Filename_Option :=
        Lovelace.Common.Source.Some_Filename (Holder);
      The_Module     : Modules.Module := Modules.Create ("Hello");
      The_Subroutine : Subroutines.Subroutine :=
        Support.Make_Subroutine
          (Name        => "Hello",
           Return_Type => Types.Unit,
           Flags       => Subroutines.Export_Flag or Subroutines.Entrypoint_Flag);
      Decoded        : Modules.Module;
      Decoded_Sub    : Subroutines.Subroutine;
      Module_Origin  : Modules.Origin_Option;
      Sub_Origin     : Subroutines.Origin_Option;
   begin
      Modules.Set_Origin
        (The_Module, (Name_Span => Name_Span, Span => Unit_Span, Filename => File_Opt));
      Subroutines.Set_Origin
        (The_Subroutine, (Name_Span => Name_Span, Filename => File_Opt));
      Modules.Append_Subroutine (The_Module, The_Subroutine);

      Decoded :=
        Support.Must_Decode
          (Support.Must_Encode (The_Module, "encode with origins"), "decode with origins");

      Module_Origin := Modules.Origin (Decoded);
      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (Condition => False, Message => "decoded module origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Condition => Module_Origin.Value.Name_Span.First.Byte_Index = 1,
               Message   => "decoded module name span");
            AUnit.Assertions.Assert
              (Condition => Module_Origin.Value.Span.Last.Line = 2, Message => "decoded module unit span");
            AUnit.Assertions.Assert
              (Condition => Lovelace.Common.Source.To_Utf_8 (Module_Origin.Value.Filename) = "origins.love",
               Message   => "decoded module filename");
      end case;

      Decoded_Sub := Modules.Get_Subroutine (Decoded, 1);
      Sub_Origin := Subroutines.Origin (Decoded_Sub);
      case Sub_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (Condition => False, Message => "decoded subroutine origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Condition => Sub_Origin.Value.Name_Span.Last.Column = 5,
               Message   => "decoded subroutine name span");
            AUnit.Assertions.Assert
              (Condition => Lovelace.Common.Source.To_Utf_8 (Sub_Origin.Value.Filename) = "origins.love",
               Message   => "decoded subroutine filename");
      end case;

      declare
         Text_Result : constant Lovelace.Lir.Text.To_Text_Result := Lovelace.Lir.Text.To_Text (The_Module);
      begin
         case Text_Result.Ok is
            when False =>
               AUnit.Assertions.Assert (Condition => False, Message => "To_Text with origins");

            when True  =>
               declare
                  Text : constant String := Ada.Strings.Unbounded.To_String (Text_Result.Value);
               begin
                  Support.Assert_Contains (Text, "(origin", "text origin form");
                  Support.Assert_Contains (Text, "(filename ""origins.love"")", "text filename");
                  Support.Assert_Contains (Text, "(name-span", "text name-span");
                  Support.Assert_Contains (Text, "(position 1 1 1)", "text position");
               end;
         end case;
      end;
   end Test_Codecs_Preserve_Origins;

   procedure Test_Create_Absent (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module     : constant Modules.Module := Modules.Create ("M");
      The_Subroutine : constant Subroutines.Subroutine :=
        Support.Make_Subroutine (Name => "S", Return_Type => Types.Unit);
   begin
      AUnit.Assertions.Assert
        (Condition => not Modules.Origin (The_Module).Present, Message => "Create module origin absent");
      AUnit.Assertions.Assert
        (Condition => not Subroutines.Origin (The_Subroutine).Present, Message => "Create subroutine origin absent");
   end Test_Create_Absent;

   procedure Test_Set_Origin (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Name_Span           : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 9, Line => 1, Column => 9), Last => (Byte_Index => 13, Line => 1, Column => 13));
      Unit_Span           : constant Lovelace.Common.Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 30, Line => 3, Column => 2));
      Holder              : constant Lovelace.Common.Source.Shared_Filename :=
        Lovelace.Common.Source.From_Utf_8 ("set-origin.love");
      File_Opt            : constant Lovelace.Common.Source.Filename_Option :=
        Lovelace.Common.Source.Some_Filename (Holder);
      The_Module          : Modules.Module := Modules.Create ("Prog");
      The_Subroutine      : Subroutines.Subroutine :=
        Support.Make_Subroutine
          (Name => "Prog", Return_Type => Types.Unit, Flags => Subroutines.Export_Flag or Subroutines.Entrypoint_Flag);
      Module_Origin_Value : Modules.Origin_Option;
      Sub_Origin_Value    : Subroutines.Origin_Option;
   begin
      Modules.Set_Origin (The_Module, (Name_Span => Name_Span, Span => Unit_Span, Filename => File_Opt));
      Subroutines.Set_Origin (The_Subroutine, (Name_Span => Name_Span, Filename => File_Opt));
      Modules.Append_Subroutine (The_Module, The_Subroutine);

      Module_Origin_Value := Modules.Origin (The_Module);
      case Module_Origin_Value.Present is
         when False =>
            AUnit.Assertions.Assert (Condition => False, Message => "module origin should be present");

         when True  =>
            AUnit.Assertions.Assert
              (Condition => Module_Origin_Value.Value.Name_Span.First.Byte_Index = 9,
               Message   => "module name span first byte");
            AUnit.Assertions.Assert
              (Condition => Module_Origin_Value.Value.Span.Last.Line = 3, Message => "module unit span last line");
            AUnit.Assertions.Assert
              (Condition => Lovelace.Common.Source.Same_Storage (Module_Origin_Value.Value.Filename, File_Opt),
               Message   => "module filename shares storage");
      end case;

      Sub_Origin_Value := Subroutines.Origin (Modules.Get_Subroutine (The_Module, 1));
      case Sub_Origin_Value.Present is
         when False =>
            AUnit.Assertions.Assert (Condition => False, Message => "subroutine origin should be present");

         when True  =>
            AUnit.Assertions.Assert
              (Condition => Sub_Origin_Value.Value.Name_Span.Last.Column = 13,
               Message   => "subroutine name span last column");
            AUnit.Assertions.Assert
              (Condition => Lovelace.Common.Source.Same_Storage (Sub_Origin_Value.Value.Filename, File_Opt),
               Message   => "subroutine filename shares storage");
      end case;

      declare
         Validation : constant Errors.Validation_Results.Result := Modules.Validate (The_Module);
      begin
         case Validation.Ok is
            when True  =>
               null;

            when False =>
               AUnit.Assertions.Assert (Condition => False, Message => "origin does not affect Validate");
         end case;
      end;
   end Test_Set_Origin;

end Lovelace.Lir.Tests.Origins;
