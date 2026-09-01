--  Compile a UTF-8 regular-expression subset to an NFA and match
--  prefixes by Unicode scalar.
with Lovelace.Common.Internal_Error;
private with Ada.Containers.Vectors;

package Lovelace.Common.Regex is

   --  Why regex compilation failed (implementers only).
   type Regex_Error_Group is (Invalid_Utf_8, Parse_Error);

   package Internal_Errors is new Lovelace.Common.Internal_Error
     (Error_Group => Regex_Error_Group);

   --  Internal compile failure: group plus detail string.
   type Regex_Error is new Internal_Errors.Lovelace_Internal_Error;

   --  A compiled NFA. Default value matches nothing.
   type Engine is private;

   --  Result<Engine, Regex_Error> (same shape as Lovelace.Common.Result).
   --  Reusable for any regex operation that returns Engine or Regex_Error.
   type Regex_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Value : Engine;
         when False =>
            Error : Regex_Error;
      end case;
   end record;

   --  Compile Pattern into an NFA. Pattern is a UTF-8 byte string.
   --  On failure, Ok is False and Error is a Regex_Error.
   function Compile (Pattern : String) return Regex_Result;

   --  Longest accepting prefix length in UTF-8 bytes starting at
   --  Input (From). Returns 0 when there is no match of length at
   --  least 1, when From is past Input'Last, or when the match is
   --  empty-only. Invalid UTF-8 in Input does not match.
   function Match_Prefix
     (E     : Engine;
      Input : String;
      From  : Positive) return Natural;

private

   type State_Index is new Positive;

   type Transition_Kind is (Epsilon, Code, Class, Any);

   type Code_Range is record
      Low  : Wide_Wide_Character := Wide_Wide_Character'Val (0);
      High : Wide_Wide_Character := Wide_Wide_Character'Val (0);
   end record;

   package Range_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Code_Range);

   type Transition is record
      Kind     : Transition_Kind := Epsilon;
      Symbol   : Wide_Wide_Character := Wide_Wide_Character'Val (0);
      Ranges   : Range_Vectors.Vector;
      Negated  : Boolean := False;
      Target   : State_Index := 1;
      Next     : Natural := 0;
   end record;

   package Transition_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Transition);

   package Head_Vectors is new Ada.Containers.Vectors
     (Index_Type   => State_Index,
      Element_Type => Natural);

   type Engine is record
      Start     : State_Index := 1;
      Accepting : State_Index := 1;
      Heads     : Head_Vectors.Vector;
      Trans     : Transition_Vectors.Vector;
   end record;

end Lovelace.Common.Regex;
