with Ada.Strings.Unbounded;

with Lovelace.Compiler.Ast;
with Lovelace.Lir.Types;

--  Closed table of `@intrinsic` signatures (module + name + params + return).

package Lovelace.Compiler.Intrinsics is

   --  Known compiler-synthesized intrinsic bodies.
   --  @enum Print_Integer_Stdout Decimal ASCII + WASI 0.3 stdout write for
   --  `augusta.std.io.print(integer)`.
   type Intrinsic_Kind is (Print_Integer_Stdout);

   --  Optional Intrinsic_Kind (table miss â absent).
   --  @disc Present True when Kind is set.
   --  @field Kind Matched intrinsic when Present is True.
   type Intrinsic_Kind_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Kind : Intrinsic_Kind;

         when False =>
            null;
      end case;
   end record;

   --  Match a LIR signature against the closed intrinsic table.
   --  @param Module_Name Enclosing module name (e.g. augusta.std.io).
   --  @param Subroutine_Name Unqualified procedure name.
   --  @param Return_Type LIR return type.
   --  @param Parameters LIR parameter list.
   --  @return Present Kind on hit; absent when unknown.
   function Match_Intrinsic
     (Module_Name     : String;
      Subroutine_Name : String;
      Return_Type     : Lovelace.Lir.Types.Value_Type;
      Parameters      : Lovelace.Lir.Types.Parameter_Sequence) return Intrinsic_Kind_Option;

   --  Match an AST subroutine in Module_Name against the closed table.
   --  @param Module_Name Enclosing module name.
   --  @param The_Subroutine Frontend subroutine (name, params, return).
   --  @return Present Kind on hit; absent when unknown.
   function Match_Intrinsic (Module_Name : String; The_Subroutine : Ast.Subroutine) return Intrinsic_Kind_Option;

   --  Split a flattened LIR subroutine name into module + unqualified name.
   --  Dotted Lir_Name â module is the prefix, name is the last segment.
   --  Undotted â module is Root_Module_Name and name is Lir_Name.
   --  @param Root_Module_Name LIR module name (root compilation unit).
   --  @param Lir_Name Signature name as stored in LIR.
   --  @param Module_Name Out: owning module name.
   --  @param Subroutine_Name Out: unqualified procedure name.
   procedure Split_Lir_Subroutine_Name
     (Root_Module_Name : String;
      Lir_Name         : String;
      Module_Name      : out Ada.Strings.Unbounded.Unbounded_String;
      Subroutine_Name  : out Ada.Strings.Unbounded.Unbounded_String);

end Lovelace.Compiler.Intrinsics;
