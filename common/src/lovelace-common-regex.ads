--  Compile a UTF-8 regular-expression subset to an NFA and match
--  prefixes by Unicode scalar.
with Lovelace.Common.Internal_Error;
private with Ada.Containers.Vectors;

package Lovelace.Common.Regex is

   --  Why regex compilation failed (implementers only).
   --  @enum Invalid_Utf_8 Pattern is not valid UTF-8.
   --  @enum Parse_Error Pattern is valid UTF-8 but the grammar failed.
   type Regex_Error_Group is (Invalid_Utf_8, Parse_Error);

   --  Internal_Error instantiated with Regex_Error_Group.
   package Internal_Errors is new Lovelace.Common.Internal_Error
     (Error_Group => Regex_Error_Group);

   --  Internal compile failure: group plus detail string.
   type Regex_Error is new Internal_Errors.Lovelace_Internal_Error;

   --  A compiled NFA. Default value matches nothing.
   type Engine is private;

   --  Result of Engine or Regex_Error (same shape as Result).
   --  @disc Ok True when Value is present; False when Error is.
   --  @field Value Compiled NFA when Ok is True.
   --  @field Error Compile failure when Ok is False.
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
   --  @param Pattern UTF-8 regular-expression source.
   --  @return Compiled engine, or a Regex_Error.
   function Compile (Pattern : String) return Regex_Result;

   --  Longest accepting prefix length in UTF-8 bytes starting at
   --  Input (From). Returns 0 when there is no match of length at
   --  least 1, when From is past Input'Last, or when the match is
   --  empty-only. Invalid UTF-8 in Input does not match.
   --  @param The_Engine Compiled NFA.
   --  @param Input UTF-8 subject string.
   --  @param From First byte of the attempted prefix.
   --  @return Match length in bytes, or 0.
   function Match_Prefix
     (The_Engine : Engine;
      Input      : String;
      From       : Positive) return Natural;

private

   --  Index of an NFA state in Heads and Transactions.
   type State_Index is new Positive;

   --  Kind of a single NFA edge.
   --  @enum Epsilon Empty move; does not consume a scalar.
   --  @enum Exact_Scalar Matches one exact scalar in Symbol.
   --  @enum Class Matches a scalar in Ranges, honoring Negated.
   --  @enum Any Matches any single scalar.
   type Transition_Kind is (Epsilon, Exact_Scalar, Class, Any);

   --  Inclusive Unicode scalar interval used by Class transitions.
   --  @field Low First scalar in the interval.
   --  @field High Last scalar in the interval.
   type Code_Range is record
      Low  : Wide_Wide_Character := Wide_Wide_Character'Val (0);
      High : Wide_Wide_Character := Wide_Wide_Character'Val (0);
   end record;

   --  Ordered list of Code_Range values for a Class transition.
   package Range_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Code_Range);

   --  One NFA edge from a state, chained via Next.
   --  @field Kind How this edge matches.
   --  @field Symbol Scalar for Kind Exact_Scalar.
   --  @field Ranges Intervals for Kind Class.
   --  @field Negated When True, Class matches outside Ranges.
   --  @field Target Destination state.
   --  @field Next Index of the next edge from the same state, or 0.
   type Transition is record
      Kind     : Transition_Kind := Epsilon;
      Symbol   : Wide_Wide_Character := Wide_Wide_Character'Val (0);
      Ranges   : Range_Vectors.Vector;
      Negated  : Boolean := False;
      Target   : State_Index := 1;
      Next     : Natural := 0;
   end record;

   --  All transitions of a compiled or in-progress NFA.
   package Transition_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Transition);

   --  Per-state head index into Transition_Vectors, or 0 if none.
   package Head_Vectors is new Ada.Containers.Vectors
     (Index_Type   => State_Index,
      Element_Type => Natural);

   --  Compiled Thompson NFA.
   --  @field Start Initial state.
   --  @field Accepting Unique accepting state.
   --  @field Heads First transition index per state, or 0.
   --  @field Transactions All edges, chained per state by Next.
   type Engine is record
      Start        : State_Index := 1;
      Accepting    : State_Index := 1;
      Heads        : Head_Vectors.Vector;
      Transactions : Transition_Vectors.Vector;
   end record;

end Lovelace.Common.Regex;
