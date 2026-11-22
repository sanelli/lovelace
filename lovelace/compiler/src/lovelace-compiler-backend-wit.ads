with Lovelace.Compiler.Backend.Model;

--  Companion WIT text printer for a lowered component model.

package Lovelace.Compiler.Backend.Wit is

   --  Render The_Model as companion WIT source
   --  (`package lovelace:<segments>@<version>;`, world module). Multi-segment
   --  module names use '-' in the WIT package id (WIT forbids '/' there).
   --  @param The_Model Lowered component model.
   --  @return UTF-8 WIT text with a trailing newline.
   function To_Wit (The_Model : Model.Component_Model) return String;

end Lovelace.Compiler.Backend.Wit;
