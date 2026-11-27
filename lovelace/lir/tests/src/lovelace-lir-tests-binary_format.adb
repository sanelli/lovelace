with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with GNAT.OS_Lib;

with Interfaces;

with Lovelace.Common.Source;
with Lovelace.Lir.Binary;
with Lovelace.Lir.Errors;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Tests.Support;
with Lovelace.Lir.Types;

package body Lovelace.Lir.Tests.Binary_Format is

   use type Ada.Streams.Stream_Element_Array;
   use type Ada.Streams.Stream_Element_Offset;
   use type Errors.Error_Code;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_32;
   use type Modules.Module_Flags;
   use type Opcodes.Opcode;
   use type Subroutines.Subroutine_Flags;

   package Source renames Lovelace.Common.Source;

   --  Raw image bytes, built by hand so that each failure arm can be hit.
   subtype Octets is Ada.Streams.Stream_Element_Array;

   --  Presence byte values and type codes used by the hand-built images.
   Absent        : constant Octets (1 .. 1) := [1 => 0];
   Code_Unit     : constant Natural := 0;
   Code_I32      : constant Natural := 3;
   Code_F64      : constant Natural := 10;
   Code_Bad      : constant Natural := 16#FF#;
   Nothing       : constant Octets (1 .. 0) := [others => 0];
   Above_Highest : constant Interfaces.Unsigned_32 := 16#8000_0000#;

   --  Magic "LIR" NUL followed by format version 1.0.
   Magic_And_Version : constant Octets (1 .. 8) :=
     [16#4C#, 16#49#, 16#52#, 0, 1, 0, 0, 0];

   --  Not valid UTF-8: a lone 0xFF byte and a lead byte without continuation.
   Bad_Utf_Ff   : constant String := "a" & Character'Val (16#FF#);
   Bad_Utf_Lead : constant String := "a" & Character'Val (16#C3#);

   procedure Assert_Read_Error
     (Path : String; Expected : Errors.Error_Code; Message : String);

   procedure Assert_Write_Error
     (The_Module : Modules.Module;
      Path       : String;
      Expected   : Errors.Error_Code;
      Message    : String);

   function U08 (Value : Natural) return Octets;

   function U16 (Value : Natural) return Octets;

   function U32 (Value : Interfaces.Unsigned_32) return Octets;

   function Str (Text : String) return Octets;

   function Position
     (Byte_Index : Interfaces.Unsigned_32;
      Line       : Interfaces.Unsigned_32;
      Column     : Interfaces.Unsigned_32) return Octets;

   function Good_Position return Octets;

   function Good_Span return Octets;

   --  One span whose first or last position is out of range.
   --  @param Kind 0 .. 7 selects the bad component.
   function Bad_Span (Kind : Natural) return Octets;

   --  Origin record with presence byte 1.
   function Origin_Present
     (Filename  : String;
      Name_Span : Octets := Good_Span;
      Unit_Span : Octets := Good_Span) return Octets;

   --  One instruction: opcode word plus a 32-bit immediate.
   function Op
     (Operation : Opcodes.Opcode; Operand : Interfaces.Unsigned_32)
      return Octets;

   function Noop return Octets;

   --  Instruction count (one) followed by Item.
   function One_Instruction (Item : Octets) return Octets;

   --  Parameter list (count one) with a single named, typed entry.
   function One_Parameter (Name : String; Code : Natural) return Octets;

   --  Local list (count one) with a single indexed, named, typed entry.
   function One_Local
     (Index : Interfaces.Unsigned_32; Name : String; Code : Natural)
      return Octets;

   --  Signature fields: name, return code, parameter list.
   function Signature_Bytes
     (Name        : String := "S";
      Return_Code : Natural := Code_Unit;
      Parameters  : Octets := U32 (0)) return Octets;

   --  One subroutine body (signature repeated, locals, flags, optional parts, instructions).
   function Body_Bytes
     (Signature       : Octets := Signature_Bytes;
      Locals          : Octets := U32 (0);
      Flags           : Interfaces.Unsigned_32 := 0;
      Origin          : Octets := Absent;
      From_Dependency : Octets := Absent;
      Native          : Octets := Absent;
      Instructions    : Octets := U32 (0)) return Octets;

   --  Body bytes up to and including the flags word (no locals), for cut-off bodies.
   function Body_Through_Flags return Octets;

   --  Everything from the magic through the module origin.
   function Header
     (Version      : String := "0.0.1";
      Name         : String := "m";
      Flags        : Interfaces.Unsigned_32 := 0;
      Dependencies : Octets := U32 (0);
      Origin       : Octets := Absent) return Octets;

   --  Complete image with one subroutine; Offset_Delta skews the preamble offset.
   function Image
     (Prefix       : Octets := Header;
      Index_Sig    : Octets := Signature_Bytes;
      Body_Part    : Octets := Body_Bytes;
      Offset_Delta : Integer := 0) return Octets;

   --  Module with dependencies, origins, locals, from-dependency, native binding, and
   --  every instruction kind.
   function Make_Rich_Module return Modules.Module;

   --  Image whose only subroutine takes one I32 parameter and has Instructions as its body stream.
   function With_Instructions (Instructions : Octets) return Octets;

   procedure Expect
     (Bytes : Octets; Expected : Errors.Error_Code; Message : String)
   renames Support.Assert_Decode_Error;

   procedure Assert_Read_Error
     (Path : String; Expected : Errors.Error_Code; Message : String)
   is
      Result : constant Binary.Decode_Result := Binary.Read (Path);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, Message & ": unexpected read success");

         when False =>
            AUnit.Assertions.Assert
              (Result.Error = Expected,
               Message & ": got " & Errors.Error_Code'Image (Result.Error));
      end case;
   end Assert_Read_Error;

   procedure Assert_Write_Error
     (The_Module : Modules.Module;
      Path       : String;
      Expected   : Errors.Error_Code;
      Message    : String)
   is
      Result : constant Binary.Write_Result := Binary.Write (The_Module, Path);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, Message & ": unexpected write success");

         when False =>
            AUnit.Assertions.Assert
              (Result.Error = Expected,
               Message & ": got " & Errors.Error_Code'Image (Result.Error));
      end case;
   end Assert_Write_Error;

   function Bad_Span (Kind : Natural) return Octets is
   begin
      case Kind is
         when 0      =>
            return Position (0, 1, 1) & Good_Position;

         when 1      =>
            return Position (1, 0, 1) & Good_Position;

         when 2      =>
            return Position (1, 1, 0) & Good_Position;

         when 3      =>
            return Position (Above_Highest, 1, 1) & Good_Position;

         when 4      =>
            return Position (1, Above_Highest, 1) & Good_Position;

         when 5      =>
            return Position (1, 1, Above_Highest) & Good_Position;

         when 6      =>
            return Good_Position & Position (0, 1, 1);

         when others =>
            return Good_Position & Position (1, 1, Above_Highest);
      end case;
   end Bad_Span;

   function Body_Bytes
     (Signature       : Octets := Signature_Bytes;
      Locals          : Octets := U32 (0);
      Flags           : Interfaces.Unsigned_32 := 0;
      Origin          : Octets := Absent;
      From_Dependency : Octets := Absent;
      Native          : Octets := Absent;
      Instructions    : Octets := U32 (0)) return Octets is
   begin
      return
        Signature
        & Locals
        & U32 (Flags)
        & Origin
        & From_Dependency
        & Native
        & Instructions;
   end Body_Bytes;

   function Body_Through_Flags return Octets is
   begin
      return Signature_Bytes & U32 (0) & U32 (0);
   end Body_Through_Flags;

   function Good_Position return Octets is
   begin
      return Position (1, 1, 1);
   end Good_Position;

   function Good_Span return Octets is
   begin
      return Good_Position & Position (2, 1, 2);
   end Good_Span;

   function Header
     (Version      : String := "0.0.1";
      Name         : String := "m";
      Flags        : Interfaces.Unsigned_32 := 0;
      Dependencies : Octets := U32 (0);
      Origin       : Octets := Absent) return Octets is
   begin
      return
        Magic_And_Version
        & Str (Version)
        & Str (Name)
        & U32 (Flags)
        & Dependencies
        & Origin;
   end Header;

   function Image
     (Prefix       : Octets := Header;
      Index_Sig    : Octets := Signature_Bytes;
      Body_Part    : Octets := Body_Bytes;
      Offset_Delta : Integer := 0) return Octets
   is
      Offset : constant Integer :=
        Prefix'Length + 4 + Index_Sig'Length + 4 + Offset_Delta;
   begin
      return
        Prefix
        & U32 (1)
        & Index_Sig
        & U32 (Interfaces.Unsigned_32 (Offset))
        & Body_Part;
   end Image;

   function Make_Rich_Module return Modules.Module is
      File_Opt   : constant Source.Filename_Option :=
        Source.Some_Filename (Source.From_Utf_8 ("rich.love"));
      Span       : constant Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 9, Line => 2, Column => 3));
      The_Module : Modules.Module := Modules.Create ("rich");
      Params     : Types.Parameter_Sequence := Types.Empty_Sequence;
      Imported   : Subroutines.Subroutine;
      Printer    : Subroutines.Subroutine;
   begin
      Types.Append (Params, "a", Types.I32);
      Types.Append (Params, "b", Types.F64);
      Modules.Set_Flags (The_Module, 5);
      Modules.Append_Dependency (The_Module, "dep_a", "1.2.3");
      Modules.Append_Dependency (The_Module, "dep_b");
      Modules.Set_Origin
        (The_Module, (Name_Span => Span, Span => Span, Filename => File_Opt));

      Imported :=
        Support.Make_Subroutine
          ("Imported",
           Types.I32,
           Parameters => Params,
           Flags      => Subroutines.Export_Flag,
           Noop_Count => 1);
      Subroutines.Set_Origin
        (Imported, (Name_Span => Span, Span => Span, Filename => File_Opt));
      Subroutines.Set_From_Dependency (Imported, "dep_a");
      Subroutines.Append_Local (Imported, "x", Types.I8);
      Subroutines.Append_Local (Imported, "y", Types.U64);
      Subroutines.Append_Instruction
        (Imported,
         (Operation     => Opcodes.Constant_I32,
          Immediate_I32 => Interfaces.Integer_32'(-7)));
      Subroutines.Append_Instruction
        (Imported, (Operation => Opcodes.Local_Get, Local_Index => 1));
      Subroutines.Append_Instruction
        (Imported, (Operation => Opcodes.Local_Set, Local_Index => 4));
      Subroutines.Append_Instruction
        (Imported, (Operation => Opcodes.Call, Target_Index => 2));

      Printer :=
        Support.Make_Subroutine ("print", Types.Unit, Parameters => Params);
      Subroutines.Set_Origin
        (Printer, (Name_Span => Span, Span => Span, Filename => File_Opt));
      Subroutines.Set_Native_Binding (Printer, "wasi", "print-integer");

      Modules.Append_Subroutine (The_Module, Imported);
      Modules.Append_Subroutine (The_Module, Printer);
      return The_Module;
   end Make_Rich_Module;

   function Noop return Octets is
   begin
      return U16 (Natural (Opcodes.To_Word (Opcodes.No_Operation)));
   end Noop;

   function One_Instruction (Item : Octets) return Octets is
   begin
      return U32 (1) & Item;
   end One_Instruction;

   function One_Local
     (Index : Interfaces.Unsigned_32; Name : String; Code : Natural)
      return Octets is
   begin
      return U32 (1) & U32 (Index) & Str (Name) & U08 (Code);
   end One_Local;

   function One_Parameter (Name : String; Code : Natural) return Octets is
   begin
      return U32 (1) & Str (Name) & U08 (Code);
   end One_Parameter;

   function Op
     (Operation : Opcodes.Opcode; Operand : Interfaces.Unsigned_32)
      return Octets is
   begin
      return U16 (Natural (Opcodes.To_Word (Operation))) & U32 (Operand);
   end Op;

   function Origin_Present
     (Filename  : String;
      Name_Span : Octets := Good_Span;
      Unit_Span : Octets := Good_Span) return Octets is
   begin
      return U08 (1) & Str (Filename) & Name_Span & Unit_Span;
   end Origin_Present;

   function Position
     (Byte_Index : Interfaces.Unsigned_32;
      Line       : Interfaces.Unsigned_32;
      Column     : Interfaces.Unsigned_32) return Octets is
   begin
      return U32 (Byte_Index) & U32 (Line) & U32 (Column);
   end Position;

   function Signature_Bytes
     (Name        : String := "S";
      Return_Code : Natural := Code_Unit;
      Parameters  : Octets := U32 (0)) return Octets is
   begin
      return Str (Name) & U08 (Return_Code) & Parameters;
   end Signature_Bytes;

   function Str (Text : String) return Octets is
      Result : Octets (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
   begin
      for Index in Text'Range loop
         Result (Ada.Streams.Stream_Element_Offset (Index - Text'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Text (Index)));
      end loop;
      return U32 (Interfaces.Unsigned_32 (Text'Length)) & Result;
   end Str;

   procedure Test_Absent_Filename_Origins (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Span           : constant Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 2, Line => 1, Column => 2));
      The_Module     : Modules.Module := Modules.Create ("m");
      The_Subroutine : Subroutines.Subroutine :=
        Support.Make_Subroutine ("S", Types.Unit);
   begin
      Modules.Set_Origin
        (The_Module,
         (Name_Span => Span,
          Span      => Span,
          Filename  => Source.Absent_Filename));
      Subroutines.Set_Origin
        (The_Subroutine,
         (Name_Span => Span,
          Span      => Span,
          Filename  => Source.Absent_Filename));
      Modules.Append_Subroutine (The_Module, The_Subroutine);
      Support.Assert_Binary_Round_Trip (The_Module, "absent filename origins");

      declare
         Decoded       : constant Modules.Module :=
           Support.Must_Decode
             (Support.Must_Encode (The_Module, "encode"), "decode");
         Module_Origin : constant Modules.Origin_Option :=
           Modules.Origin (Decoded);
         Sub_Origin    : constant Subroutines.Origin_Option :=
           Subroutines.Origin (Modules.Get_Subroutine (Decoded, 1));
      begin
         AUnit.Assertions.Assert
           (Module_Origin.Present, "module origin present");
         AUnit.Assertions.Assert
           (not Module_Origin.Value.Filename.Present,
            "module filename absent");
         AUnit.Assertions.Assert
           (Sub_Origin.Present, "subroutine origin present");
         AUnit.Assertions.Assert
           (not Sub_Origin.Value.Filename.Present,
            "subroutine filename absent");
      end;
   end Test_Absent_Filename_Origins;

   procedure Test_All_Value_Types (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      for The_Type in Types.Value_Type loop
         declare
            Params           : Types.Parameter_Sequence :=
              Types.Empty_Sequence;
            As_Param_Module  : Modules.Module := Modules.Create ("m");
            As_Result_Module : Modules.Module := Modules.Create ("m");
         begin
            Types.Append (Params, "p", The_Type);
            Modules.Append_Subroutine
              (As_Param_Module,
               Support.Make_Subroutine
                 (Name        => "P",
                  Return_Type => Types.Unit,
                  Parameters  => Params));
            Modules.Append_Subroutine
              (As_Result_Module,
               Support.Make_Subroutine (Name => "R", Return_Type => The_Type));
            Support.Assert_Binary_Round_Trip
              (As_Param_Module, "param " & Types.Value_Type'Image (The_Type));
            Support.Assert_Binary_Round_Trip
              (As_Result_Module,
               "result " & Types.Value_Type'Image (The_Type));

            declare
               As_Local_Module : Modules.Module := Modules.Create ("m");
               Local_Sub       : Subroutines.Subroutine :=
                 Support.Make_Subroutine
                   (Name => "L", Return_Type => Types.Unit);
            begin
               Subroutines.Append_Local (Local_Sub, "v", The_Type);
               Modules.Append_Subroutine (As_Local_Module, Local_Sub);
               Support.Assert_Binary_Round_Trip
                 (As_Local_Module,
                  "local " & Types.Value_Type'Image (The_Type));
            end;
         end;
      end loop;
   end Test_All_Value_Types;

   procedure Test_Body_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Param_I32 : constant Octets := One_Parameter ("a", Code_I32);
      Param_Bad : constant Octets := One_Parameter ("a", Code_Bad);
   begin
      Expect
        (Image
           (Body_Part =>
              Body_Bytes (Signature_Bytes (Return_Code => Code_Bad))),
         Errors.Unknown_Type,
         "body return type");

      Expect
        (Image
           (Index_Sig => Signature_Bytes (Parameters => Param_I32),
            Body_Part =>
              Body_Bytes (Signature_Bytes (Parameters => Param_Bad))),
         Errors.Unknown_Type,
         "body parameter type");

      Expect
        (Image
           (Body_Part => Body_Bytes (Locals => One_Local (1, "x", Code_Bad))),
         Errors.Unknown_Type,
         "local type");

      Expect
        (Image
           (Body_Part => Body_Bytes (Locals => One_Local (2, "x", Code_I32))),
         Errors.Invalid_Local_Index,
         "local index skips one");

      Expect
        (Image
           (Body_Part => Body_Bytes (Locals => One_Local (0, "x", Code_I32))),
         Errors.Invalid_Local_Index,
         "local index zero");

      --  Local lists that stop early.
      Expect
        (Image (Body_Part => Signature_Bytes & U32 (1)),
         Errors.Truncated,
         "local index missing");
      Expect
        (Image (Body_Part => Signature_Bytes & U32 (1) & U32 (1)),
         Errors.Truncated,
         "local name missing");
      Expect
        (Image (Body_Part => Signature_Bytes & U32 (1) & U32 (1) & Str ("x")),
         Errors.Truncated,
         "local type code missing");

      --  A well-formed local decodes.
      declare
         Decoded : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Body_Part =>
                   Body_Bytes (Locals => One_Local (1, "x", Code_I32))),
              "one local");
      begin
         AUnit.Assertions.Assert
           (Types.Length
              (Subroutines.Get_Locals (Modules.Get_Subroutine (Decoded, 1)))
            = 1,
            "local count");
      end;

      --  Native binding fields.
      Expect
        (Image (Body_Part => Body_Bytes (Flags => 4)),
         Errors.Invalid_Native_Binding,
         "native flag without binding");

      --  A binding record with a clear flag word sets the native flag.
      declare
         Decoded : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Body_Part =>
                   Body_Bytes (Native => U08 (1) & Str ("lib") & Str ("fn"))),
              "binding without native flag");
      begin
         AUnit.Assertions.Assert
           (Subroutines.Has_Native
              (Subroutines.Get_Flags (Modules.Get_Subroutine (Decoded, 1))),
            "native flag set by binding");
      end;

      Expect
        (Image
           (Body_Part =>
              Body_Through_Flags & Absent & Absent & U08 (1) & Str ("lib")),
         Errors.Truncated,
         "native function name missing");
      Expect
        (Image (Body_Part => Body_Through_Flags & Absent & Absent & U08 (1)),
         Errors.Truncated,
         "native library missing");

      declare
         Decoded : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Body_Part =>
                   Body_Bytes
                     (Flags  => 4,
                      Native => U08 (1) & Str ("lib") & Str ("fn"))),
              "native binding");
         Native  : constant Subroutines.Native_Binding_Option :=
           Subroutines.Native (Modules.Get_Subroutine (Decoded, 1));
      begin
         AUnit.Assertions.Assert (Native.Present, "native present");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Native.Value.Library) = "lib",
            "native library");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Native.Value.Function_Name)
            = "fn",
            "native function");
      end;

      --  From-dependency field.
      Expect
        (Image (Body_Part => Body_Through_Flags & Absent & U08 (1)),
         Errors.Truncated,
         "from-dependency name missing");
      Expect
        (Image (Body_Part => Body_Through_Flags & Absent),
         Errors.Truncated,
         "from-dependency presence missing");
      Expect
        (Image (Body_Part => Body_Through_Flags & Absent & Absent),
         Errors.Truncated,
         "native presence missing");

      declare
         Decoded : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Body_Part =>
                   Body_Bytes (From_Dependency => U08 (1) & Str ("other"))),
              "from dependency");
         From    : constant Subroutines.From_Dependency_Option :=
           Subroutines.From_Dependency (Modules.Get_Subroutine (Decoded, 1));
      begin
         AUnit.Assertions.Assert (From.Present, "from-dependency present");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (From.Module_Name) = "other",
            "from-dependency name");
      end;
   end Test_Body_Failures;

   procedure Test_Const_And_Call_Encoding (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("m");
      Sink       : constant Subroutines.Subroutine :=
        Support.Make_Subroutine ("Sink", Types.Unit);
      Caller     : Subroutines.Subroutine :=
        Support.Make_Subroutine ("Caller", Types.Unit);
   begin
      Subroutines.Append_Local (Caller, "x", Types.I32);
      Subroutines.Append_Instruction
        (Caller,
         (Operation     => Opcodes.Constant_I32,
          Immediate_I32 => Interfaces.Integer_32'(-42)));
      Subroutines.Append_Instruction
        (Caller, (Operation => Opcodes.Local_Set, Local_Index => 1));
      Subroutines.Append_Instruction
        (Caller, (Operation => Opcodes.Local_Get, Local_Index => 1));
      Subroutines.Append_Instruction
        (Caller, (Operation => Opcodes.Call, Target_Index => 1));
      Modules.Append_Subroutine (The_Module, Sink);
      Modules.Append_Subroutine (The_Module, Caller);
      Support.Assert_Binary_Round_Trip (The_Module, "const call local");

      declare
         Decoded     : constant Modules.Module :=
           Support.Must_Decode
             (Support.Must_Encode (The_Module, "encode"), "decode");
         Body_Instrs : constant Instructions.Instruction_Sequence :=
           Subroutines.Get_Instructions (Modules.Get_Subroutine (Decoded, 2));
      begin
         AUnit.Assertions.Assert
           (Instructions.Length (Body_Instrs) = 4, "body length");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 1).Operation
            = Opcodes.Constant_I32,
            "const opcode");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 1).Immediate_I32
            = Interfaces.Integer_32'(-42),
            "const value");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 2).Operation
            = Opcodes.Local_Set,
            "local.set opcode");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 2).Local_Index = 1,
            "local.set index");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 3).Operation
            = Opcodes.Local_Get,
            "local.get opcode");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 3).Local_Index = 1,
            "local.get index");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 4).Operation = Opcodes.Call,
            "call opcode");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 4).Target_Index = 1,
            "call target");
      end;
   end Test_Const_And_Call_Encoding;

   procedure Test_Decode_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Base_Module : constant Modules.Module := Modules.Create ("m");
      With_Noop   : Modules.Module := Modules.Create ("m");
      Base        : constant Ada.Streams.Stream_Element_Array :=
        Support.Must_Encode (Base_Module, "base");
   begin
      Modules.Append_Subroutine
        (With_Noop,
         Support.Make_Subroutine ("S", Types.Unit, Noop_Count => 1));

      declare
         Noop_Bytes : constant Ada.Streams.Stream_Element_Array :=
           Support.Must_Encode (With_Noop, "noop module");
      begin
         Support.Assert_Decode_Error
           (Support.Replace_Byte (Base, Base'First, 16#00#),
            Errors.Invalid_Magic,
            "bad magic");

         Support.Assert_Decode_Error
           (Support.Replace_Byte (Base, Base'First + 4, 16#02#),
            Errors.Unsupported_Version,
            "version 2.0");

         Support.Assert_Decode_Error
           (Support.Truncate (Base, Base'Length - 1),
            Errors.Truncated,
            "truncated");

         Support.Assert_Decode_Error
           (Support.Append_Byte (Base, 16#FF#),
            Errors.Trailing_Bytes,
            "trailing");

         Support.Assert_Decode_Error
           (Support.Replace_Byte (Noop_Bytes, Noop_Bytes'Last - 1, 16#FF#),
            Errors.Unknown_Opcode,
            "unknown opcode");
      end;

      declare
         Typed : Modules.Module := Modules.Create ("m");
      begin
         Modules.Append_Subroutine
           (Typed, Support.Make_Subroutine ("S", Types.I32));
         declare
            Typed_Bytes : constant Ada.Streams.Stream_Element_Array :=
              Support.Must_Encode (Typed, "typed");
         begin
            --  Return type is 19 bytes before end:
            --  param_count + local_count + flags + origin + from-dep + native
            --  + instr_count.
            Support.Assert_Decode_Error
              (Support.Replace_Byte
                 (Typed_Bytes, Typed_Bytes'Last - 19, 16#FF#),
               Errors.Unknown_Type,
               "unknown type");
         end;
      end;

      --  After magic(4)+version(4)+module-version("0.0.1"=9) lies name length;
      --  first name byte is at +21 for module "m".
      Support.Assert_Decode_Error
        (Support.Replace_Byte (Base, Base'First + 21, 16#FF#),
         Errors.Invalid_Utf_8,
         "invalid utf-8 name");
   end Test_Decode_Failures;

   procedure Test_Empty_Module_File (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("example");
      Path       : constant String := "obj/lir_test_roundtrip.lir";
      Written    : Binary.Write_Result;
      Loaded     : Binary.Decode_Result;
      Deleted    : Boolean;
   begin
      Written := Binary.Write (The_Module, Path);
      case Written.Ok is
         when False =>
            AUnit.Assertions.Assert
              (False,
               "write failed " & Errors.Error_Code'Image (Written.Error));

         when True  =>
            Loaded := Binary.Read (Path);
            case Loaded.Ok is
               when False =>
                  AUnit.Assertions.Assert
                    (False,
                     "read failed " & Errors.Error_Code'Image (Loaded.Error));

               when True  =>
                  declare
                     Before :
                       constant Ada.Strings.Unbounded.Unbounded_String :=
                         Support.Must_To_Text (The_Module, "before");
                     After  :
                       constant Ada.Strings.Unbounded.Unbounded_String :=
                         Support.Must_To_Text (Loaded.Value, "after");
                  begin
                     AUnit.Assertions.Assert
                       (Ada.Strings.Unbounded."=" (Before, After),
                        "file round-trip To_Text");
                  end;
            end case;
      end case;
      GNAT.OS_Lib.Delete_File (Path, Deleted);
   end Test_Empty_Module_File;

   procedure Test_Empty_Module_Memory (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Modules.Create ("example");
   begin
      Support.Assert_Binary_Round_Trip (The_Module, "empty module");
   end Test_Empty_Module_Memory;

   procedure Test_Encode_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Result : constant Binary.Encode_Result :=
        Binary.Encode (Modules.Create (""));
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, "encode of invalid module succeeded");

         when False =>
            AUnit.Assertions.Assert
              (Result.Error = Errors.Empty_Name, "encode error code");
      end case;
   end Test_Encode_Failures;

   procedure Test_File_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Empty_Path : constant String := "obj/lir_test_empty.lir";
      Invalid    : constant Modules.Module := Modules.Create ("");
      Valid      : constant Modules.Module := Modules.Create ("example");
      Descriptor : GNAT.OS_Lib.File_Descriptor;
      Deleted    : Boolean;
   begin
      Assert_Read_Error
        ("obj/lir_test_missing.lir", Errors.Io_Failure, "missing file");

      --  A directory opens but holds no module. Platforms differ: a failed
      --  read gives Io_Failure, a zero reported length gives Truncated.
      declare
         Directory : constant Binary.Decode_Result := Binary.Read (".");
      begin
         case Directory.Ok is
            when True  =>
               AUnit.Assertions.Assert
                 (False, "directory: unexpected read success");

            when False =>
               AUnit.Assertions.Assert
                 (Directory.Error in Errors.Io_Failure | Errors.Truncated,
                  "directory: got "
                  & Errors.Error_Code'Image (Directory.Error));
         end case;
      end;

      Descriptor := GNAT.OS_Lib.Create_File (Empty_Path, GNAT.OS_Lib.Binary);
      GNAT.OS_Lib.Close (Descriptor);
      Assert_Read_Error (Empty_Path, Errors.Truncated, "empty file");
      GNAT.OS_Lib.Delete_File (Empty_Path, Deleted);

      Assert_Write_Error
        (Invalid,
         "obj/lir_test_invalid.lir",
         Errors.Empty_Name,
         "write invalid module");
      Assert_Write_Error
        (Valid,
         "obj/lir_test_no_dir/out.lir",
         Errors.Io_Failure,
         "write into missing directory");

      --  Short write: only meaningful where /dev/full exists.
      if GNAT.OS_Lib.Is_Write_Accessible_File ("/dev/full") then
         Assert_Write_Error
           (Valid, "/dev/full", Errors.Io_Failure, "write to full device");
      end if;
   end Test_File_Failures;

   procedure Test_Hand_Built_Baseline (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Hand_Built : constant Octets := Image;
      Decoded    : constant Modules.Module :=
        Support.Must_Decode (Hand_Built, "hand-built image");
      Encoded    : constant Octets :=
        Support.Must_Encode (Decoded, "re-encode");
      Header_Mod : constant Modules.Module :=
        Support.Must_Decode (Header (Flags => 7) & U32 (0), "module flags");
   begin
      AUnit.Assertions.Assert
        (Encoded = Hand_Built, "hand-built image matches canonical encoding");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Decoded) = 1, "subroutine count");
      AUnit.Assertions.Assert
        (Modules.Flags (Header_Mod) = 7, "module flags value");
   end Test_Hand_Built_Baseline;

   procedure Test_Header_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Good : constant Octets := Image;
   begin
      for Offset in 0 .. 3 loop
         Expect
           (Support.Replace_Byte
              (Good,
               Good'First + Ada.Streams.Stream_Element_Offset (Offset),
               16#7F#),
            Errors.Invalid_Magic,
            "magic byte" & Natural'Image (Offset));
      end loop;

      Expect
        (Support.Replace_Byte (Good, Good'First + 4, 16#00#),
         Errors.Unsupported_Version,
         "major low");
      Expect
        (Support.Replace_Byte (Good, Good'First + 5, 16#01#),
         Errors.Unsupported_Version,
         "major high");
      Expect
        (Support.Replace_Byte (Good, Good'First + 6, 16#01#),
         Errors.Unsupported_Version,
         "minor low");
      Expect
        (Support.Replace_Byte (Good, Good'First + 7, 16#01#),
         Errors.Unsupported_Version,
         "minor high");

      for Keep in Ada.Streams.Stream_Element_Offset range 0 .. 8 loop
         Expect
           (Support.Truncate (Good, Keep),
            Errors.Truncated,
            "header prefix" & Ada.Streams.Stream_Element_Offset'Image (Keep));
      end loop;

      Expect
        (Magic_And_Version & U32 (60),
         Errors.Truncated,
         "module version string");
      Expect
        (Magic_And_Version & Str ("0.0.1") & U32 (60),
         Errors.Truncated,
         "module name string");
      Expect
        (Magic_And_Version & Str ("0.0.1") & Str ("m") & U16 (0),
         Errors.Truncated,
         "module flags");
      Expect
        (Magic_And_Version & Str ("0.0.1") & Str ("m") & U32 (0) & U16 (0),
         Errors.Truncated,
         "dependency count");

      Expect
        (Header (Dependencies => U32 (1) & Str ("dep"), Origin => Nothing),
         Errors.Truncated,
         "dependency version missing");
      Expect
        (Header (Dependencies => U32 (1) & U32 (60), Origin => Nothing),
         Errors.Truncated,
         "dependency name string");
      Expect
        (Header (Origin => Nothing),
         Errors.Truncated,
         "module origin presence missing");
   end Test_Header_Failures;

   procedure Test_Instruction_Immediates (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      declare
         Decoded     : constant Modules.Module :=
           Support.Must_Decode
             (With_Instructions
                (U32 (6)
                 & Op (Opcodes.Constant_I32, 16#8000_0000#)
                 & Op (Opcodes.Constant_I32, 16#7FFF_FFFF#)
                 & Op (Opcodes.Call, 1)
                 & Op (Opcodes.Local_Get, 1)
                 & Op (Opcodes.Local_Set, 1)
                 & Noop),
              "immediates");
         Body_Instrs : constant Instructions.Instruction_Sequence :=
           Subroutines.Get_Instructions (Modules.Get_Subroutine (Decoded, 1));
      begin
         AUnit.Assertions.Assert
           (Instructions.Length (Body_Instrs) = 6, "instruction count");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 1).Immediate_I32
            = Interfaces.Integer_32'First,
            "minimum immediate");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 2).Immediate_I32
            = Interfaces.Integer_32'Last,
            "maximum immediate");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 3).Target_Index = 1,
            "call target");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 4).Local_Index = 1,
            "local.get index");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 5).Local_Index = 1,
            "local.set index");
         AUnit.Assertions.Assert
           (Instructions.Element (Body_Instrs, 6).Operation
            = Opcodes.No_Operation,
            "noop");
      end;

      Expect
        (With_Instructions (One_Instruction (Op (Opcodes.Call, 0))),
         Errors.Invalid_Call_Target,
         "call target zero");
      Expect
        (With_Instructions (One_Instruction (Op (Opcodes.Call, 2))),
         Errors.Invalid_Call_Target,
         "call target past end");
      Expect
        (With_Instructions (One_Instruction (Op (Opcodes.Local_Get, 0))),
         Errors.Invalid_Local_Index,
         "local.get zero");
      Expect
        (With_Instructions (One_Instruction (Op (Opcodes.Local_Get, 2))),
         Errors.Invalid_Local_Index,
         "local.get past slots");
      Expect
        (With_Instructions (One_Instruction (Op (Opcodes.Local_Set, 0))),
         Errors.Invalid_Local_Index,
         "local.set zero");
      Expect
        (With_Instructions (One_Instruction (Op (Opcodes.Local_Set, 2))),
         Errors.Invalid_Local_Index,
         "local.set past slots");

      Expect
        (With_Instructions (One_Instruction (U16 (5))),
         Errors.Unknown_Opcode,
         "opcode just past the set");
      Expect
        (With_Instructions (One_Instruction (U16 (16#FFFF#))),
         Errors.Unknown_Opcode,
         "opcode all ones");

      Expect
        (With_Instructions (U32 (1)), Errors.Truncated, "instruction missing");
      Expect
        (With_Instructions (U32 (2) & Noop),
         Errors.Truncated,
         "second instruction missing");
      Expect
        (With_Instructions (U32 (1) & U08 (0)),
         Errors.Truncated,
         "opcode word cut");
      Expect
        (With_Instructions
           (U32 (1)
            & U16 (Natural (Opcodes.To_Word (Opcodes.Constant_I32)))
            & U16 (0)),
         Errors.Truncated,
         "immediate cut");
      Expect
        (With_Instructions (Absent),
         Errors.Truncated,
         "instruction count cut");
   end Test_Instruction_Immediates;

   procedure Test_Magic_And_Version (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Bytes : constant Ada.Streams.Stream_Element_Array :=
        Support.Must_Encode (Modules.Create ("m"), "magic");
   begin
      Support.Assert_Byte_Count (Bytes, Natural (Bytes'Length), "non-empty");
      AUnit.Assertions.Assert (Bytes'Length >= 8, "header length");
      Support.Assert_Byte (Bytes, Bytes'First + 0, 16#4C#, "L");
      Support.Assert_Byte (Bytes, Bytes'First + 1, 16#49#, "I");
      Support.Assert_Byte (Bytes, Bytes'First + 2, 16#52#, "R");
      Support.Assert_Byte (Bytes, Bytes'First + 3, 16#00#, "NUL");
      Support.Assert_Byte (Bytes, Bytes'First + 4, 16#01#, "major low");
      Support.Assert_Byte (Bytes, Bytes'First + 5, 16#00#, "major high");
      Support.Assert_Byte (Bytes, Bytes'First + 6, 16#00#, "minor low");
      Support.Assert_Byte (Bytes, Bytes'First + 7, 16#00#, "minor high");
   end Test_Magic_And_Version;

   procedure Test_Name_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      for Variant in 1 .. 2 loop
         declare
            Text : constant String :=
              (if Variant = 1 then Bad_Utf_Ff else Bad_Utf_Lead);
         begin
            Expect
              (Image (Prefix => Header (Name => Text)),
               Errors.Invalid_Utf_8,
               "module name");
            Expect
              (Image (Prefix => Header (Version => Text)),
               Errors.Invalid_Utf_8,
               "module version");
            Expect
              (Image
                 (Prefix =>
                    Header
                      (Dependencies => U32 (1) & Str (Text) & Str ("1.0"))),
               Errors.Invalid_Utf_8,
               "dependency name");
            Expect
              (Image
                 (Prefix =>
                    Header
                      (Dependencies => U32 (1) & Str ("dep") & Str (Text))),
               Errors.Invalid_Utf_8,
               "dependency version");
            Expect
              (Image
                 (Index_Sig => Signature_Bytes (Name => Text),
                  Body_Part => Body_Bytes (Signature_Bytes (Name => Text))),
               Errors.Invalid_Utf_8,
               "subroutine name");
            Expect
              (Image
                 (Index_Sig =>
                    Signature_Bytes
                      (Parameters => One_Parameter (Text, Code_I32)),
                  Body_Part =>
                    Body_Bytes
                      (Signature_Bytes
                         (Parameters => One_Parameter (Text, Code_I32)))),
               Errors.Invalid_Utf_8,
               "parameter name");
            Expect
              (Image
                 (Body_Part =>
                    Body_Bytes (Locals => One_Local (1, Text, Code_I32))),
               Errors.Invalid_Utf_8,
               "local name");
            Expect
              (Image
                 (Body_Part =>
                    Body_Bytes (From_Dependency => U08 (1) & Str (Text))),
               Errors.Invalid_Utf_8,
               "from-dependency name");
         end;
      end loop;

      Expect
        (Image (Prefix => Header (Name => "")),
         Errors.Empty_Name,
         "empty module name");
      Expect
        (Image
           (Prefix =>
              Header (Dependencies => U32 (1) & Str ("m") & Str ("1.0"))),
         Errors.Self_Dependency,
         "self dependency");
      Expect
        (Image
           (Prefix =>
              Header
                (Dependencies =>
                   U32 (2)
                   & Str ("dep")
                   & Str ("1.0")
                   & Str ("dep")
                   & Str ("2.0"))),
         Errors.Duplicate_Name,
         "duplicate dependency");
   end Test_Name_Failures;

   procedure Test_Noop_Encoding (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("m");
   begin
      AUnit.Assertions.Assert
        (Opcodes.Encoded_Length (Opcodes.No_Operation) = 2, "Encoded_Length");
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine ("S", Types.Unit, Noop_Count => 1));
      declare
         Bytes : constant Ada.Streams.Stream_Element_Array :=
           Support.Must_Encode (The_Module, "noop");
      begin
         Support.Assert_Byte (Bytes, Bytes'Last - 1, 16#00#, "noop low");
         Support.Assert_Byte (Bytes, Bytes'Last, 16#00#, "noop high");
      end;
   end Test_Noop_Encoding;

   procedure Test_Optional_Sections_Round_Trip (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : constant Modules.Module := Make_Rich_Module;
   begin
      Support.Assert_Binary_Round_Trip (The_Module, "optional sections");

      declare
         Decoded     : constant Modules.Module :=
           Support.Must_Decode
             (Support.Must_Encode (The_Module, "encode"), "decode");
         Imported    : constant Subroutines.Subroutine :=
           Modules.Get_Subroutine (Decoded, 1);
         Printer     : constant Subroutines.Subroutine :=
           Modules.Get_Subroutine (Decoded, 2);
         From        : constant Subroutines.From_Dependency_Option :=
           Subroutines.From_Dependency (Imported);
         Native      : constant Subroutines.Native_Binding_Option :=
           Subroutines.Native (Printer);
         Sub_Origin  : constant Subroutines.Origin_Option :=
           Subroutines.Origin (Imported);
         Mod_Origin  : constant Modules.Origin_Option :=
           Modules.Origin (Decoded);
         Body_Instrs : constant Instructions.Instruction_Sequence :=
           Subroutines.Get_Instructions (Imported);
      begin
         AUnit.Assertions.Assert
           (Modules.Dependency_Count (Decoded) = 2, "dependency count");
         AUnit.Assertions.Assert
           (Modules.Dependency_Name (Decoded, 1) = "dep_a",
            "first dependency");
         AUnit.Assertions.Assert
           (Modules.Dependency_Version (Decoded, 1) = "1.2.3",
            "first dependency version");
         AUnit.Assertions.Assert
           (Modules.Dependency_Name (Decoded, 2) = "dep_b",
            "second dependency");
         AUnit.Assertions.Assert (Modules.Flags (Decoded) = 5, "module flags");
         AUnit.Assertions.Assert (Mod_Origin.Present, "module origin");
         AUnit.Assertions.Assert (Sub_Origin.Present, "subroutine origin");
         AUnit.Assertions.Assert (From.Present, "from-dependency present");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (From.Module_Name) = "dep_a",
            "from-dependency name");
         AUnit.Assertions.Assert (Native.Present, "native present");
         AUnit.Assertions.Assert
           (not Subroutines.From_Dependency (Printer).Present,
            "printer has no from-dependency");
         AUnit.Assertions.Assert
           (Instructions.Length (Body_Instrs) = 5, "instruction count");
         AUnit.Assertions.Assert
           (Types.Length (Subroutines.Get_Locals (Imported)) = 2,
            "local count");
      end;
   end Test_Optional_Sections_Round_Trip;

   procedure Test_Origin_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Max_Position : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Positive'Last);
      Max_Span     : constant Octets :=
        Position (Max_Position, Max_Position, Max_Position) & Good_Position;
   begin
      for Kind in 0 .. 7 loop
         declare
            Bad   : constant Octets := Bad_Span (Kind);
            Label : constant String := Natural'Image (Kind);
         begin
            Expect
              (Image
                 (Prefix =>
                    Header
                      (Origin => Origin_Present ("f.love", Name_Span => Bad))),
               Errors.Truncated,
               "module name span" & Label);
            Expect
              (Image
                 (Prefix =>
                    Header
                      (Origin => Origin_Present ("f.love", Unit_Span => Bad))),
               Errors.Truncated,
               "module unit span" & Label);
            Expect
              (Image
                 (Body_Part =>
                    Body_Bytes
                      (Origin => Origin_Present ("f.love", Name_Span => Bad))),
               Errors.Truncated,
               "subroutine name span" & Label);
            Expect
              (Image
                 (Body_Part =>
                    Body_Bytes
                      (Origin => Origin_Present ("f.love", Unit_Span => Bad))),
               Errors.Truncated,
               "subroutine span" & Label);
         end;
      end loop;

      --  Positive'Last in every position field is still accepted.
      declare
         Module_Decoded : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Prefix =>
                   Header
                     (Origin =>
                        Origin_Present ("f.love", Name_Span => Max_Span))),
              "max module span");
         Sub_Decoded    : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Body_Part =>
                   Body_Bytes
                     (Origin =>
                        Origin_Present ("f.love", Unit_Span => Max_Span))),
              "max subroutine span");
         Module_Origin  : constant Modules.Origin_Option :=
           Modules.Origin (Module_Decoded);
         Sub_Origin     : constant Subroutines.Origin_Option :=
           Subroutines.Origin (Modules.Get_Subroutine (Sub_Decoded, 1));
      begin
         AUnit.Assertions.Assert
           (Module_Origin.Present
            and then Module_Origin.Value.Name_Span.First.Byte_Index
                     = Positive'Last,
            "module max byte index");
         AUnit.Assertions.Assert
           (Sub_Origin.Present
            and then Sub_Origin.Value.Span.First.Column = Positive'Last,
            "subroutine max column");
      end;

      --  Empty filename means an absent Filename_Option.
      declare
         Decoded : constant Modules.Module :=
           Support.Must_Decode
             (Image
                (Prefix    => Header (Origin => Origin_Present ("")),
                 Body_Part => Body_Bytes (Origin => Origin_Present (""))),
              "empty filenames");
      begin
         AUnit.Assertions.Assert
           (not Modules.Origin (Decoded).Value.Filename.Present,
            "module filename absent");
         AUnit.Assertions.Assert
           (not Subroutines.Origin (Modules.Get_Subroutine (Decoded, 1))
                  .Value
                  .Filename
                  .Present,
            "subroutine filename absent");
      end;

      --  Origin strings and spans that stop early.
      Expect
        (Header (Origin => U08 (1) & U32 (60)),
         Errors.Truncated,
         "module filename string");
      Expect
        (Header (Origin => U08 (1) & Str ("f.love")),
         Errors.Truncated,
         "module name span missing");
      Expect
        (Header (Origin => U08 (1) & Str ("f.love") & Good_Span),
         Errors.Truncated,
         "module unit span missing");
      Expect
        (Image (Body_Part => Body_Through_Flags & U08 (1) & U32 (60)),
         Errors.Truncated,
         "subroutine filename string");
      Expect
        (Image (Body_Part => Body_Through_Flags & U08 (1) & Str ("f.love")),
         Errors.Truncated,
         "subroutine name span missing");
      Expect
        (Image
           (Body_Part =>
              Body_Through_Flags & U08 (1) & Str ("f.love") & Good_Span),
         Errors.Truncated,
         "subroutine span missing");
   end Test_Origin_Failures;

   procedure Test_Preamble_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Param_I32 : constant Octets := One_Parameter ("a", Code_I32);
   begin
      Expect
        (Image (Index_Sig => Signature_Bytes (Return_Code => Code_Bad)),
         Errors.Unknown_Type,
         "index return type");
      Expect
        (Image
           (Index_Sig =>
              Signature_Bytes (Parameters => One_Parameter ("a", Code_Bad))),
         Errors.Unknown_Type,
         "index parameter type");

      --  Preamble rows that stop early.
      Expect
        (Header & U32 (1), Errors.Truncated, "preamble signature missing");
      Expect
        (Header & U32 (1) & U32 (60), Errors.Truncated, "index name string");
      Expect
        (Header & U32 (1) & Str ("S"),
         Errors.Truncated,
         "index return code missing");
      Expect
        (Header & U32 (1) & Str ("S") & U08 (0),
         Errors.Truncated,
         "index parameter count missing");
      Expect
        (Header & U32 (1) & Str ("S") & U08 (0) & U32 (1),
         Errors.Truncated,
         "index parameter name missing");
      Expect
        (Header & U32 (1) & Str ("S") & U08 (0) & U32 (1) & Str ("a"),
         Errors.Truncated,
         "index parameter type missing");
      Expect
        (Header & U32 (1) & Signature_Bytes & U16 (0),
         Errors.Truncated,
         "index offset cut");
      Expect (Header & U16 (0), Errors.Truncated, "subroutine count cut");

      --  Body offsets that disagree with the file layout.
      Expect
        (Image (Offset_Delta => 1),
         Errors.Invalid_Offset,
         "offset one past body");
      Expect
        (Image (Offset_Delta => -1),
         Errors.Invalid_Offset,
         "offset one before body");
      Expect
        (Image (Offset_Delta => 1000),
         Errors.Invalid_Offset,
         "offset far past end");

      --  Preamble signature disagrees with the body signature.
      Expect
        (Image (Body_Part => Body_Bytes (Signature_Bytes (Name => "T"))),
         Errors.Invalid_Offset,
         "name differs");
      Expect
        (Image
           (Body_Part =>
              Body_Bytes (Signature_Bytes (Return_Code => Code_I32))),
         Errors.Invalid_Offset,
         "return type differs");
      Expect
        (Image
           (Body_Part =>
              Body_Bytes (Signature_Bytes (Parameters => Param_I32))),
         Errors.Invalid_Offset,
         "parameter count differs");
      Expect
        (Image
           (Index_Sig => Signature_Bytes (Parameters => Param_I32),
            Body_Part =>
              Body_Bytes
                (Signature_Bytes
                   (Parameters => One_Parameter ("b", Code_I32)))),
         Errors.Invalid_Offset,
         "parameter name differs");
      Expect
        (Image
           (Index_Sig => Signature_Bytes (Parameters => Param_I32),
            Body_Part =>
              Body_Bytes
                (Signature_Bytes
                   (Parameters => One_Parameter ("a", Code_F64)))),
         Errors.Invalid_Offset,
         "parameter type differs");

      --  Body signature that stops early.
      Expect
        (Image (Body_Part => Str ("S")),
         Errors.Truncated,
         "body return code missing");
      Expect
        (Image (Body_Part => Str ("S") & U08 (0)),
         Errors.Truncated,
         "body parameter count missing");
      Expect
        (Image (Body_Part => Str ("S") & U08 (0) & U32 (1)),
         Errors.Truncated,
         "body parameter missing");
      Expect
        (Image (Body_Part => Str ("S") & U08 (0) & U32 (1) & Str ("a")),
         Errors.Truncated,
         "body parameter type missing");
      Expect
        (Image (Body_Part => Signature_Bytes),
         Errors.Truncated,
         "body locals missing");
      Expect
        (Image (Body_Part => Signature_Bytes & U32 (0)),
         Errors.Truncated,
         "body flags missing");
      Expect
        (Image (Body_Part => Signature_Bytes & U32 (0) & U32 (0)),
         Errors.Truncated,
         "body origin missing");
   end Test_Preamble_Failures;

   procedure Test_Presence_Failures (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      Expect
        (Image (Prefix => Header (Origin => U08 (2))),
         Errors.Invalid_Presence,
         "module origin presence");
      Expect
        (Image (Prefix => Header (Origin => U08 (16#FF#))),
         Errors.Invalid_Presence,
         "module origin presence ff");
      Expect
        (Image (Body_Part => Body_Bytes (Origin => U08 (2))),
         Errors.Invalid_Presence,
         "subroutine origin presence");
      Expect
        (Image (Body_Part => Body_Bytes (From_Dependency => U08 (2))),
         Errors.Invalid_Presence,
         "from-dependency presence");
      Expect
        (Image (Body_Part => Body_Bytes (Native => U08 (2))),
         Errors.Invalid_Presence,
         "native presence");
   end Test_Presence_Failures;

   procedure Test_Subroutines_And_Flags (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Module : Modules.Module := Modules.Create ("mod");
      Params     : Types.Parameter_Sequence := Types.Empty_Sequence;
   begin
      Modules.Append_Dependency (The_Module, "other");
      Types.Append (Params, "a", Types.I8);
      Types.Append (Params, "b", Types.U8);
      Types.Append (Params, "c", Types.F32);

      Modules.Append_Subroutine
        (The_Module, Support.Make_Subroutine ("Empty", Types.Unit));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine ("One", Types.I32, Noop_Count => 1));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine ("Many", Types.Unit, Noop_Count => 3));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine
           ("Exp",
            Types.Unit,
            Flags      => Subroutines.Export_Flag,
            Noop_Count => 0));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine
           ("Entry",
            Types.Unit,
            Flags      => Subroutines.Entrypoint_Flag,
            Noop_Count => 0));
      Modules.Append_Subroutine
        (The_Module,
         Support.Make_Subroutine
           ("Both",
            Types.Unit,
            Parameters => Params,
            Flags      =>
              Subroutines.Export_Flag or Subroutines.Entrypoint_Flag,
            Noop_Count => 1));

      --  Duplicate entrypoint would fail Validate; replace Entry with non-entry
      --  before the Both that also has entrypoint - Both alone is one entrypoint.
      --  Rebuild without two entrypoints:
      declare
         Clean : Modules.Module := Modules.Create ("mod");
      begin
         Modules.Append_Dependency (Clean, "other");
         Modules.Append_Subroutine
           (Clean, Support.Make_Subroutine ("Empty", Types.Unit));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine ("One", Types.I32, Noop_Count => 1));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine ("Many", Types.Unit, Noop_Count => 3));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine
              ("Exp", Types.Unit, Flags => Subroutines.Export_Flag));
         Modules.Append_Subroutine
           (Clean,
            Support.Make_Subroutine
              ("Both",
               Types.Unit,
               Parameters => Params,
               Flags      =>
                 Subroutines.Export_Flag or Subroutines.Entrypoint_Flag,
               Noop_Count => 1));
         Support.Assert_Binary_Round_Trip (Clean, "subroutines and flags");
      end;

      declare
         Native_Module  : Modules.Module := Modules.Create ("io");
         Print_Sub      : Subroutines.Subroutine :=
           Support.Make_Subroutine
             ("print",
              Types.Unit,
              Parameters => Params,
              Flags      => Subroutines.Export_Flag);
         Decoded        : Modules.Module;
         Decoded_Sub    : Subroutines.Subroutine;
         Decoded_Native : Subroutines.Native_Binding_Option;
      begin
         Subroutines.Set_Native_Binding
           (Print_Sub, "wasi", "native-print-integer");
         Modules.Append_Subroutine (Native_Module, Print_Sub);
         Support.Assert_Binary_Round_Trip (Native_Module, "native binding");
         Decoded :=
           Support.Must_Decode
             (Support.Must_Encode (Native_Module, "native encode"),
              "native decode");
         Decoded_Sub := Modules.Get_Subroutine (Decoded, 1);
         Decoded_Native := Subroutines.Native (Decoded_Sub);
         AUnit.Assertions.Assert
           (Subroutines.Has_Native (Subroutines.Get_Flags (Decoded_Sub)),
            "native flag");
         AUnit.Assertions.Assert (Decoded_Native.Present, "native present");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Decoded_Native.Value.Library)
            = "wasi",
            "native library");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String
              (Decoded_Native.Value.Function_Name)
            = "native-print-integer",
            "native function");
         AUnit.Assertions.Assert
           (Instructions.Length (Subroutines.Get_Instructions (Decoded_Sub))
            = 0,
            "native empty body");
      end;
   end Test_Subroutines_And_Flags;

   procedure Test_Truncation_Sweep (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Full : constant Octets :=
        Support.Must_Encode (Make_Rich_Module, "rich module");
   begin
      --  Every proper prefix of a complete image is a truncated image.
      for Keep in 0 .. Full'Length - 1 loop
         Expect
           (Support.Truncate (Full, Ada.Streams.Stream_Element_Offset (Keep)),
            Errors.Truncated,
            "prefix" & Keep'Image);
      end loop;
   end Test_Truncation_Sweep;

   procedure Test_Unicode_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe       : constant String :=
        "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Rocket     : constant String :=
        Support.To_Utf_8 (Wide_Wide_Character'Val (16#1F680#));
      The_Module : Modules.Module := Modules.Create (Cafe);
   begin
      Modules.Append_Subroutine
        (The_Module, Support.Make_Subroutine (Rocket, Types.Unit));
      Support.Assert_Binary_Round_Trip (The_Module, "unicode names");
   end Test_Unicode_Names;

   function U08 (Value : Natural) return Octets is
   begin
      return [1 => Ada.Streams.Stream_Element (Value)];
   end U08;

   function U16 (Value : Natural) return Octets is
   begin
      return
        [1 => Ada.Streams.Stream_Element (Value mod 256),
         2 => Ada.Streams.Stream_Element (Value / 256)];
   end U16;

   function U32 (Value : Interfaces.Unsigned_32) return Octets is
      Result : Octets (1 .. 4);
   begin
      for Index in Result'Range loop
         Result (Index) :=
           Ada.Streams.Stream_Element
             (Interfaces.Shift_Right (Value, 8 * Natural (Index - 1))
              and 16#FF#);
      end loop;
      return Result;
   end U32;

   function With_Instructions (Instructions : Octets) return Octets is
      Self_Param : constant Octets := One_Parameter ("a", Code_I32);
   begin
      return
        Image
          (Index_Sig => Signature_Bytes (Parameters => Self_Param),
           Body_Part =>
             Body_Bytes
               (Signature_Bytes (Parameters => Self_Param),
                Instructions => Instructions));
   end With_Instructions;

end Lovelace.Lir.Tests.Binary_Format;
