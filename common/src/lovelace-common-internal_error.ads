with Ada.Strings.Unbounded;

generic
   --  Subsystem-specific failure class (parse error, invalid UTF-8).
   type Error_Group is (<>);
--  Compiler-internal failure for one subsystem, not a user diagnostic.
package Lovelace.Common.Internal_Error is

   --  Internal failure: a subsystem group plus a UTF-8 detail string.
   --  @field Group Subsystem class for implementers, logs, and tests.
   --  @field Message UTF-8 detail string; shown by Report after a
   --  generic prefix.
   type Lovelace_Internal_Error is record
      Group   : Error_Group;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Build an internal error from Group and a UTF-8 Message.
   --  @param Group Subsystem-specific failure class.
   --  @param Message UTF-8 detail string.
   --  @return Record with Group and Message set.
   function Make
     (Group   : Error_Group;
      Message : String) return Lovelace_Internal_Error;

   --  UTF-8 detail string only.
   --  @param Item Internal error to read.
   --  @return Contents of Message.
   function Detail
     (Item : Lovelace_Internal_Error) return String;

   --  User-visible text: generic internal error plus details.
   --  Does not include Error_Group.
   --  @param Item Internal error to report.
   --  @return Fixed prefix plus Detail.
   function Report
     (Item : Lovelace_Internal_Error) return String;

end Lovelace.Common.Internal_Error;
