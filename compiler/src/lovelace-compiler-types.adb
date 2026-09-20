package body Lovelace.Compiler.Types is

   function Unit_Type return Type_Expression is
   begin
      return (Kind => Unit);
   end Unit_Type;

end Lovelace.Compiler.Types;
