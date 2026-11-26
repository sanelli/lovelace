--  Product release identity (without git hash).

package Lovelace.Common.Release is

   --  Lovelace product version used for install layout paths (no git hash).
   --  Keep in sync with the CLI version line prefix (`â¦ @ <githash>`).
   Version : constant String := "0.0.1-alpha.1";

end Lovelace.Common.Release;
