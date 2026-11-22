with Ada.Containers.Vectors;

--  Definite-assignment state for the variables of one subroutine walk.
--  Control flow is straight-line (nested blocks execute inline), so one bit per variable suffices.

package Lovelace.Compiler.Semantics.Definite_Assignment is

   --  Assigned bit per variable slot.
   type Tracker is private;

   --  Forget every variable (start of a subroutine).
   --  @param The_Tracker Tracker to clear.
   procedure Reset (The_Tracker : in out Tracker);

   --  Register a new variable slot.
   --  @param The_Tracker Tracker to extend.
   --  @param Assigned True for parameters; False for locals.
   --  @param Id New 1-based slot id.
   procedure Declare_Variable (The_Tracker : in out Tracker; Assigned : Boolean; Id : out Positive);

   --  Record that Id definitely holds a value from now on.
   --  @param The_Tracker Tracker to update.
   --  @param Id Slot id from Declare_Variable.
   procedure Mark_Assigned (The_Tracker : in out Tracker; Id : Positive);

   --  True when Id is definitely assigned at this point.
   --  @param The_Tracker Tracker to query.
   --  @param Id Slot id from Declare_Variable.
   --  @return Assigned bit.
   function Is_Assigned (The_Tracker : Tracker; Id : Positive) return Boolean;

private

   package Boolean_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Boolean);

   type Tracker is record
      Assigned : Boolean_Vectors.Vector;
   end record;

end Lovelace.Compiler.Semantics.Definite_Assignment;
