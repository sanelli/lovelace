with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Interfaces;

with Lovelace.Common.Source;
with Lovelace.Compiler.Ast;
with Lovelace.Compiler.Error_Codes;
with Lovelace.Compiler.Reporting;
with Lovelace.Compiler.Semantics;
with Lovelace.Compiler.Semantics.Environment;
with Lovelace.Compiler.Semantics.Lovelace_Types;
with Lovelace.Compiler.Semantics.Typecheck;
with Lovelace.Compiler.Tests.Support;
with Lovelace.Compiler.Types;
with Lovelace.Compiler.Unit_Graph;

package body Lovelace.Compiler.Tests.Semantics is

   package Source renames Lovelace.Common.Source;
   package Compiler_Semantics renames Lovelace.Compiler.Semantics;
   package Environment renames Lovelace.Compiler.Semantics.Environment;
   package Lovelace_Types renames Lovelace.Compiler.Semantics.Lovelace_Types;
   package Typecheck renames Lovelace.Compiler.Semantics.Typecheck;

   use type Compiler_Semantics.Semantics_Error_Code;
   use type Lovelace_Types.Type_Class;
   use type Error_Codes.Error_Code;
   use type Error_Codes.Severity;
   use type Interfaces.Integer_32;

   Origin : constant Source.Source_Span :=
     (First => (Byte_Index => 1, Line => 1, Column => 1), Last => (Byte_Index => 1, Line => 1, Column => 1));

   --  Exported callee used by most matrices.
   Sink_Module : constant String := "module M; export procedure Sink(V : integer); begin end; ";

   function Analyze_Pair
     (Caller_Text : String; Library_Text : String; Message : String) return Compiler_Semantics.Analysis_Result;

   function Analyze_Text (Source_Text : String; Message : String) return Compiler_Semantics.Analysis_Result;

   procedure Assert_Clean (Result : Compiler_Semantics.Analysis_Result; Message : String);

   procedure Assert_Only_Error
     (Result : Compiler_Semantics.Analysis_Result; Code : Compiler_Semantics.Semantics_Error_Code; Message : String);

   procedure Assert_Warnings
     (Result            : Compiler_Semantics.Analysis_Result;
      Unused_Variables  : Natural;
      Unused_Assignment : Natural;
      Message           : String);

   function Count_Code
     (Items : Compiler_Semantics.Diagnostic_Sequence; Code : Compiler_Semantics.Semantics_Error_Code) return Natural;

   function Make_Entity
     (Kind : Environment.Entity_Kind; Name : String; Variable_Id : Natural) return Environment.Entity;

   function Analyze_Pair
     (Caller_Text : String; Library_Text : String; Message : String) return Compiler_Semantics.Analysis_Result
   is
      Units : Unit_Graph.Compilation_Set;
   begin
      Units.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Support.Must_Parse (Caller_Text, Message & ": caller"),
            Source_Path => Ada.Strings.Unbounded.To_Unbounded_String ("Caller.love"),
            Source_Text => Ada.Strings.Unbounded.To_Unbounded_String (Caller_Text)));
      Units.Append
        (Unit_Graph.Loaded_Unit'
           (The_Module  => Support.Must_Parse (Library_Text, Message & ": library"),
            Source_Path => Ada.Strings.Unbounded.To_Unbounded_String ("Lib.love"),
            Source_Text => Ada.Strings.Unbounded.To_Unbounded_String (Library_Text)));
      return Compiler_Semantics.Analyze (Units);
   end Analyze_Pair;

   function Analyze_Text (Source_Text : String; Message : String) return Compiler_Semantics.Analysis_Result is
   begin
      return Compiler_Semantics.Analyze (Support.Must_Parse (Source_Text, Message));
   end Analyze_Text;

   procedure Assert_Clean (Result : Compiler_Semantics.Analysis_Result; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Compiler_Semantics.Succeeded (Result),
         Message & ": expected no errors, found " & Natural'Image (Natural (Result.Errors.Length)));
   end Assert_Clean;

   procedure Assert_Only_Error
     (Result : Compiler_Semantics.Analysis_Result; Code : Compiler_Semantics.Semantics_Error_Code; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Natural (Result.Errors.Length) = 1,
         Message & ": expected exactly one error, found " & Natural'Image (Natural (Result.Errors.Length)));
      AUnit.Assertions.Assert (Result.Errors.Element (1).Code = Code, Message & ": error code");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.Length (Result.Errors.Element (1).Detail) > 0, Message & ": error detail present");
   end Assert_Only_Error;

   procedure Assert_Warnings
     (Result            : Compiler_Semantics.Analysis_Result;
      Unused_Variables  : Natural;
      Unused_Assignment : Natural;
      Message           : String) is
   begin
      AUnit.Assertions.Assert (Compiler_Semantics.Succeeded (Result), Message & ": no errors");
      AUnit.Assertions.Assert
        (Count_Code (Result.Warnings, Compiler_Semantics.Unused_Variable) = Unused_Variables,
         Message & ": Unused_Variable count");
      AUnit.Assertions.Assert
        (Count_Code (Result.Warnings, Compiler_Semantics.Unused_Assignment) = Unused_Assignment,
         Message & ": Unused_Assignment count");
      AUnit.Assertions.Assert
        (Natural (Result.Warnings.Length) = Unused_Variables + Unused_Assignment, Message & ": no other warnings");
   end Assert_Warnings;

   function Count_Code
     (Items : Compiler_Semantics.Diagnostic_Sequence; Code : Compiler_Semantics.Semantics_Error_Code) return Natural
   is
      Total : Natural := 0;
   begin
      for Index in 1 .. Natural (Items.Length) loop
         if Items.Element (Index).Code = Code then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Count_Code;

   function Make_Entity (Kind : Environment.Entity_Kind; Name : String; Variable_Id : Natural) return Environment.Entity
   is
   begin
      return
        (Kind             => Kind,
         Name             => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Span             => Origin,
         Value_Type       => Lovelace_Types.Unknown_Type,
         Variable_Id      => Variable_Id,
         Unit_Index       => 0,
         Subroutine_Index => 0);
   end Make_Entity;

   procedure Test_Definite_Assignment (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Before_Assign         : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare X, Y : integer; begin Y := X; end.", "read unassigned");
      Assigned_Read         : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare X, Y : integer; begin X := 1; Y := X; end.", "read assigned");
      Parameter_Read        : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module M; procedure Run(A : integer); declare B : integer; begin B := A; end; end.", "read parameter");
      Call_Argument         : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          (Sink_Module & "procedure Run(); declare X : integer; begin M.Sink(X); end; end.", "unassigned call actual");
      Nested_Outer_Ok       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare X, Y : integer; begin X := 1; " & "declare Z : integer; begin Z := X; Y := Z; end; end.",
           "nested read of assigned outer");
      Nested_Outer_Bad      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare X, Y : integer; begin declare Z : integer; begin Z := X; end; end.",
           "nested read of unassigned outer");
      Nested_Inner_Bad      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare X : integer; begin X := 1; declare Z : integer; begin X := Z; end; end.",
           "nested read of unassigned inner");
      Nested_Assign_Visible : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare X, Y : integer; begin declare Z : integer; begin Z := 1; X := Z; end; Y := X; end.",
           "assignment in nested block reaches outer read");
      Unknown_Rhs           : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare X : integer; begin X := Y; end.", "unknown rhs name");
      Unknown_Lhs           : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; begin Q := 1; end.", "unknown lhs name");
   begin
      Assert_Only_Error (Before_Assign, Compiler_Semantics.Use_Before_Assignment, "read unassigned");
      AUnit.Assertions.Assert (Before_Assign.Errors.Element (1).Span.First.Line = 1, "read unassigned: span line");
      AUnit.Assertions.Assert
        (Before_Assign.Errors.Element (1).Span.First.Byte_Index
         = Ada.Strings.Fixed.Index ("program P; declare X, Y : integer; begin Y := X; end.", "X; end"),
         "read unassigned: span points at the read");
      Assert_Clean (Assigned_Read, "read assigned");
      Assert_Clean (Parameter_Read, "read parameter");
      Assert_Only_Error (Call_Argument, Compiler_Semantics.Use_Before_Assignment, "unassigned call actual");
      Assert_Clean (Nested_Outer_Ok, "nested read of assigned outer");
      Assert_Only_Error (Nested_Outer_Bad, Compiler_Semantics.Use_Before_Assignment, "nested read of unassigned outer");
      Assert_Only_Error (Nested_Inner_Bad, Compiler_Semantics.Use_Before_Assignment, "nested read of unassigned inner");
      Assert_Clean (Nested_Assign_Visible, "assignment in nested block reaches outer read");
      Assert_Only_Error (Unknown_Rhs, Compiler_Semantics.Unresolved_Name, "unknown rhs name");
      Assert_Only_Error (Unknown_Lhs, Compiler_Semantics.Unresolved_Name, "unknown lhs name");
   end Test_Definite_Assignment;

   procedure Test_Environment_Scopes (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      The_Stack : Environment.Scope_Stack;
   begin
      AUnit.Assertions.Assert (Environment.Depth (The_Stack) = 0, "empty depth");
      AUnit.Assertions.Assert (not Environment.Lookup_Variable (The_Stack, "X").Found, "empty lookup");

      Environment.Push_Scope (The_Stack);
      Environment.Declare_Entity (The_Stack, Make_Entity (Environment.Local_Entity, "X", 1));
      Environment.Declare_Entity (The_Stack, Make_Entity (Environment.Module_Entity, "Lib", 0));
      Environment.Declare_Entity (The_Stack, Make_Entity (Environment.Subroutine_Entity, "Run", 0));

      Environment.Push_Scope (The_Stack);
      Environment.Declare_Entity (The_Stack, Make_Entity (Environment.Parameter_Entity, "X", 2));

      AUnit.Assertions.Assert (Environment.Depth (The_Stack) = 2, "two scopes");
      AUnit.Assertions.Assert
        (Environment.Lookup_Variable (The_Stack, "X").Found
         and then Environment.Lookup_Variable (The_Stack, "X").Value.Variable_Id = 2,
         "innermost wins");
      AUnit.Assertions.Assert (Environment.Lookup_Module (The_Stack, "Lib").Found, "outer module visible inside");
      AUnit.Assertions.Assert (not Environment.Lookup_Variable (The_Stack, "Lib").Found, "module is not a variable");
      AUnit.Assertions.Assert (not Environment.Lookup_Module (The_Stack, "X").Found, "variable is not a module");
      AUnit.Assertions.Assert (Environment.Lookup_Subroutine (The_Stack, "Run").Found, "subroutine found");
      AUnit.Assertions.Assert
        (not Environment.Lookup_Subroutine (The_Stack, "X").Found, "variable is not a subroutine");

      Environment.Pop_Scope (The_Stack);
      AUnit.Assertions.Assert (Environment.Depth (The_Stack) = 1, "one scope after pop");
      AUnit.Assertions.Assert
        (Environment.Lookup_Variable (The_Stack, "X").Value.Variable_Id = 1, "outer binding restored after pop");
      Environment.Pop_Scope (The_Stack);
      AUnit.Assertions.Assert (not Environment.Lookup_Module (The_Stack, "Lib").Found, "nothing visible after pops");
   end Test_Environment_Scopes;

   procedure Test_Missing_And_Not_Exported_Callees (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lib_Text      : constant String := "module Lib; export procedure Sink(Value : integer); begin end; end.";
      Hidden_Text   : constant String := "module Lib; procedure Sink(Value : integer); begin end; end.";
      Same_Missing  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("module Calls; procedure Run(); begin Calls.Missing(42); end; end.", "same-unit missing");
      Used_Missing  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair ("using Lib; program Caller; begin Lib.Nope(1); end.", Lib_Text, "used module, missing procedure");
      Used_Absent   : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("using Lib; program Caller; begin Lib.Sink(1); end.", "used module not loaded");
      Not_Exported  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair ("using Lib; program Caller; begin Lib.Sink(7); end.", Hidden_Text, "not exported");
      No_Using      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair ("program Caller; begin Lib.Sink(7); end.", Lib_Text, "no using, module loaded");
      No_Using_Gone : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("module Calls; procedure Run(); begin Other.Sink(42); end; end.", "no using, module absent");
      Same_Hidden   : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Value : integer); begin end; "
           & "procedure Run(); begin Calls.Sink(1); end; end.",
           "same-unit non-exported is fine");
      Cross_Ok      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair ("using Lib; program Caller; begin Lib.Sink(7); end.", Lib_Text, "exported cross-module call");
      Cascade       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare X : integer; begin Nope.Missing(X); end.", "unresolved call still analyses actuals");
   begin
      Assert_Only_Error (Same_Missing, Compiler_Semantics.Unresolved_Call, "same-unit missing");
      Assert_Only_Error (Used_Missing, Compiler_Semantics.Unresolved_Call, "used module, missing procedure");
      Assert_Only_Error (Used_Absent, Compiler_Semantics.Unresolved_Call, "used module not loaded");
      Assert_Only_Error (Not_Exported, Compiler_Semantics.Not_Exported, "not exported");
      Assert_Only_Error (No_Using, Compiler_Semantics.Call_Without_Using, "no using, module loaded");
      Assert_Only_Error (No_Using_Gone, Compiler_Semantics.Call_Without_Using, "no using, module absent");
      Assert_Clean (Same_Hidden, "same-unit non-exported is fine");
      Assert_Clean (Cross_Ok, "exported cross-module call");
      AUnit.Assertions.Assert (Natural (Cascade.Errors.Length) = 2, "cascade: two errors");
      AUnit.Assertions.Assert
        (Count_Code (Cascade.Errors, Compiler_Semantics.Call_Without_Using) = 1, "cascade: call without using");
      AUnit.Assertions.Assert
        (Count_Code (Cascade.Errors, Compiler_Semantics.Use_Before_Assignment) = 1, "cascade: actual still checked");
   end Test_Missing_And_Not_Exported_Callees;

   procedure Test_Reporting_Mapping (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
   begin
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Unresolved_Call)) = "LV00014", "LV00014");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Invalid_Arguments)) = "LV00015", "LV00015");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Call_Without_Using)) = "LV00017", "LV00017");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Not_Exported)) = "LV00018", "LV00018");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Use_Before_Assignment)) = "LV00026", "LV00026");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Type_Mismatch)) = "LV00027", "LV00027");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Unused_Variable)) = "LV00028", "LV00028");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Unused_Assignment)) = "LV00029", "LV00029");
      AUnit.Assertions.Assert
        (Error_Codes.Label (Reporting.To_Error_Code (Compiler_Semantics.Unresolved_Name)) = "LV00031", "LV00031");
      AUnit.Assertions.Assert
        (Reporting.To_Error_Code (Compiler_Semantics.Internal_Error) = Error_Codes.Internal_Error, "internal error");

      for Code in Compiler_Semantics.Semantics_Error_Code loop
         AUnit.Assertions.Assert
           ((Error_Codes.Default_Severity (Reporting.To_Error_Code (Code)) = Error_Codes.Warning)
            = Compiler_Semantics.Is_Warning (Code),
            "severity agrees with Is_Warning for " & Compiler_Semantics.Semantics_Error_Code'Image (Code));
      end loop;
   end Test_Reporting_Mapping;

   procedure Test_Scoped_Using_Visibility (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Lib_Text    : constant String := "module Lib; export procedure Sink(Value : integer); begin end; end.";
      Dotted_Text : constant String := "module Aug.Io; export procedure Print(Value : integer); begin end; end.";
      In_Block    : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair ("program Caller; begin using Lib; begin Lib.Sink(1); end; end.", Lib_Text, "call inside block");
      After_Block : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair
          ("program Caller; begin using Lib; begin Lib.Sink(1); end; Lib.Sink(2); end.", Lib_Text, "call after block");
      Siblings    : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair
          ("program Caller; begin using Lib; begin Lib.Sink(1); end; using Lib; begin Lib.Sink(2); end; end.",
           Lib_Text,
           "sibling blocks");
      Unit_Level  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair
          ("using Lib; program Caller; begin begin Lib.Sink(1); end; Lib.Sink(2); end.",
           Lib_Text,
           "unit-level using reaches nested blocks");
      Per_Routine : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair
          ("module Caller; procedure A(); using Lib; begin Lib.Sink(1); end; "
           & "procedure B(); begin Lib.Sink(2); end; end.",
           Lib_Text,
           "procedure-level using");
      Dotted      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair
          ("program Caller; begin using Aug.Io; begin Aug.Io.Print(1); end; Aug.Io.Print(2); end.",
           Dotted_Text,
           "dotted module using scope");
   begin
      Assert_Clean (In_Block, "call inside block");
      Assert_Only_Error (After_Block, Compiler_Semantics.Call_Without_Using, "call after block");
      Assert_Clean (Siblings, "sibling blocks");
      Assert_Clean (Unit_Level, "unit-level using reaches nested blocks");
      Assert_Only_Error (Per_Routine, Compiler_Semantics.Call_Without_Using, "procedure-level using");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String (Per_Routine.Errors.Element (1).Detail), "Lib") > 0,
         "procedure-level using: detail names the module");
      Assert_Only_Error (Dotted, Compiler_Semantics.Call_Without_Using, "dotted module using scope");
   end Test_Scoped_Using_Visibility;

   procedure Test_Type_Mismatch (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Int_Bool       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare X : integer; begin X := true; end.", "assign boolean to integer");
      Bool_Int       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare F : boolean; begin F := 1; end.", "assign literal to boolean");
      Bool_From_Var  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare F : boolean; X : integer; begin X := 1; F := X; end.", "assign integer var to boolean");
      Unsigned_Neg   : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare U : unsigned integer; begin U := -1; end.", "negative into unsigned");
      Narrow_Literal : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare B : integer<8>; begin B := 300; end.", "literal out of range");
      Wide_Literal   : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare L : integer<64>; begin L := 1; end.", "literal into 64-bit");
      Narrowing      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare A : integer; B : integer<8>; begin A := 1; B := A; end.", "no implicit narrowing");
      Assign_Ok      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("program P; declare A, B : integer; F, G : boolean; U : unsigned integer<8>; begin "
           & "A := 1; B := A; F := true; G := F; U := 255; A := B; end.",
           "well-typed assignments");
      Call_Int_Bool  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Value : integer); begin end; "
           & "procedure Run(); begin Calls.Sink(true); end; end.",
           "boolean literal to integer formal");
      Call_Bool_Int  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Flag : boolean); begin end; "
           & "procedure Run(); begin Calls.Sink(1); end; end.",
           "integer literal to boolean formal");
      Call_Unsigned  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Value : unsigned integer); begin end; "
           & "procedure Run(); begin Calls.Sink(-1); end; end.",
           "negative literal to unsigned formal");
      Call_Wide      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Value : integer<64>); begin end; "
           & "procedure Run(); begin Calls.Sink(1); end; end.",
           "literal to 64-bit formal");
      Call_Var       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Flag : boolean); begin end; "
           & "procedure Run(); declare X : integer; begin X := 1; Calls.Sink(X); end; end.",
           "integer variable to boolean formal");
      Call_Arity     : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Value : integer); begin end; "
           & "procedure Run(); begin Calls.Sink(1, 2); end; end.",
           "arity mismatch");
      Call_Two_Wrong : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(A : integer; B : boolean); begin end; "
           & "procedure Run(); begin Calls.Sink(true, 1); end; end.",
           "two wrong actuals");
      Call_Ok        : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          ("module Calls; procedure Sink(Flag : boolean); begin end; "
           & "procedure Run(); declare F : boolean; begin F := true; Calls.Sink(F); Calls.Sink(false); end; end.",
           "well-typed calls");
   begin
      Assert_Only_Error (Int_Bool, Compiler_Semantics.Type_Mismatch, "assign boolean to integer");
      Assert_Only_Error (Bool_Int, Compiler_Semantics.Type_Mismatch, "assign literal to boolean");
      Assert_Only_Error (Bool_From_Var, Compiler_Semantics.Type_Mismatch, "assign integer var to boolean");
      Assert_Only_Error (Unsigned_Neg, Compiler_Semantics.Type_Mismatch, "negative into unsigned");
      Assert_Only_Error (Narrow_Literal, Compiler_Semantics.Type_Mismatch, "literal out of range");
      Assert_Only_Error (Wide_Literal, Compiler_Semantics.Type_Mismatch, "literal into 64-bit");
      Assert_Only_Error (Narrowing, Compiler_Semantics.Type_Mismatch, "no implicit narrowing");
      Assert_Clean (Assign_Ok, "well-typed assignments");
      Assert_Only_Error (Call_Int_Bool, Compiler_Semantics.Type_Mismatch, "boolean literal to integer formal");
      Assert_Only_Error (Call_Bool_Int, Compiler_Semantics.Type_Mismatch, "integer literal to boolean formal");
      Assert_Only_Error (Call_Unsigned, Compiler_Semantics.Type_Mismatch, "negative literal to unsigned formal");
      Assert_Only_Error (Call_Wide, Compiler_Semantics.Type_Mismatch, "literal to 64-bit formal");
      Assert_Only_Error (Call_Var, Compiler_Semantics.Type_Mismatch, "integer variable to boolean formal");
      Assert_Only_Error (Call_Arity, Compiler_Semantics.Invalid_Arguments, "arity mismatch");
      AUnit.Assertions.Assert
        (Count_Code (Call_Two_Wrong.Errors, Compiler_Semantics.Type_Mismatch) = 2
         and then Natural (Call_Two_Wrong.Errors.Length) = 2,
         "two wrong actuals: one error each");
      Assert_Clean (Call_Ok, "well-typed calls");
   end Test_Type_Mismatch;

   procedure Test_Typecheck_Api (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Int_32  : constant Lovelace_Types.Lovelace_Type :=
        Lovelace_Types.From_Expression (Types.Integer_Type (Types.Signed, Types.Bits_32));
      Int_8   : constant Lovelace_Types.Lovelace_Type :=
        Lovelace_Types.From_Expression (Types.Integer_Type (Types.Signed, Types.Bits_8));
      Uint_8  : constant Lovelace_Types.Lovelace_Type :=
        Lovelace_Types.From_Expression (Types.Integer_Type (Types.Unsigned, Types.Bits_8));
      Int_64  : constant Lovelace_Types.Lovelace_Type :=
        Lovelace_Types.From_Expression (Types.Integer_Type (Types.Signed, Types.Bits_64));
      Flag    : constant Lovelace_Types.Lovelace_Type := Lovelace_Types.Boolean_Type;
      Nothing : constant Lovelace_Types.Lovelace_Type := Lovelace_Types.From_Expression (Types.Unit_Type);
      Real    : constant Lovelace_Types.Lovelace_Type :=
        Lovelace_Types.From_Expression (Types.Float_Type (Types.Bits_32));
      Unknown : constant Lovelace_Types.Lovelace_Type := Lovelace_Types.Unknown_Type;
      Failure : constant Typecheck.Assign_Result := Typecheck.Check_Assignable (Int_32, Flag);

      function Literal (Value : Interfaces.Integer_32) return Lovelace_Types.Lovelace_Type
      is (Lovelace_Types.Integer_Literal_Type (Value));

      Valid_Literal   : constant Ast.Expression :=
        (Kind     => Ast.Integer_Literal,
         Lexeme   => Ada.Strings.Unbounded.To_Unbounded_String ("42"),
         Span     => Origin,
         Filename => Source.Absent_Filename);
      Invalid_Literal : constant Ast.Expression :=
        (Kind     => Ast.Integer_Literal,
         Lexeme   => Ada.Strings.Unbounded.To_Unbounded_String ("99999999999"),
         Span     => Origin,
         Filename => Source.Absent_Filename);
      Boolean_Literal : constant Ast.Expression :=
        (Kind     => Ast.Boolean_Literal,
         Lexeme   => Ada.Strings.Unbounded.To_Unbounded_String ("true"),
         Span     => Origin,
         Filename => Source.Absent_Filename);
      Valid_Result    : constant Typecheck.Type_Result := Typecheck.Type_Of_Literal (Valid_Literal);
      Invalid_Result  : constant Typecheck.Type_Result := Typecheck.Type_Of_Literal (Invalid_Literal);
      Boolean_Result  : constant Typecheck.Type_Result := Typecheck.Type_Of_Literal (Boolean_Literal);
   begin
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Int_32, Literal (5)), "literal into integer");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Int_8, Literal (127)), "127 into i8");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Int_8, Literal (128)), "128 not into i8");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Int_8, Literal (-128)), "-128 into i8");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Int_8, Literal (-129)), "-129 not into i8");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Uint_8, Literal (255)), "255 into u8");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Uint_8, Literal (256)), "256 not into u8");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Uint_8, Literal (-1)), "-1 not into u8");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Int_64, Literal (5)), "literal not into i64 in this slice");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Flag, Literal (1)), "literal not into boolean");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Flag, Flag), "boolean into boolean");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Int_32, Flag), "boolean not into integer");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Int_32, Int_32), "same integer");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Int_32, Int_8), "different widths");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Int_8, Uint_8), "different signedness");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Real, Real), "same float");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Real, Literal (1)), "literal not into float");
      AUnit.Assertions.Assert (not Typecheck.Is_Assignable (Nothing, Flag), "nothing takes no value");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Unknown, Flag), "unknown target avoids cascade");
      AUnit.Assertions.Assert (Typecheck.Is_Assignable (Int_32, Unknown), "unknown source avoids cascade");

      AUnit.Assertions.Assert (not Failure.Ok, "check reports failure");
      AUnit.Assertions.Assert (Ada.Strings.Unbounded.Length (Failure.Detail) > 0, "failure carries detail");

      AUnit.Assertions.Assert (Lovelace_Types.Image (Int_32) = "integer", "image integer");
      AUnit.Assertions.Assert (Lovelace_Types.Image (Uint_8) = "unsigned integer<8>", "image unsigned integer<8>");
      AUnit.Assertions.Assert (Lovelace_Types.Image (Flag) = "boolean", "image boolean");
      AUnit.Assertions.Assert (Lovelace_Types.Is_Integral (Literal (3)), "literal is integral");
      AUnit.Assertions.Assert (Lovelace_Types.Is_Numeric (Real), "float is numeric");
      AUnit.Assertions.Assert (not Lovelace_Types.Is_Numeric (Flag), "boolean is not numeric");

      AUnit.Assertions.Assert
        (Valid_Result.Ok
         and then Valid_Result.The_Type.Class = Lovelace_Types.Integer_Literal_Class
         and then Valid_Result.The_Type.Literal_Value = 42,
         "literal 42 typed");
      AUnit.Assertions.Assert (not Invalid_Result.Ok, "out-of-range literal rejected");
      AUnit.Assertions.Assert
        (Boolean_Result.Ok and then Boolean_Result.The_Type.Class = Lovelace_Types.Boolean_Class, "true is boolean");
   end Test_Typecheck_Api;

   procedure Test_Unused_Priority (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Run_Open            : constant String := "procedure Run(); declare X : integer; begin ";
      Run_Done            : constant String := " end; end.";
      Never_Read          : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Sink_Module & Run_Open & "X := 1;" & Run_Done, "assigned but never read");
      Never_Touched       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Sink_Module & Run_Open & Run_Done, "declared but never touched");
      Many_Stores         : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Sink_Module & Run_Open & "X := 1; X := 2;" & Run_Done, "stores without any read");
      Dead_Then_Read_Text : constant String := Sink_Module & Run_Open & "X := 1; X := 2; M.Sink(X);" & Run_Done;
      Dead_Then_Read      : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Dead_Then_Read_Text, "overwritten store, later read");
      Read_Then_Store     : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Sink_Module & Run_Open & "X := 1; M.Sink(X); X := 2;" & Run_Done, "final store never read");
      All_Used            : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Sink_Module & Run_Open & "X := 1; M.Sink(X); X := 2; M.Sink(X);" & Run_Done, "every store read");
      Self_Assign         : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text (Sink_Module & Run_Open & "X := 1; X := X;" & Run_Done, "self assignment");
      Param_Unread        : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("module M; procedure Run(A : integer); begin end; end.", "parameter never read");
      Param_Dead          : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          (Sink_Module & "procedure Run(A : integer); begin A := 1; A := 2; M.Sink(A); end; end.",
           "parameter dead store");
      Nested_Unread       : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          (Sink_Module & Run_Open & "declare Y : integer; begin Y := 1; X := 1; M.Sink(X); end;" & Run_Done,
           "nested local never read");
      Nested_Dead         : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text
          (Sink_Module
           & Run_Open
           & "X := 1; M.Sink(X); declare Y : integer; begin Y := 1; M.Sink(Y); Y := 2; end;"
           & Run_Done,
           "store dead at nested block end");
      First_Store         : constant Natural := Ada.Strings.Fixed.Index (Dead_Then_Read_Text, "X := 1");
   begin
      Assert_Warnings (Never_Read, 1, 0, "assigned but never read");
      Assert_Warnings (Never_Touched, 1, 0, "declared but never touched");
      Assert_Warnings (Many_Stores, 1, 0, "stores without any read: only Unused_Variable");
      Assert_Warnings (Dead_Then_Read, 0, 1, "overwritten store, later read");
      AUnit.Assertions.Assert
        (Dead_Then_Read.Warnings.Element (1).Span.First.Byte_Index = First_Store,
         "dead store is reported at the overwritten assignment");
      Assert_Warnings (Read_Then_Store, 0, 1, "final store never read");
      Assert_Warnings (All_Used, 0, 0, "every store read");
      Assert_Warnings (Self_Assign, 0, 1, "self assignment: trailing store is dead");
      Assert_Warnings (Param_Unread, 0, 0, "parameters never get Unused_Variable");
      Assert_Warnings (Param_Dead, 0, 1, "parameter dead store");
      Assert_Warnings (Nested_Unread, 1, 0, "nested local never read");
      Assert_Warnings (Nested_Dead, 0, 1, "store dead at nested block end");
   end Test_Unused_Priority;

   procedure Test_Warnings_Do_Not_Fail (The_Test : in out Fixture) is
      pragma Unreferenced (The_Test);
      Warn_Only   : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare X : integer; begin X := 1; end.", "warning only");
      Error_Quiet : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Text ("program P; declare X, Y : integer; begin X := true; end.", "errors suppress unused warnings");
      Dependency  : constant Compiler_Semantics.Analysis_Result :=
        Analyze_Pair
          ("using Lib; program Caller; begin Lib.Sink(1); end.",
           "module Lib; export procedure Sink(Value : integer); declare X : boolean; begin X := 1; end; end.",
           "error in dependency");
   begin
      AUnit.Assertions.Assert (Compiler_Semantics.Succeeded (Warn_Only), "warnings alone succeed");
      AUnit.Assertions.Assert (Natural (Warn_Only.Warnings.Length) = 1, "one warning");
      AUnit.Assertions.Assert
        (Warn_Only.Warnings.Element (1).Code = Compiler_Semantics.Unused_Variable, "warning code");
      AUnit.Assertions.Assert (Compiler_Semantics.Is_Warning (Warn_Only.Warnings.Element (1).Code), "is warning");

      Assert_Only_Error (Error_Quiet, Compiler_Semantics.Type_Mismatch, "errors suppress unused warnings");
      AUnit.Assertions.Assert (Error_Quiet.Warnings.Is_Empty, "no unused warnings next to errors");

      Assert_Only_Error (Dependency, Compiler_Semantics.Type_Mismatch, "error in dependency");
      AUnit.Assertions.Assert (Dependency.Errors.Element (1).Unit_Index = 2, "dependency error carries unit index");
   end Test_Warnings_Do_Not_Fail;

end Lovelace.Compiler.Tests.Semantics;
