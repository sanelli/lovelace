with Lovelace.Compiler.Backend.Model;

--  Companion WIT text printer for a lowered component model.

package Lovelace.Compiler.Backend.Wit is

   --  Render The_Model as companion WIT source (package love:...@0.1.0, world module).
   --  @param The_Model Lowered component model.
   --  @return UTF-8 WIT text with a trailing newline.
   function To_Wit (The_Model : Model.Component_Model) return String;

end Lovelace.Compiler.Backend.Wit;
