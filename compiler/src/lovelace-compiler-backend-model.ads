with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Interfaces;

--  In-memory component sketch after LIR lowering (core funcs, lifts, exports).

package Lovelace.Compiler.Backend.Model is

   --  Component export name for the WASI CLI run interface instance that
   --  wasmtime run looks up (must match the host's WASI 0.3 package version).
   Wasi_Cli_Run_Export_Name : constant String := "wasi:cli/run@0.3.0";

   --  One core WASM instruction in a lowered function body.
   --  @disc Kind Selects the instruction variant.
   --  @field Target_Index 1-based core function index for Call_Function.
   --  @field Value Immediate for I32_Constant.
   type Core_Instruction_Kind is (Call_Function, I32_Constant);

   type Core_Instruction (Kind : Core_Instruction_Kind := Call_Function) is
   record
      case Kind is
         when Call_Function =>
            Target_Index : Positive;

         when I32_Constant =>
            Value : Interfaces.Integer_32;
      end case;
   end record;

   --  Ordered list of core instructions (end is implicit at emit time).
   type Instruction_Sequence is private;

   --  Empty instruction sequence.
   --  @return Sequence with no elements.
   function Empty_Instructions return Instruction_Sequence;

   --  Append Item to Sequence.
   --  @param Sequence Sequence to extend.
   --  @param Item Instruction to append.
   procedure Append
     (Sequence : in out Instruction_Sequence; Item : Core_Instruction);

   --  Number of instructions in Sequence.
   --  @param Sequence Instruction list.
   --  @return Element count.
   function Length (Sequence : Instruction_Sequence) return Natural;

   --  Instruction at Index (1 .. Length (Sequence)).
   --  @param Sequence Instruction list.
   --  @param Index 1-based index.
   --  @return Instruction at Index.
   function Element
     (Sequence : Instruction_Sequence; Index : Positive)
      return Core_Instruction;

   --  One core function in the nested core module.
   --  @field Name UTF-8 core function name (LIR name or "_start").
   --  @field Result_Is_I32 True when the function returns i32 (_start); False for Unit [].
   --  @field Instructions Body instructions (noop already stripped).
   --  @field Core_Exported True when the core module must export this function for aliasing.
   type Core_Function is record
      Name          : Ada.Strings.Unbounded.Unbounded_String;
      Result_Is_I32 : Boolean;
      Instructions  : Instruction_Sequence;
      Core_Exported : Boolean;
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

   --  Number of core functions (LIR subroutines, then optional _start).
   --  @param The_Model Model to query.
   --  @return Core function count.
   function Function_Count (The_Model : Component_Model) return Natural;

   --  Core function at Index (1 .. Function_Count).
   --  @param The_Model Model to query.
   --  @param Index 1-based index.
   --  @return Core function at Index.
   function Get_Function
     (The_Model : Component_Model; Index : Positive) return Core_Function;

   --  Number of component exports (lifted).
   --  @param The_Model Model to query.
   --  @return Lifted export count.
   function Export_Count (The_Model : Component_Model) return Natural;

   --  Lifted export at Index (1 .. Export_Count).
   --  @param The_Model Model to query.
   --  @param Index 1-based index.
   --  @return Lifted export at Index.
   function Get_Export
     (The_Model : Component_Model; Index : Positive) return Lifted_Export;

   --  True when the model includes a run export (entrypoint was present).
   --  @param The_Model Model to query.
   --  @return True iff a run / _start pair was synthesized.
   function Has_Run_Export (The_Model : Component_Model) return Boolean;

   --  Build an empty model with Module_Name and no functions or exports.
   --  @param Name UTF-8 LIR module name.
   --  @return Empty Component_Model.
   function Create (Name : String) return Component_Model;

   --  Append The_Function to The_Model.
   --  @param The_Model Model to extend.
   --  @param The_Function Core function to append.
   procedure Append_Function
     (The_Model : in out Component_Model; The_Function : Core_Function);

   --  Append The_Export to The_Model.
   --  @param The_Model Model to extend.
   --  @param The_Export Lifted export to append.
   procedure Append_Export
     (The_Model : in out Component_Model; The_Export : Lifted_Export);

private

   package Instruction_Vectors is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => Core_Instruction);

   type Instruction_Sequence is record
      Items : Instruction_Vectors.Vector;
   end record;

   package Function_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Core_Function);

   package Export_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Lifted_Export);

   type Component_Model is record
      Module_Name_Value : Ada.Strings.Unbounded.Unbounded_String;
      Functions         : Function_Vectors.Vector;
      Exports           : Export_Vectors.Vector;
   end record;

end Lovelace.Compiler.Backend.Model;
