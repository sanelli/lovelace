package body Lovelace.Compiler.Semantics.Definite_Assignment is

   procedure Declare_Variable (The_Tracker : in out Tracker; Assigned : Boolean; Id : out Positive) is
   begin
      The_Tracker.Assigned.Append (Assigned);
      Id := The_Tracker.Assigned.Last_Index;
   end Declare_Variable;

   function Is_Assigned (The_Tracker : Tracker; Id : Positive) return Boolean is
   begin
      return The_Tracker.Assigned.Element (Id);
   end Is_Assigned;

   procedure Mark_Assigned (The_Tracker : in out Tracker; Id : Positive) is
   begin
      The_Tracker.Assigned.Replace_Element (Id, True);
   end Mark_Assigned;

   procedure Reset (The_Tracker : in out Tracker) is
   begin
      The_Tracker.Assigned.Clear;
   end Reset;

end Lovelace.Compiler.Semantics.Definite_Assignment;
