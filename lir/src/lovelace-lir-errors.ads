with Lovelace.Common.Result;

--  Shared LIR format and validation error codes.

package Lovelace.Lir.Errors is

   --  Why Encode, Decode, Validate, Read, or Write failed.
   --  @enum Internal_Error Compiler or library bug.
   --  @enum Io_Failure File open, read, or write failed.
   --  @enum Invalid_Magic Bytes 0 .. 3 are not LIR NUL magic.
   --  @enum Unsupported_Version Format major or minor is not 1.0.
   --  @enum Truncated Input ended before a complete module.
   --  @enum Trailing_Bytes Extra bytes after the last instruction.
   --  @enum Invalid_Utf_8 A name is not valid UTF-8.
   --  @enum Unknown_Opcode Opcode word is not in the closed set.
   --  @enum Unknown_Type Value_Type code is outside 0 .. 13.
   --  @enum Invalid_Presence Return-type presence byte is not 0 or 1.
   --  @enum Empty_Name Module, dependency, or subroutine name is empty.
   --  @enum Duplicate_Name Duplicate dependency or subroutine name.
   --  @enum Duplicate_Entrypoint More than one Entrypoint flag.
   --  @enum Self_Dependency A dependency name equals the module name.
   type Error_Code is
     (Internal_Error,
      Io_Failure,
      Invalid_Magic,
      Unsupported_Version,
      Truncated,
      Trailing_Bytes,
      Invalid_Utf_8,
      Unknown_Opcode,
      Unknown_Type,
      Invalid_Presence,
      Empty_Name,
      Duplicate_Name,
      Duplicate_Entrypoint,
      Self_Dependency);

   --  Empty success payload for validation Results.
   type Empty_Success is null record;

   --  Validation outcome: Empty_Success or Error_Code.
   package Validation_Results is new Lovelace.Common.Result (Success_Type => Empty_Success, Error_Type => Error_Code);

end Lovelace.Lir.Errors;
