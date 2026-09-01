with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with Lovelace.Common.Utf_8;

package body Lovelace.Common.Regex is

   subtype Code_Point is Lovelace.Common.Utf_8.Code_Point;

   type Parser is record
      Pos     : Positive := 1;
      Failed  : Boolean := False;
      Group   : Regex_Error_Group := Parse_Error;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Node_Kind is
     (Lit, Alt, Concat, Star, Plus, Question, Class_Node, Any_Node);

   type Node;
   type Node_Access is access Node;

   type Node is record
      Kind    : Node_Kind := Lit;
      Point   : Code_Point := Wide_Wide_Character'Val (0);
      Ranges  : Range_Vectors.Vector;
      Negated : Boolean := False;
      Left    : Node_Access := null;
      Right   : Node_Access := null;
   end record;

   procedure Free_Node is new Ada.Unchecked_Deallocation
     (Node, Node_Access);

   type Builder is record
      Heads : Head_Vectors.Vector;
      Trans : Transition_Vectors.Vector;
   end record;

   type Fragment is record
      Start  : State_Index := 1;
      Finish : State_Index := 1;
   end record;

   type Bool_Array is array (State_Index range <>) of Boolean;

   procedure Add_Any
     (B      : in out Builder;
      From   : State_Index;
      Target : State_Index);
   procedure Add_Class
     (B       : in out Builder;
      From    : State_Index;
      Ranges  : Range_Vectors.Vector;
      Negated : Boolean;
      Target  : State_Index);
   procedure Add_Epsilon
     (B      : in out Builder;
      From   : State_Index;
      Target : State_Index);
   procedure Add_Symbol
     (B      : in out Builder;
      From   : State_Index;
      Point  : Code_Point;
      Target : State_Index);
   procedure Add_Transition
     (B    : in out Builder;
      From : State_Index;
      T    : in out Transition);
   procedure Advance
     (Pattern : String;
      P       : in out Parser);
   function As_Ascii (Point : Code_Point) return Character;
   function At_End
     (Pattern : String;
      P       : Parser) return Boolean;
   function Build
     (N : Node_Access;
      B : in out Builder) return Fragment;
   procedure Destroy_Tree (N : in out Node_Access);
   procedure Epsilon_Closure
     (E   : Engine;
      Set : in out Bool_Array);
   procedure Fail
     (P       : in out Parser;
      Message : String;
      Group   : Regex_Error_Group := Parse_Error);
   function Hex_Value (C : Character) return Integer;
   function In_Class
     (T     : Transition;
      Point : Code_Point) return Boolean;
   function Is_Ascii (Point : Code_Point) return Boolean;
   function New_State (B : in out Builder) return State_Index;
   function Parse_Alt
     (Pattern : String;
      P       : in out Parser) return Node_Access;
   function Parse_Atom
     (Pattern : String;
      P       : in out Parser) return Node_Access;
   function Parse_Class
     (Pattern : String;
      P       : in out Parser;
      Negated : out Boolean) return Range_Vectors.Vector;
   function Parse_Concat
     (Pattern : String;
      P       : in out Parser) return Node_Access;
   function Parse_Escape
     (Pattern : String;
      P       : in out Parser) return Code_Point;
   function Parse_Pattern
     (Pattern : String;
      P       : in out Parser) return Node_Access;
   function Parse_Piece
     (Pattern : String;
      P       : in out Parser) return Node_Access;
   function Parse_Unicode_Escape
     (Pattern : String;
      P       : in out Parser) return Code_Point;
   function Peek
     (Pattern : String;
      P       : in out Parser) return Code_Point;
   procedure Peek_Decode
     (Pattern : String;
      P       : Parser;
      Point   : out Code_Point;
      Length  : out Natural;
      Valid   : out Boolean);

   procedure Add_Any
     (B      : in out Builder;
      From   : State_Index;
      Target : State_Index)
   is
      T : Transition;
   begin
      T.Kind := Any;
      T.Target := Target;
      Add_Transition
        (B    => B,
         From => From,
         T    => T);
   end Add_Any;

   procedure Add_Class
     (B       : in out Builder;
      From    : State_Index;
      Ranges  : Range_Vectors.Vector;
      Negated : Boolean;
      Target  : State_Index)
   is
      T : Transition;
   begin
      T.Kind := Class;
      T.Ranges := Ranges;
      T.Negated := Negated;
      T.Target := Target;
      Add_Transition
        (B    => B,
         From => From,
         T    => T);
   end Add_Class;

   procedure Add_Epsilon
     (B      : in out Builder;
      From   : State_Index;
      Target : State_Index)
   is
      T : Transition;
   begin
      T.Kind := Epsilon;
      T.Target := Target;
      Add_Transition
        (B    => B,
         From => From,
         T    => T);
   end Add_Epsilon;

   procedure Add_Symbol
     (B      : in out Builder;
      From   : State_Index;
      Point  : Code_Point;
      Target : State_Index)
   is
      T : Transition;
   begin
      T.Kind := Code;
      T.Symbol := Point;
      T.Target := Target;
      Add_Transition
        (B    => B,
         From => From,
         T    => T);
   end Add_Symbol;

   procedure Add_Transition
     (B    : in out Builder;
      From : State_Index;
      T    : in out Transition)
   is
   begin
      T.Next := B.Heads (From);
      B.Trans.Append (T);
      B.Heads (From) := B.Trans.Last_Index;
   end Add_Transition;

   procedure Advance
     (Pattern : String;
      P       : in out Parser)
   is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      if P.Failed or else At_End (Pattern, P) then
         return;
      end if;
      Peek_Decode
        (Pattern => Pattern,
         P       => P,
         Point   => Point,
         Length  => Length,
         Valid   => Valid);
      if not Valid or else Length = 0 then
         Fail (P, "invalid UTF-8", Invalid_Utf_8);
         return;
      end if;
      P.Pos := P.Pos + Length;
   end Advance;

   function As_Ascii (Point : Code_Point) return Character is
     (Character'Val (Wide_Wide_Character'Pos (Point)));

   function At_End
     (Pattern : String;
      P       : Parser) return Boolean
   is
     (P.Pos > Pattern'Last);

   function Build
     (N : Node_Access;
      B : in out Builder) return Fragment
   is
      L, R : Fragment;
      S, A : State_Index;
   begin
      case N.Kind is
         when Lit =>
            S := New_State (B);
            A := New_State (B);
            Add_Symbol
              (B      => B,
               From   => S,
               Point  => N.Point,
               Target => A);
            return (Start => S, Finish => A);

         when Any_Node =>
            S := New_State (B);
            A := New_State (B);
            Add_Any
              (B      => B,
               From   => S,
               Target => A);
            return (Start => S, Finish => A);

         when Class_Node =>
            S := New_State (B);
            A := New_State (B);
            Add_Class
              (B       => B,
               From    => S,
               Ranges  => N.Ranges,
               Negated => N.Negated,
               Target  => A);
            return (Start => S, Finish => A);

         when Concat =>
            L := Build (N.Left, B);
            R := Build (N.Right, B);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => R.Start);
            return (Start => L.Start, Finish => R.Finish);

         when Alt =>
            S := New_State (B);
            A := New_State (B);
            L := Build (N.Left, B);
            R := Build (N.Right, B);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => L.Start);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => R.Start);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => A);
            Add_Epsilon
              (B      => B,
               From   => R.Finish,
               Target => A);
            return (Start => S, Finish => A);

         when Star =>
            S := New_State (B);
            A := New_State (B);
            L := Build (N.Left, B);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => L.Start);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => A);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => L.Start);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => A);
            return (Start => S, Finish => A);

         when Plus =>
            S := New_State (B);
            A := New_State (B);
            L := Build (N.Left, B);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => L.Start);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => L.Start);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => A);
            return (Start => S, Finish => A);

         when Question =>
            S := New_State (B);
            A := New_State (B);
            L := Build (N.Left, B);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => L.Start);
            Add_Epsilon
              (B      => B,
               From   => S,
               Target => A);
            Add_Epsilon
              (B      => B,
               From   => L.Finish,
               Target => A);
            return (Start => S, Finish => A);
      end case;
   end Build;

   function Compile (Pattern : String) return Regex_Result
   is
      P     : Parser;
      Root  : Node_Access := null;
      B     : Builder;
      Frag  : Fragment;
      Built : Engine;
   begin
      P.Pos := Pattern'First;
      Root := Parse_Pattern (Pattern, P);
      case P.Failed is
         when True =>
            Destroy_Tree (Root);
            return
              (Ok    => False,
               Error =>
                 Regex_Error
                   (Internal_Errors.Make
                      (Group   => P.Group,
                       Message =>
                         Ada.Strings.Unbounded.To_String
                           (P.Message))));
         when False =>
            Frag := Build (Root, B);
            Destroy_Tree (Root);
            Built.Start := Frag.Start;
            Built.Accepting := Frag.Finish;
            Built.Heads := B.Heads;
            Built.Trans := B.Trans;
            return (Ok => True, Value => Built);
      end case;
   end Compile;

   procedure Destroy_Tree (N : in out Node_Access) is
   begin
      if N = null then
         return;
      end if;
      Destroy_Tree (N.Left);
      Destroy_Tree (N.Right);
      Free_Node (N);
   end Destroy_Tree;

   procedure Epsilon_Closure
     (E   : Engine;
      Set : in out Bool_Array)
   is
      Changed : Boolean := True;
      Idx     : Natural;
   begin
      while Changed loop
         Changed := False;
         for S in Set'Range loop
            if Set (S) then
               Idx := E.Heads (S);
               while Idx /= 0 loop
                  declare
                     T : constant Transition := E.Trans (Idx);
                  begin
                     if T.Kind = Epsilon
                       and then not Set (T.Target)
                     then
                        Set (T.Target) := True;
                        Changed := True;
                     end if;
                     Idx := T.Next;
                  end;
               end loop;
            end if;
         end loop;
      end loop;
   end Epsilon_Closure;

   procedure Fail
     (P       : in out Parser;
      Message : String;
      Group   : Regex_Error_Group := Parse_Error)
   is
   begin
      if P.Failed then
         return;
      end if;
      P.Failed := True;
      P.Group := Group;
      P.Message :=
        Ada.Strings.Unbounded.To_Unbounded_String (Message);
   end Fail;

   function Hex_Value (C : Character) return Integer is
   begin
      case C is
         when '0' .. '9' =>
            return Character'Pos (C) - Character'Pos ('0');
         when 'a' .. 'f' =>
            return Character'Pos (C) - Character'Pos ('a') + 10;
         when 'A' .. 'F' =>
            return Character'Pos (C) - Character'Pos ('A') + 10;
         when others =>
            return -1;
      end case;
   end Hex_Value;

   function In_Class
     (T     : Transition;
      Point : Code_Point) return Boolean
   is
      Hit : Boolean := False;
   begin
      for R of T.Ranges loop
         if Point >= R.Low and then Point <= R.High then
            Hit := True;
            exit;
         end if;
      end loop;
      if T.Negated then
         return not Hit;
      end if;
      return Hit;
   end In_Class;

   function Is_Ascii (Point : Code_Point) return Boolean is
     (Wide_Wide_Character'Pos (Point) <= 127);

   function Match_Prefix
     (E     : Engine;
      Input : String;
      From  : Positive) return Natural
   is
   begin
      if E.Heads.Is_Empty or else From > Input'Last then
         return 0;
      end if;

      declare
         First    : constant State_Index := E.Heads.First_Index;
         Last     : constant State_Index := E.Heads.Last_Index;
         Current  : Bool_Array (First .. Last) := [others => False];
         Next_Set : Bool_Array (First .. Last) := [others => False];
         Best     : Natural := 0;
         Pos      : Positive := From;
         Point    : Code_Point;
         Length   : Natural;
         Valid    : Boolean;
         Moved    : Boolean;
         Idx      : Natural;
      begin
         Current (E.Start) := True;
         Epsilon_Closure (E, Current);

         while Pos <= Input'Last loop
            Lovelace.Common.Utf_8.Decode
              (Source => Input,
               Index  => Pos,
               Point  => Point,
               Length => Length,
               Valid  => Valid);
            exit when not Valid or else Length = 0;

            Next_Set := [others => False];
            Moved := False;

            for S in Current'Range loop
               if Current (S) then
                  Idx := E.Heads (S);
                  while Idx /= 0 loop
                     declare
                        T : constant Transition :=
                          E.Trans (Idx);
                     begin
                        case T.Kind is
                           when Code =>
                              if Point = T.Symbol then
                                 Next_Set (T.Target) := True;
                                 Moved := True;
                              end if;
                           when Class =>
                              if In_Class (T, Point) then
                                 Next_Set (T.Target) := True;
                                 Moved := True;
                              end if;
                           when Any =>
                              Next_Set (T.Target) := True;
                              Moved := True;
                           when Epsilon =>
                              null;
                        end case;
                        Idx := T.Next;
                     end;
                  end loop;
               end if;
            end loop;

            exit when not Moved;

            Epsilon_Closure (E, Next_Set);
            Current := Next_Set;
            if Current (E.Accepting) then
               Best := Pos + Length - From;
            end if;
            Pos := Pos + Length;
         end loop;

         return Best;
      end;
   end Match_Prefix;

   function New_State (B : in out Builder) return State_Index is
   begin
      B.Heads.Append (0);
      return B.Heads.Last_Index;
   end New_State;

   function Parse_Alt
     (Pattern : String;
      P       : in out Parser) return Node_Access
   is
      Left : Node_Access := Parse_Concat (Pattern, P);
      N    : Node_Access;
   begin
      while not P.Failed
        and then not At_End (Pattern, P)
        and then Is_Ascii (Peek (Pattern, P))
        and then As_Ascii (Peek (Pattern, P)) = '|'
      loop
         Advance (Pattern, P);
         N := new Node'
           (Kind  => Alt,
            Left  => Left,
            Right => Parse_Concat (Pattern, P),
            others => <>);
         Left := N;
      end loop;
      return Left;
   end Parse_Alt;

   function Parse_Atom
     (Pattern : String;
      P       : in out Parser) return Node_Access
   is
      N     : Node_Access;
      Point : Code_Point;
      C     : Character;
   begin
      if P.Failed then
         return null;
      end if;
      if At_End (Pattern, P) then
         Fail (P, "unexpected end of pattern");
         return null;
      end if;

      Point := Peek (Pattern, P);
      if not Is_Ascii (Point) then
         N := new Node'(Kind => Lit, Point => Point, others => <>);
         Advance (Pattern, P);
         return N;
      end if;

      C := As_Ascii (Point);
      case C is
         when '(' =>
            Advance (Pattern, P);
            N := Parse_Alt (Pattern, P);
            if At_End (Pattern, P)
              or else not Is_Ascii (Peek (Pattern, P))
              or else As_Ascii (Peek (Pattern, P)) /= ')'
            then
               Fail (P, "unclosed group");
               return N;
            end if;
            Advance (Pattern, P);
            return N;

         when '[' =>
            Advance (Pattern, P);
            N := new Node'(Kind => Class_Node, others => <>);
            N.Ranges := Parse_Class (Pattern, P, N.Negated);
            return N;

         when '\' =>
            Advance (Pattern, P);
            N := new Node'(Kind => Lit, others => <>);
            N.Point := Parse_Escape (Pattern, P);
            return N;

         when '.' =>
            Advance (Pattern, P);
            N := new Node'(Kind => Any_Node, others => <>);
            return N;

         when ')' | '|' | '*' | '+' | '?' | ']' =>
            Fail (P, "unexpected metacharacter");
            return null;

         when others =>
            N := new Node'(Kind => Lit, Point => Point, others => <>);
            Advance (Pattern, P);
            return N;
      end case;
   end Parse_Atom;

   function Parse_Class
     (Pattern : String;
      P       : in out Parser;
      Negated : out Boolean) return Range_Vectors.Vector
   is
      Result    : Range_Vectors.Vector;
      First     : Boolean := True;
      Have_Prev : Boolean := False;
      Prev      : Code_Point := Wide_Wide_Character'Val (0);
      Point     : Code_Point;

      function After_Minus_Is_Close return Boolean;
      function Next_Char return Code_Point;

      function After_Minus_Is_Close return Boolean is
         Next_P : Parser;
         NPoint : Code_Point;
         NLen   : Natural;
         NValid : Boolean;
      begin
         if At_End (Pattern, P) then
            return True;
         end if;
         Next_P.Pos := P.Pos + 1;
         if Next_P.Pos > Pattern'Last then
            return True;
         end if;
         Peek_Decode
           (Pattern => Pattern,
            P       => Next_P,
            Point   => NPoint,
            Length  => NLen,
            Valid   => NValid);
         return NValid
           and then Is_Ascii (NPoint)
           and then As_Ascii (NPoint) = ']';
      end After_Minus_Is_Close;

      function Next_Char return Code_Point is
         C : Code_Point;
      begin
         if At_End (Pattern, P) then
            Fail (P, "unclosed character class");
            return Wide_Wide_Character'Val (0);
         end if;
         C := Peek (Pattern, P);
         if Is_Ascii (C) and then As_Ascii (C) = '\' then
            Advance (Pattern, P);
            return Parse_Escape (Pattern, P);
         end if;
         Advance (Pattern, P);
         return C;
      end Next_Char;

   begin
      Negated := False;
      if not At_End (Pattern, P)
        and then Is_Ascii (Peek (Pattern, P))
        and then As_Ascii (Peek (Pattern, P)) = '^'
      then
         Negated := True;
         Advance (Pattern, P);
      end if;

      while not P.Failed and then not At_End (Pattern, P) loop
         Point := Peek (Pattern, P);
         exit when Is_Ascii (Point) and then As_Ascii (Point) = ']';

         if Have_Prev
           and then Is_Ascii (Point)
           and then As_Ascii (Point) = '-'
           and then not After_Minus_Is_Close
         then
            Advance (Pattern, P);
            declare
               Hi : constant Code_Point := Next_Char;
            begin
               if Hi < Prev then
                  Fail (P, "invalid character range");
               else
                  Result.Append
                    (Code_Range'(Low => Prev, High => Hi));
               end if;
            end;
            Have_Prev := False;
         else
            if Have_Prev then
               Result.Append
                 (Code_Range'(Low => Prev, High => Prev));
            end if;
            Prev := Next_Char;
            Have_Prev := True;
         end if;
         First := False;
      end loop;

      if Have_Prev then
         Result.Append (Code_Range'(Low => Prev, High => Prev));
      end if;

      if First then
         Fail (P, "empty character class");
         return Result;
      end if;

      if At_End (Pattern, P)
        or else not Is_Ascii (Peek (Pattern, P))
        or else As_Ascii (Peek (Pattern, P)) /= ']'
      then
         Fail (P, "unclosed character class");
         return Result;
      end if;
      Advance (Pattern, P);
      return Result;
   end Parse_Class;

   function Parse_Concat
     (Pattern : String;
      P       : in out Parser) return Node_Access
   is
      Left : Node_Access := Parse_Piece (Pattern, P);
      N    : Node_Access;
      C    : Character;
   begin
      while not P.Failed and then not At_End (Pattern, P) loop
         if Is_Ascii (Peek (Pattern, P)) then
            C := As_Ascii (Peek (Pattern, P));
            exit when C = ')' or else C = '|';
         end if;
         N := new Node'
           (Kind  => Concat,
            Left  => Left,
            Right => Parse_Piece (Pattern, P),
            others => <>);
         Left := N;
      end loop;
      return Left;
   end Parse_Concat;

   function Parse_Escape
     (Pattern : String;
      P       : in out Parser) return Code_Point
   is
      Point : Code_Point;
      C     : Character;
   begin
      if P.Failed then
         return Wide_Wide_Character'Val (0);
      end if;
      if At_End (Pattern, P) then
         Fail (P, "trailing backslash");
         return Wide_Wide_Character'Val (0);
      end if;
      Point := Peek (Pattern, P);
      Advance (Pattern, P);
      if not Is_Ascii (Point) then
         Fail (P, "unsupported escape");
         return Wide_Wide_Character'Val (0);
      end if;
      C := As_Ascii (Point);
      case C is
         when 'n' =>
            return Wide_Wide_Character'Val
              (Character'Pos (ASCII.LF));
         when 't' =>
            return Wide_Wide_Character'Val
              (Character'Pos (ASCII.HT));
         when 'r' =>
            return Wide_Wide_Character'Val
              (Character'Pos (ASCII.CR));
         when 'f' =>
            return Wide_Wide_Character'Val
              (Character'Pos (ASCII.FF));
         when 'e' =>
            return Wide_Wide_Character'Val
              (Character'Pos (ASCII.ESC));
         when '\' =>
            return Wide_Wide_Character'Val (Character'Pos ('\'));
         when 'u' =>
            return Parse_Unicode_Escape (Pattern, P);
         when '|' | '(' | ')' | '+' | '*' | '?' | '[' | ']' | '.'
            | '-' | '^' | '$' | '%' | '/' | '{' | '}' | '"' | ''' =>
            return Point;
         when others =>
            Fail (P, "unsupported escape");
            return Wide_Wide_Character'Val (0);
      end case;
   end Parse_Escape;

   function Parse_Pattern
     (Pattern : String;
      P       : in out Parser) return Node_Access
   is
      Root : Node_Access;
   begin
      if Pattern'Length = 0 then
         Fail (P, "empty pattern");
         return null;
      end if;
      Root := Parse_Alt (Pattern, P);
      if P.Failed then
         return Root;
      end if;
      if not At_End (Pattern, P) then
         Fail (P, "trailing characters in pattern");
      end if;
      return Root;
   end Parse_Pattern;

   function Parse_Piece
     (Pattern : String;
      P       : in out Parser) return Node_Access
   is
      Atom : constant Node_Access := Parse_Atom (Pattern, P);
      N    : Node_Access;
      C    : Character;
   begin
      if P.Failed then
         return Atom;
      end if;
      if not At_End (Pattern, P)
        and then Is_Ascii (Peek (Pattern, P))
      then
         C := As_Ascii (Peek (Pattern, P));
         case C is
            when '*' =>
               Advance (Pattern, P);
               N := new Node'
                 (Kind => Star, Left => Atom, others => <>);
               return N;
            when '+' =>
               Advance (Pattern, P);
               N := new Node'
                 (Kind => Plus, Left => Atom, others => <>);
               return N;
            when '?' =>
               Advance (Pattern, P);
               N := new Node'
                 (Kind => Question, Left => Atom, others => <>);
               return N;
            when others =>
               null;
         end case;
      end if;
      return Atom;
   end Parse_Piece;

   function Parse_Unicode_Escape
     (Pattern : String;
      P       : in out Parser) return Code_Point
   is
      Acc         : Natural := 0;
      Digit_Count : Natural := 0;
      Point       : Code_Point;
      Hex_Digit   : Integer;
      C           : Character;
   begin
      if At_End (Pattern, P) or else not Is_Ascii (Peek (Pattern, P))
        or else As_Ascii (Peek (Pattern, P)) /= '{'
      then
         Fail (P, "expected '{'");
         return Wide_Wide_Character'Val (0);
      end if;
      Advance (Pattern, P);

      while not P.Failed and then not At_End (Pattern, P) loop
         Point := Peek (Pattern, P);
         if Is_Ascii (Point) and then As_Ascii (Point) = '}' then
            exit;
         end if;
         if not Is_Ascii (Point) then
            Fail (P, "invalid hex digit");
            return Wide_Wide_Character'Val (0);
         end if;
         C := As_Ascii (Point);
         Hex_Digit := Hex_Value (C);
         if Hex_Digit < 0 then
            Fail (P, "invalid hex digit");
            return Wide_Wide_Character'Val (0);
         end if;
         Digit_Count := Digit_Count + 1;
         if Digit_Count > 6 then
            Fail (P, "Unicode escape too long");
            return Wide_Wide_Character'Val (0);
         end if;
         Acc := Acc * 16 + Natural (Hex_Digit);
         if Acc > 16#10FFFF# then
            Fail (P, "Unicode scalar too large");
            return Wide_Wide_Character'Val (0);
         end if;
         Advance (Pattern, P);
      end loop;

      if Digit_Count = 0 then
         Fail (P, "empty Unicode escape");
         return Wide_Wide_Character'Val (0);
      end if;
      if At_End (Pattern, P) or else not Is_Ascii (Peek (Pattern, P))
        or else As_Ascii (Peek (Pattern, P)) /= '}'
      then
         Fail (P, "unclosed Unicode escape");
         return Wide_Wide_Character'Val (0);
      end if;
      Advance (Pattern, P);

      if Acc in 16#D800# .. 16#DFFF# then
         Fail (P, "surrogate in Unicode escape");
         return Wide_Wide_Character'Val (0);
      end if;
      return Wide_Wide_Character'Val (Acc);
   end Parse_Unicode_Escape;

   function Peek
     (Pattern : String;
      P       : in out Parser) return Code_Point
   is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      if P.Failed or else At_End (Pattern, P) then
         return Wide_Wide_Character'Val (0);
      end if;
      Peek_Decode
        (Pattern => Pattern,
         P       => P,
         Point   => Point,
         Length  => Length,
         Valid   => Valid);
      if not Valid then
         Fail (P, "invalid UTF-8", Invalid_Utf_8);
         return Wide_Wide_Character'Val (0);
      end if;
      return Point;
   end Peek;

   procedure Peek_Decode
     (Pattern : String;
      P       : Parser;
      Point   : out Code_Point;
      Length  : out Natural;
      Valid   : out Boolean)
   is
   begin
      Lovelace.Common.Utf_8.Decode
        (Source => Pattern,
         Index  => P.Pos,
         Point  => Point,
         Length => Length,
         Valid  => Valid);
   end Peek_Decode;

end Lovelace.Common.Regex;
