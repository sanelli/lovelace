with Ada.Strings.Unbounded;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;

--  Versioned textual .tlir writer (no parser).
--  Canonical form: 2-space indent, LF newlines, final newline.

package Lovelace.Lir.Text is

   --  To_Text outcome: UTF-8 text or Error_Code.
   --  @disc Ok True when Value is present; False when Error is.
   --  @field Value Canonical .tlir text when Ok is True.
   --  @field Error Failure code when Ok is False.
   type To_Text_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Value : Ada.Strings.Unbounded.Unbounded_String;

         when False =>
            Error : Errors.Error_Code;
      end case;
   end record;

   --  Write or Print outcome.
   --  @disc Ok True on success; False when Error is.
   --  @field Error Failure code when Ok is False.
   type Write_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            null;

         when False =>
            Error : Errors.Error_Code;
      end case;
   end record;

   --  Write To_Text of The_Module to standard output.
   --  Does not print on validation failure.
   --  @param The_Module Module to print.
   --  @return Success, or Error_Code.
   function Print (The_Module : Modules.Module) return Write_Result;

   --  Canonical .tlir text for The_Module after Validate.
   --  @param The_Module Module to render.
   --  @return UTF-8 text, or a validation Error_Code.
   function To_Text (The_Module : Modules.Module) return To_Text_Result;

   --  Write To_Text of The_Module to Path (conventionally .tlir).
   --  @param The_Module Module to write.
   --  @param Path Destination filesystem path.
   --  @return Success, or Error_Code.
   function Write
     (The_Module : Modules.Module; Path : String) return Write_Result;

end Lovelace.Lir.Text;
