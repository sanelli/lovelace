with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with Lovelace.Common.Utf_8;

package body Lovelace.Common.Regex is

   subtype Code_Point is Lovelace.Common.Utf_8.Code_Point;

   type Parser is record
      Position : Positive := 1;
      Failed   : Boolean := False;
      Group    : Regex_Error_Group := Parse_Error;
      Message  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Node_Kind is (Literal, Alternation, Concat, Star, Plus, Question, Class_Node, Any_Node);

   type Node;
   type Node_Access is access Node;

   type Node is record
      Kind    : Node_Kind := Literal;
      Point   : Code_Point := Wide_Wide_Character'Val (0);
      Ranges  : Range_Vectors.Vector;
      Negated : Boolean := False;
      Left    : Node_Access := null;
      Right   : Node_Access := null;
   end record;

   procedure Free_Node is new Ada.Unchecked_Deallocation (Node, Node_Access);

   type Builder is record
      Heads        : Head_Vectors.Vector;
      Transactions : Transition_Vectors.Vector;
   end record;

   type Fragment is record
      Start  : State_Index := 1;
      Finish : State_Index := 1;
   end record;

   type Bool_Array is array (State_Index range <>) of Boolean;

   procedure Accumulate_Hex_Digit
     (The_Parser : in out Parser; Point : Code_Point; Accumulator : in out Natural; Digit_Count : in out Natural);
   procedure Add_Any (The_Builder : in out Builder; From : State_Index; Target : State_Index);
   procedure Add_Class
     (The_Builder : in out Builder;
      From        : State_Index;
      Ranges      : Range_Vectors.Vector;
      Negated     : Boolean;
      Target      : State_Index);
   procedure Add_Epsilon (The_Builder : in out Builder; From : State_Index; Target : State_Index);
   procedure Add_Symbol (The_Builder : in out Builder; From : State_Index; Point : Code_Point; Target : State_Index);
   procedure Add_Transition (The_Builder : in out Builder; From : State_Index; The_Transition : in out Transition);
   procedure Advance (Pattern : String; The_Parser : in out Parser);
   function After_Minus_Is_Close (Pattern : String; The_Parser : Parser) return Boolean;
   function As_Ascii (Point : Code_Point) return Character;
   function At_End (Pattern : String; The_Parser : Parser) return Boolean;
   function Build (The_Node : Node_Access; The_Builder : in out Builder) return Fragment;
   function Control_Escape (The_Character : Character) return Code_Point;
   procedure Destroy_Tree (The_Node : in out Node_Access);
   procedure Epsilon_Closure (The_Engine : Engine; Set : in out Bool_Array);
   procedure Fail (The_Parser : in out Parser; Message : String; Group : Regex_Error_Group := Parse_Error);
   function Hex_Value (The_Character : Character) return Integer;
   function In_Class (The_Transition : Transition; Point : Code_Point) return Boolean;
   function Is_Ascii (Point : Code_Point) return Boolean;
   function Is_Char (Point : Code_Point; Expected : Character) return Boolean;
   function New_State (The_Builder : in out Builder) return State_Index;
   function Next_Scalar (Pattern : String; The_Parser : in out Parser) return Code_Point;
   function Parse_Alt (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Atom (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Atom_Ascii (Pattern : String; The_Parser : in out Parser; Point : Code_Point) return Node_Access;
   function Parse_Class
     (Pattern : String; The_Parser : in out Parser; Negated : out Boolean) return Range_Vectors.Vector;
   procedure Parse_Class_Caret (Pattern : String; The_Parser : in out Parser; Negated : out Boolean);
   procedure Parse_Class_Item
     (Pattern        : String;
      The_Parser     : in out Parser;
      Point          : Code_Point;
      Result         : in out Range_Vectors.Vector;
      Have_Previous  : in out Boolean;
      Previous_Point : in out Code_Point);
   procedure Parse_Class_Items
     (Pattern : String; The_Parser : in out Parser; Result : in out Range_Vectors.Vector; Empty : out Boolean);
   function Parse_Class_Node (Pattern : String; The_Parser : in out Parser) return Node_Access;
   procedure Parse_Class_Range
     (Pattern : String; The_Parser : in out Parser; Previous_Point : Code_Point; Result : in out Range_Vectors.Vector);
   function Parse_Concat (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Escape (Pattern : String; The_Parser : in out Parser) return Code_Point;
   function Parse_Escape_Node (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Group (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Literal (Pattern : String; The_Parser : in out Parser; Point : Code_Point) return Node_Access;
   function Parse_Pattern (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Piece (Pattern : String; The_Parser : in out Parser) return Node_Access;
   function Parse_Unicode_Escape (Pattern : String; The_Parser : in out Parser) return Code_Point;
   function Peek (Pattern : String; The_Parser : in out Parser) return Code_Point;
   procedure Peek_Decode
     (Pattern : String; The_Parser : Parser; Point : out Code_Point; Length : out Natural; Valid : out Boolean);
   function Peek_Is (Pattern : String; The_Parser : in out Parser; Expected : Character) return Boolean;
   procedure Read_Hex_Digits
     (Pattern : String; The_Parser : in out Parser; Accumulator : out Natural; Digit_Count : out Natural);
   procedure Step_Set
     (The_Engine : Engine; Current : Bool_Array; Point : Code_Point; Next_Set : out Bool_Array; Moved : out Boolean);
   function Transition_Matches (The_Transition : Transition; Point : Code_Point) return Boolean;

   procedure Accumulate_Hex_Digit
     (The_Parser : in out Parser; Point : Code_Point; Accumulator : in out Natural; Digit_Count : in out Natural)
   is
      Hex_Digit : Integer := -1;
   begin
      if Is_Ascii (Point) then
         Hex_Digit := Hex_Value (As_Ascii (Point));
      end if;
      if Hex_Digit < 0 then
         Fail (The_Parser, "invalid hex digit");
         return;
      end if;
      Digit_Count := Digit_Count + 1;
      if Digit_Count > 6 then
         Fail (The_Parser, "Unicode escape too long");
         return;
      end if;
      Accumulator := Accumulator * 16 + Natural (Hex_Digit);
      if Accumulator > 16#10FFFF# then
         Fail (The_Parser, "Unicode scalar too large");
      end if;
   end Accumulate_Hex_Digit;

   procedure Add_Any (The_Builder : in out Builder; From : State_Index; Target : State_Index) is
      The_Transition : Transition;
   begin
      The_Transition.Kind := Any;
      The_Transition.Target := Target;
      Add_Transition (The_Builder => The_Builder, From => From, The_Transition => The_Transition);
   end Add_Any;

   procedure Add_Class
     (The_Builder : in out Builder;
      From        : State_Index;
      Ranges      : Range_Vectors.Vector;
      Negated     : Boolean;
      Target      : State_Index)
   is
      The_Transition : Transition;
   begin
      The_Transition.Kind := Class;
      The_Transition.Ranges := Ranges;
      The_Transition.Negated := Negated;
      The_Transition.Target := Target;
      Add_Transition (The_Builder => The_Builder, From => From, The_Transition => The_Transition);
   end Add_Class;

   procedure Add_Epsilon (The_Builder : in out Builder; From : State_Index; Target : State_Index) is
      The_Transition : Transition;
   begin
      The_Transition.Kind := Epsilon;
      The_Transition.Target := Target;
      Add_Transition (The_Builder => The_Builder, From => From, The_Transition => The_Transition);
   end Add_Epsilon;

   procedure Add_Symbol (The_Builder : in out Builder; From : State_Index; Point : Code_Point; Target : State_Index) is
      The_Transition : Transition;
   begin
      The_Transition.Kind := Exact_Scalar;
      The_Transition.Symbol := Point;
      The_Transition.Target := Target;
      Add_Transition (The_Builder => The_Builder, From => From, The_Transition => The_Transition);
   end Add_Symbol;

   procedure Add_Transition (The_Builder : in out Builder; From : State_Index; The_Transition : in out Transition) is
   begin
      The_Transition.Next := The_Builder.Heads (From);
      The_Builder.Transactions.Append (The_Transition);
      The_Builder.Heads (From) := The_Builder.Transactions.Last_Index;
   end Add_Transition;

   procedure Advance (Pattern : String; The_Parser : in out Parser) is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      if The_Parser.Failed or else At_End (Pattern, The_Parser) then
         return;
      end if;
      Peek_Decode (Pattern => Pattern, The_Parser => The_Parser, Point => Point, Length => Length, Valid => Valid);
      if not Valid or else Length = 0 then
         Fail (The_Parser, "invalid UTF-8", Invalid_Utf_8);
         return;
      end if;
      The_Parser.Position := The_Parser.Position + Length;
   end Advance;

   function After_Minus_Is_Close (Pattern : String; The_Parser : Parser) return Boolean is
      Next_Parser : Parser;
      Next_Point  : Code_Point;
      Next_Length : Natural;
      Next_Valid  : Boolean;
   begin
      if At_End (Pattern, The_Parser) then
         return True;
      end if;
      Next_Parser.Position := The_Parser.Position + 1;
      if Next_Parser.Position > Pattern'Last then
         return True;
      end if;
      Peek_Decode
        (Pattern    => Pattern,
         The_Parser => Next_Parser,
         Point      => Next_Point,
         Length     => Next_Length,
         Valid      => Next_Valid);
      return Next_Valid and then Is_Char (Next_Point, ']');
   end After_Minus_Is_Close;

   function As_Ascii (Point : Code_Point) return Character
   is (Character'Val (Wide_Wide_Character'Pos (Point)));

   function At_End (Pattern : String; The_Parser : Parser) return Boolean
   is (The_Parser.Position > Pattern'Last);

   function Build (The_Node : Node_Access; The_Builder : in out Builder) return Fragment is
      Left, Right               : Fragment;
      Start_State, Accept_State : State_Index;
   begin
      case The_Node.Kind is
         when Literal     =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Add_Symbol
              (The_Builder => The_Builder, From => Start_State, Point => The_Node.Point, Target => Accept_State);
            return (Start => Start_State, Finish => Accept_State);

         when Any_Node    =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Add_Any (The_Builder => The_Builder, From => Start_State, Target => Accept_State);
            return (Start => Start_State, Finish => Accept_State);

         when Class_Node  =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Add_Class
              (The_Builder => The_Builder,
               From        => Start_State,
               Ranges      => The_Node.Ranges,
               Negated     => The_Node.Negated,
               Target      => Accept_State);
            return (Start => Start_State, Finish => Accept_State);

         when Concat      =>
            Left := Build (The_Node.Left, The_Builder);
            Right := Build (The_Node.Right, The_Builder);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Right.Start);
            return (Start => Left.Start, Finish => Right.Finish);

         when Alternation =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Left := Build (The_Node.Left, The_Builder);
            Right := Build (The_Node.Right, The_Builder);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Left.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Right.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Accept_State);
            Add_Epsilon (The_Builder => The_Builder, From => Right.Finish, Target => Accept_State);
            return (Start => Start_State, Finish => Accept_State);

         when Star        =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Left := Build (The_Node.Left, The_Builder);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Left.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Accept_State);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Left.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Accept_State);
            return (Start => Start_State, Finish => Accept_State);

         when Plus        =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Left := Build (The_Node.Left, The_Builder);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Left.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Left.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Accept_State);
            return (Start => Start_State, Finish => Accept_State);

         when Question    =>
            Start_State := New_State (The_Builder);
            Accept_State := New_State (The_Builder);
            Left := Build (The_Node.Left, The_Builder);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Left.Start);
            Add_Epsilon (The_Builder => The_Builder, From => Start_State, Target => Accept_State);
            Add_Epsilon (The_Builder => The_Builder, From => Left.Finish, Target => Accept_State);
            return (Start => Start_State, Finish => Accept_State);
      end case;
   end Build;

   function Compile (Pattern : String) return Regex_Result is
      The_Parser   : Parser;
      Root         : Node_Access := null;
      The_Builder  : Builder;
      The_Fragment : Fragment;
      Built        : Engine;
   begin
      The_Parser.Position := Pattern'First;
      Root := Parse_Pattern (Pattern, The_Parser);
      case The_Parser.Failed is
         when True  =>
            Destroy_Tree (Root);
            return
              (Ok    => False,
               Error =>
                 Regex_Error
                   (Internal_Errors.Make
                      (Group => The_Parser.Group, Message => Ada.Strings.Unbounded.To_String (The_Parser.Message))));

         when False =>
            The_Fragment := Build (Root, The_Builder);
            Destroy_Tree (Root);
            Built.Start := The_Fragment.Start;
            Built.Accepting := The_Fragment.Finish;
            Built.Heads := The_Builder.Heads;
            Built.Transactions := The_Builder.Transactions;
            return (Ok => True, Value => Built);
      end case;
   end Compile;

   function Control_Escape (The_Character : Character) return Code_Point is
   begin
      case The_Character is
         when 'n'    =>
            return Wide_Wide_Character'Val (Character'Pos (ASCII.LF));

         when 't'    =>
            return Wide_Wide_Character'Val (Character'Pos (ASCII.HT));

         when 'r'    =>
            return Wide_Wide_Character'Val (Character'Pos (ASCII.CR));

         when 'f'    =>
            return Wide_Wide_Character'Val (Character'Pos (ASCII.FF));

         when others =>
            return Wide_Wide_Character'Val (Character'Pos (ASCII.ESC));
      end case;
   end Control_Escape;

   procedure Destroy_Tree (The_Node : in out Node_Access) is
   begin
      if The_Node = null then
         return;
      end if;
      Destroy_Tree (The_Node.Left);
      Destroy_Tree (The_Node.Right);
      Free_Node (The_Node);
   end Destroy_Tree;

   procedure Epsilon_Closure (The_Engine : Engine; Set : in out Bool_Array) is
      Changed : Boolean := True;
      Index   : Natural;
   begin
      while Changed loop
         Changed := False;
         for State in Set'Range loop
            if Set (State) then
               Index := The_Engine.Heads (State);
               while Index /= 0 loop
                  declare
                     The_Transition : constant Transition := The_Engine.Transactions (Index);
                  begin
                     if The_Transition.Kind = Epsilon and then not Set (The_Transition.Target) then
                        Set (The_Transition.Target) := True;
                        Changed := True;
                     end if;
                     Index := The_Transition.Next;
                  end;
               end loop;
            end if;
         end loop;
      end loop;
   end Epsilon_Closure;

   procedure Fail (The_Parser : in out Parser; Message : String; Group : Regex_Error_Group := Parse_Error) is
   begin
      if The_Parser.Failed then
         return;
      end if;
      The_Parser.Failed := True;
      The_Parser.Group := Group;
      The_Parser.Message := Ada.Strings.Unbounded.To_Unbounded_String (Message);
   end Fail;

   function Hex_Value (The_Character : Character) return Integer is
   begin
      case The_Character is
         when '0' .. '9' =>
            return Character'Pos (The_Character) - Character'Pos ('0');

         when 'a' .. 'f' =>
            return Character'Pos (The_Character) - Character'Pos ('a') + 10;

         when 'A' .. 'F' =>
            return Character'Pos (The_Character) - Character'Pos ('A') + 10;

         when others     =>
            return -1;
      end case;
   end Hex_Value;

   function In_Class (The_Transition : Transition; Point : Code_Point) return Boolean is
      Hit : Boolean := False;
   begin
      for The_Range of The_Transition.Ranges loop
         if Point >= The_Range.Low and then Point <= The_Range.High then
            Hit := True;
            exit;
         end if;
      end loop;
      if The_Transition.Negated then
         return not Hit;
      end if;
      return Hit;
   end In_Class;

   function Is_Ascii (Point : Code_Point) return Boolean
   is (Wide_Wide_Character'Pos (Point) <= 127);

   function Is_Char (Point : Code_Point; Expected : Character) return Boolean
   is (Is_Ascii (Point) and then As_Ascii (Point) = Expected);

   function Match_Prefix (The_Engine : Engine; Input : String; From : Positive) return Natural is
   begin
      if The_Engine.Heads.Is_Empty or else From > Input'Last then
         return 0;
      end if;

      declare
         First    : constant State_Index := The_Engine.Heads.First_Index;
         Last     : constant State_Index := The_Engine.Heads.Last_Index;
         Current  : Bool_Array (First .. Last) := [others => False];
         Next_Set : Bool_Array (First .. Last) := [others => False];
         Best     : Natural := 0;
         Position : Positive := From;
         Point    : Code_Point;
         Length   : Natural;
         Valid    : Boolean;
         Moved    : Boolean;
      begin
         Current (The_Engine.Start) := True;
         Epsilon_Closure (The_Engine, Current);

         while Position <= Input'Last loop
            Lovelace.Common.Utf_8.Decode
              (Source => Input, Index => Position, Point => Point, Length => Length, Valid => Valid);
            exit when not Valid or else Length = 0;

            Step_Set
              (The_Engine => The_Engine, Current => Current, Point => Point, Next_Set => Next_Set, Moved => Moved);

            exit when not Moved;

            Epsilon_Closure (The_Engine, Next_Set);
            Current := Next_Set;
            if Current (The_Engine.Accepting) then
               Best := Position + Length - From;
            end if;
            Position := Position + Length;
         end loop;

         return Best;
      end;
   end Match_Prefix;

   function New_State (The_Builder : in out Builder) return State_Index is
   begin
      The_Builder.Heads.Append (0);
      return The_Builder.Heads.Last_Index;
   end New_State;

   function Next_Scalar (Pattern : String; The_Parser : in out Parser) return Code_Point is
      Current_Point : Code_Point;
   begin
      if At_End (Pattern, The_Parser) then
         Fail (The_Parser, "unclosed character class");
         return Wide_Wide_Character'Val (0);
      end if;
      Current_Point := Peek (Pattern, The_Parser);
      Advance (Pattern, The_Parser);
      if Is_Char (Current_Point, '\') then
         return Parse_Escape (Pattern, The_Parser);
      end if;
      return Current_Point;
   end Next_Scalar;

   function Parse_Alt (Pattern : String; The_Parser : in out Parser) return Node_Access is
      Left     : Node_Access := Parse_Concat (Pattern, The_Parser);
      The_Node : Node_Access;
   begin
      while not The_Parser.Failed and then Peek_Is (Pattern, The_Parser, '|') loop
         Advance (Pattern, The_Parser);
         The_Node :=
           new Node'(Kind => Alternation, Left => Left, Right => Parse_Concat (Pattern, The_Parser), others => <>);
         Left := The_Node;
      end loop;
      return Left;
   end Parse_Alt;

   function Parse_Atom (Pattern : String; The_Parser : in out Parser) return Node_Access is
      Point : Code_Point;
   begin
      if The_Parser.Failed then
         return null;
      end if;
      if At_End (Pattern, The_Parser) then
         Fail (The_Parser, "unexpected end of pattern");
         return null;
      end if;

      Point := Peek (Pattern, The_Parser);
      if not Is_Ascii (Point) then
         return Parse_Literal (Pattern, The_Parser, Point);
      end if;
      return Parse_Atom_Ascii (Pattern, The_Parser, Point);
   end Parse_Atom;

   function Parse_Atom_Ascii (Pattern : String; The_Parser : in out Parser; Point : Code_Point) return Node_Access is
   begin
      case As_Ascii (Point) is
         when '('                               =>
            return Parse_Group (Pattern, The_Parser);

         when '['                               =>
            return Parse_Class_Node (Pattern, The_Parser);

         when '\'                               =>
            return Parse_Escape_Node (Pattern, The_Parser);

         when '.'                               =>
            Advance (Pattern, The_Parser);
            return new Node'(Kind => Any_Node, others => <>);

         when ')' | '|' | '*' | '+' | '?' | ']' =>
            Fail (The_Parser, "unexpected metacharacter");
            return null;

         when others                            =>
            return Parse_Literal (Pattern, The_Parser, Point);
      end case;
   end Parse_Atom_Ascii;

   function Parse_Class
     (Pattern : String; The_Parser : in out Parser; Negated : out Boolean) return Range_Vectors.Vector
   is
      Result : Range_Vectors.Vector;
      Empty  : Boolean;
   begin
      Parse_Class_Caret (Pattern, The_Parser, Negated);
      Parse_Class_Items (Pattern, The_Parser, Result, Empty);

      if Empty then
         Fail (The_Parser, "empty character class");
         return Result;
      end if;

      if not Peek_Is (Pattern, The_Parser, ']') then
         Fail (The_Parser, "unclosed character class");
         return Result;
      end if;
      Advance (Pattern, The_Parser);
      return Result;
   end Parse_Class;

   procedure Parse_Class_Caret (Pattern : String; The_Parser : in out Parser; Negated : out Boolean) is
   begin
      Negated := Peek_Is (Pattern, The_Parser, '^');
      if Negated then
         Advance (Pattern, The_Parser);
      end if;
   end Parse_Class_Caret;

   procedure Parse_Class_Item
     (Pattern        : String;
      The_Parser     : in out Parser;
      Point          : Code_Point;
      Result         : in out Range_Vectors.Vector;
      Have_Previous  : in out Boolean;
      Previous_Point : in out Code_Point) is
   begin
      if Have_Previous and then Is_Char (Point, '-') and then not After_Minus_Is_Close (Pattern, The_Parser) then
         Parse_Class_Range (Pattern, The_Parser, Previous_Point, Result);
         Have_Previous := False;
      else
         if Have_Previous then
            Result.Append (Code_Range'(Low => Previous_Point, High => Previous_Point));
         end if;
         Previous_Point := Next_Scalar (Pattern, The_Parser);
         Have_Previous := True;
      end if;
   end Parse_Class_Item;

   procedure Parse_Class_Items
     (Pattern : String; The_Parser : in out Parser; Result : in out Range_Vectors.Vector; Empty : out Boolean)
   is
      Have_Previous  : Boolean := False;
      Previous_Point : Code_Point := Wide_Wide_Character'Val (0);
      Point          : Code_Point;
   begin
      Empty := True;
      while not The_Parser.Failed and then not At_End (Pattern, The_Parser) loop
         Point := Peek (Pattern, The_Parser);
         exit when Is_Char (Point, ']');
         Parse_Class_Item
           (Pattern        => Pattern,
            The_Parser     => The_Parser,
            Point          => Point,
            Result         => Result,
            Have_Previous  => Have_Previous,
            Previous_Point => Previous_Point);
         Empty := False;
      end loop;

      if Have_Previous then
         Result.Append (Code_Range'(Low => Previous_Point, High => Previous_Point));
      end if;
   end Parse_Class_Items;

   function Parse_Class_Node (Pattern : String; The_Parser : in out Parser) return Node_Access is
      The_Node : Node_Access;
   begin
      Advance (Pattern, The_Parser);
      The_Node := new Node'(Kind => Class_Node, others => <>);
      The_Node.Ranges := Parse_Class (Pattern, The_Parser, The_Node.Negated);
      return The_Node;
   end Parse_Class_Node;

   procedure Parse_Class_Range
     (Pattern : String; The_Parser : in out Parser; Previous_Point : Code_Point; Result : in out Range_Vectors.Vector)
   is
      High_Point : Code_Point;
   begin
      Advance (Pattern, The_Parser);
      High_Point := Next_Scalar (Pattern, The_Parser);
      if High_Point < Previous_Point then
         Fail (The_Parser, "invalid character range");
      else
         Result.Append (Code_Range'(Low => Previous_Point, High => High_Point));
      end if;
   end Parse_Class_Range;

   function Parse_Concat (Pattern : String; The_Parser : in out Parser) return Node_Access is
      Left              : Node_Access := Parse_Piece (Pattern, The_Parser);
      The_Node          : Node_Access;
      Current_Character : Character;
   begin
      while not The_Parser.Failed and then not At_End (Pattern, The_Parser) loop
         if Is_Ascii (Peek (Pattern, The_Parser)) then
            Current_Character := As_Ascii (Peek (Pattern, The_Parser));
            exit when Current_Character = ')' or else Current_Character = '|';
         end if;
         The_Node := new Node'(Kind => Concat, Left => Left, Right => Parse_Piece (Pattern, The_Parser), others => <>);
         Left := The_Node;
      end loop;
      return Left;
   end Parse_Concat;

   function Parse_Escape (Pattern : String; The_Parser : in out Parser) return Code_Point is
      Point : Code_Point;
   begin
      if The_Parser.Failed then
         return Wide_Wide_Character'Val (0);
      end if;
      if At_End (Pattern, The_Parser) then
         Fail (The_Parser, "trailing backslash");
         return Wide_Wide_Character'Val (0);
      end if;
      Point := Peek (Pattern, The_Parser);
      Advance (Pattern, The_Parser);
      if not Is_Ascii (Point) then
         Fail (The_Parser, "unsupported escape");
         return Wide_Wide_Character'Val (0);
      end if;
      case As_Ascii (Point) is
         when 'n' | 't' | 'r' | 'f' | 'e' =>
            return Control_Escape (As_Ascii (Point));

         when 'u'                         =>
            return Parse_Unicode_Escape (Pattern, The_Parser);

         when '\'
            | '|'
            | '('
            | ')'
            | '+'
            | '*'
            | '?'
            | '['
            | ']'
            | '.'
            | '-'
            | '^'
            | '$'
            | '%'
            | '/'
            | '{'
            | '}'
            | '"'
            | '''                         =>
            return Point;

         when others                      =>
            Fail (The_Parser, "unsupported escape");
            return Wide_Wide_Character'Val (0);
      end case;
   end Parse_Escape;

   function Parse_Escape_Node (Pattern : String; The_Parser : in out Parser) return Node_Access is
      The_Node : Node_Access;
   begin
      Advance (Pattern, The_Parser);
      The_Node := new Node'(Kind => Literal, others => <>);
      The_Node.Point := Parse_Escape (Pattern, The_Parser);
      return The_Node;
   end Parse_Escape_Node;

   function Parse_Group (Pattern : String; The_Parser : in out Parser) return Node_Access is
      The_Node : Node_Access;
   begin
      Advance (Pattern, The_Parser);
      The_Node := Parse_Alt (Pattern, The_Parser);
      if not Peek_Is (Pattern, The_Parser, ')') then
         Fail (The_Parser, "unclosed group");
         return The_Node;
      end if;
      Advance (Pattern, The_Parser);
      return The_Node;
   end Parse_Group;

   function Parse_Literal (Pattern : String; The_Parser : in out Parser; Point : Code_Point) return Node_Access is
      The_Node : constant Node_Access := new Node'(Kind => Literal, Point => Point, others => <>);
   begin
      Advance (Pattern, The_Parser);
      return The_Node;
   end Parse_Literal;

   function Parse_Pattern (Pattern : String; The_Parser : in out Parser) return Node_Access is
      Root : Node_Access;
   begin
      if Pattern'Length = 0 then
         Fail (The_Parser, "empty pattern");
         return null;
      end if;
      Root := Parse_Alt (Pattern, The_Parser);
      if The_Parser.Failed then
         return Root;
      end if;
      if not At_End (Pattern, The_Parser) then
         Fail (The_Parser, "trailing characters in pattern");
      end if;
      return Root;
   end Parse_Pattern;

   function Parse_Piece (Pattern : String; The_Parser : in out Parser) return Node_Access is
      Atom              : constant Node_Access := Parse_Atom (Pattern, The_Parser);
      The_Node          : Node_Access;
      Current_Character : Character;
   begin
      if The_Parser.Failed then
         return Atom;
      end if;
      if not At_End (Pattern, The_Parser) and then Is_Ascii (Peek (Pattern, The_Parser)) then
         Current_Character := As_Ascii (Peek (Pattern, The_Parser));
         case Current_Character is
            when '*'    =>
               Advance (Pattern, The_Parser);
               The_Node := new Node'(Kind => Star, Left => Atom, others => <>);
               return The_Node;

            when '+'    =>
               Advance (Pattern, The_Parser);
               The_Node := new Node'(Kind => Plus, Left => Atom, others => <>);
               return The_Node;

            when '?'    =>
               Advance (Pattern, The_Parser);
               The_Node := new Node'(Kind => Question, Left => Atom, others => <>);
               return The_Node;

            when others =>
               null;
         end case;
      end if;
      return Atom;
   end Parse_Piece;

   function Parse_Unicode_Escape (Pattern : String; The_Parser : in out Parser) return Code_Point is
      Accumulator : Natural;
      Digit_Count : Natural;
   begin
      if not Peek_Is (Pattern, The_Parser, '{') then
         Fail (The_Parser, "expected '{'");
         return Wide_Wide_Character'Val (0);
      end if;
      Advance (Pattern, The_Parser);

      Read_Hex_Digits (Pattern, The_Parser, Accumulator, Digit_Count);
      if The_Parser.Failed then
         return Wide_Wide_Character'Val (0);
      end if;

      if Digit_Count = 0 then
         Fail (The_Parser, "empty Unicode escape");
         return Wide_Wide_Character'Val (0);
      end if;
      if not Peek_Is (Pattern, The_Parser, '}') then
         Fail (The_Parser, "unclosed Unicode escape");
         return Wide_Wide_Character'Val (0);
      end if;
      Advance (Pattern, The_Parser);

      if Accumulator in 16#D800# .. 16#DFFF# then
         Fail (The_Parser, "surrogate in Unicode escape");
         return Wide_Wide_Character'Val (0);
      end if;
      return Wide_Wide_Character'Val (Accumulator);
   end Parse_Unicode_Escape;

   function Peek (Pattern : String; The_Parser : in out Parser) return Code_Point is
      Point  : Code_Point;
      Length : Natural;
      Valid  : Boolean;
   begin
      if The_Parser.Failed or else At_End (Pattern, The_Parser) then
         return Wide_Wide_Character'Val (0);
      end if;
      Peek_Decode (Pattern => Pattern, The_Parser => The_Parser, Point => Point, Length => Length, Valid => Valid);
      if not Valid then
         Fail (The_Parser, "invalid UTF-8", Invalid_Utf_8);
         return Wide_Wide_Character'Val (0);
      end if;
      return Point;
   end Peek;

   procedure Peek_Decode
     (Pattern : String; The_Parser : Parser; Point : out Code_Point; Length : out Natural; Valid : out Boolean) is
   begin
      Lovelace.Common.Utf_8.Decode
        (Source => Pattern, Index => The_Parser.Position, Point => Point, Length => Length, Valid => Valid);
   end Peek_Decode;

   function Peek_Is (Pattern : String; The_Parser : in out Parser; Expected : Character) return Boolean is
   begin
      return not At_End (Pattern, The_Parser) and then Is_Char (Peek (Pattern, The_Parser), Expected);
   end Peek_Is;

   procedure Read_Hex_Digits
     (Pattern : String; The_Parser : in out Parser; Accumulator : out Natural; Digit_Count : out Natural)
   is
      Point : Code_Point;
   begin
      Accumulator := 0;
      Digit_Count := 0;
      while not The_Parser.Failed and then not At_End (Pattern, The_Parser) loop
         Point := Peek (Pattern, The_Parser);
         exit when Is_Char (Point, '}');
         Accumulate_Hex_Digit (The_Parser, Point, Accumulator, Digit_Count);
         Advance (Pattern, The_Parser);
      end loop;
   end Read_Hex_Digits;

   procedure Step_Set
     (The_Engine : Engine; Current : Bool_Array; Point : Code_Point; Next_Set : out Bool_Array; Moved : out Boolean)
   is
      Index : Natural;
   begin
      Next_Set := [others => False];
      Moved := False;
      for State in Current'Range loop
         if Current (State) then
            Index := The_Engine.Heads (State);
            while Index /= 0 loop
               declare
                  The_Transition : constant Transition := The_Engine.Transactions (Index);
               begin
                  if Transition_Matches (The_Transition, Point) then
                     Next_Set (The_Transition.Target) := True;
                     Moved := True;
                  end if;
                  Index := The_Transition.Next;
               end;
            end loop;
         end if;
      end loop;
   end Step_Set;

   function Transition_Matches (The_Transition : Transition; Point : Code_Point) return Boolean is
   begin
      case The_Transition.Kind is
         when Exact_Scalar =>
            return Point = The_Transition.Symbol;

         when Class        =>
            return In_Class (The_Transition, Point);

         when Any          =>
            return True;

         when Epsilon      =>
            return False;
      end case;
   end Transition_Matches;

end Lovelace.Common.Regex;
