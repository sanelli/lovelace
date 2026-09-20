package body Lovelace.Compiler.Ast is

   procedure Append (Sequence : in out Subroutine_Sequence; The_Subroutine : Subroutine) is
   begin
      Sequence.Items.Append (The_Subroutine);
   end Append;

   function Create_Module
     (Name           : String;
      Name_Span      : Source.Source_Span;
      Filename       : Source.Filename_Option;
      Span           : Source.Source_Span;
      The_Subroutine : Subroutine) return Module
   is
      Subroutines : Subroutine_Sequence := Empty_Subroutine_Sequence;
   begin
      Append (Sequence => Subroutines, The_Subroutine => The_Subroutine);
      return
        (Module_Name     => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Name_Span_Value => Name_Span,
         Filename_Value  => Filename,
         Span_Value      => Span,
         Subroutines     => Subroutines);
   end Create_Module;

   function Create_Subroutine
     (Name          : String;
      Name_Span     : Source.Source_Span;
      Filename      : Source.Filename_Option;
      Is_Entrypoint : Boolean;
      Is_Export     : Boolean;
      Return_Type   : Types.Type_Expression;
      The_Body      : Statement_Sequence) return Subroutine is
   begin
      return
        (Subroutine_Name   => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Name_Span_Value   => Name_Span,
         Filename_Value    => Filename,
         Entrypoint_Flag   => Is_Entrypoint,
         Export_Flag       => Is_Export,
         Return_Type_Value => Unit_Type_Expression (Return_Type),
         Body_Value        => The_Body);
   end Create_Subroutine;

   function Element (Sequence : Subroutine_Sequence; Index : Positive) return Subroutine is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Body return Statement_Sequence is
   begin
      return (Count => 0);
   end Empty_Body;

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

   function Get_Body (The_Subroutine : Subroutine) return Statement_Sequence is
   begin
      return The_Subroutine.Body_Value;
   end Get_Body;

   function Get_Subroutine (The_Module : Module; Index : Positive) return Subroutine is
   begin
      return Element (The_Module.Subroutines, Index);
   end Get_Subroutine;

   function Is_Entrypoint (The_Subroutine : Subroutine) return Boolean is
   begin
      return The_Subroutine.Entrypoint_Flag;
   end Is_Entrypoint;

   function Is_Export (The_Subroutine : Subroutine) return Boolean is
   begin
      return The_Subroutine.Export_Flag;
   end Is_Export;

   function Length (The_Body : Statement_Sequence) return Natural is
   begin
      return The_Body.Count;
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

   function Return_Type (The_Subroutine : Subroutine) return Types.Type_Expression is
   begin
      return Types.Type_Expression (The_Subroutine.Return_Type_Value);
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
