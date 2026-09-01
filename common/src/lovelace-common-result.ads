generic
   type T_Success is private;
   type T_Error is private;
package Lovelace.Common.Result is

   --  Discriminated union of T_Success or T_Error.
   type Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Value : T_Success;
         when False =>
            Error : T_Error;
      end case;
   end record;

   --  Result with discriminant Ok True and the given Value.
   function From_Success (Value : T_Success) return Result;

   --  Result with discriminant Ok False and the given Error.
   function From_Failure (Error : T_Error) return Result;

end Lovelace.Common.Result;
