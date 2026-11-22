package body Lovelace.Compiler.Semantics.Unused is

   function Before (Left, Right : Diagnostic) return Boolean;

   function Before (Left, Right : Diagnostic) return Boolean is
   begin
      return Left.Span.First.Byte_Index < Right.Span.First.Byte_Index;
   end Before;

   package Sorting is new Diagnostic_Vectors.Generic_Sorting ("<" => Before);

   procedure Collect_Warnings (The_Tracker : in out Tracker; Unit_Index : Positive; Into : in out Diagnostic_Sequence)
   is
      Found : Diagnostic_Sequence;
   begin
      for Id in 1 .. Natural (The_Tracker.Variables.Length) loop
         End_Of_Life (The_Tracker, Id);
      end loop;

      for Id in 1 .. Natural (The_Tracker.Variables.Length) loop
         declare
            Item : constant Variable_Usage := The_Tracker.Variables.Element (Id);
            Name : constant String := Ada.Strings.Unbounded.To_String (Item.Name);
         begin
            if Item.Read_Count = 0 then
               if not Item.Is_Parameter then
                  Found.Append
                    (Diagnostic'
                       (Code       => Unused_Variable,
                        Span       => Item.Span,
                        Detail     => Ada.Strings.Unbounded.To_Unbounded_String ("local '" & Name & "' is never read"),
                        Unit_Index => Unit_Index));
               end if;
            else
               for Store_Index in 1 .. Natural (Item.Dead_Stores.Length) loop
                  Found.Append
                    (Diagnostic'
                       (Code       => Unused_Assignment,
                        Span       => Item.Dead_Stores.Element (Store_Index),
                        Detail     =>
                          Ada.Strings.Unbounded.To_Unbounded_String ("value assigned to '" & Name & "' is never read"),
                        Unit_Index => Unit_Index));
               end loop;
            end if;
         end;
      end loop;

      Sorting.Sort (Found);
      for Index in 1 .. Natural (Found.Length) loop
         Into.Append (Found.Element (Index));
      end loop;
   end Collect_Warnings;

   procedure Declare_Variable
     (The_Tracker : in out Tracker; Name : String; Span : Source.Source_Span; Is_Parameter : Boolean; Id : out Positive)
   is
      Item : Variable_Usage;
   begin
      Item.Name := Ada.Strings.Unbounded.To_Unbounded_String (Name);
      Item.Span := Span;
      Item.Is_Parameter := Is_Parameter;
      The_Tracker.Variables.Append (Item);
      Id := The_Tracker.Variables.Last_Index;
   end Declare_Variable;

   procedure End_Of_Life (The_Tracker : in out Tracker; Id : Positive) is
      Item : Variable_Usage := The_Tracker.Variables.Element (Id);
   begin
      if Item.Has_Pending then
         Item.Dead_Stores.Append (Item.Pending_Span);
         Item.Has_Pending := False;
         The_Tracker.Variables.Replace_Element (Id, Item);
      end if;
   end End_Of_Life;

   procedure Note_Read (The_Tracker : in out Tracker; Id : Positive) is
      Item : Variable_Usage := The_Tracker.Variables.Element (Id);
   begin
      Item.Read_Count := Item.Read_Count + 1;
      Item.Has_Pending := False;
      The_Tracker.Variables.Replace_Element (Id, Item);
   end Note_Read;

   procedure Note_Store (The_Tracker : in out Tracker; Id : Positive; Span : Source.Source_Span) is
      Item : Variable_Usage := The_Tracker.Variables.Element (Id);
   begin
      if Item.Has_Pending then
         Item.Dead_Stores.Append (Item.Pending_Span);
      end if;
      Item.Has_Pending := True;
      Item.Pending_Span := Span;
      The_Tracker.Variables.Replace_Element (Id, Item);
   end Note_Store;

   procedure Reset (The_Tracker : in out Tracker) is
   begin
      The_Tracker.Variables.Clear;
   end Reset;

end Lovelace.Compiler.Semantics.Unused;
