generic
   --  Payload stored when Ok is True.
   type Success_Type is private;
   --  Payload stored when Ok is False.
   type Error_Type is private;
   --  Discriminated union of Success_Type or Error_Type.
package Lovelace.Common.Result is

   --  Success payload or error payload, selected by Ok.
   --  @disc Ok True when Value is present; False when Error is.
   --  @field Value Payload when Ok is True.
   --  @field Error Payload when Ok is False.
   type Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Value : Success_Type;

         when False =>
            Error : Error_Type;
      end case;
   end record;

   --  Result with discriminant Ok True and the given Value.
   --  @param Value Success payload.
   --  @return Result with Ok True.
   function From_Success (Value : Success_Type) return Result;

   --  Result with discriminant Ok False and the given Error.
   --  @param Error Failure payload.
   --  @return Result with Ok False.
   function From_Failure (Error : Error_Type) return Result;

end Lovelace.Common.Result;
