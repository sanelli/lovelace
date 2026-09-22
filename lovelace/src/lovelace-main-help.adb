with Ada.Text_IO;

package body Lovelace.Main.Help is

   procedure Put_Build (File : Ada.Text_IO.File_Type);
   procedure Put_General (File : Ada.Text_IO.File_Type);
   procedure Put_Line (File : Ada.Text_IO.File_Type; Text : String);

   procedure Put_Build (File : Ada.Text_IO.File_Type) is
   begin
      Put_Line (File, "Usage: lovelace build <file.love> [options...]");
      Put_Line (File, "");
      Put_Line
        (File,
         "Compile a Lovelace source file through tokenize, parse, LIR, and");
      Put_Line
        (File,
         "WASM/WAT/WIT backends. The program identifier must match the .love");
      Put_Line (File, "basename (excluding the extension).");
      Put_Line (File, "");
      Put_Line (File, "Options:");
      Put_Line
        (File,
         "  --no-wit                 Do not write a companion .wit file");
      Put_Line
        (File,
         "  --output-format <fmt>    wasm (default), wat, wasm,wat, or wat,wasm");
      Put_Line
        (File,
         "  --output-folder <path>   Replace the default .output directory");
      Put_Line (File, "");
      Put_Line (File, "Output layout under the output folder:");
      Put_Line (File, "  obj/<Program>.lir");
      Put_Line
        (File, "  bin/<Program>.wasm and/or .wat, plus .wit unless --no-wit");
      Put_Line (File, "");
      Put_Line
        (File,
         "Incremental builds skip stages whose outputs are newer than inputs.");
      Put_Line (File, "");
      Put_Line (File, "Examples:");
      Put_Line (File, "  lovelace build foo.love");
      Put_Line (File, "  lovelace build foo.love --no-wit");
      Put_Line
        (File, "  lovelace build foo.love --output-format wat --no-wit");
      Put_Line
        (File,
         "  lovelace build foo.love --no-wit --output-format wasm --output-folder bar");
   end Put_Build;

   procedure Put_General (File : Ada.Text_IO.File_Type) is
   begin
      Put_Line
        (File,
         "Usage: lovelace [global-options...] <command> [command-parameters...]");
      Put_Line (File, "");
      Put_Line (File, "Global options (must appear before the command):");
      Put_Line (File, "  --no-logo     Do not print the startup logo");
      Put_Line (File, "  --no-colour   Disable ANSI colours in output");
      Put_Line (File, "");
      Put_Line (File, "Commands:");
      Put_Line (File, "  build     Compile a .love source file");
      Put_Line (File, "  help      Show this help, or help for a command");
      Put_Line (File, "  version   Print the Lovelace version string");
      Put_Line (File, "");
      Put_Line (File, "Run 'lovelace help <command>' for command details.");
   end Put_General;

   procedure Put_Line (File : Ada.Text_IO.File_Type; Text : String) is
   begin
      Ada.Text_IO.Put_Line (File, Text);
   end Put_Line;

   function Run
     (Command_Arguments : Arguments.String_Vectors.Vector;
      To_Standard_Error : Boolean := False) return Boolean
   is
      File : constant Ada.Text_IO.File_Access :=
        (if To_Standard_Error
         then Ada.Text_IO.Standard_Error
         else Ada.Text_IO.Standard_Output);
   begin
      if Natural (Command_Arguments.Length) = 0 then
         Put_General (File.all);
         return True;
      end if;

      if Natural (Command_Arguments.Length) = 1 then
         declare
            Topic : constant String := Command_Arguments.Element (1);
         begin
            if Topic = "build" then
               Put_Build (File.all);
               return True;
            elsif Topic = "help" then
               Put_Line (File.all, "Usage: lovelace help [command]");
               Put_Line
                 (File.all,
                  "Show general help, or details for build, help, or version.");
               return True;
            elsif Topic = "version" then
               Put_Line (File.all, "Usage: lovelace version");
               Put_Line
                 (File.all,
                  "Print the product version as 0.0.1-alpha.1 @ <githash>.");
               return True;
            else
               Put_Line (File.all, "Unknown help topic '" & Topic & "'.");
               return False;
            end if;
         end;
      end if;

      Put_Line (File.all, "Usage: lovelace help [command]");
      return False;
   end Run;

end Lovelace.Main.Help;
