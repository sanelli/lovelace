with Ada.Strings.Unbounded;

with Lovelace.Compiler.Backend.Lowering;
with Lovelace.Compiler.Backend.Model;
with Lovelace.Compiler.Backend.Wit;

package body Lovelace.Compiler.Backend.Wat is

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural;
   --  0-based alias index among Core_Exported functions for Core_Function_Index.

   function Dollar_Name (Name : String) return String;
   --  WAT $Name form (Name is already a safe identifier in this slice).

   function Image_Without_Leading_Space (Value : Integer) return String;
   --  Decimal image without the leading blank Ada puts on positive'Image.

   function To_Wat (The_Model : Model.Component_Model) return String;
   --  Render The_Model as component WAT text.

   function Core_Func_Alias_Index (The_Model : Model.Component_Model; Core_Function_Index : Positive) return Natural is
      Alias_Index : Natural := 0;
   begin
      for Index in 1 .. Core_Function_Index loop
         if Model.Get_Function (The_Model, Index).Core_Exported then
            if Index = Core_Function_Index then
               return Alias_Index;
            end if;

            Alias_Index := Alias_Index + 1;
         end if;
      end loop;

      return 0;
   end Core_Func_Alias_Index;

   function Dollar_Name (Name : String) return String is
   begin
      return "$" & Name;
   end Dollar_Name;

   function Emit_Wat (The_Module : Lovelace.Lir.Modules.Module) return Wat_Emit_Result is
      Lowered : constant Lowering.Lower_Result := Lowering.Lower (The_Module);
   begin
      case Lowered.Ok is
         when False =>
            return (Ok => False, Error => Lowered.Error);

         when True  =>
            return
              (Ok       => True,
               Wat_Text => Ada.Strings.Unbounded.To_Unbounded_String (To_Wat (Lowered.The_Model)),
               Wit_Text => Ada.Strings.Unbounded.To_Unbounded_String (Wit.To_Wit (Lowered.The_Model)));
      end case;
   end Emit_Wat;

   function Image_Without_Leading_Space (Value : Integer) return String is
      Raw : constant String := Integer'Image (Value);
   begin
      if Raw'Length > 0 and then Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      end if;

      return Raw;
   end Image_Without_Leading_Space;

   function To_Wat (The_Model : Model.Component_Model) return String is
      Buffer            : Ada.Strings.Unbounded.Unbounded_String;
      Unit_Type_Index   : Integer := -1;
      Result_Type_Index : Integer := -1;
      Next_Type_Index   : Natural := 0;
      Lifted_Func_Index : Natural := 0;
   begin
      Ada.Strings.Unbounded.Append (Buffer, "(component" & ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, "  (core module" & ASCII.LF);

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Result_Is_I32 then
               Ada.Strings.Unbounded.Append
                 (Buffer, "    (func " & Dollar_Name (Func_Name) & " (result i32)" & ASCII.LF);
            else
               Ada.Strings.Unbounded.Append (Buffer, "    (func " & Dollar_Name (Func_Name) & ASCII.LF);
            end if;

            for Instr_Index in 1 .. Model.Length (The_Function.Instructions) loop
               declare
                  Item : constant Model.Core_Instruction := Model.Element (The_Function.Instructions, Instr_Index);
               begin
                  case Item.Kind is
                     when Model.Call_Function =>
                        declare
                           Target      : constant Model.Core_Function :=
                             Model.Get_Function (The_Model, Item.Target_Index);
                           Target_Name : constant String := Ada.Strings.Unbounded.To_String (Target.Name);
                        begin
                           Ada.Strings.Unbounded.Append (Buffer, "      call " & Dollar_Name (Target_Name) & ASCII.LF);
                        end;

                     when Model.I32_Constant  =>
                        Ada.Strings.Unbounded.Append
                          (Buffer, "      i32.const " & Image_Without_Leading_Space (Integer (Item.Value)) & ASCII.LF);
                  end case;
               end;
            end loop;

            Ada.Strings.Unbounded.Append (Buffer, "    )" & ASCII.LF);
         end;
      end loop;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Ada.Strings.Unbounded.Append
                 (Buffer, "    (export """ & Func_Name & """ (func " & Dollar_Name (Func_Name) & "))" & ASCII.LF);
            end if;
         end;
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, "  )" & ASCII.LF);
      Ada.Strings.Unbounded.Append (Buffer, "  (core instance (instantiate 0))" & ASCII.LF);

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function := Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String := Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Ada.Strings.Unbounded.Append
                 (Buffer, "  (alias core export 0 """ & Func_Name & """ (core func))" & ASCII.LF);
            end if;
         end;
      end loop;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               if Result_Type_Index < 0 then
                  Result_Type_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
                  Ada.Strings.Unbounded.Append (Buffer, "  (type (func (result (result))))" & ASCII.LF);
               end if;
            else
               if Unit_Type_Index < 0 then
                  Unit_Type_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
                  Ada.Strings.Unbounded.Append (Buffer, "  (type (func))" & ASCII.LF);
               end if;
            end if;
         end;
      end loop;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
            Alias_Index : constant Natural := Core_Func_Alias_Index (The_Model, The_Export.Core_Function_Index);
            Type_Index  : Natural;
         begin
            if The_Export.Returns_Result then
               Type_Index := Natural (Result_Type_Index);
            else
               Type_Index := Natural (Unit_Type_Index);
            end if;

            Ada.Strings.Unbounded.Append
              (Buffer,
               "  (canon lift (core func "
               & Image_Without_Leading_Space (Integer (Alias_Index))
               & ") (type "
               & Image_Without_Leading_Space (Integer (Type_Index))
               & "))"
               & ASCII.LF);
         end;
      end loop;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export  : constant Model.Lifted_Export := Model.Get_Export (The_Model, Export_Index);
            Export_Name : constant String := Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
         begin
            Ada.Strings.Unbounded.Append
              (Buffer,
               "  (export """
               & Export_Name
               & """ (func "
               & Image_Without_Leading_Space (Integer (Lifted_Func_Index))
               & "))"
               & ASCII.LF);
            Lifted_Func_Index := Lifted_Func_Index + 1;
         end;
      end loop;

      Ada.Strings.Unbounded.Append (Buffer, ")" & ASCII.LF);
      return Ada.Strings.Unbounded.To_String (Buffer);
   end To_Wat;

end Lovelace.Compiler.Backend.Wat;
