package body Lovelace.Compiler.Flavor is

   function Default return Flavor is
   begin
      return Wasi;
   end Default;

   function Name (The_Flavor : Flavor) return String is
   begin
      case The_Flavor is
         when Wasi   =>
            return "wasi";

         when Native =>
            return "native";

         when Web    =>
            return "web";
      end case;
   end Name;

   function Try_Parse_Name (Text : String; The_Flavor : out Flavor) return Boolean is
   begin
      if Text = "wasi" then
         The_Flavor := Wasi;
         return True;
      elsif Text = "native" then
         The_Flavor := Native;
         return True;
      elsif Text = "web" then
         The_Flavor := Web;
         return True;
      else
         The_Flavor := Wasi;
         return False;
      end if;
   end Try_Parse_Name;

end Lovelace.Compiler.Flavor;
