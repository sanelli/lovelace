with Interfaces;

package body Lovelace.Compiler.Backend.Native_Print is

   use type Interfaces.Integer_32;

   --  Local indices after the single i32 parameter at 0.
   L_N      : constant := 1;
   L_Neg    : constant := 2;
   L_Ptr    : constant := 3;
   L_Len    : constant := 4;
   L_Reader : constant := 5;
   L_Writer : constant := 6;
   L_Fut    : constant := 7;
   L_Tmp    : constant := 8;
   L_Pair   : constant := 9;

   Buffer_End     : constant Interfaces.Integer_32 := 96;
   Result_Addr    : constant Interfaces.Integer_32 := 32;
   Int_Min_Addr   : constant Interfaces.Integer_32 := 16;
   Int_Min_Length : constant Interfaces.Integer_32 := 11;

   procedure Emit (Body_Out : in out Model.Instruction_Sequence; Item : Model.Core_Instruction);
   --  Append one instruction.

   procedure Emit_I32 (Body_Out : in out Model.Instruction_Sequence; Value : Interfaces.Integer_32);
   --  i32.const Value.

   procedure Emit_Local_Get (Body_Out : in out Model.Instruction_Sequence; Index : Natural);
   --  local.get Index.

   procedure Emit_Local_Set (Body_Out : in out Model.Instruction_Sequence; Index : Natural);
   --  local.set Index.

   procedure Emit_Call_Import (Body_Out : in out Model.Instruction_Sequence; Index : Natural);
   --  call import Index.

   procedure Store_Int_Min_Literal (Body_Out : in out Model.Instruction_Sequence);
   --  Store ASCII "-2147483648" at Int_Min_Addr.

   procedure Emit_Write_Buffer
     (Body_Out : in out Model.Instruction_Sequence;
      Addr_Local : Natural;
      Len_Local  : Natural);
   --  write-via-stream the [Addr_Local, Len_Local) buffer; trap on failure.

   procedure Emit
     (Body_Out : in out Model.Instruction_Sequence; Item : Model.Core_Instruction) is
   begin
      Model.Append (Body_Out, Item);
   end Emit;

   procedure Emit_Call_Import
     (Body_Out : in out Model.Instruction_Sequence; Index : Natural) is
   begin
      Emit (Body_Out, (Kind => Model.Call_Import, Import_Index => Index));
   end Emit_Call_Import;

   procedure Emit_I32
     (Body_Out : in out Model.Instruction_Sequence; Value : Interfaces.Integer_32) is
   begin
      Emit (Body_Out, (Kind => Model.I32_Constant, Value => Value));
   end Emit_I32;

   procedure Emit_Local_Get
     (Body_Out : in out Model.Instruction_Sequence; Index : Natural) is
   begin
      Emit (Body_Out, (Kind => Model.Local_Get, Local_Index => Index));
   end Emit_Local_Get;

   procedure Emit_Local_Set
     (Body_Out : in out Model.Instruction_Sequence; Index : Natural) is
   begin
      Emit (Body_Out, (Kind => Model.Local_Set, Local_Index => Index));
   end Emit_Local_Set;

   procedure Emit_Write_Buffer
     (Body_Out   : in out Model.Instruction_Sequence;
      Addr_Local : Natural;
      Len_Local  : Natural) is
   begin
      Emit_Call_Import (Body_Out, Model.Stream_New_Import_Index);
      Emit_Local_Set (Body_Out, L_Pair);

      Emit_Local_Get (Body_Out, L_Pair);
      Emit (Body_Out, (Kind => Model.I32_Wrap_I64));
      Emit_Local_Set (Body_Out, L_Reader);

      Emit_Local_Get (Body_Out, L_Pair);
      Emit (Body_Out, (Kind => Model.I64_Constant, Value_I64 => 32));
      Emit (Body_Out, (Kind => Model.I64_Shr_U));
      Emit (Body_Out, (Kind => Model.I32_Wrap_I64));
      Emit_Local_Set (Body_Out, L_Writer);

      Emit_Local_Get (Body_Out, L_Reader);
      Emit_Call_Import (Body_Out, Model.Write_Via_Stream_Import_Index);
      Emit_Local_Set (Body_Out, L_Fut);

      Emit_Local_Get (Body_Out, L_Writer);
      Emit_Local_Get (Body_Out, Addr_Local);
      Emit_Local_Get (Body_Out, Len_Local);
      Emit_Call_Import (Body_Out, Model.Stream_Write_Import_Index);
      Emit_Local_Set (Body_Out, L_Tmp);

      Emit_Local_Get (Body_Out, L_Tmp);
      Emit_I32 (Body_Out, -1);
      Emit (Body_Out, (Kind => Model.I32_Eq));
      Emit (Body_Out, (Kind => Model.If_Empty));
      Emit (Body_Out, (Kind => Model.Unreachable));
      Emit (Body_Out, (Kind => Model.End_Op));

      Emit_Local_Get (Body_Out, L_Writer);
      Emit_Call_Import (Body_Out, Model.Stream_Drop_Writable_Import_Index);

      Emit_Local_Get (Body_Out, L_Fut);
      Emit_I32 (Body_Out, Result_Addr);
      Emit_Call_Import (Body_Out, Model.Future_Read_Import_Index);
      Emit_Local_Set (Body_Out, L_Tmp);

      Emit_Local_Get (Body_Out, L_Tmp);
      Emit_I32 (Body_Out, -1);
      Emit (Body_Out, (Kind => Model.I32_Eq));
      Emit (Body_Out, (Kind => Model.If_Empty));
      Emit (Body_Out, (Kind => Model.Unreachable));
      Emit (Body_Out, (Kind => Model.End_Op));

      Emit_I32 (Body_Out, Result_Addr);
      Emit (Body_Out, (Kind => Model.I32_Load8_U));
      Emit_I32 (Body_Out, 0);
      Emit (Body_Out, (Kind => Model.I32_Ne));
      Emit (Body_Out, (Kind => Model.If_Empty));
      Emit (Body_Out, (Kind => Model.Unreachable));
      Emit (Body_Out, (Kind => Model.End_Op));

      Emit_Local_Get (Body_Out, L_Fut);
      Emit_Call_Import (Body_Out, Model.Future_Drop_Readable_Import_Index);
   end Emit_Write_Buffer;

   procedure Store_Int_Min_Literal (Body_Out : in out Model.Instruction_Sequence) is
      Literal : constant String := "-2147483648";
   begin
      for Index in Literal'Range loop
         Emit_I32 (Body_Out, Int_Min_Addr + Interfaces.Integer_32 (Index - Literal'First));
         Emit_I32 (Body_Out, Interfaces.Integer_32 (Character'Pos (Literal (Index))));
         Emit (Body_Out, (Kind => Model.I32_Store8));
      end loop;
   end Store_Int_Min_Literal;

   procedure Synthesize
     (Locals       : out Model.Core_Local_Sequence;
      Instructions : out Model.Instruction_Sequence) is
   begin
      Locals := Model.Empty_Locals;
      Model.Append (Locals, Model.I32); -- n
      Model.Append (Locals, Model.I32); -- neg
      Model.Append (Locals, Model.I32); -- ptr
      Model.Append (Locals, Model.I32); -- len
      Model.Append (Locals, Model.I32); -- reader
      Model.Append (Locals, Model.I32); -- writer
      Model.Append (Locals, Model.I32); -- fut
      Model.Append (Locals, Model.I32); -- tmp
      Model.Append (Locals, Model.I64); -- pair

      Instructions := Model.Empty_Instructions;

      --  n := value
      Emit_Local_Get (Instructions, 0);
      Emit_Local_Set (Instructions, L_N);
      Emit_I32 (Instructions, 0);
      Emit_Local_Set (Instructions, L_Neg);
      Emit_I32 (Instructions, Buffer_End);
      Emit_Local_Set (Instructions, L_Ptr);

      --  if n == 0 then store '0' and write
      Emit_Local_Get (Instructions, L_N);
      Emit (Instructions, (Kind => Model.I32_Eqz));
      Emit (Instructions, (Kind => Model.If_Empty));
      Emit_Local_Get (Instructions, L_Ptr);
      Emit_I32 (Instructions, 1);
      Emit (Instructions, (Kind => Model.I32_Sub));
      Emit_Local_Set (Instructions, L_Ptr);
      Emit_Local_Get (Instructions, L_Ptr);
      Emit_I32 (Instructions, Character'Pos ('0'));
      Emit (Instructions, (Kind => Model.I32_Store8));
      Emit_I32 (Instructions, 1);
      Emit_Local_Set (Instructions, L_Len);
      Emit_Write_Buffer (Instructions, L_Ptr, L_Len);
      Emit (Instructions, (Kind => Model.Else_Op));

      --  if n == Integer'First then write literal
      Emit_Local_Get (Instructions, L_N);
      Emit_I32 (Instructions, Interfaces.Integer_32'First);
      Emit (Instructions, (Kind => Model.I32_Eq));
      Emit (Instructions, (Kind => Model.If_Empty));
      Store_Int_Min_Literal (Instructions);
      Emit_I32 (Instructions, Int_Min_Addr);
      Emit_Local_Set (Instructions, L_Ptr);
      Emit_I32 (Instructions, Int_Min_Length);
      Emit_Local_Set (Instructions, L_Len);
      Emit_Write_Buffer (Instructions, L_Ptr, L_Len);
      Emit (Instructions, (Kind => Model.Else_Op));

      --  if n < 0 then neg := 1; n := -n
      Emit_Local_Get (Instructions, L_N);
      Emit_I32 (Instructions, 0);
      Emit (Instructions, (Kind => Model.I32_Lt_S));
      Emit (Instructions, (Kind => Model.If_Empty));
      Emit_I32 (Instructions, 1);
      Emit_Local_Set (Instructions, L_Neg);
      Emit_I32 (Instructions, 0);
      Emit_Local_Get (Instructions, L_N);
      Emit (Instructions, (Kind => Model.I32_Sub));
      Emit_Local_Set (Instructions, L_N);
      Emit (Instructions, (Kind => Model.End_Op));

      --  digit loop
      Emit (Instructions, (Kind => Model.Loop_Empty));
      Emit_Local_Get (Instructions, L_Ptr);
      Emit_I32 (Instructions, 1);
      Emit (Instructions, (Kind => Model.I32_Sub));
      Emit_Local_Set (Instructions, L_Ptr);
      Emit_Local_Get (Instructions, L_Ptr);
      Emit_Local_Get (Instructions, L_N);
      Emit_I32 (Instructions, 10);
      Emit (Instructions, (Kind => Model.I32_Rem_S));
      Emit_I32 (Instructions, Character'Pos ('0'));
      Emit (Instructions, (Kind => Model.I32_Add));
      Emit (Instructions, (Kind => Model.I32_Store8));
      Emit_Local_Get (Instructions, L_N);
      Emit_I32 (Instructions, 10);
      Emit (Instructions, (Kind => Model.I32_Div_S));
      Emit_Local_Set (Instructions, L_N);
      Emit_Local_Get (Instructions, L_N);
      Emit_I32 (Instructions, 0);
      Emit (Instructions, (Kind => Model.I32_Ne));
      Emit (Instructions, (Kind => Model.Br_If, Label_Depth => 0));
      Emit (Instructions, (Kind => Model.End_Op));

      --  optional leading '-'
      Emit_Local_Get (Instructions, L_Neg);
      Emit (Instructions, (Kind => Model.If_Empty));
      Emit_Local_Get (Instructions, L_Ptr);
      Emit_I32 (Instructions, 1);
      Emit (Instructions, (Kind => Model.I32_Sub));
      Emit_Local_Set (Instructions, L_Ptr);
      Emit_Local_Get (Instructions, L_Ptr);
      Emit_I32 (Instructions, Character'Pos ('-'));
      Emit (Instructions, (Kind => Model.I32_Store8));
      Emit (Instructions, (Kind => Model.End_Op));

      Emit_I32 (Instructions, Buffer_End);
      Emit_Local_Get (Instructions, L_Ptr);
      Emit (Instructions, (Kind => Model.I32_Sub));
      Emit_Local_Set (Instructions, L_Len);
      Emit_Write_Buffer (Instructions, L_Ptr, L_Len);

      Emit (Instructions, (Kind => Model.End_Op)); -- end int-min else
      Emit (Instructions, (Kind => Model.End_Op)); -- end zero else
   end Synthesize;

end Lovelace.Compiler.Backend.Native_Print;
