package body Lovelace.Common.Result is

   function From_Failure (Error : Error_Type) return Result is
   begin
      return (Ok => False, Error => Error);
   end From_Failure;

   function From_Success (Value : Success_Type) return Result is
   begin
      return (Ok => True, Value => Value);
   end From_Success;

end Lovelace.Common.Result;
