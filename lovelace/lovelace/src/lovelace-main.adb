with Lovelace.Main.Arguments;
with Lovelace.Main.Dispatch;
with Lovelace.Main.Terminal;

package body Lovelace.Main is

   procedure Report_Error (Context : String; Description : String) is
      Text : constant String := "[err] " & Context & ASCII.LF & ASCII.LF & ASCII.LF & Description & ASCII.LF;
   begin
      Terminal.Put_Error_Text (Text);
   end Report_Error;

   procedure Run is
   begin
      Dispatch.Run (Arguments.Parse);
   end Run;

end Lovelace.Main;
