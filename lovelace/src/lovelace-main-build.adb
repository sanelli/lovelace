with Ada.Calendar;
with Ada.Directories;
with Ada.Streams;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Backend;
with Lovelace.Compiler.Backend.Wasm;
with Lovelace.Compiler.Backend.Wat;
with Lovelace.Compiler.Diagnostics;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Ir_Generator;
with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Reporting;
with Lovelace.Compiler.Tokenizer;
with Lovelace.Lir.Binary;
with Lovelace.Lir.Modules;
with Lovelace.Main.Terminal;

package body Lovelace.Main.Build is

   use type Ada.Calendar.Time;
   use type GNAT.OS_Lib.File_Descriptor;

   package Source renames Lovelace.Common.Source;
   package Ast renames Lovelace.Compiler.Ast;
   package Backend renames Lovelace.Compiler.Backend;
   package Backend_Wasm renames Lovelace.Compiler.Backend.Wasm;
   package Backend_Wat renames Lovelace.Compiler.Backend.Wat;
   package Diagnostics renames Lovelace.Compiler.Diagnostics;
   package Error_Codes renames Lovelace.Compiler.Error_Codes;
   package Ir_Generator renames Lovelace.Compiler.Ir_Generator;
   package Parser renames Lovelace.Compiler.Parser;
   package Reporting renames Lovelace.Compiler.Reporting;
   package Tokenizer renames Lovelace.Compiler.Tokenizer;
   package Lir_Binary renames Lovelace.Lir.Binary;
   package Modules renames Lovelace.Lir.Modules;

   type Output_Format_Set is record
      Want_Wasm : Boolean := True;
      Want_Wat  : Boolean := False;
   end record;

   type Build_Options is record
      Source_Path   : Ada.Strings.Unbounded.Unbounded_String;
      Output_Root   : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String (".output");
      No_Wit        : Boolean := False;
      Output_Format : Output_Format_Set;
   end record;

   function Compose_Path (Left, Right : String) return String;
   function File_Is_Newer_Or_Equal
     (Candidate, Reference : String) return Boolean;
   function Is_Stale (Output_Path, Input_Path : String) return Boolean;
   function Parse_Options
     (Command_Arguments : Arguments.String_Vectors.Vector;
      Options           : out Build_Options) return Boolean;
   function Parse_Output_Format
     (Text : String; Format_Set : out Output_Format_Set) return Boolean;
   function Read_Entire_File
     (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;
   procedure Report_Cli_Error (Description : String);
   procedure Report_Located
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String);
   function Write_Bytes
     (Path : String; Bytes : Backend.Byte_Sequence) return Boolean;
   function Write_Text (Path : String; Text : String) return Boolean;

   function Compose_Path (Left, Right : String) return String is
   begin
      return Ada.Directories.Compose (Left, Right);
   end Compose_Path;

   function File_Is_Newer_Or_Equal
     (Candidate, Reference : String) return Boolean is
   begin
      if not Ada.Directories.Exists (Candidate) then
         return False;
      end if;
      if not Ada.Directories.Exists (Reference) then
         return True;
      end if;
      return
        Ada.Directories.Modification_Time (Candidate)
        >= Ada.Directories.Modification_Time (Reference);
   end File_Is_Newer_Or_Equal;

   function Is_Stale (Output_Path, Input_Path : String) return Boolean is
   begin
      return not File_Is_Newer_Or_Equal (Output_Path, Input_Path);
   end Is_Stale;

   function Parse_Options
     (Command_Arguments : Arguments.String_Vectors.Vector;
      Options           : out Build_Options) return Boolean
   is
      Index          : Positive := 1;
      Have_Source    : Boolean := False;
      Argument_Count : constant Natural := Natural (Command_Arguments.Length);
   begin
      Options :=
        (Source_Path   => Ada.Strings.Unbounded.Null_Unbounded_String,
         Output_Root   =>
           Ada.Strings.Unbounded.To_Unbounded_String (".output"),
         No_Wit        => False,
         Output_Format => (Want_Wasm => True, Want_Wat => False));

      while Index <= Argument_Count loop
         declare
            Token : constant String := Command_Arguments.Element (Index);
         begin
            if Token = "--no-wit" then
               Options.No_Wit := True;
               Index := Index + 1;
            elsif Token = "--output-format" then
               if Index >= Argument_Count then
                  Report_Cli_Error ("--output-format requires a value");
                  return False;
               end if;
               declare
                  Format_Text : constant String :=
                    Command_Arguments.Element (Index + 1);
                  Format_Set  : Output_Format_Set;
               begin
                  if not Parse_Output_Format (Format_Text, Format_Set) then
                     Report_Cli_Error
                       ("invalid --output-format '" & Format_Text & "'");
                     return False;
                  end if;
                  Options.Output_Format := Format_Set;
               end;
               Index := Index + 2;
            elsif Token = "--output-folder" then
               if Index >= Argument_Count then
                  Report_Cli_Error ("--output-folder requires a path");
                  return False;
               end if;
               Options.Output_Root :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Command_Arguments.Element (Index + 1));
               Index := Index + 2;
            elsif Token'Length >= 2
              and then Token (Token'First .. Token'First + 1) = "--"
            then
               Report_Cli_Error ("unknown build option '" & Token & "'");
               return False;
            else
               if Have_Source then
                  Report_Cli_Error
                    ("unexpected extra argument '" & Token & "'");
                  return False;
               end if;
               Options.Source_Path :=
                 Ada.Strings.Unbounded.To_Unbounded_String (Token);
               Have_Source := True;
               Index := Index + 1;
            end if;
         end;
      end loop;

      if not Have_Source then
         Report_Cli_Error
           ("missing .love source file (future builds may use .pjlove/.slnlove)");
         return False;
      end if;
      return True;
   end Parse_Options;

   function Parse_Output_Format
     (Text : String; Format_Set : out Output_Format_Set) return Boolean is
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
   end Parse_Output_Format;

   function Read_Entire_File
     (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean
   is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      Contents := Ada.Strings.Unbounded.Null_Unbounded_String;
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      declare
         File_Size : constant Long_Integer :=
           GNAT.OS_Lib.File_Length (Descriptor);
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
                    Integer
                      (Long_Integer'Min
                         (Remaining_Bytes, Long_Integer (Chunk'Length))));
               if Bytes_Read <= 0 then
                  GNAT.OS_Lib.Close (Descriptor);
                  return False;
               end if;
               for Offset in 1 .. Bytes_Read loop
                  Ada.Strings.Unbounded.Append
                    (Contents,
                     Character'Val
                       (Natural
                          (Chunk
                             (Ada.Streams.Stream_Element_Offset (Offset)))));
               end loop;
               Remaining_Bytes := Remaining_Bytes - Long_Integer (Bytes_Read);
            end loop;
         end;
      end;

      GNAT.OS_Lib.Close (Descriptor);
      return True;
   end Read_Entire_File;

   procedure Report_Cli_Error (Description : String) is
      Text : constant String :=
        "[err] build"
        & ASCII.LF
        & ASCII.LF
        & ASCII.LF
        & Description
        & ASCII.LF;
   begin
      Terminal.Put_Error_Text (Text);
   end Report_Cli_Error;

   procedure Report_Located
     (Filename    : String;
      Span        : Source.Source_Span;
      Source_Text : String;
      Code        : Error_Codes.Error_Code;
      Description : String) is
   begin
      Terminal.Put_Error_Text
        (Diagnostics.Format (Filename, Span, Source_Text, Code, Description));
   end Report_Located;

   function Run
     (Command_Arguments : Arguments.String_Vectors.Vector) return Boolean
   is
      Options       : Build_Options;
      Source_Path   : Ada.Strings.Unbounded.Unbounded_String;
      Output_Root   : Ada.Strings.Unbounded.Unbounded_String;
      Obj_Dir       : Ada.Strings.Unbounded.Unbounded_String;
      Bin_Dir       : Ada.Strings.Unbounded.Unbounded_String;
      Program_Name  : Ada.Strings.Unbounded.Unbounded_String;
      Lir_Path      : Ada.Strings.Unbounded.Unbounded_String;
      Wasm_Path     : Ada.Strings.Unbounded.Unbounded_String;
      Wat_Path      : Ada.Strings.Unbounded.Unbounded_String;
      Wit_Path      : Ada.Strings.Unbounded.Unbounded_String;
      Source_Text   : Ada.Strings.Unbounded.Unbounded_String;
      The_Module    : Modules.Module;
      Need_Frontend : Boolean;
      Need_Wasm     : Boolean;
      Need_Wat      : Boolean;
      Need_Wit      : Boolean;
      Wit_Text      : Ada.Strings.Unbounded.Unbounded_String;
      Have_Wit_Text : Boolean := False;
   begin
      if not Parse_Options (Command_Arguments, Options) then
         return False;
      end if;

      Source_Path := Options.Source_Path;
      Output_Root := Options.Output_Root;
      Obj_Dir :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Compose_Path
             (Ada.Strings.Unbounded.To_String (Output_Root), "obj"));
      Bin_Dir :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Compose_Path
             (Ada.Strings.Unbounded.To_String (Output_Root), "bin"));

      Ada.Directories.Create_Path (Ada.Strings.Unbounded.To_String (Obj_Dir));
      Ada.Directories.Create_Path (Ada.Strings.Unbounded.To_String (Bin_Dir));

      Program_Name :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Reporting.Love_Basename
             (Ada.Strings.Unbounded.To_String (Source_Path)));
      Lir_Path :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Compose_Path
             (Ada.Strings.Unbounded.To_String (Obj_Dir),
              Ada.Strings.Unbounded.To_String (Program_Name) & ".lir"));
      Wasm_Path :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Compose_Path
             (Ada.Strings.Unbounded.To_String (Bin_Dir),
              Ada.Strings.Unbounded.To_String (Program_Name) & ".wasm"));
      Wat_Path :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Compose_Path
             (Ada.Strings.Unbounded.To_String (Bin_Dir),
              Ada.Strings.Unbounded.To_String (Program_Name) & ".wat"));
      Wit_Path :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Compose_Path
             (Ada.Strings.Unbounded.To_String (Bin_Dir),
              Ada.Strings.Unbounded.To_String (Program_Name) & ".wit"));

      Need_Frontend :=
        Is_Stale
          (Ada.Strings.Unbounded.To_String (Lir_Path),
           Ada.Strings.Unbounded.To_String (Source_Path));

      if Need_Frontend then
         Terminal.Put_Info
           ("Reading source " & Ada.Strings.Unbounded.To_String (Source_Path));
         if not Read_Entire_File
                  (Ada.Strings.Unbounded.To_String (Source_Path), Source_Text)
         then
            Report_Located
              (Filename    => Ada.Strings.Unbounded.To_String (Source_Path),
               Span        =>
                 (First => (Byte_Index => 1, Line => 1, Column => 1),
                  Last  => (Byte_Index => 1, Line => 1, Column => 1)),
               Source_Text => "",
               Code        => Error_Codes.Source_File_Io,
               Description => "cannot read source file");
            return False;
         end if;

         Terminal.Put_Info ("Tokenizing");
         declare
            Token_Result : constant Tokenizer.Tokenize_Result :=
              Tokenizer.Tokenize
                (Ada.Strings.Unbounded.To_String (Source_Text),
                 Ada.Strings.Unbounded.To_String (Source_Path));
         begin
            case Token_Result.Ok is
               when False =>
                  for Error_Index in
                    1 .. Tokenizer.Length (Token_Result.Errors)
                  loop
                     declare
                        Item : constant Tokenizer.Tokenizer_Error :=
                          Tokenizer.Element (Token_Result.Errors, Error_Index);
                        Name : constant String :=
                          (if Item.Filename.Present
                           then Source.To_Utf_8 (Item.Filename)
                           else Ada.Strings.Unbounded.To_String (Source_Path));
                     begin
                        Report_Located
                          (Filename    => Name,
                           Span        => Item.Span,
                           Source_Text =>
                             Ada.Strings.Unbounded.To_String (Source_Text),
                           Code        => Reporting.To_Error_Code (Item.Code),
                           Description =>
                             Ada.Strings.Unbounded.To_String (Item.Detail));
                     end;
                  end loop;
                  return False;

               when True  =>
                  Terminal.Put_Info ("Parsing");
                  declare
                     Parse_Result : constant Parser.Parse_Result :=
                       Parser.Parse
                         (Ada.Strings.Unbounded.To_String (Source_Text),
                          Token_Result.Tokens);
                  begin
                     case Parse_Result.Ok is
                        when False =>
                           for Error_Index in
                             1 .. Parser.Length (Parse_Result.Errors)
                           loop
                              declare
                                 Item : constant Parser.Parser_Error :=
                                   Parser.Element
                                     (Parse_Result.Errors, Error_Index);
                                 Name : constant String :=
                                   (if Item.Filename.Present
                                    then Source.To_Utf_8 (Item.Filename)
                                    else
                                      Ada.Strings.Unbounded.To_String
                                        (Source_Path));
                              begin
                                 Report_Located
                                   (Filename    => Name,
                                    Span        => Item.Span,
                                    Source_Text =>
                                      Ada.Strings.Unbounded.To_String
                                        (Source_Text),
                                    Code        =>
                                      Reporting.To_Error_Code (Item.Code),
                                    Description =>
                                      Ada.Strings.Unbounded.To_String
                                        (Item.Detail));
                              end;
                           end loop;
                           return False;

                        when True  =>
                           if not Reporting.Program_Name_Matches_File
                                    (Parse_Result.The_Module,
                                     Ada.Strings.Unbounded.To_String
                                       (Source_Path))
                           then
                              Report_Located
                                (Filename    =>
                                   Ada.Strings.Unbounded.To_String
                                     (Source_Path),
                                 Span        =>
                                   Ast.Name_Span (Parse_Result.The_Module),
                                 Source_Text =>
                                   Ada.Strings.Unbounded.To_String
                                     (Source_Text),
                                 Code        =>
                                   Error_Codes.Program_Name_Filename_Mismatch,
                                 Description =>
                                   "program identifier '"
                                   & Ast.Name (Parse_Result.The_Module)
                                   & "' does not match file stem '"
                                   & Reporting.Love_Basename
                                       (Ada.Strings.Unbounded.To_String
                                          (Source_Path))
                                   & "'");
                              return False;
                           end if;

                           Program_Name :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Ast.Name (Parse_Result.The_Module));
                           Lir_Path :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Compose_Path
                                  (Ada.Strings.Unbounded.To_String (Obj_Dir),
                                   Ada.Strings.Unbounded.To_String
                                     (Program_Name)
                                   & ".lir"));
                           Wasm_Path :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Compose_Path
                                  (Ada.Strings.Unbounded.To_String (Bin_Dir),
                                   Ada.Strings.Unbounded.To_String
                                     (Program_Name)
                                   & ".wasm"));
                           Wat_Path :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Compose_Path
                                  (Ada.Strings.Unbounded.To_String (Bin_Dir),
                                   Ada.Strings.Unbounded.To_String
                                     (Program_Name)
                                   & ".wat"));
                           Wit_Path :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Compose_Path
                                  (Ada.Strings.Unbounded.To_String (Bin_Dir),
                                   Ada.Strings.Unbounded.To_String
                                     (Program_Name)
                                   & ".wit"));

                           Terminal.Put_Info ("Generating LIR");
                           declare
                              Generate_Result :
                                constant Ir_Generator.Generate_Result :=
                                  Ir_Generator.Generate
                                    (Parse_Result.The_Module);
                           begin
                              case Generate_Result.Ok is
                                 when False =>
                                    Report_Located
                                      (Filename    =>
                                         Ada.Strings.Unbounded.To_String
                                           (Source_Path),
                                       Span        =>
                                         Ast.Name_Span
                                           (Parse_Result.The_Module),
                                       Source_Text =>
                                         Ada.Strings.Unbounded.To_String
                                           (Source_Text),
                                       Code        =>
                                         Reporting.To_Error_Code
                                           (Generate_Result.Error.Code),
                                       Description =>
                                         Ada.Strings.Unbounded.To_String
                                           (Generate_Result.Error.Detail));
                                    return False;

                                 when True  =>
                                    The_Module := Generate_Result.The_Module;
                                    Terminal.Put_Info
                                      ("Writing "
                                       & Ada.Strings.Unbounded.To_String
                                           (Lir_Path));
                                    declare
                                       Written :
                                         constant Lir_Binary.Write_Result :=
                                           Lir_Binary.Write
                                             (The_Module,
                                              Ada.Strings.Unbounded.To_String
                                                (Lir_Path));
                                    begin
                                       case Written.Ok is
                                          when False =>
                                             Report_Cli_Error
                                               ("failed to write LIR file "
                                                & Ada
                                                    .Strings
                                                    .Unbounded
                                                    .To_String (Lir_Path));
                                             return False;

                                          when True  =>
                                             null;
                                       end case;
                                    end;
                              end case;
                           end;
                     end case;
                  end;
            end case;
         end;
      else
         Terminal.Put_Info ("LIR up to date, skipping frontend");
         declare
            Decoded : constant Lir_Binary.Decode_Result :=
              Lir_Binary.Read (Ada.Strings.Unbounded.To_String (Lir_Path));
         begin
            case Decoded.Ok is
               when False =>
                  Report_Cli_Error
                    ("failed to read LIR file "
                     & Ada.Strings.Unbounded.To_String (Lir_Path));
                  return False;

               when True  =>
                  The_Module := Decoded.Value;
                  Program_Name :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      (Modules.Name (The_Module));
                  Lir_Path :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      (Compose_Path
                         (Ada.Strings.Unbounded.To_String (Obj_Dir),
                          Ada.Strings.Unbounded.To_String (Program_Name)
                          & ".lir"));
                  Wasm_Path :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      (Compose_Path
                         (Ada.Strings.Unbounded.To_String (Bin_Dir),
                          Ada.Strings.Unbounded.To_String (Program_Name)
                          & ".wasm"));
                  Wat_Path :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      (Compose_Path
                         (Ada.Strings.Unbounded.To_String (Bin_Dir),
                          Ada.Strings.Unbounded.To_String (Program_Name)
                          & ".wat"));
                  Wit_Path :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      (Compose_Path
                         (Ada.Strings.Unbounded.To_String (Bin_Dir),
                          Ada.Strings.Unbounded.To_String (Program_Name)
                          & ".wit"));
            end case;
         end;
      end if;

      Need_Wasm :=
        Options.Output_Format.Want_Wasm
        and then Is_Stale
                   (Ada.Strings.Unbounded.To_String (Wasm_Path),
                    Ada.Strings.Unbounded.To_String (Lir_Path));
      Need_Wat :=
        Options.Output_Format.Want_Wat
        and then Is_Stale
                   (Ada.Strings.Unbounded.To_String (Wat_Path),
                    Ada.Strings.Unbounded.To_String (Lir_Path));
      Need_Wit :=
        not Options.No_Wit
        and then Is_Stale
                   (Ada.Strings.Unbounded.To_String (Wit_Path),
                    Ada.Strings.Unbounded.To_String (Lir_Path));

      if not Need_Wasm and then not Need_Wat and then not Need_Wit then
         Terminal.Put_Info ("Artifacts up to date, skipping backend");
         Terminal.Put_Info ("Build succeeded");
         return True;
      end if;

      if Need_Wasm or else (Need_Wit and then not Need_Wat) then
         Terminal.Put_Info ("Emitting WASM");
         declare
            Emit_Result : constant Backend.Wasm_Emit_Result :=
              Backend_Wasm.Emit_Wasm (The_Module);
         begin
            case Emit_Result.Ok is
               when False =>
                  Report_Located
                    (Filename    =>
                       Ada.Strings.Unbounded.To_String (Source_Path),
                     Span        =>
                       (First => (Byte_Index => 1, Line => 1, Column => 1),
                        Last  => (Byte_Index => 1, Line => 1, Column => 1)),
                     Source_Text => "",
                     Code        =>
                       Reporting.To_Error_Code (Emit_Result.Error.Code),
                     Description =>
                       Ada.Strings.Unbounded.To_String
                         (Emit_Result.Error.Detail));
                  return False;

               when True  =>
                  if Need_Wasm then
                     if not Write_Bytes
                              (Ada.Strings.Unbounded.To_String (Wasm_Path),
                               Emit_Result.Wasm_Bytes)
                     then
                        Report_Cli_Error
                          ("failed to write "
                           & Ada.Strings.Unbounded.To_String (Wasm_Path));
                        return False;
                     end if;
                  end if;
                  Wit_Text := Emit_Result.Wit_Text;
                  Have_Wit_Text := True;
            end case;
         end;
      end if;

      if Need_Wat then
         Terminal.Put_Info ("Emitting WAT");
         declare
            Emit_Result : constant Backend.Wat_Emit_Result :=
              Backend_Wat.Emit_Wat (The_Module);
         begin
            case Emit_Result.Ok is
               when False =>
                  Report_Located
                    (Filename    =>
                       Ada.Strings.Unbounded.To_String (Source_Path),
                     Span        =>
                       (First => (Byte_Index => 1, Line => 1, Column => 1),
                        Last  => (Byte_Index => 1, Line => 1, Column => 1)),
                     Source_Text => "",
                     Code        =>
                       Reporting.To_Error_Code (Emit_Result.Error.Code),
                     Description =>
                       Ada.Strings.Unbounded.To_String
                         (Emit_Result.Error.Detail));
                  return False;

               when True  =>
                  if not Write_Text
                           (Ada.Strings.Unbounded.To_String (Wat_Path),
                            Ada.Strings.Unbounded.To_String
                              (Emit_Result.Wat_Text))
                  then
                     Report_Cli_Error
                       ("failed to write "
                        & Ada.Strings.Unbounded.To_String (Wat_Path));
                     return False;
                  end if;
                  if not Have_Wit_Text then
                     Wit_Text := Emit_Result.Wit_Text;
                     Have_Wit_Text := True;
                  end if;
            end case;
         end;
      end if;

      if Need_Wit then
         if not Have_Wit_Text then
            Terminal.Put_Info ("Emitting WIT");
            declare
               Emit_Result : constant Backend.Wat_Emit_Result :=
                 Backend_Wat.Emit_Wat (The_Module);
            begin
               case Emit_Result.Ok is
                  when False =>
                     Report_Located
                       (Filename    =>
                          Ada.Strings.Unbounded.To_String (Source_Path),
                        Span        =>
                          (First => (Byte_Index => 1, Line => 1, Column => 1),
                           Last  => (Byte_Index => 1, Line => 1, Column => 1)),
                        Source_Text => "",
                        Code        =>
                          Reporting.To_Error_Code (Emit_Result.Error.Code),
                        Description =>
                          Ada.Strings.Unbounded.To_String
                            (Emit_Result.Error.Detail));
                     return False;

                  when True  =>
                     Wit_Text := Emit_Result.Wit_Text;
                     Have_Wit_Text := True;
               end case;
            end;
         else
            Terminal.Put_Info ("Writing WIT");
         end if;

         if not Write_Text
                  (Ada.Strings.Unbounded.To_String (Wit_Path),
                   Ada.Strings.Unbounded.To_String (Wit_Text))
         then
            Report_Cli_Error
              ("failed to write "
               & Ada.Strings.Unbounded.To_String (Wit_Path));
            return False;
         end if;
      end if;

      Terminal.Put_Info ("Build succeeded");
      return True;
   end Run;

   function Write_Bytes
     (Path : String; Bytes : Backend.Byte_Sequence) return Boolean
   is
      Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
   begin
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      if Backend.Length (Bytes) > 0 then
         declare
            Buffer  :
              Ada.Streams.Stream_Element_Array
                (1
                 .. Ada.Streams.Stream_Element_Offset
                      (Backend.Length (Bytes)));
            Written : Integer;
         begin
            for Index in 1 .. Backend.Length (Bytes) loop
               Buffer (Ada.Streams.Stream_Element_Offset (Index)) :=
                 Ada.Streams.Stream_Element (Backend.Element (Bytes, Index));
            end loop;
            Written :=
              GNAT.OS_Lib.Write (Descriptor, Buffer'Address, Buffer'Length);
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
      Descriptor : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
   begin
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return False;
      end if;

      if Text'Length > 0 then
         declare
            Buffer  :
              Ada.Streams.Stream_Element_Array
                (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
            Written : Integer;
         begin
            for Index in Text'Range loop
               Buffer
                 (Ada.Streams.Stream_Element_Offset
                    (Index - Text'First + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Text (Index)));
            end loop;
            Written :=
              GNAT.OS_Lib.Write (Descriptor, Buffer'Address, Buffer'Length);
            if Written /= Integer (Buffer'Length) then
               GNAT.OS_Lib.Close (Descriptor);
               return False;
            end if;
         end;
      end if;

      GNAT.OS_Lib.Close (Descriptor);
      return True;
   end Write_Text;

end Lovelace.Main.Build;
