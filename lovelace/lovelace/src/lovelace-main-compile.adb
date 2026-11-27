with Ada.Calendar;
with Ada.Directories;
with Ada.Streams;
with Ada.Strings;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Backend;
with Lovelace.Compiler.Backend.Wasm;
with Lovelace.Compiler.Backend.Wat;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Flavor;
with Lovelace.Compiler.Ir_Generator;
with Lovelace.Compiler.Module_Path;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Reporting;
with Lovelace.Compiler.Semantics;
with Lovelace.Compiler.Tokenizer;
with Lovelace.Compiler.Unit_Graph;
with Lovelace.Compiler.Versioning;
with Lovelace.Lir.Binary;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Text;
with Lovelace.Main.Terminal;

package body Lovelace.Main.Compile is

   use type Ada.Calendar.Time;
   use type GNAT.OS_Lib.File_Descriptor;

   package Source renames Lovelace.Common.Source;
   package Ast renames Lovelace.Compiler.Ast;
   package Backend renames Lovelace.Compiler.Backend;
   package Backend_Wasm renames Lovelace.Compiler.Backend.Wasm;
   package Backend_Wat renames Lovelace.Compiler.Backend.Wat;
   package Diagnostics renames Lovelace.Compiler.Diagnostics;
   package Error_Codes renames Lovelace.Compiler.Error_Codes;
   package Flavor renames Lovelace.Compiler.Flavor;
   package Ir_Generator renames Lovelace.Compiler.Ir_Generator;
   package Module_Path renames Lovelace.Compiler.Module_Path;
   package Parser renames Lovelace.Compiler.Parser;
   package Reporting renames Lovelace.Compiler.Reporting;
   package Semantics renames Lovelace.Compiler.Semantics;
   package Tokenizer renames Lovelace.Compiler.Tokenizer;
   package Unit_Graph renames Lovelace.Compiler.Unit_Graph;
   package Versioning renames Lovelace.Compiler.Versioning;
   package Lir_Binary renames Lovelace.Lir.Binary;
   package Lir_Text renames Lovelace.Lir.Text;
   package Modules renames Lovelace.Lir.Modules;

   type Compile_Options is record
      Source_Path    : Ada.Strings.Unbounded.Unbounded_String;
      Output_Root    : Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.To_Unbounded_String (".output");
      No_Wit         : Boolean := False;
      Force          : Boolean := False;
      Generate_Tlir  : Boolean := False;
      Output_Format  : Output_Format_Set;
      The_Flavor     : Flavor.Flavor := Flavor.Default;
      Include_Paths  : Module_Path.Path_Sequence;
      The_Policy     : Diagnostics.Policy := Diagnostics.Default_Policy;
      Module_Version : Versioning.Version_Option;
   end record;

   Origin_Span : constant Source.Source_Span :=
     (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1));

   --  Artifact directories and file paths for one compile.
   type Artifact_Paths is record
      Obj_Dir : Ada.Strings.Unbounded.Unbounded_String;
      Bin_Dir : Ada.Strings.Unbounded.Unbounded_String;
      Lir     : Ada.Strings.Unbounded.Unbounded_String;
      Tlir    : Ada.Strings.Unbounded.Unbounded_String;
      Wasm    : Ada.Strings.Unbounded.Unbounded_String;
      Wat     : Ada.Strings.Unbounded.Unbounded_String;
      Wit     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Backend artifacts that must be (re)generated.
   type Backend_Needs is record
      Wasm : Boolean;
      Wat  : Boolean;
      Wit  : Boolean;
   end record;

   function Apply_Flavor (Value : String; Options : in out Compile_Options) return Boolean;
   procedure Apply_Include_Path (Value : String; Options : in out Compile_Options);
   function Apply_Module_Version (Value : String; Options : in out Compile_Options) return Boolean;
   function Apply_No_Warnings (Value : String; Options : in out Compile_Options) return Boolean;
   procedure Apply_Output_Folder (Value : String; Options : in out Compile_Options);
   function Apply_Output_Format (Value : String; Options : in out Compile_Options) return Boolean;
   function Apply_Positional
     (Token : String; Options : in out Compile_Options; Have_Source : in out Boolean) return Boolean;
   procedure Apply_Switch (Token : String; Options : in out Compile_Options);
   function Apply_Value_Option (Token : String; Value : String; Options : in out Compile_Options) return Boolean;
   function Check_Unit_Name (Root_Module : Ast.Module; Source_Path : String; Source_Text : String) return Boolean;
   function Compose_Path (Left, Right : String) return String;
   function Decide_Stale (Options : Compile_Options; Paths : Artifact_Paths) return Backend_Needs;
   function Emit_Outputs
     (Needs : Backend_Needs; Source_Path : String; Paths : Artifact_Paths; The_Module : Modules.Module) return Boolean;
   function Emit_Wasm_Stage
     (Needs         : Backend_Needs;
      Source_Path   : String;
      Wasm_Path     : String;
      The_Module    : Modules.Module;
      Wit_Text      : in out Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : in out Boolean) return Boolean;
   function Emit_Wat_Stage
     (Source_Path   : String;
      Wat_Path      : String;
      The_Module    : Modules.Module;
      Wit_Text      : in out Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : in out Boolean) return Boolean;
   function Emit_Wit_Stage
     (Source_Path   : String;
      Wit_Path      : String;
      The_Module    : Modules.Module;
      Wit_Text      : in out Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : Boolean) return Boolean;
   function File_Is_Newer_Or_Equal (Candidate, Reference : String) return Boolean;
   function Frontend_Is_Stale
     (Options : Compile_Options; Units : Unit_Graph.Compilation_Set; Lir_Path : String) return Boolean;
   function Generate_Lir
     (Units       : Unit_Graph.Compilation_Set;
      Source_Path : String;
      Source_Text : String;
      Lir_Path    : String;
      The_Module  : out Modules.Module) return Boolean;
   function Is_Attached_Include (Token : String) return Boolean;
   function Is_Stale (Output_Path, Input_Path : String) return Boolean;
   function Is_Switch (Token : String) return Boolean;
   function Is_Unknown_Option (Token : String) return Boolean;
   function Is_Value_Option (Token : String) return Boolean;
   function Needs_Backend (Needs : Backend_Needs) return Boolean;
   function Needs_Wasm_Pass (Needs : Backend_Needs) return Boolean;
   function Output_Needed (Wanted : Boolean; Force : Boolean; Output_Path : String; Lir_Path : String) return Boolean;
   function Parse_Options
     (Command_Arguments : Arguments.String_Vectors.Vector; Options : out Compile_Options) return Boolean;
   function Parse_Token
     (Command_Arguments : Arguments.String_Vectors.Vector;
      Token             : String;
      Index             : in out Positive;
      Options           : in out Compile_Options;
      Have_Source       : in out Boolean) return Boolean;
   function Read_Entire_File (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   function Read_Lir (Lir_Path : String; The_Module : out Modules.Module) return Boolean;
   procedure Report_Backend_Error
     (Source_Path : String; Code : Error_Codes.Error_Code; Detail : Ada.Strings.Unbounded.Unbounded_String);
   procedure Report_Cli_Error (Description : String);
   procedure Report_Invalid_Warning_Suppression (Detail : String);
   procedure Report_Loaded_Units (Units : Unit_Graph.Compilation_Set);
   procedure Report_Located
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String;
      The_Policy  : Diagnostics.Policy := Diagnostics.Default_Policy);
   procedure Report_Missing_Value (Token : String);
   procedure Report_Parser_Errors (Result : Parser.Parse_Result; Source_Path : String; Source_Text : String);
   procedure Report_Tokenizer_Errors (Result : Tokenizer.Tokenize_Result; Source_Path : String; Source_Text : String);
   procedure Resolve_Paths
     (Options : Compile_Options; Source_Path : out Ada.Strings.Unbounded.Unbounded_String; Paths : out Artifact_Paths);
   function Run_Frontend
     (Options : Compile_Options; Source_Path : String; Paths : in out Artifact_Paths; The_Module : out Modules.Module)
      return Boolean;
   function Run_Generate_Stage
     (Options     : Compile_Options;
      Source_Path : String;
      Source_Text : String;
      Units       : Unit_Graph.Compilation_Set;
      Paths       : Artifact_Paths;
      The_Module  : out Modules.Module) return Boolean;
   function Run_Load_Stage
     (Options     : Compile_Options;
      Source_Path : String;
      Source_Text : String;
      Root_Module : Ast.Module;
      Paths       : Artifact_Paths;
      The_Module  : out Modules.Module) return Boolean;
   function Run_Parse_Stage
     (Options      : Compile_Options;
      Source_Path  : String;
      Source_Text  : String;
      Token_Result : Tokenizer.Tokenize_Result;
      Paths        : in out Artifact_Paths;
      The_Module   : out Modules.Module) return Boolean;
   function Run_Semantics (Units : Unit_Graph.Compilation_Set; The_Policy : Diagnostics.Policy) return Boolean;
   function Run_Tokenize_Stage
     (Options     : Compile_Options;
      Source_Path : String;
      Source_Text : String;
      Paths       : in out Artifact_Paths;
      The_Module  : out Modules.Module) return Boolean;
   procedure Set_Program_Paths (Paths : in out Artifact_Paths; Program_Name : String);
   function Write_Bytes (Path : String; Bytes : Backend.Byte_Sequence) return Boolean;
   function Write_Text (Path : String; Text : String) return Boolean;
   function Write_Tlir (The_Module : Modules.Module; Tlir_Path : String) return Boolean;

   function Apply_Flavor (Value : String; Options : in out Compile_Options) return Boolean is
      Parsed : Flavor.Flavor;
      Result : constant Boolean := Flavor.Try_Parse_Name (Value, Parsed);
   begin
      if Result then
         Options.The_Flavor := Parsed;
      else
         Report_Cli_Error ("invalid --flavor '" & Value & "'; expected wasi, native, or web");
      end if;
      return Result;
   end Apply_Flavor;

   procedure Apply_Include_Path (Value : String; Options : in out Compile_Options) is
   begin
      Options.Include_Paths.Append (Value);
   end Apply_Include_Path;

   function Apply_Module_Version (Value : String; Options : in out Compile_Options) return Boolean is
      Result : constant Boolean := Versioning.Is_Valid_Version (Value);
   begin
      if Result then
         Options.Module_Version := (Present => True, Value => Ada.Strings.Unbounded.To_Unbounded_String (Value));
      else
         Report_Cli_Error
           ("invalid --module-version '"
            & Value
            & "'; expected MAJOR.MINOR.BUILD"
            & "[-preview-name[.preview-number]]");
      end if;
      return Result;
   end Apply_Module_Version;

   function Apply_No_Warnings (Value : String; Options : in out Compile_Options) return Boolean is
      Detail : Ada.Strings.Unbounded.Unbounded_String;
      Result : constant Boolean :=
        Try_Apply_No_Warnings (Text => Value, The_Policy => Options.The_Policy, Detail => Detail);
   begin
      if not Result then
         Report_Invalid_Warning_Suppression (Ada.Strings.Unbounded.To_String (Detail));
      end if;
      return Result;
   end Apply_No_Warnings;

   procedure Apply_Output_Folder (Value : String; Options : in out Compile_Options) is
   begin
      Options.Output_Root := Ada.Strings.Unbounded.To_Unbounded_String (Value);
   end Apply_Output_Folder;

   function Apply_Output_Format (Value : String; Options : in out Compile_Options) return Boolean is
      Format_Set : Output_Format_Set;
      Result     : constant Boolean := Try_Parse_Output_Format (Value, Format_Set);
   begin
      if Result then
         Options.Output_Format := Format_Set;
      else
         Report_Cli_Error ("invalid --output-format '" & Value & "'");
      end if;
      return Result;
   end Apply_Output_Format;

   function Apply_Positional
     (Token : String; Options : in out Compile_Options; Have_Source : in out Boolean) return Boolean
   is
      Result : constant Boolean := not Have_Source;
   begin
      if Result then
         Options.Source_Path := Ada.Strings.Unbounded.To_Unbounded_String (Token);
         Have_Source := True;
      else
         Report_Cli_Error ("unexpected extra argument '" & Token & "'");
      end if;
      return Result;
   end Apply_Positional;

   procedure Apply_Switch (Token : String; Options : in out Compile_Options) is
   begin
      if Token = "--no-wit" then
         Options.No_Wit := True;
      elsif Token = "--force" then
         Options.Force := True;
      elsif Token = "--warning-as-errors" then
         Diagnostics.Set_Promote_Warnings (Options.The_Policy, True);
      else
         --  Remaining switch: --generate-tlir (see Is_Switch).
         Options.Generate_Tlir := True;
      end if;
   end Apply_Switch;

   function Apply_Value_Option (Token : String; Value : String; Options : in out Compile_Options) return Boolean is
      Result : Boolean := True;
   begin
      if Token = "--no-warnings" then
         Result := Apply_No_Warnings (Value, Options);
      elsif Token = "--flavor" then
         Result := Apply_Flavor (Value, Options);
      elsif Token = "--include-path" or else Token = "-I" then
         Apply_Include_Path (Value, Options);
      elsif Token = "--module-version" then
         Result := Apply_Module_Version (Value, Options);
      elsif Token = "--output-format" then
         Result := Apply_Output_Format (Value, Options);
      else
         --  Remaining value option: --output-folder (see Is_Value_Option).
         Apply_Output_Folder (Value, Options);
      end if;
      return Result;
   end Apply_Value_Option;

   function Check_Unit_Name (Root_Module : Ast.Module; Source_Path : String; Source_Text : String) return Boolean is
      Result : constant Boolean := Reporting.Unit_Name_Matches_File (Root_Module, Source_Path);
   begin
      if not Result then
         Report_Located
           (Filename    => Source_Path,
            Span        => Ast.Name_Span (Root_Module),
            Source_Text => Source_Text,
            Code        => Error_Codes.Program_Name_Filename_Mismatch,
            Description =>
              Reporting.Unit_Kind_Label (Root_Module)
              & " identifier '"
              & Ast.Name (Root_Module)
              & "' does not match file stem '"
              & Reporting.Love_Basename (Source_Path)
              & "'");
      end if;
      return Result;
   end Check_Unit_Name;

   function Compose_Path (Left, Right : String) return String is
   begin
      return Ada.Directories.Compose (Left, Right);
   end Compose_Path;

   function Decide_Stale (Options : Compile_Options; Paths : Artifact_Paths) return Backend_Needs is
      Lir_Path : constant String := Ada.Strings.Unbounded.To_String (Paths.Lir);
   begin
      return
        (Wasm =>
           Output_Needed
             (Options.Output_Format.Want_Wasm, Options.Force, Ada.Strings.Unbounded.To_String (Paths.Wasm), Lir_Path),
         Wat  =>
           Output_Needed
             (Options.Output_Format.Want_Wat, Options.Force, Ada.Strings.Unbounded.To_String (Paths.Wat), Lir_Path),
         Wit  =>
           Output_Needed (not Options.No_Wit, Options.Force, Ada.Strings.Unbounded.To_String (Paths.Wit), Lir_Path));
   end Decide_Stale;

   function Emit_Outputs
     (Needs : Backend_Needs; Source_Path : String; Paths : Artifact_Paths; The_Module : Modules.Module) return Boolean
   is
      Wit_Text      : Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : Boolean := False;
      Result        : Boolean := True;
   begin
      if Needs_Wasm_Pass (Needs) then
         Result :=
           Emit_Wasm_Stage
             (Needs         => Needs,
              Source_Path   => Source_Path,
              Wasm_Path     => Ada.Strings.Unbounded.To_String (Paths.Wasm),
              The_Module    => The_Module,
              Wit_Text      => Wit_Text,
              Have_Wit_Text => Have_Wit_Text);
      end if;
      if Result and then Needs.Wat then
         Result :=
           Emit_Wat_Stage
             (Source_Path   => Source_Path,
              Wat_Path      => Ada.Strings.Unbounded.To_String (Paths.Wat),
              The_Module    => The_Module,
              Wit_Text      => Wit_Text,
              Have_Wit_Text => Have_Wit_Text);
      end if;
      if Result and then Needs.Wit then
         Result :=
           Emit_Wit_Stage
             (Source_Path   => Source_Path,
              Wit_Path      => Ada.Strings.Unbounded.To_String (Paths.Wit),
              The_Module    => The_Module,
              Wit_Text      => Wit_Text,
              Have_Wit_Text => Have_Wit_Text);
      end if;
      return Result;
   end Emit_Outputs;

   function Emit_Wasm_Stage
     (Needs         : Backend_Needs;
      Source_Path   : String;
      Wasm_Path     : String;
      The_Module    : Modules.Module;
      Wit_Text      : in out Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : in out Boolean) return Boolean
   is
      Result : Boolean;
   begin
      Terminal.Put_Info ("Emitting WASM");
      declare
         Emit_Result : constant Backend.Wasm_Emit_Result := Backend_Wasm.Emit_Wasm (The_Module);
      begin
         Result := Emit_Result.Ok;
         if Emit_Result.Ok then
            if Needs.Wasm then
               Result := Write_Bytes (Wasm_Path, Emit_Result.Wasm_Bytes);
               if not Result then
                  Report_Cli_Error ("failed to write " & Wasm_Path);
               end if;
            end if;
            Wit_Text := Emit_Result.Wit_Text;
            Have_Wit_Text := True;
         else
            Report_Backend_Error
              (Source_Path, Reporting.To_Error_Code (Emit_Result.Error.Code), Emit_Result.Error.Detail);
         end if;
      end;
      return Result;
   end Emit_Wasm_Stage;

   function Emit_Wat_Stage
     (Source_Path   : String;
      Wat_Path      : String;
      The_Module    : Modules.Module;
      Wit_Text      : in out Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : in out Boolean) return Boolean
   is
      Result : Boolean;
   begin
      Terminal.Put_Info ("Emitting WAT");
      declare
         Emit_Result : constant Backend.Wat_Emit_Result := Backend_Wat.Emit_Wat (The_Module);
      begin
         Result := Emit_Result.Ok;
         if Emit_Result.Ok then
            Result := Write_Text (Wat_Path, Ada.Strings.Unbounded.To_String (Emit_Result.Wat_Text));
            if not Result then
               Report_Cli_Error ("failed to write " & Wat_Path);
            end if;
            if not Have_Wit_Text then
               Wit_Text := Emit_Result.Wit_Text;
               Have_Wit_Text := True;
            end if;
         else
            Report_Backend_Error
              (Source_Path, Reporting.To_Error_Code (Emit_Result.Error.Code), Emit_Result.Error.Detail);
         end if;
      end;
      return Result;
   end Emit_Wat_Stage;

   function Emit_Wit_Stage
     (Source_Path   : String;
      Wit_Path      : String;
      The_Module    : Modules.Module;
      Wit_Text      : in out Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : Boolean) return Boolean
   is
      Result : Boolean;
      pragma Unreferenced (Source_Path, The_Module);
   begin
      --  Needs_Wasm_Pass / Wat always populate Wit_Text before this stage.
      if not Have_Wit_Text then
         raise Program_Error with "Emit_Wit_Stage without companion WIT text";
      end if;
      Terminal.Put_Info ("Writing WIT");
      Result := Write_Text (Wit_Path, Ada.Strings.Unbounded.To_String (Wit_Text));
      if not Result then
         Report_Cli_Error ("failed to write " & Wit_Path);
      end if;
      return Result;
   end Emit_Wit_Stage;

   function File_Is_Newer_Or_Equal (Candidate, Reference : String) return Boolean is
   begin
      if not Ada.Directories.Exists (Candidate) then
         return False;
      end if;
      begin
         return Ada.Directories.Modification_Time (Candidate) >= Ada.Directories.Modification_Time (Reference);
      exception
         when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
            --  Missing reference => treat candidate as not up to date.
            return False;
      end;
   end File_Is_Newer_Or_Equal;

   function Frontend_Is_Stale
     (Options : Compile_Options; Units : Unit_Graph.Compilation_Set; Lir_Path : String) return Boolean
   is
      Result : Boolean := Options.Force;
   begin
      for Unit_Index in 1 .. Natural (Units.Length) loop
         exit when Result;
         Result := Is_Stale (Lir_Path, Ada.Strings.Unbounded.To_String (Units.Element (Unit_Index).Source_Path));
      end loop;
      return Result;
   end Frontend_Is_Stale;

   function Generate_Lir
     (Units       : Unit_Graph.Compilation_Set;
      Source_Path : String;
      Source_Text : String;
      Lir_Path    : String;
      The_Module  : out Modules.Module) return Boolean
   is
      Result : Boolean;
   begin
      Terminal.Put_Info ("Generating LIR");
      declare
         Generate_Result : constant Ir_Generator.Generate_Result := Ir_Generator.Generate (Units);
      begin
         Result := Generate_Result.Ok;
         if Generate_Result.Ok then
            The_Module := Generate_Result.The_Module;
            Terminal.Put_Info ("Writing " & Lir_Path);
            Result := Lir_Binary.Write (The_Module, Lir_Path).Ok;
            if not Result then
               Report_Cli_Error ("failed to write LIR file " & Lir_Path);
            end if;
         else
            Report_Located
              (Filename    => Source_Path,
               Span        => Generate_Result.Error.Span,
               Source_Text => Source_Text,
               Code        => Reporting.To_Error_Code (Generate_Result.Error.Code),
               Description => Ada.Strings.Unbounded.To_String (Generate_Result.Error.Detail));
         end if;
      end;
      return Result;
   end Generate_Lir;

   function Is_Attached_Include (Token : String) return Boolean
   is (Token'Length > 2 and then Token (Token'First .. Token'First + 1) = "-I");

   function Is_Stale (Output_Path, Input_Path : String) return Boolean is
   begin
      return not File_Is_Newer_Or_Equal (Output_Path, Input_Path);
   end Is_Stale;

   function Is_Switch (Token : String) return Boolean
   is (Token = "--no-wit"
       or else Token = "--force"
       or else Token = "--warning-as-errors"
       or else Token = "--generate-tlir");

   function Is_Unknown_Option (Token : String) return Boolean
   is (Token'Length >= 2 and then Token (Token'First .. Token'First + 1) = "--");

   function Is_Value_Option (Token : String) return Boolean
   is (Token = "--no-warnings"
       or else Token = "--flavor"
       or else Token = "--include-path"
       or else Token = "-I"
       or else Token = "--module-version"
       or else Token = "--output-format"
       or else Token = "--output-folder");

   function Needs_Backend (Needs : Backend_Needs) return Boolean
   is (Needs.Wasm or else Needs.Wat or else Needs.Wit);

   function Needs_Wasm_Pass (Needs : Backend_Needs) return Boolean
   is (Needs.Wasm or else (Needs.Wit and then not Needs.Wat));

   function Output_Needed (Wanted : Boolean; Force : Boolean; Output_Path : String; Lir_Path : String) return Boolean
   is (Wanted and then (Force or else Is_Stale (Output_Path, Lir_Path)));

   function Parse_Options
     (Command_Arguments : Arguments.String_Vectors.Vector; Options : out Compile_Options) return Boolean
   is
      Index          : Positive := 1;
      Have_Source    : Boolean := False;
      Result         : Boolean := True;
      Argument_Count : constant Natural := Natural (Command_Arguments.Length);
   begin
      Options :=
        (Source_Path    => Ada.Strings.Unbounded.Null_Unbounded_String,
         Output_Root    => Ada.Strings.Unbounded.To_Unbounded_String (".output"),
         No_Wit         => False,
         Force          => False,
         Generate_Tlir  => False,
         Output_Format  => (Want_Wasm => True, Want_Wat => False),
         The_Flavor     => Flavor.Default,
         Include_Paths  => Module_Path.Path_Vectors.Empty_Vector,
         The_Policy     => Diagnostics.Default_Policy,
         Module_Version => (Present => False));

      while Result and then Index <= Argument_Count loop
         Result :=
           Parse_Token
             (Command_Arguments => Command_Arguments,
              Token             => Command_Arguments.Element (Index),
              Index             => Index,
              Options           => Options,
              Have_Source       => Have_Source);
      end loop;

      if Result and then not Have_Source then
         Report_Cli_Error ("missing .love source file (future compiles may use .pjlove/.slnlove)");
         Result := False;
      end if;
      return Result;
   end Parse_Options;

   function Parse_Token
     (Command_Arguments : Arguments.String_Vectors.Vector;
      Token             : String;
      Index             : in out Positive;
      Options           : in out Compile_Options;
      Have_Source       : in out Boolean) return Boolean
   is
      Result : Boolean := True;
   begin
      if Is_Switch (Token) then
         Apply_Switch (Token, Options);
         Index := Index + 1;
      elsif Is_Value_Option (Token) then
         if Index >= Natural (Command_Arguments.Length) then
            Report_Missing_Value (Token);
            Result := False;
         else
            Result := Apply_Value_Option (Token, Command_Arguments.Element (Index + 1), Options);
            Index := Index + 2;
         end if;
      elsif Is_Attached_Include (Token) then
         Apply_Include_Path (Token (Token'First + 2 .. Token'Last), Options);
         Index := Index + 1;
      elsif Is_Unknown_Option (Token) then
         Report_Cli_Error ("unknown compile option '" & Token & "'");
         Result := False;
      else
         Result := Apply_Positional (Token, Options, Have_Source);
         Index := Index + 1;
      end if;
      return Result;
   end Parse_Token;

   function Read_Entire_File (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      Contents := Ada.Strings.Unbounded.Null_Unbounded_String;
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      declare
         File_Size : constant Long_Integer := GNAT.OS_Lib.File_Length (Descriptor);
      begin
         if File_Size < 0 then
            GNAT.OS_Lib.Close (Descriptor);
            return False;
         end if;

         declare
            Remaining_Bytes : Long_Integer := File_Size;
            Chunk           : Ada.Streams.Stream_Element_Array (1 .. 4096);
            Bytes_Read      : Integer;
         begin
            while Remaining_Bytes > 0 loop
               Bytes_Read :=
                 GNAT.OS_Lib.Read
                   (Descriptor,
                    Chunk'Address,
                    Integer (Long_Integer'Min (Remaining_Bytes, Long_Integer (Chunk'Length))));
               if Bytes_Read <= 0 then
                  GNAT.OS_Lib.Close (Descriptor);
                  return False;
               end if;
               for Offset in 1 .. Bytes_Read loop
                  Ada.Strings.Unbounded.Append
                    (Contents, Character'Val (Natural (Chunk (Ada.Streams.Stream_Element_Offset (Offset)))));
               end loop;
               Remaining_Bytes := Remaining_Bytes - Long_Integer (Bytes_Read);
            end loop;
         end;
      end;

      GNAT.OS_Lib.Close (Descriptor);
      return True;
   end Read_Entire_File;

   function Read_Lir (Lir_Path : String; The_Module : out Modules.Module) return Boolean is
      Decoded : constant Lir_Binary.Decode_Result := Lir_Binary.Read (Lir_Path);
   begin
      Terminal.Put_Info ("LIR up to date, skipping IR generation");
      if Decoded.Ok then
         The_Module := Decoded.Value;
      else
         Report_Cli_Error ("failed to read LIR file " & Lir_Path);
      end if;
      return Decoded.Ok;
   end Read_Lir;

   procedure Report_Backend_Error
     (Source_Path : String; Code : Error_Codes.Error_Code; Detail : Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Report_Located
        (Filename    => Source_Path,
         Span        => Origin_Span,
         Source_Text => "",
         Code        => Code,
         Description => Ada.Strings.Unbounded.To_String (Detail));
   end Report_Backend_Error;

   procedure Report_Cli_Error (Description : String) is
      Text : constant String := "[err] compile" & ASCII.LF & ASCII.LF & ASCII.LF & Description & ASCII.LF;
   begin
      Terminal.Put_Error_Text (Text);
   end Report_Cli_Error;

   procedure Report_Invalid_Warning_Suppression (Detail : String) is
   begin
      Report_Located
        (Filename    => "compile",
         Span        =>
           (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1)),
         Source_Text => "",
         Code        => Error_Codes.Invalid_Warning_Suppression,
         Description => Detail);
   end Report_Invalid_Warning_Suppression;

   procedure Report_Loaded_Units (Units : Unit_Graph.Compilation_Set) is
   begin
      for Unit_Index in 2 .. Natural (Units.Length) loop
         Terminal.Put_Info ("Loaded " & Ada.Strings.Unbounded.To_String (Units.Element (Unit_Index).Source_Path));
      end loop;
   end Report_Loaded_Units;

   procedure Report_Located
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String;
      The_Policy  : Diagnostics.Policy := Diagnostics.Default_Policy) is
   begin
      Terminal.Put_Error_Text (Diagnostics.Format (Filename, Span, Source_Text, Code, Description, The_Policy));
   end Report_Located;

   procedure Report_Missing_Value (Token : String) is
   begin
      if Token = "--no-warnings" then
         Report_Invalid_Warning_Suppression ("--no-warnings requires a comma-separated LV list");
      elsif Token = "--flavor" then
         Report_Cli_Error ("--flavor requires a value (wasi, native, or web)");
      elsif Token = "--module-version" then
         Report_Cli_Error ("--module-version requires a version string");
      elsif Token = "--output-format" then
         Report_Cli_Error ("--output-format requires a value");
      elsif Token = "--output-folder" then
         Report_Cli_Error ("--output-folder requires a path");
      else
         --  --include-path or -I (see Is_Value_Option).
         Report_Cli_Error (Token & " requires a directory path");
      end if;
   end Report_Missing_Value;

   procedure Report_Parser_Errors (Result : Parser.Parse_Result; Source_Path : String; Source_Text : String) is
   begin
      for Error_Index in 1 .. Parser.Length (Result.Errors) loop
         declare
            Item : constant Parser.Parser_Error := Parser.Element (Result.Errors, Error_Index);
            Name : constant String := (if Item.Filename.Present then Source.To_Utf_8 (Item.Filename) else Source_Path);
         begin
            Report_Located
              (Filename    => Name,
               Span        => Item.Span,
               Source_Text => Source_Text,
               Code        => Reporting.To_Error_Code (Item.Code),
               Description => Ada.Strings.Unbounded.To_String (Item.Detail));
         end;
      end loop;
   end Report_Parser_Errors;

   procedure Report_Tokenizer_Errors (Result : Tokenizer.Tokenize_Result; Source_Path : String; Source_Text : String) is
   begin
      for Error_Index in 1 .. Tokenizer.Length (Result.Errors) loop
         declare
            Item : constant Tokenizer.Tokenizer_Error := Tokenizer.Element (Result.Errors, Error_Index);
            Name : constant String := (if Item.Filename.Present then Source.To_Utf_8 (Item.Filename) else Source_Path);
         begin
            Report_Located
              (Filename    => Name,
               Span        => Item.Span,
               Source_Text => Source_Text,
               Code        => Reporting.To_Error_Code (Item.Code),
               Description => Ada.Strings.Unbounded.To_String (Item.Detail));
         end;
      end loop;
   end Report_Tokenizer_Errors;

   procedure Resolve_Paths
     (Options : Compile_Options; Source_Path : out Ada.Strings.Unbounded.Unbounded_String; Paths : out Artifact_Paths)
   is
      Output_Root : constant String := Ada.Strings.Unbounded.To_String (Options.Output_Root);
   begin
      begin
         Source_Path :=
           Ada.Strings.Unbounded.To_Unbounded_String
             (Ada.Directories.Full_Name (Ada.Strings.Unbounded.To_String (Options.Source_Path)));
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
            Source_Path := Options.Source_Path;
      end;
      Paths.Obj_Dir := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Output_Root, "obj"));
      Paths.Bin_Dir := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Output_Root, "bin"));
      Ada.Directories.Create_Path (Ada.Strings.Unbounded.To_String (Paths.Obj_Dir));
      Ada.Directories.Create_Path (Ada.Strings.Unbounded.To_String (Paths.Bin_Dir));
   end Resolve_Paths;

   function Run (Command_Arguments : Arguments.String_Vectors.Vector) return Boolean is
      Options     : Compile_Options;
      Source_Path : Ada.Strings.Unbounded.Unbounded_String;
      Paths       : Artifact_Paths;
      The_Module  : Modules.Module;
      Needs       : Backend_Needs;
      Result      : Boolean;
   begin
      --  Fresh filename pool for this compile; drop it when the command ends.
      Source.Clear_Filename_Pool;
      begin
         Result := Parse_Options (Command_Arguments, Options);
         if Result then
            Resolve_Paths (Options, Source_Path, Paths);
            Result := Run_Frontend (Options, Ada.Strings.Unbounded.To_String (Source_Path), Paths, The_Module);
         end if;
         if Result then
            Needs := Decide_Stale (Options, Paths);
            if Needs_Backend (Needs) then
               Result := Emit_Outputs (Needs, Ada.Strings.Unbounded.To_String (Source_Path), Paths, The_Module);
            else
               Terminal.Put_Info ("Artifacts up to date, skipping backend");
            end if;
         end if;
         if Result then
            Terminal.Put_Info ("Compile succeeded");
         end if;
      exception
         when others =>
            Source.Clear_Filename_Pool;
            raise;
      end;
      Source.Clear_Filename_Pool;
      return Result;
   end Run;

   function Run_Frontend
     (Options : Compile_Options; Source_Path : String; Paths : in out Artifact_Paths; The_Module : out Modules.Module)
      return Boolean
   is
      Source_Text : Ada.Strings.Unbounded.Unbounded_String;
      Result      : Boolean;
   begin
      Terminal.Put_Info ("Reading source " & Source_Path);
      Result := Read_Entire_File (Source_Path, Source_Text);
      if Result then
         Result :=
           Run_Tokenize_Stage (Options, Source_Path, Ada.Strings.Unbounded.To_String (Source_Text), Paths, The_Module);
      else
         Report_Located
           (Filename    => Source_Path,
            Span        => Origin_Span,
            Source_Text => "",
            Code        => Error_Codes.Source_File_Io,
            Description => "cannot read source file");
      end if;
      return Result;
   end Run_Frontend;

   function Run_Generate_Stage
     (Options     : Compile_Options;
      Source_Path : String;
      Source_Text : String;
      Units       : Unit_Graph.Compilation_Set;
      Paths       : Artifact_Paths;
      The_Module  : out Modules.Module) return Boolean
   is
      Lir_Path : constant String := Ada.Strings.Unbounded.To_String (Paths.Lir);
      Result   : Boolean;
   begin
      Report_Loaded_Units (Units);
      Result := Run_Semantics (Units, Options.The_Policy);
      if Result then
         if Frontend_Is_Stale (Options, Units, Lir_Path) then
            Result := Generate_Lir (Units, Source_Path, Source_Text, Lir_Path, The_Module);
         else
            Result := Read_Lir (Lir_Path, The_Module);
         end if;
      end if;
      if Result and then Options.Generate_Tlir then
         Result := Write_Tlir (The_Module, Ada.Strings.Unbounded.To_String (Paths.Tlir));
      end if;
      return Result;
   end Run_Generate_Stage;

   function Run_Load_Stage
     (Options     : Compile_Options;
      Source_Path : String;
      Source_Text : String;
      Root_Module : Ast.Module;
      Paths       : Artifact_Paths;
      The_Module  : out Modules.Module) return Boolean
   is
      Search_Roots : constant Module_Path.Path_Sequence :=
        Module_Path.Default_Search_Roots (Source_Path, Options.Include_Paths);
      Load_Result  : constant Unit_Graph.Load_Result :=
        Unit_Graph.Load
          (Root_Module      => Root_Module,
           Root_Source_Path => Source_Path,
           Root_Source_Text => Source_Text,
           Search_Roots     => Search_Roots,
           Active_Flavor    => Options.The_Flavor,
           Cli_Version      => Options.Module_Version);
      Result       : Boolean;
   begin
      if Load_Result.Ok then
         Result := Run_Generate_Stage (Options, Source_Path, Source_Text, Load_Result.Units, Paths, The_Module);
      else
         Result := False;
         Report_Located
           (Filename    => Ada.Strings.Unbounded.To_String (Load_Result.Error.Filename),
            Span        => Load_Result.Error.Span,
            Source_Text => Ada.Strings.Unbounded.To_String (Load_Result.Error.Source_Text),
            Code        => Unit_Graph.Surface_Error_Code (Load_Result.Error),
            Description => Ada.Strings.Unbounded.To_String (Load_Result.Error.Detail));
      end if;
      return Result;
   end Run_Load_Stage;

   function Run_Parse_Stage
     (Options      : Compile_Options;
      Source_Path  : String;
      Source_Text  : String;
      Token_Result : Tokenizer.Tokenize_Result;
      Paths        : in out Artifact_Paths;
      The_Module   : out Modules.Module) return Boolean
   is
      Parse_Result : constant Parser.Parse_Result :=
        Parser.Parse (Source_Text, Token_Result.Tokens, Options.The_Flavor);
      Result       : Boolean := Parse_Result.Ok;
   begin
      Terminal.Put_Info ("Parsing");
      if Parse_Result.Ok then
         Result := Check_Unit_Name (Parse_Result.The_Module, Source_Path, Source_Text);
      else
         Report_Parser_Errors (Parse_Result, Source_Path, Source_Text);
      end if;
      if Result then
         Set_Program_Paths (Paths, Ast.Name (Parse_Result.The_Module));
         Result := Run_Load_Stage (Options, Source_Path, Source_Text, Parse_Result.The_Module, Paths, The_Module);
      end if;
      return Result;
   end Run_Parse_Stage;

   function Run_Semantics (Units : Unit_Graph.Compilation_Set; The_Policy : Diagnostics.Policy) return Boolean is
      use type Error_Codes.Severity;

      Failed : Boolean := False;
   begin
      Terminal.Put_Info ("Analyzing semantics");
      declare
         Analysis : constant Semantics.Analysis_Result := Semantics.Analyze (Units);
      begin
         for Index in 1 .. Natural (Analysis.Warnings.Length) loop
            declare
               Item : constant Semantics.Diagnostic := Analysis.Warnings.Element (Index);
               Unit : constant Unit_Graph.Loaded_Unit := Units.Element (Item.Unit_Index);
               Code : constant Error_Codes.Error_Code := Reporting.To_Error_Code (Item.Code);
            begin
               if not Diagnostics.Is_Suppressed (The_Policy, Code) then
                  Report_Located
                    (Filename    => Ada.Strings.Unbounded.To_String (Unit.Source_Path),
                     Span        => Item.Span,
                     Source_Text => Ada.Strings.Unbounded.To_String (Unit.Source_Text),
                     Code        => Code,
                     Description => Ada.Strings.Unbounded.To_String (Item.Detail),
                     The_Policy  => The_Policy);
                  if Diagnostics.Effective_Severity (Code, The_Policy) = Error_Codes.Error then
                     Failed := True;
                  end if;
               end if;
            end;
         end loop;

         for Index in 1 .. Natural (Analysis.Errors.Length) loop
            declare
               Item : constant Semantics.Diagnostic := Analysis.Errors.Element (Index);
               Unit : constant Unit_Graph.Loaded_Unit := Units.Element (Item.Unit_Index);
            begin
               Report_Located
                 (Filename    => Ada.Strings.Unbounded.To_String (Unit.Source_Path),
                  Span        => Item.Span,
                  Source_Text => Ada.Strings.Unbounded.To_String (Unit.Source_Text),
                  Code        => Reporting.To_Error_Code (Item.Code),
                  Description => Ada.Strings.Unbounded.To_String (Item.Detail),
                  The_Policy  => The_Policy);
               Failed := True;
            end;
         end loop;

         return not Failed;
      end;
   end Run_Semantics;

   function Run_Tokenize_Stage
     (Options     : Compile_Options;
      Source_Path : String;
      Source_Text : String;
      Paths       : in out Artifact_Paths;
      The_Module  : out Modules.Module) return Boolean
   is
      Result : Boolean;
   begin
      Terminal.Put_Info ("Tokenizing");
      declare
         Token_Result : constant Tokenizer.Tokenize_Result := Tokenizer.Tokenize (Source_Text, Source_Path);
      begin
         Result := Token_Result.Ok;
         if Token_Result.Ok then
            Result := Run_Parse_Stage (Options, Source_Path, Source_Text, Token_Result, Paths, The_Module);
         else
            Report_Tokenizer_Errors (Token_Result, Source_Path, Source_Text);
         end if;
      end;
      return Result;
   end Run_Tokenize_Stage;

   procedure Set_Program_Paths (Paths : in out Artifact_Paths; Program_Name : String) is
      Obj_Dir : constant String := Ada.Strings.Unbounded.To_String (Paths.Obj_Dir);
      Bin_Dir : constant String := Ada.Strings.Unbounded.To_String (Paths.Bin_Dir);
   begin
      Paths.Lir := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Obj_Dir, Program_Name & ".lir"));
      Paths.Tlir := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Obj_Dir, Program_Name & ".tlir"));
      Paths.Wasm := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Bin_Dir, Program_Name & ".wasm"));
      Paths.Wat := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Bin_Dir, Program_Name & ".wat"));
      Paths.Wit := Ada.Strings.Unbounded.To_Unbounded_String (Compose_Path (Bin_Dir, Program_Name & ".wit"));
   end Set_Program_Paths;

   function Try_Apply_No_Warnings
     (Text : String; The_Policy : in out Diagnostics.Policy; Detail : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean
   is
      First : Positive := Text'First;

      function Apply_One_Entry
        (Slice : String; The_Policy : in out Diagnostics.Policy; Detail : out Ada.Strings.Unbounded.Unbounded_String)
         return Boolean;
      --  Parse and suppress one trimmed LV label; set Detail on failure.

      function Next_Comma (From : Positive) return Natural;
      --  Index of the next ',' in Text at or after From, or 0.

      function Apply_One_Entry
        (Slice : String; The_Policy : in out Diagnostics.Policy; Detail : out Ada.Strings.Unbounded.Unbounded_String)
         return Boolean
      is
         Entry_Text : constant String := Ada.Strings.Fixed.Trim (Slice, Ada.Strings.Both);
         Code       : Error_Codes.Error_Code;
         Ok         : Boolean;
      begin
         if Entry_Text'Length = 0 then
            Detail := Ada.Strings.Unbounded.To_Unbounded_String ("--no-warnings entry is empty");
            return False;
         end if;

         if not Error_Codes.Try_From_Label (Entry_Text, Code) then
            Detail :=
              Ada.Strings.Unbounded.To_Unbounded_String
                ("unknown warning code '" & Entry_Text & "'");
            return False;
         end if;

         Diagnostics.Suppress_Warning (The_Policy, Code, Ok);
         if not Ok then
            Detail :=
              Ada.Strings.Unbounded.To_Unbounded_String
                ("'" & Entry_Text & "' is not a warning code");
            return False;
         end if;

         return True;
      end Apply_One_Entry;

      function Next_Comma (From : Positive) return Natural is
      begin
         for Index in From .. Text'Last loop
            if Text (Index) = ',' then
               return Index;
            end if;
         end loop;
         return 0;
      end Next_Comma;
   begin
      Detail := Ada.Strings.Unbounded.Null_Unbounded_String;

      if Text'Length = 0 then
         Detail := Ada.Strings.Unbounded.To_Unbounded_String ("--no-warnings list must contain at least one LV id");
         return False;
      end if;

      loop
         declare
            Comma      : constant Natural := Next_Comma (First);
            Slice_Last : constant Natural :=
              (if Comma = 0 then Text'Last else Comma - 1);
         begin
            if not Apply_One_Entry (Text (First .. Slice_Last), The_Policy, Detail) then
               return False;
            end if;

            exit when Comma = 0;
            First := Comma + 1;
            if First > Text'Last then
               Detail := Ada.Strings.Unbounded.To_Unbounded_String ("--no-warnings entry is empty");
               return False;
            end if;
         end;
      end loop;

      return True;
   end Try_Apply_No_Warnings;

   function Try_Parse_Output_Format (Text : String; Format_Set : out Output_Format_Set) return Boolean is
   begin
      if Text = "wasm" then
         Format_Set := (Want_Wasm => True, Want_Wat => False);
         return True;
      elsif Text = "wat" then
         Format_Set := (Want_Wasm => False, Want_Wat => True);
         return True;
      elsif Text = "wasm,wat" or else Text = "wat,wasm" then
         Format_Set := (Want_Wasm => True, Want_Wat => True);
         return True;
      else
         return False;
      end if;
   end Try_Parse_Output_Format;

   function Write_Bytes (Path : String; Bytes : Backend.Byte_Sequence) return Boolean is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
   begin
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      if Backend.Length (Bytes) > 0 then
         declare
            Buffer  :
              Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Backend.Length (Bytes)));
            Written : Integer;
         begin
            for Index in 1 .. Backend.Length (Bytes) loop
               Buffer (Ada.Streams.Stream_Element_Offset (Index)) :=
                 Ada.Streams.Stream_Element (Backend.Element (Bytes, Index));
            end loop;
            Written := GNAT.OS_Lib.Write (Descriptor, Buffer'Address, Buffer'Length);
            if Written /= Integer (Buffer'Length) then
               GNAT.OS_Lib.Close (Descriptor);
               return False;
            end if;
         end;
      end if;

      GNAT.OS_Lib.Close (Descriptor);
      return True;
   end Write_Bytes;

   function Write_Text (Path : String; Text : String) return Boolean is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
   begin
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      if Text'Length > 0 then
         declare
            Buffer  : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
            Written : Integer;
         begin
            for Index in Text'Range loop
               Buffer (Ada.Streams.Stream_Element_Offset (Index - Text'First + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Text (Index)));
            end loop;
            Written := GNAT.OS_Lib.Write (Descriptor, Buffer'Address, Buffer'Length);
            if Written /= Integer (Buffer'Length) then
               GNAT.OS_Lib.Close (Descriptor);
               return False;
            end if;
         end;
      end if;

      GNAT.OS_Lib.Close (Descriptor);
      return True;
   end Write_Text;

   function Write_Tlir (The_Module : Modules.Module; Tlir_Path : String) return Boolean is
      Result : Boolean;
   begin
      Terminal.Put_Info ("Writing " & Tlir_Path);
      Result := Lir_Text.Write (The_Module, Tlir_Path).Ok;
      if not Result then
         Report_Cli_Error ("failed to write textual LIR file " & Tlir_Path);
      end if;
      return Result;
   end Write_Tlir;

end Lovelace.Main.Compile;
