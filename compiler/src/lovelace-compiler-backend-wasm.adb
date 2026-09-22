with Ada.Strings.Unbounded;
with Interfaces;

with Lovelace.Compiler.Backend.Leb128;
with Lovelace.Compiler.Backend.Lowering;
with Lovelace.Compiler.Backend.Model;
with Lovelace.Compiler.Backend.Wit;

package body Lovelace.Compiler.Backend.Wasm is

   procedure Append_Name (Sequence : in out Byte_Sequence; Name : String);
   --  Length-prefixed UTF-8 name (core:name / externname bytes).

   procedure Append_Section
     (Sequence   : in out Byte_Sequence;
      Section_Id : Interfaces.Unsigned_8;
      Contents   : Byte_Sequence);
   --  Component/core style section: id, size, contents.

   function Core_Func_Alias_Index
     (The_Model : Model.Component_Model; Core_Function_Index : Positive)
      return Natural;
   --  0-based alias index among Core_Exported functions.

   function Encode_Component
     (The_Model : Model.Component_Model) return Byte_Sequence;
   --  Full component binary for The_Model.

   function Encode_Core_Module
     (The_Model : Model.Component_Model) return Byte_Sequence;
   --  Nested core module binary for The_Model.

   procedure Append_Name (Sequence : in out Byte_Sequence; Name : String) is
   begin
      Leb128.Append_Unsigned (Sequence, Interfaces.Unsigned_32 (Name'Length));

      for Index in Name'Range loop
         Append
           (Sequence, Interfaces.Unsigned_8 (Character'Pos (Name (Index))));
      end loop;
   end Append_Name;

   procedure Append_Section
     (Sequence   : in out Byte_Sequence;
      Section_Id : Interfaces.Unsigned_8;
      Contents   : Byte_Sequence) is
   begin
      Append (Sequence, Section_Id);
      Leb128.Append_Unsigned
        (Sequence, Interfaces.Unsigned_32 (Length (Contents)));
      Append_Bytes (Sequence, Contents);
   end Append_Section;

   function Core_Func_Alias_Index
     (The_Model : Model.Component_Model; Core_Function_Index : Positive)
      return Natural
   is
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

   function Emit_Wasm
     (The_Module : Lovelace.Lir.Modules.Module) return Wasm_Emit_Result
   is
      Lowered : constant Lowering.Lower_Result := Lowering.Lower (The_Module);
   begin
      case Lowered.Ok is
         when False =>
            return (Ok => False, Error => Lowered.Error);

         when True  =>
            return
              (Ok         => True,
               Wasm_Bytes => Encode_Component (Lowered.The_Model),
               Wit_Text   =>
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Wit.To_Wit (Lowered.The_Model)));
      end case;
   end Emit_Wasm;

   function Encode_Component
     (The_Model : Model.Component_Model) return Byte_Sequence
   is
      Component_Bytes       : Byte_Sequence := Empty_Bytes;
      Instance_Contents     : Byte_Sequence := Empty_Bytes;
      Alias_Contents        : Byte_Sequence := Empty_Bytes;
      Type_Contents         : Byte_Sequence := Empty_Bytes;
      Canon_Contents        : Byte_Sequence := Empty_Bytes;
      Export_Contents       : Byte_Sequence := Empty_Bytes;
      Core_Module           : constant Byte_Sequence :=
        Encode_Core_Module (The_Model);
      Alias_Count           : Natural := 0;
      Unit_Type_Index       : Integer := -1;
      Result_Valtype_Index  : Integer := -1;
      Result_Functype_Index : Integer := -1;
      Next_Type_Index       : Natural := 0;
   begin
      Append (Component_Bytes, 16#00#);
      Append (Component_Bytes, 16#61#);
      Append (Component_Bytes, 16#73#);
      Append (Component_Bytes, 16#6D#);
      Append (Component_Bytes, 16#0D#);
      Append (Component_Bytes, 16#00#);
      Append (Component_Bytes, 16#01#);
      Append (Component_Bytes, 16#00#);

      Append_Section (Component_Bytes, 1, Core_Module);

      --  core instance: instantiate module 0 with no args
      Leb128.Append_Unsigned (Instance_Contents, 1);
      Append (Instance_Contents, 16#00#); -- instantiate
      Leb128.Append_Unsigned (Instance_Contents, 0); -- moduleidx
      Leb128.Append_Unsigned (Instance_Contents, 0); -- empty args
      Append_Section (Component_Bytes, 2, Instance_Contents);

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         if Model.Get_Function (The_Model, Func_Index).Core_Exported then
            Alias_Count := Alias_Count + 1;
         end if;
      end loop;

      Leb128.Append_Unsigned
        (Alias_Contents, Interfaces.Unsigned_32 (Alias_Count));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function :=
              Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String :=
              Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Append (Alias_Contents, 16#00#); -- sort: core
               Append (Alias_Contents, 16#00#); -- core sort: func
               Append (Alias_Contents, 16#01#); -- alias core export
               Leb128.Append_Unsigned (Alias_Contents, 0); -- core instance 0
               Append_Name (Alias_Contents, Func_Name);
            end if;
         end;
      end loop;

      if Alias_Count > 0 then
         Append_Section (Component_Bytes, 6, Alias_Contents);
      end if;

      for Export_Index in 1 .. Model.Export_Count (The_Model) loop
         declare
            The_Export : constant Model.Lifted_Export :=
              Model.Get_Export (The_Model, Export_Index);
         begin
            if The_Export.Returns_Result then
               if Result_Functype_Index < 0 then
                  --  Bare (result) is a defvaltype; functype may only reference it by typeidx.
                  Result_Valtype_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
                  Result_Functype_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
               end if;
            else
               if Unit_Type_Index < 0 then
                  Unit_Type_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
               end if;
            end if;
         end;
      end loop;

      if Next_Type_Index > 0 then
         Leb128.Append_Unsigned
           (Type_Contents, Interfaces.Unsigned_32 (Next_Type_Index));

         for Type_Index in 0 .. Next_Type_Index - 1 loop
            if Unit_Type_Index = Integer (Type_Index) then
               --  func ()
               Append (Type_Contents, 16#40#);
               Leb128.Append_Unsigned (Type_Contents, 0); -- empty params
               Append (Type_Contents, 16#01#); -- empty resultlist
               Append (Type_Contents, 16#00#);
            elsif Result_Valtype_Index = Integer (Type_Index) then
               --  (result) with no ok/err payloads
               Append (Type_Contents, 16#6A#);
               Append (Type_Contents, 16#00#);
               Append (Type_Contents, 16#00#);
            elsif Result_Functype_Index = Integer (Type_Index) then
               --  func () -> <Result_Valtype_Index>
               Append (Type_Contents, 16#40#);
               Leb128.Append_Unsigned (Type_Contents, 0);
               Append (Type_Contents, 16#00#); -- one result
               Leb128.Append_Unsigned
                 (Type_Contents,
                  Interfaces.Unsigned_32 (Result_Valtype_Index));
            end if;
         end loop;

         Append_Section (Component_Bytes, 7, Type_Contents);
      end if;

      if Model.Export_Count (The_Model) > 0 then
         Leb128.Append_Unsigned
           (Canon_Contents,
            Interfaces.Unsigned_32 (Model.Export_Count (The_Model)));

         for Export_Index in 1 .. Model.Export_Count (The_Model) loop
            declare
               The_Export  : constant Model.Lifted_Export :=
                 Model.Get_Export (The_Model, Export_Index);
               Alias_Index : constant Natural :=
                 Core_Func_Alias_Index
                   (The_Model, The_Export.Core_Function_Index);
               Type_Index  : Natural;
            begin
               if The_Export.Returns_Result then
                  Type_Index := Natural (Result_Functype_Index);
               else
                  Type_Index := Natural (Unit_Type_Index);
               end if;

               Append (Canon_Contents, 16#00#); -- lift
               Append (Canon_Contents, 16#00#); -- core func sort
               Leb128.Append_Unsigned
                 (Canon_Contents, Interfaces.Unsigned_32 (Alias_Index));
               Leb128.Append_Unsigned (Canon_Contents, 0); -- empty opts
               Leb128.Append_Unsigned
                 (Canon_Contents, Interfaces.Unsigned_32 (Type_Index));
            end;
         end loop;

         Append_Section (Component_Bytes, 8, Canon_Contents);

         declare
            Component_Instance_Contents : Byte_Sequence := Empty_Bytes;
            Instance_Count              : Natural := 0;
            Lifted_Func_Cursor          : Natural := 0;
            Instance_Cursor             : Natural := 0;
         begin
            for Export_Index in 1 .. Model.Export_Count (The_Model) loop
               if Model.Get_Export (The_Model, Export_Index).Returns_Result
               then
                  Instance_Count := Instance_Count + 1;
               end if;
            end loop;

            if Instance_Count > 0 then
               Leb128.Append_Unsigned
                 (Component_Instance_Contents,
                  Interfaces.Unsigned_32 (Instance_Count));

               for Export_Index in 1 .. Model.Export_Count (The_Model) loop
                  declare
                     The_Export : constant Model.Lifted_Export :=
                       Model.Get_Export (The_Model, Export_Index);
                  begin
                     if The_Export.Returns_Result then
                        Append
                          (Component_Instance_Contents,
                           16#01#); -- export bundle
                        Leb128.Append_Unsigned
                          (Component_Instance_Contents, 1);
                        Append
                          (Component_Instance_Contents, 16#00#); -- plain name
                        Append_Name (Component_Instance_Contents, "run");
                        Append
                          (Component_Instance_Contents, 16#01#); -- sort: func
                        Leb128.Append_Unsigned
                          (Component_Instance_Contents,
                           Interfaces.Unsigned_32 (Lifted_Func_Cursor));
                     end if;
                     Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
                  end;
               end loop;

               Append_Section
                 (Component_Bytes, 5, Component_Instance_Contents);
            end if;

            Leb128.Append_Unsigned
              (Export_Contents,
               Interfaces.Unsigned_32 (Model.Export_Count (The_Model)));

            Lifted_Func_Cursor := 0;
            for Export_Index in 1 .. Model.Export_Count (The_Model) loop
               declare
                  The_Export  : constant Model.Lifted_Export :=
                    Model.Get_Export (The_Model, Export_Index);
                  Export_Name : constant String :=
                    Ada.Strings.Unbounded.To_String (The_Export.Export_Name);
               begin
                  Append (Export_Contents, 16#00#); -- nameattributes plain
                  Append_Name (Export_Contents, Export_Name);
                  if The_Export.Returns_Result then
                     Append (Export_Contents, 16#05#); -- sort: instance
                     Leb128.Append_Unsigned
                       (Export_Contents,
                        Interfaces.Unsigned_32 (Instance_Cursor));
                     Instance_Cursor := Instance_Cursor + 1;
                  else
                     Append (Export_Contents, 16#01#); -- sort: func
                     Leb128.Append_Unsigned
                       (Export_Contents,
                        Interfaces.Unsigned_32 (Lifted_Func_Cursor));
                  end if;
                  Append (Export_Contents, 16#00#); -- no externtype
                  Lifted_Func_Cursor := Lifted_Func_Cursor + 1;
               end;
            end loop;

            Append_Section (Component_Bytes, 11, Export_Contents);
         end;
      end if;

      return Component_Bytes;
   end Encode_Component;

   function Encode_Core_Module
     (The_Model : Model.Component_Model) return Byte_Sequence
   is
      Module_Bytes      : Byte_Sequence := Empty_Bytes;
      Type_Contents     : Byte_Sequence := Empty_Bytes;
      Function_Contents : Byte_Sequence := Empty_Bytes;
      Export_Contents   : Byte_Sequence := Empty_Bytes;
      Code_Contents     : Byte_Sequence := Empty_Bytes;
      Unit_Type_Index   : Integer := -1;
      I32_Type_Index    : Integer := -1;
      Next_Type_Index   : Natural := 0;
      Export_Count      : Natural := 0;
   begin
      Append (Module_Bytes, 16#00#);
      Append (Module_Bytes, 16#61#);
      Append (Module_Bytes, 16#73#);
      Append (Module_Bytes, 16#6D#);
      Append (Module_Bytes, 16#01#);
      Append (Module_Bytes, 16#00#);
      Append (Module_Bytes, 16#00#);
      Append (Module_Bytes, 16#00#);

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function :=
              Model.Get_Function (The_Model, Func_Index);
         begin
            if The_Function.Result_Is_I32 then
               if I32_Type_Index < 0 then
                  I32_Type_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
               end if;
            else
               if Unit_Type_Index < 0 then
                  Unit_Type_Index := Integer (Next_Type_Index);
                  Next_Type_Index := Next_Type_Index + 1;
               end if;
            end if;
         end;
      end loop;

      Leb128.Append_Unsigned
        (Type_Contents, Interfaces.Unsigned_32 (Next_Type_Index));

      if Unit_Type_Index >= 0 then
         --  [] -> []
         Append (Type_Contents, 16#60#);
         Leb128.Append_Unsigned (Type_Contents, 0);
         Leb128.Append_Unsigned (Type_Contents, 0);
      end if;

      if I32_Type_Index >= 0 then
         --  [] -> [i32]
         Append (Type_Contents, 16#60#);
         Leb128.Append_Unsigned (Type_Contents, 0);
         Leb128.Append_Unsigned (Type_Contents, 1);
         Append (Type_Contents, 16#7F#);
      end if;

      --  If both types exist and Unit was emitted first, I32 index is 1; if only I32, index 0.
      --  Recompute indices to match emission order (Unit then I32).
      declare
         Recomputed_Unit : Integer := -1;
         Recomputed_I32  : Integer := -1;
         Cursor          : Natural := 0;
      begin
         if Unit_Type_Index >= 0 then
            Recomputed_Unit := Integer (Cursor);
            Cursor := Cursor + 1;
         end if;

         if I32_Type_Index >= 0 then
            Recomputed_I32 := Integer (Cursor);
         end if;

         Unit_Type_Index := Recomputed_Unit;
         I32_Type_Index := Recomputed_I32;
      end;

      Leb128.Append_Unsigned
        (Function_Contents,
         Interfaces.Unsigned_32 (Model.Function_Count (The_Model)));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function :=
              Model.Get_Function (The_Model, Func_Index);
            Type_Index   : Natural;
         begin
            if The_Function.Result_Is_I32 then
               Type_Index := Natural (I32_Type_Index);
            else
               Type_Index := Natural (Unit_Type_Index);
            end if;

            Leb128.Append_Unsigned
              (Function_Contents, Interfaces.Unsigned_32 (Type_Index));
         end;
      end loop;

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         if Model.Get_Function (The_Model, Func_Index).Core_Exported then
            Export_Count := Export_Count + 1;
         end if;
      end loop;

      Leb128.Append_Unsigned
        (Export_Contents, Interfaces.Unsigned_32 (Export_Count));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function :=
              Model.Get_Function (The_Model, Func_Index);
            Func_Name    : constant String :=
              Ada.Strings.Unbounded.To_String (The_Function.Name);
         begin
            if The_Function.Core_Exported then
               Append_Name (Export_Contents, Func_Name);
               Append (Export_Contents, 16#00#); -- func
               Leb128.Append_Unsigned
                 (Export_Contents, Interfaces.Unsigned_32 (Func_Index - 1));
            end if;
         end;
      end loop;

      Leb128.Append_Unsigned
        (Code_Contents,
         Interfaces.Unsigned_32 (Model.Function_Count (The_Model)));

      for Func_Index in 1 .. Model.Function_Count (The_Model) loop
         declare
            The_Function : constant Model.Core_Function :=
              Model.Get_Function (The_Model, Func_Index);
            Code_Body    : Byte_Sequence := Empty_Bytes;
            Body_Size    : Byte_Sequence := Empty_Bytes;
         begin
            Leb128.Append_Unsigned (Code_Body, 0); -- locals

            for Instr_Index in 1 .. Model.Length (The_Function.Instructions)
            loop
               declare
                  Item : constant Model.Core_Instruction :=
                    Model.Element (The_Function.Instructions, Instr_Index);
               begin
                  case Item.Kind is
                     when Model.Call_Function =>
                        Append (Code_Body, 16#10#);
                        Leb128.Append_Unsigned
                          (Code_Body,
                           Interfaces.Unsigned_32 (Item.Target_Index - 1));

                     when Model.I32_Constant  =>
                        Append (Code_Body, 16#41#);
                        Leb128.Append_Signed (Code_Body, Item.Value);
                  end case;
               end;
            end loop;

            Append (Code_Body, 16#0B#); -- end
            Leb128.Append_Unsigned
              (Body_Size, Interfaces.Unsigned_32 (Length (Code_Body)));
            Append_Bytes (Code_Contents, Body_Size);
            Append_Bytes (Code_Contents, Code_Body);
         end;
      end loop;

      if Next_Type_Index > 0 then
         Append_Section (Module_Bytes, 1, Type_Contents);
      end if;

      if Model.Function_Count (The_Model) > 0 then
         Append_Section (Module_Bytes, 3, Function_Contents);
      end if;

      if Export_Count > 0 then
         Append_Section (Module_Bytes, 7, Export_Contents);
      end if;

      if Model.Function_Count (The_Model) > 0 then
         Append_Section (Module_Bytes, 10, Code_Contents);
      end if;

      return Module_Bytes;
   end Encode_Core_Module;

end Lovelace.Compiler.Backend.Wasm;
