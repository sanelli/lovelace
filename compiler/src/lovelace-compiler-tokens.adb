package body Lovelace.Compiler.Tokens is

   procedure Append (Sequence : in out Token_Sequence; Item : Token) is
   begin
      Sequence.Items.Append (Item);
   end Append;

   function Element (Sequence : Token_Sequence; Index : Positive) return Token is
   begin
      return Sequence.Items.Element (Index);
   end Element;

   function Empty_Sequence return Token_Sequence is
   begin
      return (Items => Token_Vectors.Empty_Vector);
   end Empty_Sequence;

   function Length (Sequence : Token_Sequence) return Natural is
   begin
      return Natural (Sequence.Items.Length);
   end Length;

   function Lexeme (Source_Text : String; The_Token : Token) return String is
   begin
      return Source_Text
        (The_Token.Span.First.Byte_Index .. The_Token.Span.Last.Byte_Index);
   end Lexeme;

end Lovelace.Compiler.Tokens;
