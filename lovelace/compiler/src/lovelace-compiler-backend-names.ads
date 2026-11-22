--  Component Model package identities: lovelace:<seg>[/<seg>…]@<version>.

package Lovelace.Compiler.Backend.Names is

   --  Fixed namespace for Lovelace guest and dependency package ids.
   Namespace : constant String := "lovelace";

   --  Sanitize one dotted-module segment for a WIT/CM id (lowercase ASCII
   --  letters/digits; other bytes → '-'; empty → "module").
   --  @param Segment Raw UTF-8 segment (no '.').
   --  @return Non-empty sanitized id.
   function Sanitize_Segment (Segment : String) return String;

   --  Component / import identity: namespace:first[/rest…]@version.
   --  Dots in Module_Name split segments; each is sanitized; the first becomes
   --  the package name and any further segments are '/' path parts (interface).
   --  Example: "augusta.std.io" + "1.0.0" → "lovelace:augusta/std/io@1.0.0".
   --  Example: "Assignment" + "0.0.1" → "lovelace:assignment@0.0.1".
   --  @param Module_Name LIR / source module name (may be dotted).
   --  @param Version Module version string (already validated upstream).
   --  @return Full package identity string.
   function Component_Identity
     (Module_Name : String; Version : String) return String;

   --  WIT `package` declaration name (namespace:id@version). WIT package lines
   --  cannot contain '/'; multi-segment names use '-' between sanitized segments.
   --  Example: "augusta.std.io" + "1.0.0" → "lovelace:augusta-std-io@1.0.0".
   --  Single-segment names match Component_Identity without a path.
   --  @param Module_Name LIR / source module name (may be dotted).
   --  @param Version Module version string.
   --  @return WIT-safe package identity (no '/').
   function Wit_Package_Identity
     (Module_Name : String; Version : String) return String;

end Lovelace.Compiler.Backend.Names;
