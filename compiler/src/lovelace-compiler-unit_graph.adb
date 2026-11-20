with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Streams;
with Ada.Strings.Hash;
with GNAT.OS_Lib;

with Lovelace.Compiler.Parser;
with Lovelace.Compiler.Reporting;
with Lovelace.Compiler.Tokenizer;

package body Lovelace.Compiler.Unit_Graph is

   use type GNAT.OS_Lib.File_Descriptor;
   use type Ast.Unit_Kind;

   package Name_Sets is new
     Ada.Containers.Indefinite_Hashed_Sets
       (Element_Type        => String,
        Hash                => Ada.Strings.Hash,
        Equivalent_Elements => "=");

   package Name_To_Index is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Positive,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

   function Failure
     (Code          : Unit_Graph_Error_Code;
      Span          : Source.Source_Span;
      Detail        : String;
      Filename      : String;
      Source_Text   : String;
      Frontend_Code : Error_Codes.Error_Code := Error_Codes.Internal_Error)
      return Load_Result;

   function Load_Dependency
     (Module_Name    : String;
      Import_Span    : Source.Source_Span;
      Importer_Path  : String;
      Importer_Text  : String;
      Search_Roots   : Module_Path.Path_Sequence;
      Active_Flavor  : Flavor.Flavor;
      Visiting       : in out Name_Sets.Set;
      Loaded_By_Name : in out Name_To_Index.Map;
      Units          : in out Compilation_Set) return Load_Result;

   function Read_Entire_File
     (Path : String; Contents : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   function Failure
     (Code          : Unit_Graph_Error_Code;
      Span          : Source.Source_Span;
      Detail        : String;
      Filename      : String;
      Source_Text   : String;
      Frontend_Code : Error_Codes.Error_Code := Error_Codes.Internal_Error)
      return Load_Result is
   begin
      return
        (Ok    => False,
         Error =>
           (Code          => Code,
            Span          => Span,
            Detail        =>
              Ada.Strings.Unbounded.To_Unbounded_String (Detail),
            Filename      =>
              Ada.Strings.Unbounded.To_Unbounded_String (Filename),
            Source_Text   =>
              Ada.Strings.Unbounded.To_Unbounded_String (Source_Text),
            Frontend_Code => Frontend_Code));
   end Failure;

   function Load
     (Root_Module      : Ast.Module;
      Root_Source_Path : String;
      Root_Source_Text : String;
      Search_Roots     : Module_Path.Path_Sequence;
      Active_Flavor    : Flavor.Flavor) return Load_Result
   is
      Units          : Compilation_Set;
      Visiting       : Name_Sets.Set;
      Loaded_By_Name : Name_To_Index.Map;
   begin
      Units.Append
        (Loaded_Unit'
           (The_Module  => Root_Module,
            Source_Path =>
              Ada.Strings.Unbounded.To_Unbounded_String (Root_Source_Path),
            Source_Text =>
              Ada.Strings.Unbounded.To_Unbounded_String (Root_Source_Text)));
      Loaded_By_Name.Insert (Ast.Name (Root_Module), 1);

      for Index in 1 .. Ast.Import_Count (Root_Module) loop
         declare
            The_Import : constant Ast.Import_Declaration :=
              Ast.Get_Import (Root_Module, Index);
            Nested     : constant Load_Result :=
              Load_Dependency
                (Module_Name    =>
                   Ada.Strings.Unbounded.To_String (The_Import.Module_Name),
                 Import_Span    => The_Import.Name_Span,
                 Importer_Path  => Root_Source_Path,
                 Importer_Text  => Root_Source_Text,
                 Search_Roots   => Search_Roots,
                 Active_Flavor  => Active_Flavor,
                 Visiting       => Visiting,
                 Loaded_By_Name => Loaded_By_Name,
                 Units          => Units);
         begin
            if not Nested.Ok then
               return Nested;
            end if;
         end;
      end loop;

      return (Ok => True, Units => Units);
   end Load;

   function Load_Dependency
     (Module_Name    : String;
      Import_Span    : Source.Source_Span;
      Importer_Path  : String;
      Importer_Text  : String;
      Search_Roots   : Module_Path.Path_Sequence;
      Active_Flavor  : Flavor.Flavor;
      Visiting       : in out Name_Sets.Set;
      Loaded_By_Name : in out Name_To_Index.Map;
      Units          : in out Compilation_Set) return Load_Result is
   begin
      if Loaded_By_Name.Contains (Module_Name) then
         return (Ok => True, Units => Loaded_Unit_Vectors.Empty_Vector);
      end if;

      if Visiting.Contains (Module_Name) then
         return
           Failure
             (Circular_Import,
              Import_Span,
              "circular import involving '" & Module_Name & "'",
              Importer_Path,
              Importer_Text);
      end if;

      Visiting.Include (Module_Name);

      declare
         Resolved : constant Module_Path.Resolve_Result :=
           Module_Path.Resolve_Module_File (Module_Name, Search_Roots);
      begin
         case Resolved.Status is
            when Module_Path.Not_Found =>
               Visiting.Exclude (Module_Name);
               return
                 Failure
                   (Unknown_Module,
                    Import_Span,
                    "unknown module '" & Module_Name & "'",
                    Importer_Path,
                    Importer_Text);

            when Module_Path.Ambiguous =>
               declare
                  Detail : Ada.Strings.Unbounded.Unbounded_String :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      ("ambiguous module path for '" & Module_Name & "':");
               begin
                  for Index in 1 .. Natural (Resolved.Matches.Length) loop
                     Ada.Strings.Unbounded.Append (Detail, " ");
                     Ada.Strings.Unbounded.Append
                       (Detail, Resolved.Matches.Element (Index));
                  end loop;
                  Visiting.Exclude (Module_Name);
                  return
                    Failure
                      (Ambiguous_Module_Path,
                       Import_Span,
                       Ada.Strings.Unbounded.To_String (Detail),
                       Importer_Path,
                       Importer_Text);
               end;

            when Module_Path.Unique    =>
               declare
                  Dep_Path : constant String :=
                    Ada.Strings.Unbounded.To_String (Resolved.Path);
                  Dep_Text : Ada.Strings.Unbounded.Unbounded_String;
               begin
                  if not Read_Entire_File (Dep_Path, Dep_Text) then
                     Visiting.Exclude (Module_Name);
                     return
                       Failure
                         (Source_File_Io,
                          Import_Span,
                          "cannot read module '"
                          & Module_Name
                          & "' from "
                          & Dep_Path,
                          Importer_Path,
                          Importer_Text);
                  end if;

                  declare
                     Source_String : constant String :=
                       Ada.Strings.Unbounded.To_String (Dep_Text);
                     Token_Result  : constant Tokenizer.Tokenize_Result :=
                       Tokenizer.Tokenize (Source_String, Dep_Path);
                  begin
                     if not Token_Result.Ok then
                        Visiting.Exclude (Module_Name);
                        declare
                           First_Error : constant Tokenizer.Tokenizer_Error :=
                             Tokenizer.Element (Token_Result.Errors, 1);
                        begin
                           return
                             Failure
                               (Frontend_Error,
                                First_Error.Span,
                                Ada.Strings.Unbounded.To_String
                                  (First_Error.Detail),
                                Dep_Path,
                                Source_String,
                                Reporting.To_Error_Code (First_Error.Code));
                        end;
                     end if;

                     declare
                        Parse_Result : constant Parser.Parse_Result :=
                          Parser.Parse
                            (Source_String,
                             Token_Result.Tokens,
                             Active_Flavor);
                     begin
                        if not Parse_Result.Ok then
                           Visiting.Exclude (Module_Name);
                           declare
                              First_Error : constant Parser.Parser_Error :=
                                Parser.Element (Parse_Result.Errors, 1);
                           begin
                              return
                                Failure
                                  (Frontend_Error,
                                   First_Error.Span,
                                   Ada.Strings.Unbounded.To_String
                                     (First_Error.Detail),
                                   Dep_Path,
                                   Source_String,
                                   (case First_Error.Code is
                                      when Parser.Internal_Error           =>
                                        Error_Codes.Internal_Error,
                                      when Parser.Unexpected_End_Of_Input  =>
                                        Error_Codes.Unexpected_End_Of_Input,
                                      when Parser.Unexpected_Token         =>
                                        Error_Codes.Unexpected_Token,
                                      when Parser.Unexpected_Trailing      =>
                                        Error_Codes.Unexpected_Trailing,
                                      when Parser.Name_Clash               =>
                                        Error_Codes.Name_Clash,
                                      when Parser.Invalid_Flavor_Condition =>
                                        Error_Codes.Invalid_Flavor_Condition));
                           end;
                        end if;

                        if Ast.Kind (Parse_Result.The_Module)
                          /= Ast.Module_Unit
                        then
                           Visiting.Exclude (Module_Name);
                           return
                             Failure
                               (Not_A_Module,
                                Import_Span,
                                "imported unit '"
                                & Module_Name
                                & "' must be a module, not a program",
                                Importer_Path,
                                Importer_Text);
                        end if;

                        if Ast.Name (Parse_Result.The_Module) /= Module_Name
                        then
                           Visiting.Exclude (Module_Name);
                           return
                             Failure
                               (Unit_Name_Mismatch,
                                Ast.Name_Span (Parse_Result.The_Module),
                                "module identifier '"
                                & Ast.Name (Parse_Result.The_Module)
                                & "' does not match imported name '"
                                & Module_Name
                                & "'",
                                Dep_Path,
                                Source_String);
                        end if;

                        for Index in
                          1 .. Ast.Import_Count (Parse_Result.The_Module)
                        loop
                           declare
                              The_Import : constant Ast.Import_Declaration :=
                                Ast.Get_Import
                                  (Parse_Result.The_Module, Index);
                              Nested     : constant Load_Result :=
                                Load_Dependency
                                  (Module_Name    =>
                                     Ada.Strings.Unbounded.To_String
                                       (The_Import.Module_Name),
                                   Import_Span    => The_Import.Name_Span,
                                   Importer_Path  => Dep_Path,
                                   Importer_Text  => Source_String,
                                   Search_Roots   => Search_Roots,
                                   Active_Flavor  => Active_Flavor,
                                   Visiting       => Visiting,
                                   Loaded_By_Name => Loaded_By_Name,
                                   Units          => Units);
                           begin
                              if not Nested.Ok then
                                 Visiting.Exclude (Module_Name);
                                 return Nested;
                              end if;
                           end;
                        end loop;

                        Units.Append
                          (Loaded_Unit'
                             (The_Module  => Parse_Result.The_Module,
                              Source_Path =>
                                Ada.Strings.Unbounded.To_Unbounded_String
                                  (Dep_Path),
                              Source_Text => Dep_Text));
                        Loaded_By_Name.Insert
                          (Module_Name, Positive (Units.Length));
                        Visiting.Exclude (Module_Name);
                        return
                          (Ok    => True,
                           Units => Loaded_Unit_Vectors.Empty_Vector);
                     end;
                  end;
               end;
         end case;
      end;
   end Load_Dependency;

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

   function Surface_Error_Code
     (Error : Unit_Graph_Error) return Error_Codes.Error_Code is
   begin
      case Error.Code is
         when Internal_Error        =>
            return Error_Codes.Internal_Error;

         when Unknown_Module        =>
            return Error_Codes.Unknown_Module;

         when Ambiguous_Module_Path =>
            return Error_Codes.Ambiguous_Module_Path;

         when Circular_Import       =>
            return Error_Codes.Circular_Import;

         when Not_A_Module          =>
            return Error_Codes.Invalid_Module;

         when Unit_Name_Mismatch    =>
            return Error_Codes.Program_Name_Filename_Mismatch;

         when Source_File_Io        =>
            return Error_Codes.Source_File_Io;

         when Frontend_Error        =>
            return Error.Frontend_Code;
      end case;
   end Surface_Error_Code;

end Lovelace.Compiler.Unit_Graph;
