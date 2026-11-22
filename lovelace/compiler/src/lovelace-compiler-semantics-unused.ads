with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  Unused-variable and dead-store analysis for one subroutine walk.
--  Control flow is straight-line, so "read before overwrite" is a linear scan.
--  Priority: a local never read yields only Unused_Variable; a local read at least once
--  yields Unused_Assignment for each store that is overwritten or reaches scope end unread.
--  Parameters never receive Unused_Variable.

package Lovelace.Compiler.Semantics.Unused is

   --  Read and store bookkeeping per variable slot.
   type Tracker is private;

   --  Forget every variable (start of a subroutine).
   --  @param The_Tracker Tracker to clear.
   procedure Reset (The_Tracker : in out Tracker);

   --  Register a variable slot for usage tracking (ids match Definite_Assignment).
   --  @param The_Tracker Tracker to extend.
   --  @param Name UTF-8 variable name (for the warning text).
   --  @param Span Declaration span (location of Unused_Variable).
   --  @param Is_Parameter True for parameters (never Unused_Variable).
   --  @param Id New 1-based slot id.
   procedure Declare_Variable
     (The_Tracker  : in out Tracker;
      Name         : String;
      Span         : Source.Source_Span;
      Is_Parameter : Boolean;
      Id           : out Positive);

   --  Record a read of Id (its pending store, if any, was used).
   --  @param The_Tracker Tracker to update.
   --  @param Id Slot id from Declare_Variable.
   procedure Note_Read (The_Tracker : in out Tracker; Id : Positive);

   --  Record a store to Id; an earlier unread store becomes a dead store.
   --  @param The_Tracker Tracker to update.
   --  @param Id Slot id from Declare_Variable.
   --  @param Span Span of the assignment target (location of Unused_Assignment).
   procedure Note_Store (The_Tracker : in out Tracker; Id : Positive; Span : Source.Source_Span);

   --  Id goes out of scope; a pending unread store becomes a dead store.
   --  @param The_Tracker Tracker to update.
   --  @param Id Slot id from Declare_Variable.
   procedure End_Of_Life (The_Tracker : in out Tracker; Id : Positive);

   --  Close every slot and append the resulting warnings in source order.
   --  @param The_Tracker Tracker to finish.
   --  @param Unit_Index Unit index stamped on each warning.
   --  @param Into Sequence receiving Unused_Variable / Unused_Assignment diagnostics.
   procedure Collect_Warnings (The_Tracker : in out Tracker; Unit_Index : Positive; Into : in out Diagnostic_Sequence);

private

   package Span_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Source.Source_Span, "=" => Source."=");

   type Variable_Usage is record
      Name         : Ada.Strings.Unbounded.Unbounded_String;
      Span         : Source.Source_Span;
      Is_Parameter : Boolean := False;
      Read_Count   : Natural := 0;
      Has_Pending  : Boolean := False;
      Pending_Span : Source.Source_Span;
      Dead_Stores  : Span_Vectors.Vector;
   end record;

   package Usage_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Variable_Usage);

   type Tracker is record
      Variables : Usage_Vectors.Vector;
   end record;

end Lovelace.Compiler.Semantics.Unused;
