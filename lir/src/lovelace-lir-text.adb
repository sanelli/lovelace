with Ada.Streams;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces;

with Lovelace.Common.Utf_8;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Text is

   use type GNAT.OS_Lib.File_Descriptor;

   procedure Append_Line
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Text : String);
   procedure Append_Quoted
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Text : String);
   function Hex_Digits (Scalar : Natural) return String;
   function Indent (Level : Natural) return String;
   function Instruction_Token (Item : Instructions.Instruction) return String;
   function Type_Token (The_Type : Types.Value_Type) return String;
   function Unsigned_Image (Value : Interfaces.Unsigned_32) return String;

   procedure Append_Line
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Text : String) is
   begin
      Ada.Strings.Unbounded.Append (Buffer, Text);
      Ada.Strings.Unbounded.Append (Buffer, ASCII.LF);
   end Append_Line;

   procedure Append_Quoted
     (Buffer : in out Ada.Strings.Unbounded.Unbounded_String; Text : String)
   is
      Index : Positive := Text'First;
   begin
      Ada.Strings.Unbounded.Append (Buffer, '"');
      while Index <= Text'Last loop
         declare
            Point  : Lovelace.Common.Utf_8.Code_Point;
            Length : Natural;
            Valid  : Boolean;
         begin
            Lovelace.Common.Utf_8.Decode (Text, Index, Point, Length, Valid);
            if not Valid then
               --  Validate already required UTF-8 names; treat as Internal_Error
               --  by copying the raw byte (should not occur on validated modules).
               Ada.Strings.Unbounded.Append (Buffer, Text (Index .. Index));
               Index := Index + 1;
            else
               declare
                  Scalar : constant Natural := Wide_Wide_Character'Pos (Point);
               begin
                  if Point = Wide_Wide_Character'Val (Character'Pos ('"')) then
                     Ada.Strings.Unbounded.Append (Buffer, "\""");
                  elsif Point = Wide_Wide_Character'Val (Character'Pos ('\'))
                  then
                     Ada.Strings.Unbounded.Append (Buffer, "\\");
                  elsif Point = Wide_Wide_Character'Val (10) then
                     Ada.Strings.Unbounded.Append (Buffer, "\n");
                  elsif Point = Wide_Wide_Character'Val (13) then
                     Ada.Strings.Unbounded.Append (Buffer, "\r");
                  elsif Point = Wide_Wide_Character'Val (9) then
                     Ada.Strings.Unbounded.Append (Buffer, "\t");
                  elsif Scalar < 32 then
                     Ada.Strings.Unbounded.Append (Buffer, "\u{");
                     Ada.Strings.Unbounded.Append
                       (Buffer, Hex_Digits (Scalar));
                     Ada.Strings.Unbounded.Append (Buffer, "}");
                  else
                     Ada.Strings.Unbounded.Append
                       (Buffer, Text (Index .. Index + Length - 1));
                  end if;
               end;
               Index := Index + Length;
            end if;
         end;
      end loop;
      Ada.Strings.Unbounded.Append (Buffer, '"');
   end Append_Quoted;

   function Hex_Digits (Scalar : Natural) return String is
      Hex           : constant String := "0123456789ABCDEF";
      Digits_Needed : Natural := 1;
      Value         : Natural := Scalar;
      Scratch       : Natural := Scalar;
   begin
      while Scratch >= 16 loop
         Digits_Needed := Digits_Needed + 1;
         Scratch := Scratch / 16;
      end loop;
      if Digits_Needed < 4 then
         Digits_Needed := 4;
      end if;
      declare
         Result : String (1 .. Digits_Needed);
      begin
         for Position in reverse Result'Range loop
            Result (Position) := Hex (Value mod 16 + 1);
            Value := Value / 16;
         end loop;
         return Result;
      end;
   end Hex_Digits;

   function Indent (Level : Natural) return String is
      Spaces : constant String (1 .. Level * 2) := (others => ' ');
   begin
      return Spaces;
   end Indent;

   function Instruction_Token (Item : Instructions.Instruction) return String
   is
   begin
      case Item.Operation is
         when Opcodes.No_Operation =>
            return "noop";
      end case;
   end Instruction_Token;

   function Print (The_Module : Modules.Module) return Write_Result is
      Rendered : constant To_Text_Result := To_Text (The_Module);
   begin
      case Rendered.Ok is
         when False =>
            return (Ok => False, Error => Rendered.Error);

         when True  =>
            Ada.Text_IO.Put (Ada.Strings.Unbounded.To_String (Rendered.Value));
            return (Ok => True);
      end case;
   end Print;

   function To_Text (The_Module : Modules.Module) return To_Text_Result is
      Validation : constant Errors.Validation_Results.Result :=
        Modules.Validate (The_Module);
   begin
      case Validation.Ok is
         when False =>
            return (Ok => False, Error => Validation.Error);

         when True  =>
            null;
      end case;

      declare
         Buffer : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Append_Line (Buffer, "(module");
         Append_Line (Buffer, Indent (1) & "(version 1 0)");
         Ada.Strings.Unbounded.Append (Buffer, Indent (1) & "(name ");
         Append_Quoted (Buffer, Modules.Name (The_Module));
         Append_Line (Buffer, ")");
         Append_Line
           (Buffer,
            Indent (1)
            & "(flags "
            & Unsigned_Image
                (Interfaces.Unsigned_32 (Modules.Flags (The_Module)))
            & ")");

         for Dependency_Index in 1 .. Modules.Dependency_Count (The_Module)
         loop
            Ada.Strings.Unbounded.Append (Buffer, Indent (1) & "(depend ");
            Append_Quoted
              (Buffer, Modules.Dependency_Name (The_Module, Dependency_Index));
            Append_Line (Buffer, ")");
         end loop;

         for Subroutine_Index in 1 .. Modules.Subroutine_Count (The_Module)
         loop
            declare
               The_Subroutine  : constant Subroutines.Subroutine :=
                 Modules.Get_Subroutine (The_Module, Subroutine_Index);
               The_Signature   : constant Subroutines.Signature :=
                 Subroutines.Get_Signature (The_Subroutine);
               Flags_Value     : constant Subroutines.Subroutine_Flags :=
                 Subroutines.Get_Flags (The_Subroutine);
               Body_Instrs     : constant Instructions.Instruction_Sequence :=
                 Subroutines.Get_Instructions (The_Subroutine);
               Parameter_Count : constant Natural :=
                 Types.Length (The_Signature.Parameter_Types);
            begin
               Append_Line (Buffer, Indent (1) & "(subroutine");
               Ada.Strings.Unbounded.Append (Buffer, Indent (2) & "(name ");
               Append_Quoted
                 (Buffer,
                  Ada.Strings.Unbounded.To_String (The_Signature.Name));
               Append_Line (Buffer, ")");

               if Parameter_Count > 0 then
                  Ada.Strings.Unbounded.Append (Buffer, Indent (2) & "(param");
                  for Parameter_Index in 1 .. Parameter_Count loop
                     Ada.Strings.Unbounded.Append
                       (Buffer,
                        " "
                        & Type_Token
                            (Types.Element
                               (The_Signature.Parameter_Types,
                                Parameter_Index)));
                  end loop;
                  Append_Line (Buffer, ")");
               end if;

               Append_Line
                 (Buffer,
                  Indent (2)
                  & "(result "
                  & Type_Token (The_Signature.Return_Type)
                  & ")");

               if Subroutines.Has_Export (Flags_Value) then
                  Append_Line (Buffer, Indent (2) & "export");
               end if;
               if Subroutines.Has_Entrypoint (Flags_Value) then
                  Append_Line (Buffer, Indent (2) & "entrypoint");
               end if;

               if Instructions.Length (Body_Instrs) = 0 then
                  Append_Line (Buffer, Indent (2) & "(body))");
               else
                  Append_Line (Buffer, Indent (2) & "(body");
                  for Instruction_Index in
                    1 .. Instructions.Length (Body_Instrs)
                  loop
                     declare
                        Token : constant String :=
                          Instruction_Token
                            (Instructions.Element
                               (Body_Instrs, Instruction_Index));
                     begin
                        if Instruction_Index
                          < Instructions.Length (Body_Instrs)
                        then
                           Append_Line (Buffer, Indent (3) & Token);
                        else
                           Append_Line (Buffer, Indent (3) & Token & "))");
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end loop;

         Append_Line (Buffer, ")");
         return (Ok => True, Value => Buffer);
      end;
   end To_Text;

   function Type_Token (The_Type : Types.Value_Type) return String is
   begin
      case The_Type is
         when Types.Unit =>
            return "unit";

         when Types.I8   =>
            return "i8";

         when Types.I16  =>
            return "i16";

         when Types.I32  =>
            return "i32";

         when Types.I64  =>
            return "i64";

         when Types.I128 =>
            return "i128";

         when Types.U8   =>
            return "u8";

         when Types.U16  =>
            return "u16";

         when Types.U32  =>
            return "u32";

         when Types.U64  =>
            return "u64";

         when Types.U128 =>
            return "u128";

         when Types.F16  =>
            return "f16";

         when Types.F32  =>
            return "f32";

         when Types.F64  =>
            return "f64";
      end case;
   end Type_Token;

   function Unsigned_Image (Value : Interfaces.Unsigned_32) return String is
      Image : constant String := Interfaces.Unsigned_32'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;
      return Image;
   end Unsigned_Image;

   function Write
     (The_Module : Modules.Module; Path : String) return Write_Result
   is
      Rendered : constant To_Text_Result := To_Text (The_Module);
   begin
      case Rendered.Ok is
         when False =>
            return (Ok => False, Error => Rendered.Error);

         when True  =>
            declare
               Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
                 GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
               Text       : constant String :=
                 Ada.Strings.Unbounded.To_String (Rendered.Value);
            begin
               if Descriptor = GNAT.OS_Lib.Invalid_FD then
                  return (Ok => False, Error => Errors.Io_Failure);
               end if;

               if Text'Length > 0 then
                  declare
                     Buffer  :
                       Ada.Streams.Stream_Element_Array
                         (1
                          .. Ada.Streams.Stream_Element_Offset (Text'Length));
                     Written : Integer;
                  begin
                     for Index in Text'Range loop
                        Buffer
                          (Ada.Streams.Stream_Element_Offset
                             (Index - Text'First + 1)) :=
                          Ada.Streams.Stream_Element
                            (Character'Pos (Text (Index)));
                     end loop;
                     Written :=
                       GNAT.OS_Lib.Write
                         (Descriptor, Buffer'Address, Buffer'Length);
                     if Written /= Integer (Buffer'Length) then
                        GNAT.OS_Lib.Close (Descriptor);
                        return (Ok => False, Error => Errors.Io_Failure);
                     end if;
                  end;
               end if;

               GNAT.OS_Lib.Close (Descriptor);
               return (Ok => True);
            end;
      end case;
   end Write;

end Lovelace.Lir.Text;
