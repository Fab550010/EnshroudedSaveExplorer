unit uLocalization;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

const
  LOCA_RECORD_SIZE = 24;
  MAX_LOCA_STRING_LENGTH = 1024 * 1024;

type
  TLocaEntry = packed record
    ID: Cardinal;
    RelativeOffset: Cardinal;
    Length: Cardinal;
    Unknown0C: Cardinal;
    Unknown10: Cardinal;
    Unknown14: Cardinal;
  end;

  TLocalizationItem = record
    ID: Cardinal;
    Text: UTF8String;
  end;

  TLocalizationItems = array of TLocalizationItem;

function LoadLocalizationTable(
  const FileName: string;
  SeedRecordOffset: Int64;
  out Items: TLocalizationItems
): Boolean;

function FindLocalization(
  const Items: TLocalizationItems;
  ID: Cardinal;
  out Text: UTF8String
): Boolean;

implementation

function ReadEntry(
  Stream: TFileStream;
  RecordOffset: Int64;
  out Entry: TLocaEntry
): Boolean;
begin
  Result := False;

  if (RecordOffset < 0) or
     (RecordOffset + SizeOf(TLocaEntry) > Stream.Size) then
    Exit;

  Stream.Position := RecordOffset;

  Result :=
    Stream.Read(Entry, SizeOf(Entry)) =
    SizeOf(Entry);
end;

function IsValidUtf8(const Data: TBytes): Boolean;
var
  I, N: Integer;
  B: Byte;
begin
  Result := False;

  N := Length(Data);

  if N = 0 then
    Exit;

  I := 0;

  while I < N do
  begin
    B := Data[I];

    if B = 0 then
      Exit;

    if B < $80 then
    begin
      if (B < 32) and
         (B <> 9) and
         (B <> 10) and
         (B <> 13) then
        Exit;

      Inc(I);
    end
    else if (B and $E0) = $C0 then
    begin
      if I + 1 >= N then Exit;
      if (Data[I + 1] and $C0) <> $80 then Exit;
      Inc(I, 2);
    end
    else if (B and $F0) = $E0 then
    begin
      if I + 2 >= N then Exit;
      if (Data[I + 1] and $C0) <> $80 then Exit;
      if (Data[I + 2] and $C0) <> $80 then Exit;
      Inc(I, 3);
    end
    else if (B and $F8) = $F0 then
    begin
      if I + 3 >= N then Exit;
      if (Data[I + 1] and $C0) <> $80 then Exit;
      if (Data[I + 2] and $C0) <> $80 then Exit;
      if (Data[I + 3] and $C0) <> $80 then Exit;
      Inc(I, 4);
    end
    else
      Exit;
  end;

  Result := True;
end;

function ResolveEntry(
  Stream: TFileStream;
  RecordOffset: Int64;
  const Entry: TLocaEntry;
  out Text: UTF8String
): Boolean;
var
  StringOffset: Int64;
  Raw: TBytes;
begin
  Result := False;
  Text := '';

  if (Entry.ID = 0) or
     (Entry.Length = 0) or
     (Entry.Length > MAX_LOCA_STRING_LENGTH) then
    Exit;

  StringOffset :=
    RecordOffset +
    4 +
    Int64(Entry.RelativeOffset);

  if (StringOffset < 0) or
     (StringOffset + Entry.Length > Stream.Size) then
    Exit;

  SetLength(Raw, Entry.Length);

  Stream.Position := StringOffset;

  if Stream.Read(Raw[0], Entry.Length) <>
     Integer(Entry.Length) then
    Exit;

  if not IsValidUtf8(Raw) then
    Exit;

  SetString(
    Text,
    PAnsiChar(@Raw[0]),
    Entry.Length
  );

  Result := True;
end;

function IsPlausibleEntry(
  Stream: TFileStream;
  Offset: Int64;
  out Entry: TLocaEntry
): Boolean;
var
  Text: UTF8String;
begin
  Result :=
    ReadEntry(Stream, Offset, Entry) and
    ResolveEntry(Stream, Offset, Entry, Text);
end;

function FindTableStart(
  Stream: TFileStream;
  SeedOffset: Int64
): Int64;
var
  Current, Previous: Int64;
  A, B: TLocaEntry;
begin
  Current := SeedOffset;

  while True do
  begin
    Previous := Current - LOCA_RECORD_SIZE;

    if Previous < 0 then
      Break;

    if not IsPlausibleEntry(Stream, Previous, A) then
      Break;

    if not IsPlausibleEntry(Stream, Current, B) then
      Break;

    if A.ID >= B.ID then
      Break;

    Current := Previous;
  end;

  Result := Current;
end;

function FindTableEnd(
  Stream: TFileStream;
  SeedOffset: Int64
): Int64;
var
  Current, Next: Int64;
  A, B: TLocaEntry;
begin
  Current := SeedOffset;

  while True do
  begin
    Next := Current + LOCA_RECORD_SIZE;

    if Next + LOCA_RECORD_SIZE > Stream.Size then
      Break;

    if not IsPlausibleEntry(Stream, Current, A) then
      Break;

    if not IsPlausibleEntry(Stream, Next, B) then
      Break;

    if A.ID >= B.ID then
      Break;

    Current := Next;
  end;

  Result := Current;
end;

function LoadLocalizationTable(
  const FileName: string;
  SeedRecordOffset: Int64;
  out Items: TLocalizationItems
): Boolean;
var
  Stream: TFileStream;
  SeedEntry: TLocaEntry;
  StartOffset, EndOffset: Int64;
  Offset: Int64;
  Count, I: Integer;
  Entry: TLocaEntry;
  Text: UTF8String;
begin
  Result := False;
  SetLength(Items, 0);

  Stream := TFileStream.Create(
    FileName,
    fmOpenRead or fmShareDenyNone
  );

  try
    if not IsPlausibleEntry(
         Stream,
         SeedRecordOffset,
         SeedEntry
       ) then
      Exit;

    StartOffset :=
      FindTableStart(Stream, SeedRecordOffset);

    EndOffset :=
      FindTableEnd(Stream, SeedRecordOffset);

    Count :=
      ((EndOffset - StartOffset)
       div LOCA_RECORD_SIZE) + 1;

    SetLength(Items, Count);

    Offset := StartOffset;

    for I := 0 to Count - 1 do
    begin
      if not ReadEntry(Stream, Offset, Entry) then
        Exit;

      if not ResolveEntry(Stream, Offset, Entry, Text) then
        Exit;

      Items[I].ID := Entry.ID;
      Items[I].Text := Text;

      Inc(Offset, LOCA_RECORD_SIZE);
    end;

    Result := True;

  finally
    Stream.Free;
  end;
end;

function FindLocalization(
  const Items: TLocalizationItems;
  ID: Cardinal;
  out Text: UTF8String
): Boolean;
var
  L, R, M: Integer;
begin
  Result := False;
  Text := '';

  L := 0;
  R := High(Items);

  while L <= R do
  begin
    M := L + ((R - L) div 2);

    if Items[M].ID = ID then
    begin
      Text := Items[M].Text;
      Exit(True);
    end;

    if Items[M].ID < ID then
      L := M + 1
    else
      R := M - 1;
  end;
end;

end.
