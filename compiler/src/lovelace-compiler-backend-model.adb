package body Lovelace.Compiler.Backend.Model is

   procedure Append (Sequence : in out Instruction_Sequence; Item : Core_Instruction) is
   begin
      Sequence.Items.Append (Item);
   end Append;

   procedure Append_Export (The_Model : in out Component_Model; The_Export : Lifted_Export) is
   begin
      The_Model.Exports.Append (The_Export);
   end Append_Export;

   procedure Append_Function (The_Model : in out Component_Model; The_Function : Core_Function) is
   begin
      The_Model.Functions.Append (The_Function);
   end Append_Function;

   function Create (Name : String) return Component_Model is
   begin
      return
        (Module_Name_Value => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Functions         => Function_Vectors.Empty_Vector,
         Exports           => Export_Vectors.Empty_Vector);
   end Create;

   function Element (Sequence : Instruction_Sequence; Index : Positive) return Core_Instruction is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Instructions return Instruction_Sequence is
   begin
      return (Items => Instruction_Vectors.Empty_Vector);
   end Empty_Instructions;

   function Export_Count (The_Model : Component_Model) return Natural is
   begin
      return Natural (The_Model.Exports.Length);
   end Export_Count;

   function Function_Count (The_Model : Component_Model) return Natural is
   begin
      return Natural (The_Model.Functions.Length);
   end Function_Count;

   function Get_Export (The_Model : Component_Model; Index : Positive) return Lifted_Export is
   begin
      return The_Model.Exports.Element (Index);
   end Get_Export;

   function Get_Function (The_Model : Component_Model; Index : Positive) return Core_Function is
   begin
      return The_Model.Functions.Element (Index);
   end Get_Function;

   function Has_Run_Export (The_Model : Component_Model) return Boolean is
   begin
      for Index in 1 .. Export_Count (The_Model) loop
         if Ada.Strings.Unbounded.To_String (Get_Export (The_Model, Index).Export_Name) = "run" then
            return True;
         end if;
      end loop;

      return False;
   end Has_Run_Export;

   function Length (Sequence : Instruction_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Module_Name (The_Model : Component_Model) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Model.Module_Name_Value);
   end Module_Name;

end Lovelace.Compiler.Backend.Model;
