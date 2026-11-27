package body Lovelace.Compiler.Ast is

   procedure Append (Sequence : in out Parameter_Sequence; The_Parameter : Parameter) is
   begin
      Sequence.Items.Append (The_Parameter);
   end Append;

   procedure Append (Sequence : in out Expression_Sequence; The_Expression : Expression) is
   begin
      Sequence.Items.Append (The_Expression);
   end Append;

   procedure Append (Sequence : in out Statement_Sequence; The_Statement : Statement) is
   begin
      Sequence.Items.Append (The_Statement);
   end Append;

   procedure Append (Sequence : in out Subroutine_Sequence; The_Subroutine : Subroutine) is
   begin
      Sequence.Items.Append (The_Subroutine);
   end Append;

   procedure Append (Sequence : in out Using_Sequence; The_Using : Using_Declaration) is
   begin
      Sequence.Items.Append (The_Using);
   end Append;

   function Assignment_Of (The_Statement : Statement) return Assignment_Statement is
   begin
      return The_Statement.The_Assignment;
   end Assignment_Of;

   function Block_Of (The_Statement : Statement) return Block is
   begin
      return The_Statement.The_Block;
   end Block_Of;

   function Call_Of (The_Statement : Statement) return Call_Statement is
   begin
      return The_Statement.The_Call;
   end Call_Of;

   function Create_Block
     (Usings : Using_Sequence; Locals : Local_Sequence; Statements : Statement_Sequence) return Block is
   begin
      return new Block_Data'(Usings_Value => Usings, Locals_Value => Locals, Statements_Value => Statements);
   end Create_Block;

   function Create_Module
     (Name        : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Kind        : Unit_Kind;
      Usings      : Using_Sequence;
      Subroutines : Subroutine_Sequence;
      Version     : String := "") return Module is
   begin
      return
        (Module_Name             => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Name_Span_Value         => Name_Span,
         Filename_Value          => Filename,
         Span_Value              => Span,
         Kind_Value              => Kind,
         Usings                  => Usings,
         Subroutines             => Subroutines,
         Version_Attribute_Value => Ada.Strings.Unbounded.To_Unbounded_String (Version));
   end Create_Module;

   function Create_Subroutine
     (Name        : String;
      Module_Name : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Flags       : Subroutine_Flags;
      Return_Type : Types.Type_Expression;
      Parameters  : Parameter_Sequence;
      The_Body    : Block;
      Native      : Native_Binding_Option) return Subroutine is
   begin
      return
        (Subroutine_Name   => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Full_Name_Value   => Ada.Strings.Unbounded.To_Unbounded_String (Module_Name & "." & Name),
         Name_Span_Value   => Name_Span,
         Filename_Value    => Filename,
         Span_Value        => Span,
         Flags_Value       => Flags,
         Return_Type_Value => Return_Type,
         Parameters_Value  => Parameters,
         Body_Value        => The_Body,
         Native_Value      => Native);
   end Create_Subroutine;

   function Element (Sequence : Parameter_Sequence; Index : Positive) return Parameter is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Element (Sequence : Expression_Sequence; Index : Positive) return Expression is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Element (The_Body : Statement_Sequence; Index : Positive) return Statement is
   begin
      return The_Body.Items.Element (Index);
   end Element;

   function Element (Sequence : Subroutine_Sequence; Index : Positive) return Subroutine is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Element (Sequence : Using_Sequence; Index : Positive) return Using_Declaration is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Block return Block is
   begin
      return Create_Block (Empty_Using_Sequence, Empty_Local_Sequence, Empty_Body);
   end Empty_Block;

   function Empty_Body return Statement_Sequence is
   begin
      return (Items => Statement_Vectors.Empty_Vector);
   end Empty_Body;

   function Empty_Expression_Sequence return Expression_Sequence is
   begin
      return (Items => Expression_Vectors.Empty_Vector);
   end Empty_Expression_Sequence;

   function Empty_Local_Sequence return Local_Sequence is
   begin
      return Empty_Parameter_Sequence;
   end Empty_Local_Sequence;

   function Empty_Parameter_Sequence return Parameter_Sequence is
   begin
      return (Items => Parameter_Vectors.Empty_Vector);
   end Empty_Parameter_Sequence;

   function Empty_Subroutine_Sequence return Subroutine_Sequence is
   begin
      return (Items => Subroutine_Vectors.Empty_Vector);
   end Empty_Subroutine_Sequence;

   function Empty_Using_Sequence return Using_Sequence is
   begin
      return (Items => Using_Vectors.Empty_Vector);
   end Empty_Using_Sequence;

   function Filename (The_Module : Module) return Source.Filename_Option is
   begin
      return The_Module.Filename_Value;
   end Filename;

   function Filename (The_Subroutine : Subroutine) return Source.Filename_Option is
   begin
      return The_Subroutine.Filename_Value;
   end Filename;

   function Full_Name (The_Subroutine : Subroutine) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Subroutine.Full_Name_Value);
   end Full_Name;

   function Get_Body (The_Subroutine : Subroutine) return Block is
   begin
      return The_Subroutine.Body_Value;
   end Get_Body;

   function Get_Flags (The_Subroutine : Subroutine) return Subroutine_Flags is
   begin
      return The_Subroutine.Flags_Value;
   end Get_Flags;

   function Get_Subroutine (The_Module : Module; Index : Positive) return Subroutine is
   begin
      return Element (The_Module.Subroutines, Index);
   end Get_Subroutine;

   function Get_Using (The_Module : Module; Index : Positive) return Using_Declaration is
   begin
      return Element (The_Module.Usings, Index);
   end Get_Using;

   function Has_Entrypoint (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Entrypoint_Flag) /= 0;
   end Has_Entrypoint;

   function Has_Export (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Export_Flag) /= 0;
   end Has_Export;

   function Has_Intrinsic (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Intrinsic_Flag) /= 0;
   end Has_Intrinsic;

   function Has_Native (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Native_Flag) /= 0;
   end Has_Native;

   function Has_Version_Attribute (The_Module : Module) return Boolean is
   begin
      return Ada.Strings.Unbounded.Length (The_Module.Version_Attribute_Value) > 0;
   end Has_Version_Attribute;

   function Kind (The_Module : Module) return Unit_Kind is
   begin
      return The_Module.Kind_Value;
   end Kind;

   function Kind (The_Statement : Statement) return Statement_Kind is
   begin
      return The_Statement.Kind_Value;
   end Kind;

   function Length (Sequence : Parameter_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Length (Sequence : Expression_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Length (The_Body : Statement_Sequence) return Natural is
   begin
      return Natural (The_Body.Items.Length);
   end Length;

   function Length (Sequence : Subroutine_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Length (Sequence : Using_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Locals (The_Block : Block) return Local_Sequence is
   begin
      if The_Block = null then
         return Empty_Local_Sequence;
      end if;
      return The_Block.Locals_Value;
   end Locals;

   function Make_Assignment_Statement (The_Assignment : Assignment_Statement) return Statement is
   begin
      return (Kind_Value => Assignment, The_Assignment => The_Assignment);
   end Make_Assignment_Statement;

   function Make_Call_Statement (The_Call : Call_Statement) return Statement is
   begin
      return (Kind_Value => Call, The_Call => The_Call);
   end Make_Call_Statement;

   function Make_Nested_Block_Statement (The_Block : Block) return Statement is
   begin
      return (Kind_Value => Nested_Block, The_Block => The_Block);
   end Make_Nested_Block_Statement;

   function Name (The_Module : Module) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Module.Module_Name);
   end Name;

   function Name (The_Subroutine : Subroutine) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Subroutine.Subroutine_Name);
   end Name;

   function Name_Span (The_Module : Module) return Source.Source_Span is
   begin
      return The_Module.Name_Span_Value;
   end Name_Span;

   function Name_Span (The_Subroutine : Subroutine) return Source.Source_Span is
   begin
      return The_Subroutine.Name_Span_Value;
   end Name_Span;

   function Native (The_Subroutine : Subroutine) return Native_Binding_Option is
   begin
      return The_Subroutine.Native_Value;
   end Native;

   function Parameters (The_Subroutine : Subroutine) return Parameter_Sequence is
   begin
      return The_Subroutine.Parameters_Value;
   end Parameters;

   function Return_Type (The_Subroutine : Subroutine) return Types.Type_Expression is
   begin
      return The_Subroutine.Return_Type_Value;
   end Return_Type;

   function Span (The_Module : Module) return Source.Source_Span is
   begin
      return The_Module.Span_Value;
   end Span;

   function Span (The_Subroutine : Subroutine) return Source.Source_Span is
   begin
      return The_Subroutine.Span_Value;
   end Span;

   function Statements (The_Block : Block) return Statement_Sequence is
   begin
      if The_Block = null then
         return Empty_Body;
      end if;
      return The_Block.Statements_Value;
   end Statements;

   function Subroutine_Count (The_Module : Module) return Natural is
   begin
      return Length (The_Module.Subroutines);
   end Subroutine_Count;

   function Using_Count (The_Module : Module) return Natural is
   begin
      return Length (The_Module.Usings);
   end Using_Count;

   function Usings (The_Block : Block) return Using_Sequence is
   begin
      if The_Block = null then
         return Empty_Using_Sequence;
      end if;
      return The_Block.Usings_Value;
   end Usings;

   function Version_Attribute (The_Module : Module) return String is
   begin
      return Ada.Strings.Unbounded.To_String (The_Module.Version_Attribute_Value);
   end Version_Attribute;

end Lovelace.Compiler.Ast;
