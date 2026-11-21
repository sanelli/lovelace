with Interfaces;

with Lovelace.Compiler.Literals;
with Lovelace.Compiler.Types;

package body Lovelace.Compiler.Semantics.Typecheck is

   use type Lovelace_Types.Type_Class;
   use type Types.Signedness;
   use type Types.Integer_Size;
   use type Types.Float_Size;

   function Failure (Detail : String) return Assign_Result;

   function Literal_Fits_Integer
     (Expression : Types.Type_Expression; Value : Interfaces.Integer_32) return Assign_Result;

   function Mismatch
     (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Assign_Result;

   function Check_Assignable
     (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Assign_Result is
   begin
      if Target.Class = Lovelace_Types.Unknown_Class or else Source.Class = Lovelace_Types.Unknown_Class then
         return (Ok => True);
      end if;

      case Target.Class is
         when Lovelace_Types.Unknown_Class | Lovelace_Types.Unit_Class | Lovelace_Types.Integer_Literal_Class =>
            return Mismatch (Target, Source);

         when Lovelace_Types.Boolean_Class                                                                    =>
            if Source.Class = Lovelace_Types.Boolean_Class then
               return (Ok => True);
            end if;
            return Mismatch (Target, Source);

         when Lovelace_Types.Integer_Class                                                                    =>
            case Source.Class is
               when Lovelace_Types.Integer_Literal_Class =>
                  declare
                     Fit : constant Assign_Result := Literal_Fits_Integer (Target.Expression, Source.Literal_Value);
                  begin
                     return Fit;
                  end;

               when Lovelace_Types.Integer_Class         =>
                  if Source.Expression.The_Signedness = Target.Expression.The_Signedness
                    and then Source.Expression.Integer_Bit_Size = Target.Expression.Integer_Bit_Size
                  then
                     return (Ok => True);
                  end if;
                  return Mismatch (Target, Source);

               when others                               =>
                  return Mismatch (Target, Source);
            end case;

         when Lovelace_Types.Float_Class                                                                      =>
            if Source.Class = Lovelace_Types.Float_Class
              and then Source.Expression.Float_Bit_Size = Target.Expression.Float_Bit_Size
            then
               return (Ok => True);
            end if;
            return Mismatch (Target, Source);
      end case;
   end Check_Assignable;

   function Failure (Detail : String) return Assign_Result is
   begin
      return (Ok => False, Detail => Ada.Strings.Unbounded.To_Unbounded_String (Detail));
   end Failure;

   function Is_Assignable (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Boolean
   is
   begin
      return Check_Assignable (Target, Source).Ok;
   end Is_Assignable;

   function Literal_Fits_Integer
     (Expression : Types.Type_Expression; Value : Interfaces.Integer_32) return Assign_Result
   is
      Bits : Natural;
      Low  : Long_Long_Integer;
      High : Long_Long_Integer;
      Wide : constant Long_Long_Integer := Long_Long_Integer (Value);
   begin
      case Expression.Integer_Bit_Size is
         when Types.Bits_8  =>
            Bits := 8;

         when Types.Bits_16 =>
            Bits := 16;

         when Types.Bits_32 =>
            Bits := 32;

         when Types.Bits_64 =>
            return Failure ("a 64-bit integer cannot take an integer literal in this slice");
      end case;

      case Expression.The_Signedness is
         when Types.Signed   =>
            Low := -(2**(Bits - 1));
            High := 2**(Bits - 1) - 1;

         when Types.Unsigned =>
            Low := 0;
            High := 2**Bits - 1;
      end case;

      if Wide < Low then
         return
           Failure
             ((if Expression.The_Signedness = Types.Unsigned
               then "negative literal cannot be assigned to an unsigned integer"
               else "integer literal " & Long_Long_Integer'Image (Wide) & " is below the range of the target"));
      elsif Wide > High then
         return Failure ("integer literal " & Long_Long_Integer'Image (Wide) & " is above the range of the target");
      end if;

      return (Ok => True);
   end Literal_Fits_Integer;

   function Mismatch (Target : Lovelace_Types.Lovelace_Type; Source : Lovelace_Types.Lovelace_Type) return Assign_Result
   is
   begin
      return Failure ("cannot assign " & Lovelace_Types.Image (Source) & " to " & Lovelace_Types.Image (Target));
   end Mismatch;

   function Type_Of_Literal (The_Expression : Ast.Expression) return Type_Result is
      Lexeme : constant String := Ada.Strings.Unbounded.To_String (The_Expression.Lexeme);
   begin
      case The_Expression.Kind is
         when Ast.Boolean_Literal =>
            return (Ok => True, The_Type => Lovelace_Types.Boolean_Type);

         when Ast.Integer_Literal =>
            declare
               Interpreted : constant Literals.Integer_Literal_Results.Result := Literals.Interpret_Integer (Lexeme);
            begin
               case Interpreted.Ok is
                  when False =>
                     return
                       (Ok     => False,
                        Detail =>
                          Ada.Strings.Unbounded.To_Unbounded_String
                            ("invalid integer literal: "
                             & Ada.Strings.Unbounded.To_String (Interpreted.Error.Detail)));

                  when True  =>
                     declare
                        Evaluated : constant Literals.Integer_32_Results.Result :=
                          Literals.To_Integer_32 (Interpreted.Value);
                     begin
                        case Evaluated.Ok is
                           when False =>
                              return
                                (Ok     => False,
                                 Detail =>
                                   Ada.Strings.Unbounded.To_Unbounded_String
                                     ("invalid integer literal: "
                                      & Ada.Strings.Unbounded.To_String (Evaluated.Error.Detail)));

                           when True  =>
                              --  Trailing signedness/size pins a concrete integer type (disambiguates overloads).
                              --  Bare literals stay Integer_Literal_Class and match by range fit.
                              if Interpreted.Value.Has_Signedness or else Interpreted.Value.Has_Size then
                                 declare
                                    The_Signedness : constant Types.Signedness :=
                                      (if Interpreted.Value.Has_Signedness
                                       then Interpreted.Value.The_Signedness
                                       else Types.Signed);
                                    The_Size       : constant Types.Integer_Size :=
                                      (if Interpreted.Value.Has_Size
                                       then Interpreted.Value.The_Size
                                       else Types.Bits_32);
                                    Expression     : constant Types.Type_Expression :=
                                      Types.Integer_Type (The_Signedness, The_Size);
                                    Fit            : constant Assign_Result :=
                                      Literal_Fits_Integer (Expression, Evaluated.Value);
                                 begin
                                    if not Fit.Ok then
                                       return
                                         (Ok     => False,
                                          Detail => Fit.Detail);
                                    end if;

                                    return
                                      (Ok      => True,
                                       The_Type => Lovelace_Types.From_Expression (Expression));
                                 end;
                              end if;

                              return
                                (Ok      => True,
                                 The_Type => Lovelace_Types.Integer_Literal_Type (Evaluated.Value));
                        end case;
                     end;
               end case;
            end;

         when Ast.Name_Reference  =>
            return
              (Ok => False, Detail => Ada.Strings.Unbounded.To_Unbounded_String ("'" & Lexeme & "' is not a literal"));
      end case;
   end Type_Of_Literal;

end Lovelace.Compiler.Semantics.Typecheck;
