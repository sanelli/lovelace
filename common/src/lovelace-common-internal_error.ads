with Ada.Strings.Unbounded;

generic
   --  Subsystem-specific failure class (parse error, invalid UTF-8, …).
   type Error_Group is (<>);
package Lovelace.Common.Internal_Error is

   --  Compiler-internal failure. Not a user diagnostic.
   --  Group is for implementers; Message is the detail string.
   type Lovelace_Internal_Error is record
      Group   : Error_Group;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Build an internal error from Group and a UTF-8 Message.
   function Make
     (Group   : Error_Group;
      Message : String) return Lovelace_Internal_Error;

   --  UTF-8 detail string only.
   function Detail
     (Item : Lovelace_Internal_Error) return String;

   --  User-visible text: generic internal error plus details.
   --  Does not include Error_Group.
   function Report
     (Item : Lovelace_Internal_Error) return String;

end Lovelace.Common.Internal_Error;
