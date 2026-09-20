with Ada.Strings.Fixed;
with AUnit.Assertions;

with Lovelace.Common.Utf_8;
with Lovelace.Lir.Binary;
with Lovelace.Lir.Opcodes;
with Lovelace.Lir.Text;

package body Lovelace.Lir.Tests.Support is

   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Errors.Error_Code;

   function To_Stream
     (Sequence : Binary.Byte_Sequence) return Ada.Streams.Stream_Element_Array;

   function Append_Byte
     (Bytes : Ada.Streams.Stream_Element_Array;
      Value : Ada.Streams.Stream_Element)
      return Ada.Streams.Stream_Element_Array
   is
      Result :
        Ada.Streams.Stream_Element_Array (Bytes'First .. Bytes'Last + 1);
   begin
      Result (Bytes'Range) := Bytes;
      Result (Result'Last) := Value;
      return Result;
   end Append_Byte;

   procedure Assert_Binary_Round_Trip
     (The_Module : Modules.Module; Message : String)
   is
      Encoded : constant Ada.Streams.Stream_Element_Array :=
        Must_Encode (The_Module, Message & " encode");
      Decoded : constant Modules.Module :=
        Must_Decode (Encoded, Message & " decode");
      Before  : constant Ada.Strings.Unbounded.Unbounded_String :=
        Must_To_Text (The_Module, Message & " before");
      After   : constant Ada.Strings.Unbounded.Unbounded_String :=
        Must_To_Text (Decoded, Message & " after");
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded."=" (Before, After),
         Message & ": To_Text mismatch after round-trip");
   end Assert_Binary_Round_Trip;

   procedure Assert_Byte
     (Bytes    : Ada.Streams.Stream_Element_Array;
      Index    : Ada.Streams.Stream_Element_Offset;
      Expected : Ada.Streams.Stream_Element;
      Message  : String)
   is
      Actual : constant Ada.Streams.Stream_Element := Bytes (Index);
   begin
      AUnit.Assertions.Assert
        (Actual = Expected,
         Message
         & ": expected"
         & Ada.Streams.Stream_Element'Image (Expected)
         & " got"
         & Ada.Streams.Stream_Element'Image (Actual));
   end Assert_Byte;

   procedure Assert_Byte_Count
     (Bytes           : Ada.Streams.Stream_Element_Array;
      Expected_Length : Natural;
      Message         : String)
   is
      Actual_Length : constant Natural := Natural (Bytes'Length);
   begin
      AUnit.Assertions.Assert
        (Actual_Length = Expected_Length,
         Message
         & ": expected"
         & Natural'Image (Expected_Length)
         & " got"
         & Natural'Image (Actual_Length));
   end Assert_Byte_Count;

   procedure Assert_Contains
     (Text : String; Fragment : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Text, Fragment) > 0,
         Message & ": missing fragment");
   end Assert_Contains;

   procedure Assert_Decode_Error
     (Bytes    : Ada.Streams.Stream_Element_Array;
      Expected : Errors.Error_Code;
      Message  : String)
   is
      Result : constant Binary.Decode_Result := Binary.Decode (Bytes);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, Message & ": unexpected decode success");

         when False =>
            AUnit.Assertions.Assert
              (Result.Error = Expected,
               Message
               & ": expected "
               & Errors.Error_Code'Image (Expected)
               & " got "
               & Errors.Error_Code'Image (Result.Error));
      end case;
   end Assert_Decode_Error;

   procedure Assert_Not_Contains
     (Text : String; Fragment : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Text, Fragment) = 0,
         Message & ": unexpected fragment");
   end Assert_Not_Contains;

   procedure Assert_Validate_Error
     (The_Module : Modules.Module;
      Expected   : Errors.Error_Code;
      Message    : String)
   is
      Result : constant Errors.Validation_Results.Result :=
        Modules.Validate (The_Module);
   begin
      case Result.Ok is
         when True  =>
            AUnit.Assertions.Assert
              (False, Message & ": unexpected validate success");

         when False =>
            AUnit.Assertions.Assert
              (Result.Error = Expected,
               Message
               & ": expected "
               & Errors.Error_Code'Image (Expected)
               & " got "
               & Errors.Error_Code'Image (Result.Error));
      end case;
   end Assert_Validate_Error;

   function Make_Subroutine
     (Name            : String;
      Return_Type     : Types.Value_Type;
      Parameter_Types : Types.Value_Type_Sequence := Types.Empty_Sequence;
      Flags           : Subroutines.Subroutine_Flags := 0;
      Noop_Count      : Natural := 0) return Subroutines.Subroutine
   is
      The_Subroutine : Subroutines.Subroutine :=
        Subroutines.Create
          (The_Signature =>
             (Name            =>
                Ada.Strings.Unbounded.To_Unbounded_String (Name),
              Return_Type     => Return_Type,
              Parameter_Types => Parameter_Types),
           Flags         => Flags);
   begin
      for Unused in 1 .. Noop_Count loop
         Subroutines.Append_Instruction
           (The_Subroutine, (Operation => Opcodes.No_Operation));
      end loop;
      return The_Subroutine;
   end Make_Subroutine;

   function Must_Decode
     (Bytes : Ada.Streams.Stream_Element_Array; Message : String)
      return Modules.Module
   is
      Result : constant Binary.Decode_Result := Binary.Decode (Bytes);
   begin
      case Result.Ok is
         when True  =>
            return Result.Value;

         when False =>
            AUnit.Assertions.Assert
              (False,
               Message
               & ": decode failed "
               & Errors.Error_Code'Image (Result.Error));
            return Modules.Create ("unreachable");
      end case;
   end Must_Decode;

   function Must_Encode
     (The_Module : Modules.Module; Message : String)
      return Ada.Streams.Stream_Element_Array
   is
      Result : constant Binary.Encode_Result := Binary.Encode (The_Module);
      Empty  : Ada.Streams.Stream_Element_Array (1 .. 0);
   begin
      case Result.Ok is
         when True  =>
            return To_Stream (Result.Value);

         when False =>
            AUnit.Assertions.Assert
              (False,
               Message
               & ": encode failed "
               & Errors.Error_Code'Image (Result.Error));
            return Empty;
      end case;
   end Must_Encode;

   function Must_To_Text
     (The_Module : Modules.Module; Message : String)
      return Ada.Strings.Unbounded.Unbounded_String
   is
      Result : constant Text.To_Text_Result := Text.To_Text (The_Module);
   begin
      case Result.Ok is
         when True  =>
            return Result.Value;

         when False =>
            AUnit.Assertions.Assert
              (False,
               Message
               & ": To_Text failed "
               & Errors.Error_Code'Image (Result.Error));
            return Ada.Strings.Unbounded.Null_Unbounded_String;
      end case;
   end Must_To_Text;

   function Replace_Byte
     (Bytes : Ada.Streams.Stream_Element_Array;
      Index : Ada.Streams.Stream_Element_Offset;
      Value : Ada.Streams.Stream_Element)
      return Ada.Streams.Stream_Element_Array
   is
      Result : Ada.Streams.Stream_Element_Array := Bytes;
   begin
      Result (Index) := Value;
      return Result;
   end Replace_Byte;

   function To_Stream
     (Sequence : Binary.Byte_Sequence) return Ada.Streams.Stream_Element_Array
   is
      Result :
        Ada.Streams.Stream_Element_Array
          (1 .. Ada.Streams.Stream_Element_Offset (Binary.Length (Sequence)));
   begin
      for Index in 1 .. Binary.Length (Sequence) loop
         Result (Ada.Streams.Stream_Element_Offset (Index)) :=
           Ada.Streams.Stream_Element (Binary.Element (Sequence, Index));
      end loop;
      return Result;
   end To_Stream;

   function To_Utf_8 (Point : Wide_Wide_Character) return String is
      Result : constant Lovelace.Common.Utf_8.Encode_Results.Result :=
        Lovelace.Common.Utf_8.Encode (Point);
   begin
      case Result.Ok is
         when True  =>
            return Ada.Strings.Unbounded.To_String (Result.Value);

         when False =>
            AUnit.Assertions.Assert
              (False,
               "UTF-8 encode failed: "
               & Ada.Strings.Unbounded.To_String (Result.Error.Message));
            return "";
      end case;
   end To_Utf_8;

   function Truncate
     (Bytes      : Ada.Streams.Stream_Element_Array;
      Keep_Count : Ada.Streams.Stream_Element_Offset)
      return Ada.Streams.Stream_Element_Array is
   begin
      return Bytes (Bytes'First .. Bytes'First + Keep_Count - 1);
   end Truncate;

end Lovelace.Lir.Tests.Support;
