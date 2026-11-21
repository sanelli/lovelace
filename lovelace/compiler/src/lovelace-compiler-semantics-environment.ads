with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Lovelace.Common.Source;
with Lovelace.Compiler.Semantics.Lovelace_Types;

--  Scope-stack environment: what each name binds to at a point in the AST walk.
--  New entity kinds (types, constants, ...) extend Entity_Kind without reshaping callers.

package Lovelace.Compiler.Semantics.Environment is

   package Source renames Lovelace.Common.Source;

   --  What a name binds to.
   --  @enum Local_Entity Local variable declared in a block's `declare` part.
   --  @enum Parameter_Entity Subroutine parameter (assigned on entry).
   --  @enum Module_Entity Module brought into scope by `using`.
   --  @enum Subroutine_Entity Subroutine of the unit being analysed.
   type Entity_Kind is (Local_Entity, Parameter_Entity, Module_Entity, Subroutine_Entity);

   --  Set of entity kinds used to filter lookups.
   type Kind_Set is array (Entity_Kind) of Boolean;

   --  Kinds that can appear as an expression or assignment target.
   Variable_Kinds : constant Kind_Set := [Local_Entity | Parameter_Entity => True, others => False];

   --  Kinds that name modules.
   Module_Kinds : constant Kind_Set := [Module_Entity => True, others => False];

   --  Kinds that name subroutines.
   Subroutine_Kinds : constant Kind_Set := [Subroutine_Entity => True, others => False];

   --  One named binding.
   --  @field Kind Entity kind.
   --  @field Name UTF-8 name (dotted for modules).
   --  @field Span Source extent of the declaration.
   --  @field Value_Type Declared type for variables and parameters.
   --  @field Variable_Id Slot in the flow trackers for variables and parameters (0 otherwise).
   --  @field Unit_Index Owning unit for subroutines (0 otherwise).
   --  @field Subroutine_Index 1-based subroutine index within the owning unit (0 otherwise).
   type Entity is record
      Kind             : Entity_Kind := Local_Entity;
      Name             : Ada.Strings.Unbounded.Unbounded_String;
      Span             : Source.Source_Span;
      Value_Type       : Lovelace_Types.Lovelace_Type;
      Variable_Id      : Natural := 0;
      Unit_Index       : Natural := 0;
      Subroutine_Index : Natural := 0;
   end record;

   --  Stack of scopes (innermost last).
   type Scope_Stack is private;

   --  Result of Lookup.
   --  @disc Found True when a binding matched.
   --  @field Value The matching entity when Found is True.
   type Lookup_Result (Found : Boolean := False) is record
      case Found is
         when True =>
            Value : Entity;

         when False =>
            null;
      end case;
   end record;

   --  Open a new innermost scope.
   --  @param The_Stack Stack to extend.
   procedure Push_Scope (The_Stack : in out Scope_Stack);

   --  Close the innermost scope (no-op when the stack is empty).
   --  @param The_Stack Stack to shrink.
   procedure Pop_Scope (The_Stack : in out Scope_Stack);

   --  Number of open scopes.
   --  @param The_Stack Stack to query.
   --  @return Open scope count.
   function Depth (The_Stack : Scope_Stack) return Natural;

   --  Bind The_Entity in the innermost scope (opens one when the stack is empty).
   --  @param The_Stack Stack to extend.
   --  @param The_Entity Binding to add.
   procedure Declare_Entity (The_Stack : in out Scope_Stack; The_Entity : Entity);

   --  Find the innermost binding named Name whose kind is in Kinds.
   --  @param The_Stack Stack to search (innermost scope first).
   --  @param Name UTF-8 name.
   --  @param Kinds Entity kinds that may match.
   --  @return Matching entity, or not found.
   function Lookup (The_Stack : Scope_Stack; Name : String; Kinds : Kind_Set) return Lookup_Result;

   --  Variable or parameter named Name visible from the current scope.
   --  @param The_Stack Stack to search.
   --  @param Name UTF-8 identifier.
   --  @return Matching entity, or not found.
   function Lookup_Variable (The_Stack : Scope_Stack; Name : String) return Lookup_Result;

   --  Module named Name visible via a using at the current scope.
   --  @param The_Stack Stack to search.
   --  @param Name UTF-8 dotted module name.
   --  @return Matching entity, or not found.
   function Lookup_Module (The_Stack : Scope_Stack; Name : String) return Lookup_Result;

   --  Subroutine of the current unit named Name.
   --  @param The_Stack Stack to search.
   --  @param Name UTF-8 unqualified subroutine name.
   --  @return Matching entity, or not found.
   function Lookup_Subroutine (The_Stack : Scope_Stack; Name : String) return Lookup_Result;

private

   package Entity_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Entity);

   package Scope_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Entity_Vectors.Vector, "=" => Entity_Vectors."=");

   type Scope_Stack is record
      Scopes : Scope_Vectors.Vector;
   end record;

end Lovelace.Compiler.Semantics.Environment;
