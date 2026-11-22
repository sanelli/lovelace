with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Interfaces;

--  In-memory component sketch after LIR lowering (core funcs, lifts, exports).

package Lovelace.Compiler.Backend.Model is

   --  Component export name for the WASI CLI run interface instance that
   --  wasmtime run looks up (must match the host's WASI 0.3 package version).
   Wasi_Cli_Run_Export_Name : constant String := "wasi:cli/run@0.3.0";

   --  WASI 0.3 stdout import package name.
   Wasi_Cli_Stdout_Import_Name : constant String := "wasi:cli/stdout@0.3.0";

   --  WASI 0.3 CLI types import (error-code for stdout futures).
   Wasi_Cli_Types_Import_Name : constant String := "wasi:cli/types@0.3.0";

   --  Fixed core-import slots when Has_Wasi_Stdout (0-based WASM indices).
   Stream_New_Import_Index            : constant := 0;
   Stream_Write_Import_Index          : constant := 1;
   Stream_Drop_Writable_Import_Index  : constant := 2;
   Future_Read_Import_Index           : constant := 3;
   Future_Drop_Readable_Import_Index  : constant := 4;
   Write_Via_Stream_Import_Index      : constant := 5;
   Wasi_Stdout_Import_Count           : constant := 6;

   --  One core WASM instruction in a lowered function body.
   --  @disc Kind Selects the instruction variant.
   type Core_Instruction_Kind is
     (Call_Function,
      Call_Import,
      I32_Constant,
      I64_Constant,
      Local_Get,
      Local_Set,
      I32_Add,
      I32_Sub,
      I32_Mul,
      I32_Div_S,
      I32_Rem_S,
      I32_Eqz,
      I32_Eq,
      I32_Ne,
      I32_Lt_S,
      I32_Gt_S,
      I32_Le_S,
      I32_Ge_S,
      I32_Store8,
      I32_Load8_U,
      I32_Wrap_I64,
      I64_Extend_I32_U,
      I64_Shr_U,
      Unreachable,
      If_Empty,
      Else_Op,
      End_Op,
      Loop_Empty,
      Br,
      Br_If);

   --  @field Target_Index 1-based guest core function index for Call_Function.
   --  @field Import_Index 0-based import slot for Call_Import.
   --  @field Value Immediate for I32_Constant.
   --  @field Value_I64 Immediate for I64_Constant.
   --  @field Local_Index 0-based local index (params then locals).
   --  @field Label_Depth Relative label depth for Br / Br_If.
   type Core_Instruction (Kind : Core_Instruction_Kind := Call_Function) is record
      case Kind is
         when Call_Function =>
            Target_Index : Positive;

         when Call_Import =>
            Import_Index : Natural;

         when I32_Constant =>
            Value : Interfaces.Integer_32;

         when I64_Constant =>
            Value_I64 : Interfaces.Integer_64;

         when Local_Get | Local_Set =>
            Local_Index : Natural;

         when Br | Br_If =>
            Label_Depth : Natural;

         when I32_Add
            | I32_Sub
            | I32_Mul
            | I32_Div_S
            | I32_Rem_S
            | I32_Eqz
            | I32_Eq
            | I32_Ne
            | I32_Lt_S
            | I32_Gt_S
            | I32_Le_S
            | I32_Ge_S
            | I32_Store8
            | I32_Load8_U
            | I32_Wrap_I64
            | I64_Extend_I32_U
            | I64_Shr_U
            | Unreachable
            | If_Empty
            | Else_Op
            | End_Op
            | Loop_Empty =>
            null;
      end case;
   end record;

   --  Ordered list of core instructions (end is implicit at emit time only when
   --  the body does not already contain matching End_Op for structured blocks).
   type Instruction_Sequence is private;

   --  Empty instruction sequence.
   --  @return Sequence with no elements.
   function Empty_Instructions return Instruction_Sequence;

   --  Append Item to Sequence.
   --  @param Sequence Sequence to extend.
   --  @param Item Instruction to append.
   procedure Append (Sequence : in out Instruction_Sequence; Item : Core_Instruction);

   --  Number of instructions in Sequence.
   --  @param Sequence Instruction list.
   --  @return Element count.
   function Length (Sequence : Instruction_Sequence) return Natural;

   --  Instruction at Index (1 .. Length (Sequence)).
   --  @param Sequence Instruction list.
   --  @param Index 1-based index.
   --  @return Instruction at Index.
   function Element (Sequence : Instruction_Sequence; Index : Positive) return Core_Instruction;

   --  Core WASM value type used in functypes (after LIR numeric widening).
   --  @enum I32 32-bit integer (also widened I8/I16/U8/U16/U32).
   --  @enum I64 64-bit integer (also widened U64).
   --  @enum F32 32-bit float.
   --  @enum F64 64-bit float.
   type Core_Value_Type is (I32, I64, F32, F64);

   --  Ordered list of core parameter types for a Core_Function.
   type Core_Parameter_Sequence is private;

   --  Empty core parameter sequence.
   --  @return Sequence with no elements.
   function Empty_Parameters return Core_Parameter_Sequence;

   --  Append The_Type to the end of Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Type Core parameter type.
   procedure Append (Sequence : in out Core_Parameter_Sequence; The_Type : Core_Value_Type);

   --  Number of parameters in Sequence.
   --  @param Sequence Parameter list.
   --  @return Element count.
   function Length (Sequence : Core_Parameter_Sequence) return Natural;

   --  Parameter type at Index (1 .. Length (Sequence)).
   --  @param Sequence Parameter list.
   --  @param Index 1-based index.
   --  @return Core value type at Index.
   function Element (Sequence : Core_Parameter_Sequence; Index : Positive) return Core_Value_Type;

   --  Ordered list of local types (after parameters) for a Core_Function.
   type Core_Local_Sequence is private;

   --  Empty local sequence.
   --  @return Sequence with no elements.
   function Empty_Locals return Core_Local_Sequence;

   --  Append The_Type to Sequence.
   --  @param Sequence Sequence to extend.
   --  @param The_Type Local value type.
   procedure Append (Sequence : in out Core_Local_Sequence; The_Type : Core_Value_Type);

   --  Number of locals in Sequence.
   --  @param Sequence Local list.
   --  @return Element count.
   function Length (Sequence : Core_Local_Sequence) return Natural;

   --  Local type at Index (1 .. Length (Sequence)).
   --  @param Sequence Local list.
   --  @param Index 1-based index.
   --  @return Core value type at Index.
   function Element (Sequence : Core_Local_Sequence; Index : Positive) return Core_Value_Type;

   --  One core function in the nested core module.
   --  @field Name UTF-8 core function name (LIR name or "_start").
   --  @field Parameter_Types Core parameter types (widened from LIR); empty for `_start`.
   --  @field Local_Types Extra locals after parameters.
   --  @field Result_Is_I32 True when the function returns i32 (_start); False for Unit [].
   --  @field Instructions Body instructions (noop already stripped).
   --  @field Core_Exported True when the core module must export this function for aliasing.
   type Core_Function is record
      Name            : Ada.Strings.Unbounded.Unbounded_String;
      Parameter_Types : Core_Parameter_Sequence;
      Local_Types     : Core_Local_Sequence := Empty_Locals;
      Result_Is_I32   : Boolean;
      Instructions    : Instruction_Sequence;
      Core_Exported   : Boolean;
   end record;

   --  One canon-lifted component export.
   --  @field Export_Name Component export name (kebab-case LIR name, or
   --    Wasi_Cli_Run_Export_Name when Returns_Result).
   --  @field Core_Function_Index 1-based index into the core function list.
   --  @field Returns_Result True for the entrypoint: lift to func() -> result and
   --    export as a wasi:cli/run instance; False for a Unit func() export.
   type Lifted_Export is record
      Export_Name         : Ada.Strings.Unbounded.Unbounded_String;
      Core_Function_Index : Positive;
      Returns_Result      : Boolean;
   end record;

   --  Lowered component model for one LIR module.
   type Component_Model is private;

   --  UTF-8 LIR module name (used for WIT package naming later).
   --  @param The_Model Model to query.
   --  @return Module name bytes.
   function Module_Name (The_Model : Component_Model) return String;

   --  Module version string (WIT package version).
   --  @param The_Model Model to query.
   --  @return Module version bytes.
   function Module_Version (The_Model : Component_Model) return String;

   --  Number of core functions (LIR subroutines, then optional _start).
   --  @param The_Model Model to query.
   --  @return Core function count.
   function Function_Count (The_Model : Component_Model) return Natural;

   --  Core function at Index (1 .. Function_Count).
   --  @param The_Model Model to query.
   --  @param Index 1-based index.
   --  @return Core function at Index.
   function Get_Function (The_Model : Component_Model; Index : Positive) return Core_Function;

   --  Number of component exports (lifted).
   --  @param The_Model Model to query.
   --  @return Lifted export count.
   function Export_Count (The_Model : Component_Model) return Natural;

   --  Lifted export at Index (1 .. Export_Count).
   --  @param The_Model Model to query.
   --  @param Index 1-based index.
   --  @return Lifted export at Index.
   function Get_Export (The_Model : Component_Model; Index : Positive) return Lifted_Export;

   --  True when the model includes a run export (entrypoint was present).
   --  @param The_Model Model to query.
   --  @return True iff a run / _start pair was synthesized.
   function Has_Run_Export (The_Model : Component_Model) return Boolean;

   --  True when the model imports wasi:cli/stdout and synthesizes stream builtins.
   --  @param The_Model Model to query.
   --  @return True iff native-print-integer wiring is present.
   function Has_Wasi_Stdout (The_Model : Component_Model) return Boolean;

   --  Module version used when Create is not given one.
   Default_Module_Version : constant String := "0.0.1";

   --  Build an empty model with Module_Name and no functions or exports.
   --  @param Name UTF-8 LIR module name.
   --  @param Version UTF-8 module version (WIT package version).
   --  @return Empty Component_Model.
   function Create
     (Name : String; Version : String := Default_Module_Version)
      return Component_Model;

   --  One LIR dependency recorded for component metadata (name + version).
   --  @field Name UTF-8 depended-on module name (may be dotted).
   --  @field Version UTF-8 module version.
   type Dependency is record
      Name    : Ada.Strings.Unbounded.Unbounded_String;
      Version : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Append a dependency module name and version for emit metadata.
   --  @param The_Model Model to extend.
   --  @param Name UTF-8 module name.
   --  @param Version UTF-8 module version.
   procedure Append_Dependency
     (The_Model : in out Component_Model; Name : String; Version : String);

   --  Append The_Export to The_Model.
   --  @param The_Model Model to extend.
   --  @param The_Export Lifted export to append.
   procedure Append_Export (The_Model : in out Component_Model; The_Export : Lifted_Export);

   --  Append The_Function to The_Model.
   --  @param The_Model Model to extend.
   --  @param The_Function Core function to append.
   procedure Append_Function (The_Model : in out Component_Model; The_Function : Core_Function);

   --  Number of recorded dependencies.
   --  @param The_Model Model to query.
   --  @return Dependency count.
   function Dependency_Count (The_Model : Component_Model) return Natural;

   --  Mark The_Model as needing WASI 0.3 stdout imports + memory + stream builtins.
   --  @param The_Model Model to update.
   procedure Enable_Wasi_Stdout (The_Model : in out Component_Model);

   --  Dependency at Index (1 .. Dependency_Count).
   --  @param The_Model Model to query.
   --  @param Index 1-based index.
   --  @return Dependency record.
   function Get_Dependency
     (The_Model : Component_Model; Index : Positive) return Dependency;

private

   package Instruction_Vectors is new
     Ada.Containers.Indefinite_Vectors (Index_Type => Positive, Element_Type => Core_Instruction);

   type Instruction_Sequence is record
      Items : Instruction_Vectors.Vector;
   end record;

   package Core_Parameter_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Core_Value_Type);

   type Core_Parameter_Sequence is record
      Items : Core_Parameter_Vectors.Vector;
   end record;

   type Core_Local_Sequence is record
      Items : Core_Parameter_Vectors.Vector;
   end record;

   package Function_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Core_Function);

   package Export_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Lifted_Export);

   package Dependency_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Dependency);

   type Component_Model is record
      Module_Name_Value    : Ada.Strings.Unbounded.Unbounded_String;
      Module_Version_Value : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String (Default_Module_Version);
      Functions            : Function_Vectors.Vector;
      Exports              : Export_Vectors.Vector;
      Dependencies         : Dependency_Vectors.Vector;
      Wasi_Stdout_Enabled  : Boolean := False;
   end record;

end Lovelace.Compiler.Backend.Model;
