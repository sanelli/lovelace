with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Interfaces;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Ir_Generator;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Types;
with Lovelace.Compiler.Unit_Graph;
with Lovelace.Lir.Instructions;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

package body Lovelace.Compiler.Tests.Ir_Generator is

   package Source renames Lovelace.Common.Source;
   package Ir_Gen renames Lovelace.Compiler.Ir_Generator;
   package Modules renames Lovelace.Lir.Modules;
   package Subroutines renames Lovelace.Lir.Subroutines;

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_32;
   use type Ir_Gen.Ir_Generator_Error_Code;
   use type Lovelace.Lir.Opcodes.Opcode;
   use type Lovelace.Lir.Types.Value_Type;
   use type Source.Source_Span;

   procedure Assert_Entrypoint_Lir
     (Lir_Module    : Modules.Module;
      Expected_Name : String;
      Ast_Module    : Ast.Module;
      Message       : String);
   --  Assert LIR module/subroutine shape and origins match Expected_Name and Ast_Module.

   procedure Assert_Entrypoint_Lir
     (Lir_Module    : Modules.Module;
      Expected_Name : String;
      Ast_Module    : Ast.Module;
      Message       : String)
   is
      Lir_Subroutine : constant Subroutines.Subroutine :=
        Modules.Get_Subroutine (Lir_Module, 1);
      The_Signature  : constant Subroutines.Signature :=
        Subroutines.Get_Signature (Lir_Subroutine);
      Flags          : constant Subroutines.Subroutine_Flags :=
        Subroutines.Get_Flags (Lir_Subroutine);
      Instructions   :
        constant Lovelace.Lir.Instructions.Instruction_Sequence :=
          Subroutines.Get_Instructions (Lir_Subroutine);
      Module_Origin  : constant Modules.Origin_Option :=
        Modules.Origin (Lir_Module);
      Sub_Origin     : constant Subroutines.Origin_Option :=
        Subroutines.Origin (Lir_Subroutine);
      Ast_Subroutine : constant Ast.Subroutine :=
        Ast.Get_Subroutine (Ast_Module, 1);
   begin
      AUnit.Assertions.Assert
        (Modules.Name (Lir_Module) = Expected_Name, Message & ": module name");
      AUnit.Assertions.Assert
        (Modules.Dependency_Count (Lir_Module) = 0,
         Message & ": no dependencies");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Lir_Module) = 1,
         Message & ": one subroutine");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (The_Signature.Name) = Expected_Name,
         Message & ": subroutine name");
      AUnit.Assertions.Assert
        (The_Signature.Return_Type = Lovelace.Lir.Types.Unit,
         Message & ": return Unit");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Length (The_Signature.Parameters) = 0,
         Message & ": no params");
      AUnit.Assertions.Assert
        (Subroutines.Has_Export (Flags), Message & ": export");
      AUnit.Assertions.Assert
        (Subroutines.Has_Entrypoint (Flags), Message & ": entrypoint");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Length (Instructions) = 0,
         Message & ": empty instructions");

      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert
              (False, Message & ": module origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Module_Origin.Value.Name_Span = Ast.Name_Span (Ast_Module),
               Message & ": module name span");
            AUnit.Assertions.Assert
              (Module_Origin.Value.Span = Ast.Span (Ast_Module),
               Message & ": module unit span");
            AUnit.Assertions.Assert
              (Source.Same_Storage
                 (Module_Origin.Value.Filename, Ast.Filename (Ast_Module)),
               Message & ": module filename");
      end case;

      case Sub_Origin.Present is
         when False =>
            AUnit.Assertions.Assert
              (False, Message & ": subroutine origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Sub_Origin.Value.Name_Span = Ast.Name_Span (Ast_Subroutine),
               Message & ": subroutine name span");
            AUnit.Assertions.Assert
              (Source.Same_Storage
                 (Sub_Origin.Value.Filename, Ast.Filename (Ast_Subroutine)),
               Message & ": subroutine filename");
      end case;
   end Assert_Entrypoint_Lir;

   procedure Test_Canonical_Multiline (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "program Hello;" & ASCII.LF & "begin" & ASCII.LF & "end.";
      Ast_Module  : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "canonical");
      Lir_Module  : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "canonical");
   begin
      Assert_Entrypoint_Lir (Lir_Module, "Hello", Ast_Module, "canonical");
   end Test_Canonical_Multiline;

   procedure Test_Cross_Module_Calls (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lib_Ast    : constant Ast.Module :=
        Support.Must_Parse
          ("module Lib; export procedure Sink(Value : integer); begin end; end.",
           "lib");
      Hidden_Ast : constant Ast.Module :=
        Support.Must_Parse
          ("module Lib; procedure Sink(Value : integer); begin end; end.",
           "hidden lib");
      Caller_Ast : constant Ast.Module :=
        Support.Must_Parse
          ("import Lib; program Caller; begin Lib.Sink(7); end.", "caller");
      No_Imp_Ast : constant Ast.Module :=
        Support.Must_Parse
          ("program Caller; begin Lib.Sink(7); end.", "no import");
      Units      : Unit_Graph.Compilation_Set;
      Hidden     : Unit_Graph.Compilation_Set;
      No_Import  : Unit_Graph.Compilation_Set;
      Ok_Result  : Ir_Gen.Generate_Result;
      Hidden_Err : Ir_Gen.Generate_Result;
      No_Imp_Err : Ir_Gen.Generate_Result;
   begin
      Units.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Caller_Ast,
            Source_Path =>
              Ada.Strings.Unbounded.To_Unbounded_String ("Caller.love"),
            Source_Text => Ada.Strings.Unbounded.To_Unbounded_String ("")));
      Units.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Lib_Ast,
            Source_Path =>
              Ada.Strings.Unbounded.To_Unbounded_String ("Lib.love"),
            Source_Text => Ada.Strings.Unbounded.To_Unbounded_String ("")));
      Ok_Result := Ir_Gen.Generate (Units);
      AUnit.Assertions.Assert (Ok_Result.Ok, "cross ok");
      declare
         Caller_Body :
           constant Lovelace.Lir.Instructions.Instruction_Sequence :=
             Subroutines.Get_Instructions
               (Modules.Get_Subroutine (Ok_Result.The_Module, 1));
      begin
         AUnit.Assertions.Assert
           (Modules.Subroutine_Count (Ok_Result.The_Module) = 2,
            "flattened count");
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String
              (Subroutines.Get_Signature
                 (Modules.Get_Subroutine (Ok_Result.The_Module, 2))
                 .Name)
            = "Lib.Sink",
            "mangled name");
         AUnit.Assertions.Assert
           (Lovelace.Lir.Instructions.Element (Caller_Body, 2).Target_Index
            = 2,
            "call Lib.Sink");
      end;

      Hidden.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Caller_Ast,
            Source_Path => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text => Ada.Strings.Unbounded.Null_Unbounded_String));
      Hidden.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Hidden_Ast,
            Source_Path => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text => Ada.Strings.Unbounded.Null_Unbounded_String));
      Hidden_Err := Ir_Gen.Generate (Hidden);
      AUnit.Assertions.Assert (not Hidden_Err.Ok, "hidden fails");
      AUnit.Assertions.Assert
        (Hidden_Err.Error.Code = Ir_Gen.Not_Exported, "not exported");

      No_Import.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => No_Imp_Ast,
            Source_Path => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text => Ada.Strings.Unbounded.Null_Unbounded_String));
      No_Import.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Lib_Ast,
            Source_Path => Ada.Strings.Unbounded.Null_Unbounded_String,
            Source_Text => Ada.Strings.Unbounded.Null_Unbounded_String));
      No_Imp_Err := Ir_Gen.Generate (No_Import);
      AUnit.Assertions.Assert (not No_Imp_Err.Ok, "no import fails");
      AUnit.Assertions.Assert
        (No_Imp_Err.Error.Code = Ir_Gen.Call_Without_Import,
         "call without import");
   end Test_Cross_Module_Calls;

   procedure Test_Dotted_Module_Name (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text   : constant String := "module Foo.Bar; end.";
      Ast_Module    : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "dotted module");
      Lir_Module    : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "dotted module");
      Module_Origin : constant Modules.Origin_Option :=
        Modules.Origin (Lir_Module);
   begin
      AUnit.Assertions.Assert
        (Modules.Name (Lir_Module) = "Foo.Bar", "dotted module: name");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Lir_Module) = 0,
         "dotted module: no subroutines");
      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (False, "dotted module: origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Module_Origin.Value.Name_Span = Ast.Name_Span (Ast_Module),
               "dotted module: name span");
            AUnit.Assertions.Assert
              (Module_Origin.Value.Span = Ast.Span (Ast_Module),
               "dotted module: unit span");
      end case;
   end Test_Dotted_Module_Name;

   procedure Test_Empty_Module (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text   : constant String := "module Empty; end.";
      Ast_Module    : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "empty module");
      Lir_Module    : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "empty module");
      Module_Origin : constant Modules.Origin_Option :=
        Modules.Origin (Lir_Module);
   begin
      AUnit.Assertions.Assert
        (Modules.Name (Lir_Module) = "Empty", "empty module: name");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Lir_Module) = 0,
         "empty module: no subroutines");
      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (False, "empty module: origin present");

         when True  =>
            AUnit.Assertions.Assert
              (Module_Origin.Value.Name_Span = Ast.Name_Span (Ast_Module),
               "empty module: name span");
      end case;
   end Test_Empty_Module;

   procedure Test_Export_Only_Flags (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Name_Span       : constant Source.Source_Span :=
        (First => (Byte_Index => 9, Line => 1, Column => 9),
         Last  => (Byte_Index => 11, Line => 1, Column => 11));
      Unit_Span       : constant Source.Source_Span :=
        (First => (Byte_Index => 1, Line => 1, Column => 1),
         Last  => (Byte_Index => 20, Line => 1, Column => 20));
      Ast_Sub         : constant Ast.Subroutine :=
        Ast.Create_Subroutine
          (Name        => "Lib",
           Module_Name => "Lib",
           Name_Span   => Name_Span,
           Filename    => Source.Absent_Filename,
           Flags       => Ast.Export_Flag,
           Return_Type => Types.Unit_Type,
           Parameters  => Ast.Empty_Parameter_Sequence,
           The_Body    => Ast.Empty_Block,
           Native      => (Present => False));
      Ast_Subroutines : Ast.Subroutine_Sequence :=
        Ast.Empty_Subroutine_Sequence;
      Ast_Module      : Ast.Module;
      Lir_Module      : Modules.Module;
      Lir_Sub         : Subroutines.Subroutine;
      Flags           : Subroutines.Subroutine_Flags;
   begin
      Ast.Append (Sequence => Ast_Subroutines, The_Subroutine => Ast_Sub);
      Ast_Module :=
        Ast.Create_Module
          (Name        => "Lib",
           Name_Span   => Name_Span,
           Filename    => Source.Absent_Filename,
           Span        => Unit_Span,
           Kind        => Ast.Program_Unit,
           Imports     => Ast.Empty_Import_Sequence,
           Subroutines => Ast_Subroutines);
      Lir_Module := Support.Must_Generate (Ast_Module, "export only");
      Lir_Sub := Modules.Get_Subroutine (Lir_Module, 1);
      Flags := Subroutines.Get_Flags (Lir_Sub);
      AUnit.Assertions.Assert
        (Subroutines.Has_Export (Flags), "export only: export");
      AUnit.Assertions.Assert
        (not Subroutines.Has_Entrypoint (Flags), "export only: no entrypoint");
      AUnit.Assertions.Assert
        (Modules.Origin (Lir_Module).Present, "export only: module origin");
      AUnit.Assertions.Assert
        (Subroutines.Origin (Lir_Sub).Present,
         "export only: subroutine origin");
   end Test_Export_Only_Flags;

   procedure Test_Export_Procedure_Parameters (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text    : constant String :=
        "module Lib; export procedure Print(Value : integer); begin end; end.";
      Ast_Module     : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "export procedure params");
      Lir_Module     : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "export procedure params");
      Lir_Subroutine : constant Subroutines.Subroutine :=
        Modules.Get_Subroutine (Lir_Module, 1);
      The_Signature  : constant Subroutines.Signature :=
        Subroutines.Get_Signature (Lir_Subroutine);
      Flags          : constant Subroutines.Subroutine_Flags :=
        Subroutines.Get_Flags (Lir_Subroutine);
      Parameters     : constant Lovelace.Lir.Types.Parameter_Sequence :=
        The_Signature.Parameters;
   begin
      AUnit.Assertions.Assert
        (Modules.Name (Lir_Module) = "Lib", "export procedure params: module");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (The_Signature.Name) = "Print",
         "export procedure params: name");
      AUnit.Assertions.Assert
        (Subroutines.Has_Export (Flags), "export procedure params: export");
      AUnit.Assertions.Assert
        (not Subroutines.Has_Entrypoint (Flags),
         "export procedure params: no entry");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Length (Parameters) = 1,
         "export procedure params: one");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String
           (Lovelace.Lir.Types.Element (Parameters, 1).Name)
         = "Value",
         "export procedure params: Value");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Parameters, 1).The_Type
         = Lovelace.Lir.Types.I32,
         "export procedure params: I32");
   end Test_Export_Procedure_Parameters;

   procedure Test_Filename_Shared (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text   : constant String := "program Hello; begin end.";
      Ast_Module    : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "unit.love", "filename shared");
      Lir_Module    : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "filename shared");
      Module_Origin : constant Modules.Origin_Option :=
        Modules.Origin (Lir_Module);
      Sub_Origin    : constant Subroutines.Origin_Option :=
        Subroutines.Origin (Modules.Get_Subroutine (Lir_Module, 1));
   begin
      Assert_Entrypoint_Lir
        (Lir_Module, "Hello", Ast_Module, "filename shared");

      case Module_Origin.Present is
         when False =>
            AUnit.Assertions.Assert (False, "filename shared: module origin");

         when True  =>
            AUnit.Assertions.Assert
              (Module_Origin.Value.Filename.Present,
               "filename shared: module has filename");

            case Sub_Origin.Present is
               when False =>
                  AUnit.Assertions.Assert
                    (False, "filename shared: subroutine origin");

               when True  =>
                  AUnit.Assertions.Assert
                    (Source.Same_Storage
                       (Module_Origin.Value.Filename,
                        Sub_Origin.Value.Filename),
                     "filename shared: module and subroutine Same_Storage");
            end case;
      end case;
   end Test_Filename_Shared;

   procedure Test_Flattened_Locals (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text : constant String :=
        "program Demo;"
        & ASCII.LF
        & "declare"
        & ASCII.LF
        & "   Outer : integer;"
        & ASCII.LF
        & "   Flag : boolean;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "   declare"
        & ASCII.LF
        & "      Inner : float<32>;"
        & ASCII.LF
        & "      Byte : unsigned integer<8>;"
        & ASCII.LF
        & "   begin"
        & ASCII.LF
        & "   end;"
        & ASCII.LF
        & "end.";
      Ast_Module  : constant Ast.Module := Support.Must_Parse (Source_Text, "flattened locals");
      Lir_Module  : constant Modules.Module := Support.Must_Generate (Ast_Module, "flattened locals");
      Lir_Sub     : constant Subroutines.Subroutine := Modules.Get_Subroutine (Lir_Module, 1);
      Locals      : constant Lovelace.Lir.Types.Parameter_Sequence := Subroutines.Get_Locals (Lir_Sub);
   begin
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Length (Locals) = 4, "four flattened locals");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Lovelace.Lir.Types.Element (Locals, 1).Name) = "Outer",
         "Outer name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Locals, 1).The_Type = Lovelace.Lir.Types.I32, "Outer i32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Lovelace.Lir.Types.Element (Locals, 2).Name) = "Flag",
         "Flag name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Locals, 2).The_Type = Lovelace.Lir.Types.I32, "Flag boolean to i32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Lovelace.Lir.Types.Element (Locals, 3).Name) = "Inner",
         "Inner name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Locals, 3).The_Type = Lovelace.Lir.Types.F32, "Inner f32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Lovelace.Lir.Types.Element (Locals, 4).Name) = "Byte",
         "Byte name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Locals, 4).The_Type = Lovelace.Lir.Types.U8, "Byte u8");
   end Test_Flattened_Locals;

   procedure Test_Identifier_Names (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Cafe_Name   : constant String :=
        "caf" & Support.To_Utf_8 (Wide_Wide_Character'Val (16#00E9#));
      Cafe_Source : constant String := "program " & Cafe_Name & "; begin end.";
      At_Source   : constant String := "program @foo; begin end.";
      Cafe_Ast    : constant Ast.Module :=
        Support.Must_Parse (Cafe_Source, "unicode name");
      At_Ast      : constant Ast.Module :=
        Support.Must_Parse (At_Source, "@foo name");
      Cafe_Lir    : constant Modules.Module :=
        Support.Must_Generate (Cafe_Ast, "unicode name");
      At_Lir      : constant Modules.Module :=
        Support.Must_Generate (At_Ast, "@foo name");
   begin
      Assert_Entrypoint_Lir (Cafe_Lir, Cafe_Name, Cafe_Ast, "unicode name");
      Assert_Entrypoint_Lir (At_Lir, "@foo", At_Ast, "@foo name");
   end Test_Identifier_Names;

   procedure Test_Import_Dependencies (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Program_Source : constant String :=
        "import augusta.std.io;"
        & ASCII.LF
        & "import Other;"
        & ASCII.LF
        & "program Hello;"
        & ASCII.LF
        & "begin"
        & ASCII.LF
        & "end.";
      Module_Source  : constant String :=
        "import Lib.A;" & ASCII.LF & "module Host; end.";
      Empty_Source   : constant String := "program EmptyImports; begin end.";
      Program_Ast    : constant Ast.Module :=
        Support.Must_Parse (Program_Source, "program imports");
      Module_Ast     : constant Ast.Module :=
        Support.Must_Parse (Module_Source, "module imports");
      Empty_Ast      : constant Ast.Module :=
        Support.Must_Parse (Empty_Source, "empty imports");
      Program_Lir    : constant Modules.Module :=
        Support.Must_Generate (Program_Ast, "program imports");
      Module_Lir     : constant Modules.Module :=
        Support.Must_Generate (Module_Ast, "module imports");
      Empty_Lir      : constant Modules.Module :=
        Support.Must_Generate (Empty_Ast, "empty imports");
   begin
      AUnit.Assertions.Assert
        (Modules.Dependency_Count (Program_Lir) = 2, "program imports: count");
      AUnit.Assertions.Assert
        (Modules.Dependency_Name (Program_Lir, 1) = "augusta.std.io",
         "program imports: first");
      AUnit.Assertions.Assert
        (Modules.Dependency_Name (Program_Lir, 2) = "Other",
         "program imports: second");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Program_Lir) = 1,
         "program imports: entrypoint");

      AUnit.Assertions.Assert
        (Modules.Dependency_Count (Module_Lir) = 1, "module imports: count");
      AUnit.Assertions.Assert
        (Modules.Dependency_Name (Module_Lir, 1) = "Lib.A",
         "module imports: first");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Module_Lir) = 0, "module imports: no subs");

      AUnit.Assertions.Assert
        (Modules.Dependency_Count (Empty_Lir) = 0, "empty imports: count");
   end Test_Import_Dependencies;

   procedure Test_Module_Procedure_Parameters (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text    : constant String :=
        "module MyModule; procedure Whatever(x : integer; y, z : float<32>); begin end; end.";
      Ast_Module     : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "module procedure params");
      Lir_Module     : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "module procedure params");
      Lir_Subroutine : constant Subroutines.Subroutine :=
        Modules.Get_Subroutine (Lir_Module, 1);
      The_Signature  : constant Subroutines.Signature :=
        Subroutines.Get_Signature (Lir_Subroutine);
      Flags          : constant Subroutines.Subroutine_Flags :=
        Subroutines.Get_Flags (Lir_Subroutine);
      Parameters     : constant Lovelace.Lir.Types.Parameter_Sequence :=
        The_Signature.Parameters;
   begin
      AUnit.Assertions.Assert
        (Modules.Name (Lir_Module) = "MyModule",
         "module procedure params: module name");
      AUnit.Assertions.Assert
        (Modules.Subroutine_Count (Lir_Module) = 1,
         "module procedure params: one sub");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (The_Signature.Name) = "Whatever",
         "module procedure params: name");
      AUnit.Assertions.Assert
        (The_Signature.Return_Type = Lovelace.Lir.Types.Unit,
         "module procedure params: Unit");
      AUnit.Assertions.Assert
        (not Subroutines.Has_Export (Flags),
         "module procedure params: no export");
      AUnit.Assertions.Assert
        (not Subroutines.Has_Entrypoint (Flags),
         "module procedure params: no entry");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Length (Parameters) = 3,
         "module procedure params: three");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String
           (Lovelace.Lir.Types.Element (Parameters, 1).Name)
         = "x",
         "module procedure params: x name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Parameters, 1).The_Type
         = Lovelace.Lir.Types.I32,
         "module procedure params: x I32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String
           (Lovelace.Lir.Types.Element (Parameters, 2).Name)
         = "y",
         "module procedure params: y name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Parameters, 2).The_Type
         = Lovelace.Lir.Types.F32,
         "module procedure params: y F32");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String
           (Lovelace.Lir.Types.Element (Parameters, 3).Name)
         = "z",
         "module procedure params: z name");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Element (Parameters, 3).The_Type
         = Lovelace.Lir.Types.F32,
         "module procedure params: z F32");
   end Test_Module_Procedure_Parameters;

   procedure Test_Native_Binding (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      package U renames Ada.Strings.Unbounded;
      Native_Source     : constant String :=
        "module Lib; export @native(""libx"", ""print_fn"") procedure print(value : integer); end.";
      Intrinsic_Ok_Src  : constant String :=
        "module augusta.std.io; export @intrinsic procedure print(value : integer); end.";
      Intrinsic_Bad_Src : constant String :=
        "module Lib; export @intrinsic procedure print(value : integer); end.";
      Native_Module     : constant Ast.Module := Support.Must_Parse (Native_Source, "native ok");
      Lir_Native        : constant Modules.Module := Support.Must_Generate (Native_Module, "native ok");
      Native_Sub        : constant Subroutines.Subroutine := Modules.Get_Subroutine (Lir_Native, 1);
      The_Native        : constant Subroutines.Native_Binding_Option := Subroutines.Native (Native_Sub);
      Intrinsic_Module  : constant Ast.Module :=
        Support.Must_Parse (Intrinsic_Ok_Src, "intrinsic ok");
      Lir_Intrinsic     : constant Modules.Module :=
        Support.Must_Generate (Intrinsic_Module, "intrinsic ok");
      Intrinsic_Sub     : constant Subroutines.Subroutine :=
        Modules.Get_Subroutine (Lir_Intrinsic, 1);
      Unknown_Intrinsic : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Intrinsic_Bad_Src, "intrinsic bad"), "intrinsic bad");
   begin
      AUnit.Assertions.Assert
        (Subroutines.Has_Export (Subroutines.Get_Flags (Native_Sub)), "native export");
      AUnit.Assertions.Assert
        (Subroutines.Has_Native (Subroutines.Get_Flags (Native_Sub)), "native flag");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Length (Subroutines.Get_Instructions (Native_Sub)) = 0,
         "native empty body");
      AUnit.Assertions.Assert (The_Native.Present, "binding present");
      AUnit.Assertions.Assert (U.To_String (The_Native.Value.Library) = "libx", "library");
      AUnit.Assertions.Assert
        (U.To_String (The_Native.Value.Function_Name) = "print_fn", "function");
      AUnit.Assertions.Assert
        (Subroutines.Has_Intrinsic (Subroutines.Get_Flags (Intrinsic_Sub)), "intrinsic flag");
      AUnit.Assertions.Assert
        (not Subroutines.Has_Native (Subroutines.Get_Flags (Intrinsic_Sub)),
         "intrinsic not native");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Length (Subroutines.Get_Instructions (Intrinsic_Sub)) = 0,
         "intrinsic empty body");
      AUnit.Assertions.Assert
        (Unknown_Intrinsic.Code = Ir_Gen.Unknown_Intrinsic, "unknown intrinsic code");
   end Test_Native_Binding;

   procedure Test_Parameter_Type_Mapping (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Source_Text   : constant String :=
        "module Types; procedure Map("
        & "i8 : signed integer<8>; "
        & "i16 : signed integer<16>; "
        & "i32 : integer; "
        & "i64 : integer<64>; "
        & "u8 : unsigned integer<8>; "
        & "u16 : unsigned integer<16>; "
        & "u32 : unsigned integer; "
        & "u64 : unsigned integer<64>; "
        & "f32 : float; "
        & "f64 : float<64>; "
        & "flag : boolean"
        & "); begin end; end.";
      Ast_Module    : constant Ast.Module :=
        Support.Must_Parse (Source_Text, "param type mapping");
      Lir_Module    : constant Modules.Module :=
        Support.Must_Generate (Ast_Module, "param type mapping");
      The_Signature : constant Subroutines.Signature :=
        Subroutines.Get_Signature (Modules.Get_Subroutine (Lir_Module, 1));
      Parameters    : constant Lovelace.Lir.Types.Parameter_Sequence :=
        The_Signature.Parameters;

      procedure Assert_Param
        (Index         : Positive;
         Expected_Name : String;
         Expected_Type : Lovelace.Lir.Types.Value_Type);
      --  Assert Parameters (Index) has Expected_Name and Expected_Type.

      procedure Assert_Param
        (Index         : Positive;
         Expected_Name : String;
         Expected_Type : Lovelace.Lir.Types.Value_Type)
      is
         The_Parameter : constant Lovelace.Lir.Types.Parameter :=
           Lovelace.Lir.Types.Element (Parameters, Index);
      begin
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (The_Parameter.Name)
            = Expected_Name,
            "param type mapping: " & Expected_Name & " name");
         AUnit.Assertions.Assert
           (The_Parameter.The_Type = Expected_Type,
            "param type mapping: " & Expected_Name & " type");
      end Assert_Param;
   begin
      AUnit.Assertions.Assert
        (Lovelace.Lir.Types.Length (Parameters) = 11,
         "param type mapping: eleven params");
      Assert_Param (1, "i8", Lovelace.Lir.Types.I8);
      Assert_Param (2, "i16", Lovelace.Lir.Types.I16);
      Assert_Param (3, "i32", Lovelace.Lir.Types.I32);
      Assert_Param (4, "i64", Lovelace.Lir.Types.I64);
      Assert_Param (5, "u8", Lovelace.Lir.Types.U8);
      Assert_Param (6, "u16", Lovelace.Lir.Types.U16);
      Assert_Param (7, "u32", Lovelace.Lir.Types.U32);
      Assert_Param (8, "u64", Lovelace.Lir.Types.U64);
      Assert_Param (9, "f32", Lovelace.Lir.Types.F32);
      Assert_Param (10, "f64", Lovelace.Lir.Types.F64);
      Assert_Param (11, "flag", Lovelace.Lir.Types.I32);
   end Test_Parameter_Type_Mapping;

   procedure Test_Same_Unit_Calls (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Success_Source  : constant String :=
        "module Calls;"
        & ASCII.LF
        & "procedure Sink(Value : integer); begin end;"
        & ASCII.LF
        & "procedure Run(); begin Calls.Sink(42); end;"
        & ASCII.LF
        & "end.";
      Ast_Ok          : constant Ast.Module :=
        Support.Must_Parse (Success_Source, "same-unit call");
      Lir_Ok          : constant Modules.Module :=
        Support.Must_Generate (Ast_Ok, "same-unit call");
      Run_Body        :
        constant Lovelace.Lir.Instructions.Instruction_Sequence :=
          Subroutines.Get_Instructions (Modules.Get_Subroutine (Lir_Ok, 2));
      Cross_Source    : constant String :=
        "module Calls; procedure Run(); begin Other.Sink(42); end; end.";
      Unknown_Source  : constant String :=
        "module Calls; procedure Run(); begin Calls.Missing(42); end; end.";
      Arity_Source    : constant String :=
        "module Calls; procedure Sink(Value : integer); begin end; "
        & "procedure Run(); begin Calls.Sink(1, 2); end; end.";
      Unsigned_Source : constant String :=
        "module Calls; procedure Sink(Value : unsigned integer); begin end; "
        & "procedure Run(); begin Calls.Sink(-1); end; end.";
      Wide_Source     : constant String :=
        "module Calls; procedure Sink(Value : integer<64>); begin end; "
        & "procedure Run(); begin Calls.Sink(1); end; end.";
      Bool_Source     : constant String :=
        "module Calls;"
        & ASCII.LF
        & "procedure Sink(Flag : boolean); begin end;"
        & ASCII.LF
        & "procedure Run(); begin Calls.Sink(true); Calls.Sink(false); end;"
        & ASCII.LF
        & "end.";
      Bool_Int_Source : constant String :=
        "module Calls; procedure Sink(Flag : boolean); begin end; "
        & "procedure Run(); begin Calls.Sink(1); end; end.";
      Int_Bool_Source : constant String :=
        "module Calls; procedure Sink(Value : integer); begin end; "
        & "procedure Run(); begin Calls.Sink(true); end; end.";
      Cross_Error     : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Cross_Source, "cross"), "cross");
      Unknown_Error   : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Unknown_Source, "unknown"), "unknown");
      Arity_Error     : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Arity_Source, "arity"), "arity");
      Unsigned_Error  : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Unsigned_Source, "unsigned"), "unsigned");
      Wide_Error      : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Wide_Source, "wide"), "wide");
      Bool_Ast        : constant Ast.Module :=
        Support.Must_Parse (Bool_Source, "boolean calls");
      Bool_Lir        : constant Modules.Module :=
        Support.Must_Generate (Bool_Ast, "boolean calls");
      Bool_Body       :
        constant Lovelace.Lir.Instructions.Instruction_Sequence :=
          Subroutines.Get_Instructions (Modules.Get_Subroutine (Bool_Lir, 2));
      Bool_Int_Error  : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Bool_Int_Source, "bool int"), "bool int");
      Int_Bool_Error  : constant Ir_Gen.Ir_Generator_Error :=
        Support.Must_Fail_Generate
          (Support.Must_Parse (Int_Bool_Source, "int bool"), "int bool");
   begin
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Length (Run_Body) = 2, "two instructions");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Element (Run_Body, 1).Operation
         = Lovelace.Lir.Opcodes.Constant_I32,
         "const");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Element (Run_Body, 1).Immediate_I32 = 42,
         "const value");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Element (Run_Body, 2).Operation
         = Lovelace.Lir.Opcodes.Call,
         "call");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Element (Run_Body, 2).Target_Index = 1,
         "call target Sink");

      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Length (Bool_Body) = 4, "boolean four instructions");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Element (Bool_Body, 1).Immediate_I32 = 1, "true to 1");
      AUnit.Assertions.Assert
        (Lovelace.Lir.Instructions.Element (Bool_Body, 3).Immediate_I32 = 0, "false to 0");

      AUnit.Assertions.Assert
        (Cross_Error.Code = Ir_Gen.Call_Without_Import, "cross code");
      AUnit.Assertions.Assert
        (Unknown_Error.Code = Ir_Gen.Unresolved_Call, "unknown code");
      AUnit.Assertions.Assert
        (Arity_Error.Code = Ir_Gen.Invalid_Arguments, "arity code");
      AUnit.Assertions.Assert
        (Unsigned_Error.Code = Ir_Gen.Invalid_Arguments, "unsigned code");
      AUnit.Assertions.Assert
        (Wide_Error.Code = Ir_Gen.Invalid_Arguments, "wide code");
      AUnit.Assertions.Assert
        (Bool_Int_Error.Code = Ir_Gen.Invalid_Arguments, "bool int code");
      AUnit.Assertions.Assert
        (Int_Bool_Error.Code = Ir_Gen.Invalid_Arguments, "int bool code");
   end Test_Same_Unit_Calls;

end Lovelace.Compiler.Tests.Ir_Generator;
