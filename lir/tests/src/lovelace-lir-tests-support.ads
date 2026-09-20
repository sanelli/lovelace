with Ada.Streams;
with Ada.Strings.Unbounded;

with Lovelace.Lir.Errors;
with Lovelace.Lir.Modules;
with Lovelace.Lir.Subroutines;
with Lovelace.Lir.Types;

--  Shared helpers for lovelace_lir AUnit tests.

package Lovelace.Lir.Tests.Support is

   --  Encode one Unicode scalar as UTF-8 bytes.
   --  @param Point Unicode scalar.
   --  @return UTF-8 byte string.
   function To_Utf_8 (Point : Wide_Wide_Character) return String;

   --  Build a subroutine with Name, Return_Type, optional params, flags, and noop count.
   --  @param Name UTF-8 subroutine name.
   --  @param Return_Type Result type.
   --  @param Parameter_Types Parameter types (may be empty).
   --  @param Flags Subroutine flag bits.
   --  @param Noop_Count Number of No_Operation instructions to append.
   --  @return Built subroutine.
   function Make_Subroutine
     (Name            : String;
      Return_Type     : Types.Value_Type;
      Parameter_Types : Types.Value_Type_Sequence := Types.Empty_Sequence;
      Flags           : Subroutines.Subroutine_Flags := 0;
      Noop_Count      : Natural := 0) return Subroutines.Subroutine;

   --  Require Encode success and return a stream copy of the bytes.
   --  @param The_Module Module to encode.
   --  @param Message Assertion message on failure.
   --  @return Encoded bytes as a stream array.
   function Must_Encode
     (The_Module : Modules.Module; Message : String)
      return Ada.Streams.Stream_Element_Array;

   --  Require Decode success and return the module.
   --  @param Bytes Encoded image.
   --  @param Message Assertion message on failure.
   --  @return Decoded module.
   function Must_Decode
     (Bytes : Ada.Streams.Stream_Element_Array; Message : String)
      return Modules.Module;

   --  Require Decode failure with Expected code.
   --  @param Bytes Encoded image.
   --  @param Expected Expected Error_Code.
   --  @param Message Assertion message.
   procedure Assert_Decode_Error
     (Bytes    : Ada.Streams.Stream_Element_Array;
      Expected : Errors.Error_Code;
      Message  : String);

   --  Require Validate failure with Expected code.
   --  @param The_Module Module to validate.
   --  @param Expected Expected Error_Code.
   --  @param Message Assertion message.
   procedure Assert_Validate_Error
     (The_Module : Modules.Module;
      Expected   : Errors.Error_Code;
      Message    : String);

   --  Require To_Text success and return the text.
   --  @param The_Module Module to render.
   --  @param Message Assertion message on failure.
   --  @return Canonical .tlir text.
   function Must_To_Text
     (The_Module : Modules.Module; Message : String)
      return Ada.Strings.Unbounded.Unbounded_String;

   --  Assert Bytes has Expected_Length elements.
   --  @param Bytes Stream array.
   --  @param Expected_Length Expected length.
   --  @param Message Assertion message.
   procedure Assert_Byte_Count
     (Bytes           : Ada.Streams.Stream_Element_Array;
      Expected_Length : Natural;
      Message         : String);

   --  Assert byte at Index equals Expected.
   --  @param Bytes Stream array.
   --  @param Index Index into Bytes.
   --  @param Expected Expected byte.
   --  @param Message Assertion message.
   procedure Assert_Byte
     (Bytes    : Ada.Streams.Stream_Element_Array;
      Index    : Ada.Streams.Stream_Element_Offset;
      Expected : Ada.Streams.Stream_Element;
      Message  : String);

   --  Copy Bytes and replace the element at Index.
   --  @param Bytes Source stream array.
   --  @param Index Index to replace.
   --  @param Value New byte value.
   --  @return Mutated copy.
   function Replace_Byte
     (Bytes : Ada.Streams.Stream_Element_Array;
      Index : Ada.Streams.Stream_Element_Offset;
      Value : Ada.Streams.Stream_Element)
      return Ada.Streams.Stream_Element_Array;

   --  Copy Bytes and append Value.
   --  @param Bytes Source stream array.
   --  @param Value Byte to append.
   --  @return Extended copy.
   function Append_Byte
     (Bytes : Ada.Streams.Stream_Element_Array;
      Value : Ada.Streams.Stream_Element)
      return Ada.Streams.Stream_Element_Array;

   --  Copy Bytes truncated to Keep_Count leading elements.
   --  @param Bytes Source stream array.
   --  @param Keep_Count Number of leading bytes to keep.
   --  @return Truncated copy.
   function Truncate
     (Bytes      : Ada.Streams.Stream_Element_Array;
      Keep_Count : Ada.Streams.Stream_Element_Offset)
      return Ada.Streams.Stream_Element_Array;

   --  Assert Encode then Decode preserves To_Text of The_Module.
   --  @param The_Module Module to round-trip.
   --  @param Message Assertion message.
   procedure Assert_Binary_Round_Trip
     (The_Module : Modules.Module; Message : String);

   --  Assert Text contains Fragment as a substring.
   --  @param Text Full text.
   --  @param Fragment Expected substring.
   --  @param Message Assertion message.
   procedure Assert_Contains
     (Text : String; Fragment : String; Message : String);

   --  Assert Text does not contain Fragment.
   --  @param Text Full text.
   --  @param Fragment Forbidden substring.
   --  @param Message Assertion message.
   procedure Assert_Not_Contains
     (Text : String; Fragment : String; Message : String);

end Lovelace.Lir.Tests.Support;
