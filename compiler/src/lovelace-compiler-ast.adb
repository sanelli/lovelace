package body Lovelace.Compiler.Ast is

   procedure Append (Sequence : in out Parameter_Sequence; The_Parameter : Parameter) is
   begin
      Sequence.Items.Append (The_Parameter);
   end Append;

   procedure Append (Sequence : in out Subroutine_Sequence; The_Subroutine : Subroutine) is
   begin
      Sequence.Items.Append (The_Subroutine);
   end Append;

   function Create_Module
     (Name        : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Span        : Source.Source_Span;
      Kind        : Unit_Kind;
      Subroutines : Subroutine_Sequence) return Module is
   begin
      return
        (Module_Name     => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Name_Span_Value => Name_Span,
         Filename_Value  => Filename,
         Span_Value      => Span,
         Kind_Value      => Kind,
         Subroutines     => Subroutines);
   end Create_Module;

   function Create_Subroutine
     (Name        : String;
      Module_Name : String;
      Name_Span   : Source.Source_Span;
      Filename    : Source.Filename_Option;
      Flags       : Subroutine_Flags;
      Return_Type : Types.Type_Expression;
      Parameters  : Parameter_Sequence;
      The_Body    : Statement_Sequence) return Subroutine is
   begin
      return
        (Subroutine_Name   => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Full_Name_Value   => Ada.Strings.Unbounded.To_Unbounded_String (Module_Name & "." & Name),
         Name_Span_Value   => Name_Span,
         Filename_Value    => Filename,
         Flags_Value       => Flags,
         Return_Type_Value => Return_Type,
         Parameters_Value  => Parameters,
         Body_Value        => The_Body);
   end Create_Subroutine;

   function Element (Sequence : Parameter_Sequence; Index : Positive) return Parameter is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Element (Sequence : Subroutine_Sequence; Index : Positive) return Subroutine is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Body return Statement_Sequence is
   begin
      return (Count => 0);
   end Empty_Body;

   function Empty_Parameter_Sequence return Parameter_Sequence is
   begin
      return (Items => Parameter_Vectors.Empty_Vector);
   end Empty_Parameter_Sequence;

   function Empty_Subroutine_Sequence return Subroutine_Sequence is
   begin
      return (Items => Subroutine_Vectors.Empty_Vector);
   end Empty_Subroutine_Sequence;

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

   function Get_Body (The_Subroutine : Subroutine) return Statement_Sequence is
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

   function Has_Entrypoint (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Entrypoint_Flag) /= 0;
   end Has_Entrypoint;

   function Has_Export (Flags : Subroutine_Flags) return Boolean is
   begin
      return (Flags and Export_Flag) /= 0;
   end Has_Export;

   function Kind (The_Module : Module) return Unit_Kind is
   begin
      return The_Module.Kind_Value;
   end Kind;

   function Length (The_Body : Statement_Sequence) return Natural is
   begin
      return The_Body.Count;
   end Length;

   function Length (Sequence : Parameter_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Length (Sequence : Subroutine_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

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

   function Subroutine_Count (The_Module : Module) return Natural is
   begin
      return Length (The_Module.Subroutines);
   end Subroutine_Count;

end Lovelace.Compiler.Ast;
