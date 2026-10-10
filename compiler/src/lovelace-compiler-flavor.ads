--  Compilation flavors for Augusta / Lovelace directive selection (native, wasi, web).

package Lovelace.Compiler.Flavor is

   --  Active compilation flavor for `#if flavor = "Ã¢ÂÂ¦"`.
   --  @enum Wasi WASI guest capabilities (default for now).
   --  @enum Native Host native Augusta / love: path.
   --  @enum Web Browser / web flavor (no Wasmtime component host).
   type Flavor is (Wasi, Native, Web);

   --  Default flavor when the CLI omits `--flavor`.
   --  @return Wasi.
   function Default return Flavor;

   --  Canonical lowercase name for The_Flavor.
   --  @param The_Flavor Flavor value.
   --  @return "wasi", "native", or "web".
   function Name (The_Flavor : Flavor) return String;

   --  Parse Text as a flavor name (case-sensitive exact match).
   --  @param Text Candidate UTF-8 name.
   --  @param The_Flavor Set when the function returns True.
   --  @return True when Text is wasi, native, or web.
   function Try_Parse_Name (Text : String; The_Flavor : out Flavor) return Boolean;

end Lovelace.Compiler.Flavor;
