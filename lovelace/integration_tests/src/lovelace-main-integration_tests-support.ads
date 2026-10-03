--  Shared helpers for CLI build, wasm-tools validate, entrypoint run, and reporting.

package Lovelace.Main.Integration_Tests.Support is

   --  Outcome of an optional external tool step.
   --  @enum Missing Tool not on PATH; caller should treat as inconclusive.
   --  @enum Succeeded Tool ran and exited 0.
   --  @enum Failed Tool ran and exited non-zero (assertion already failed).
   type Tool_Status is (Missing, Succeeded, Failed);

   --  Printed status for one integration test case.
   --  @enum Ok Test completed successfully.
   --  @enum Fail Test hit a failing assertion.
   --  @enum Inconclusive Optional tool missing for a required step.
   type Test_Outcome is (Ok, Fail, Inconclusive);

   --  Ada.Directories.Compose for Root / Relative.
   --  @param Root Parent directory.
   --  @param Relative Child name.
   --  @return Combined path.
   function Compose_Under (Root, Relative : String) return String;

   --  Absolute path to the lovelace executable under ../bin or on PATH.
   --  @return Path bytes, or empty when not found.
   function Locate_Lovelace return String;

   --  Absolute path to Name on PATH, or empty when missing.
   --  @param Name Executable basename (e.g. "wasm-tools", "wasmtime").
   --  @return Full path, or "".
   function Locate_Tool (Name : String) return String;

   --  Path to samples/<Feature_Folder>/<File_Name> relative to this crate.
   --  @param Feature_Folder Samples subfolder (e.g. "program", "module").
   --  @param File_Name .love basename.
   --  @return Relative path to the sample.
   function Locate_Sample (Feature_Folder, File_Name : String) return String;

   --  Repo .tests/integration-tests[/<Subfolder>] output root.
   --  @param Subfolder Optional subfolder under integration-tests ("" for root).
   --  @return Absolute output directory path.
   function Locate_Output_Root (Subfolder : String := "") return String;

   --  Print wasm-tools and wasmtime paths; assert both are on PATH.
   procedure Report_And_Require_Tools;

   --  Print "NAME  [OK|FAIL|INCONCLUSIVE]" for one test.
   --  @param Name Test display name.
   --  @param Outcome Result to print.
   procedure Report_Test_Result (Name : String; Outcome : Test_Outcome);

   --  Ensure Output_Root exists as an empty directory tree.
   --  @param Output_Root Directory to recreate.
   procedure Reset_Output_Root (Output_Root : String);

   --  Run lovelace build --force for Sample_Path into Output_Root.
   --  Stdout ([info]) is discarded; stderr ([err]) still prints.
   --  @param Lovelace_Path Path to the lovelace executable.
   --  @param Sample_Path Path to the .love source.
   --  @param Output_Root Build output folder.
   --  @param Message Assertion prefix on failure.
   procedure Build_Sample (Lovelace_Path : String; Sample_Path : String; Output_Root : String; Message : String);

   --  Assert obj/Unit_Name.lir and bin Unit_Name .wasm/.wat/.wit exist.
   --  @param Output_Root Build output folder.
   --  @param Unit_Name Unit stem (matches .love basename).
   --  @param Message Assertion prefix.
   procedure Assert_Build_Artifacts (Output_Root : String; Unit_Name : String; Message : String);

   --  Assert bin/Unit_Name.wat contains Fragment.
   --  @param Output_Root Build output folder.
   --  @param Unit_Name Unit stem.
   --  @param Fragment Required UTF-8 substring.
   --  @param Message Assertion prefix.
   procedure Assert_Wat_Contains (Output_Root : String; Unit_Name : String; Fragment : String; Message : String);

   --  If wasm-tools is on PATH, validate Path; otherwise Status is Missing.
   --  @param Path .wasm or .wat file to validate.
   --  @param Message Assertion prefix when validation fails.
   --  @param Status Missing, Succeeded, or Failed.
   procedure Validate_Artifact (Path : String; Message : String; Status : out Tool_Status);

   --  Validate bin/Unit_Name.wasm and .wat when wasm-tools is available.
   --  @param Output_Root Build output folder.
   --  @param Unit_Name Unit stem.
   --  @param Message Assertion prefix.
   --  @param Status Missing if wasm-tools absent; Succeeded if both files validate.
   procedure Validate_Unit_Artifacts
     (Output_Root : String; Unit_Name : String; Message : String; Status : out Tool_Status);

   --  Run an entrypoint artifact with the current host policy (wasmtime today).
   --  Future: WASI -> wasmtime; native -> lovelace CLI; web -> headless Chrome/Node + JS glue.
   --  @param Path .wasm or .wat component with wasi:cli/run.
   --  @param Message Assertion prefix when the run fails.
   --  @param Status Missing if wasmtime absent; Succeeded if exit 0.
   procedure Run_Entrypoint_Artifact (Path : String; Message : String; Status : out Tool_Status);

   --  Run bin/Unit_Name.wasm and .wat when wasmtime is available (program/entrypoint only).
   --  @param Output_Root Build output folder.
   --  @param Unit_Name Unit stem.
   --  @param Message Assertion prefix.
   --  @param Status Missing if wasmtime absent; Succeeded if both runs exit 0.
   procedure Run_Unit_Entrypoint (Output_Root : String; Unit_Name : String; Message : String; Status : out Tool_Status);

end Lovelace.Main.Integration_Tests.Support;
