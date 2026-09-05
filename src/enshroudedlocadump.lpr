program EnshroudedLocaDump;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

const
  LOCA_RECORD_SIZE = 24;
  MAX_STRING_LENGTH = 1024 * 1024;

type
  TLocaEntry = packed record
    ID: Cardinal;
    RelativeOffset: Cardinal;
    Length: Cardinal;
    Unknown0C: Cardinal;
    Unknown10: Cardinal;
    Unknown14: Cardinal;
  end;

function ParseUInt(const S: string): QWord;
var
  T: string;
begin
  T := Trim(S);

  if Pos('0x', LowerCase(T)) = 1 then
    Result := StrToQWord('$' + Copy(T, 3, MaxInt))
  else if Pos('$', T) = 1 then
    Result := StrToQWord(T)
  else if
    (Pos('A', UpperCase(T)) > 0) or
    (Pos('B', UpperCase(T)) > 0) or
    (Pos('C', UpperCase(T)) > 0) or
    (Pos('D', UpperCase(T)) > 0) or
    (Pos('E', UpperCase(T)) > 0) or
    (Pos('F', UpperCase(T)) > 0)
  then
    Result := StrToQWord('$' + T)
  else
    Result := StrToQWord(T);
end;

function ReadEntry(
  Stream: TFileStream;
  RecordOffset: Int64;
  out Entry: TLocaEntry
): Boolean;
begin
  Result := False;

  if RecordOffset < 0 then
    Exit;

  if RecordOffset + SizeOf(TLocaEntry) > Stream.Size then
    Exit;

  Stream.Position := RecordOffset;

  Result :=
    Stream.Read(Entry, SizeOf(TLocaEntry)) =
    SizeOf(TLocaEntry);
end;

function IsValidUtf8(const Data: TBytes): Boolean;
var
  I, N: Integer;
  B: Byte;
begin
  Result := False;
  I := 0;
  N := Length(Data);

  if N = 0 then
    Exit;

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
  out StringOffset: Int64;
  out Text: UTF8String
): Boolean;
var
  Raw: TBytes;
begin
  Result := False;
  Text := '';

  if Entry.ID = 0 then
    Exit;

  if (Entry.Length = 0) or
     (Entry.Length > MAX_STRING_LENGTH) then
    Exit;

  StringOffset :=
    RecordOffset +
    4 +
    Int64(Entry.RelativeOffset);

  if StringOffset < 0 then
    Exit;

  if StringOffset + Entry.Length > Stream.Size then
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
  RecordOffset: Int64;
  out Entry: TLocaEntry;
  out Text: UTF8String
): Boolean;
var
  StringOffset: Int64;
begin
  Result := False;

  if not ReadEntry(Stream, RecordOffset, Entry) then
    Exit;

  if not ResolveEntry(
       Stream,
       RecordOffset,
       Entry,
       StringOffset,
       Text
     ) then
    Exit;

  Result := True;
end;

function IsOrderedPair(
  Stream: TFileStream;
  OffsetA, OffsetB: Int64
): Boolean;
var
  A, B: TLocaEntry;
  TA, TB: UTF8String;
begin
  Result := False;

  if not IsPlausibleEntry(Stream, OffsetA, A, TA) then
    Exit;

  if not IsPlausibleEntry(Stream, OffsetB, B, TB) then
    Exit;

  Result := A.ID < B.ID;
end;

function FindTableStart(
  Stream: TFileStream;
  SeedOffset: Int64
): Int64;
var
  Current, Previous: Int64;
begin
  Current := SeedOffset;

  while True do
  begin
    Previous := Current - LOCA_RECORD_SIZE;

    if Previous < 0 then
      Break;

    if not IsOrderedPair(
         Stream,
         Previous,
         Current
       ) then
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
begin
  Current := SeedOffset;

  while True do
  begin
    Next := Current + LOCA_RECORD_SIZE;

    if Next + LOCA_RECORD_SIZE > Stream.Size then
      Break;

    if not IsOrderedPair(
         Stream,
         Current,
         Next
       ) then
      Break;

    Current := Next;
  end;

  Result := Current;
end;

procedure DumpRecord(
  Stream: TFileStream;
  RecordOffset: Int64
);
var
  Entry: TLocaEntry;
  Text: UTF8String;
  StringOffset: Int64;
begin
  if not ReadEntry(Stream, RecordOffset, Entry) then
    Exit;

  if not ResolveEntry(
       Stream,
       RecordOffset,
       Entry,
       StringOffset,
       Text
     ) then
    Exit;

  WriteLn(
    '$', IntToHex(Entry.ID, 8),
    #9,
    RecordOffset,
    #9,
    StringOffset,
    #9,
    Entry.Length,
    #9,
    Text
  );
end;

procedure DumpTable(
  const FileName: string;
  SeedOffset: Int64
);
var
  Stream: TFileStream;
  SeedEntry: TLocaEntry;
  SeedText: UTF8String;

  StartOffset: Int64;
  EndOffset: Int64;
  Current: Int64;

  Count: QWord;
begin
  Stream := TFileStream.Create(
    FileName,
    fmOpenRead or fmShareDenyNone
  );

  try
    if not IsPlausibleEntry(
         Stream,
         SeedOffset,
         SeedEntry,
         SeedText
       ) then
      raise Exception.Create(
        'Seed offset does not point to a valid localization record'
      );

    WriteLn(
      'Seed ID   : $',
      IntToHex(SeedEntry.ID, 8)
    );

    WriteLn(
      'Seed text : ',
      SeedText
    );

    WriteLn;
    WriteLn('Detecting table boundaries...');

    StartOffset :=
      FindTableStart(
        Stream,
        SeedOffset
      );

    EndOffset :=
      FindTableEnd(
        Stream,
        SeedOffset
      );

    Count :=
      ((EndOffset - StartOffset)
       div LOCA_RECORD_SIZE) + 1;

    WriteLn(
      'Start     : 0x',
      IntToHex(StartOffset, 1)
    );

    WriteLn(
      'End       : 0x',
      IntToHex(EndOffset, 1)
    );

    WriteLn(
      'Records   : ',
      Count
    );

    WriteLn;
    WriteLn(
      'ID',
      #9,
      'RecordOffset',
      #9,
      'StringOffset',
      #9,
      'Length',
      #9,
      'Text'
    );

    Current := StartOffset;

    while Current <= EndOffset do
    begin
      DumpRecord(
        Stream,
        Current
      );

      Inc(
        Current,
        LOCA_RECORD_SIZE
      );
    end;

  finally
    Stream.Free;
  end;
end;

procedure FindID(
  const FileName: string;
  TargetID: Cardinal
);
const
  BUFFER_SIZE = 32 * 1024 * 1024;
var
  Stream: TFileStream;
  Buffer: TBytes;

  Pattern: array[0..3] of Byte;

  ReadCount: Integer;
  FilePos: Int64;
  BaseOffset: Int64;
  I: Integer;

  RecordOffset: Int64;
  Entry: TLocaEntry;
  Text: UTF8String;
  StringOffset: Int64;

  Tail: array[0..2] of Byte;
  TailSize: Integer;

  FoundCount: Integer;
begin
  Stream := TFileStream.Create(
    FileName,
    fmOpenRead or fmShareDenyNone
  );

  try
    Pattern[0] := Byte(TargetID and $FF);
    Pattern[1] := Byte((TargetID shr 8) and $FF);
    Pattern[2] := Byte((TargetID shr 16) and $FF);
    Pattern[3] := Byte((TargetID shr 24) and $FF);

    SetLength(
      Buffer,
      BUFFER_SIZE + 3
    );

    FilePos := 0;
    TailSize := 0;
    FoundCount := 0;

    while FilePos < Stream.Size do
    begin
      if TailSize > 0 then
        Move(
          Tail[0],
          Buffer[0],
          TailSize
        );

      Stream.Position := FilePos;

      ReadCount :=
        Stream.Read(
          Buffer[TailSize],
          BUFFER_SIZE
        );

      if ReadCount <= 0 then
        Break;

      BaseOffset :=
        FilePos - TailSize;

      for I := 0 to TailSize + ReadCount - 4 do
      begin
        if
          (Buffer[I] = Pattern[0]) and
          (Buffer[I + 1] = Pattern[1]) and
          (Buffer[I + 2] = Pattern[2]) and
          (Buffer[I + 3] = Pattern[3])
        then
        begin
          RecordOffset :=
            BaseOffset + I;

          if ReadEntry(
               Stream,
               RecordOffset,
               Entry
             ) and
             (Entry.ID = TargetID) and
             ResolveEntry(
               Stream,
               RecordOffset,
               Entry,
               StringOffset,
               Text
             ) then
          begin
            Inc(FoundCount);

            WriteLn;
            WriteLn(
              'Localization ID : $',
              IntToHex(Entry.ID, 8)
            );

            WriteLn(
              'Record offset   : 0x',
              IntToHex(RecordOffset, 1)
            );

            WriteLn(
              'Relative offset : 0x',
              IntToHex(Entry.RelativeOffset, 1)
            );

            WriteLn(
              'String offset   : 0x',
              IntToHex(StringOffset, 1)
            );

            WriteLn(
              'Length          : ',
              Entry.Length
            );

            WriteLn(
              'Unknown0C       : 0x',
              IntToHex(Entry.Unknown0C, 8)
            );

            WriteLn(
              'Unknown10       : 0x',
              IntToHex(Entry.Unknown10, 8)
            );

            WriteLn(
              'Unknown14       : 0x',
              IntToHex(Entry.Unknown14, 8)
            );

            WriteLn(
              'Text            : ',
              Text
            );
          end;
        end;
      end;

      if TailSize + ReadCount >= 3 then
      begin
        TailSize := 3;

        Move(
          Buffer[TailSize + ReadCount - 3],
          Tail[0],
          3
        );
      end
      else
        TailSize := 0;

      Inc(
        FilePos,
        ReadCount
      );
    end;

    WriteLn;
    WriteLn(
      'Valid localization entries found: ',
      FoundCount
    );

  finally
    Stream.Free;
  end;
end;

procedure Usage;
begin
  WriteLn('Usage:');
  WriteLn;
  WriteLn(
    '  EnshroudedLocaDump --find ',
    '<dat-file> <localization-id>'
  );
  WriteLn;
  WriteLn(
    '  EnshroudedLocaDump --dump-table ',
    '<dat-file> <record-offset>'
  );
  WriteLn;
  WriteLn('Examples:');
  WriteLn;
  WriteLn(
    '  EnshroudedLocaDump --find ',
    'enshrouded_016.dat C6CDFD78'
  );
  WriteLn;
  WriteLn(
    '  EnshroudedLocaDump --dump-table ',
    'enshrouded_016.dat 3F95ABE0'
  );
end;

var
  Mode: string;
  FileName: string;
  Value: QWord;

begin
  try
    if ParamCount <> 3 then
    begin
      Usage;
      Halt(1);
    end;

    Mode := LowerCase(
      ParamStr(1)
    );

    FileName :=
      ParamStr(2);

    if not FileExists(FileName) then
      raise Exception.Create(
        'File not found: ' +
        FileName
      );

    Value :=
      ParseUInt(
        ParamStr(3)
      );

    if Mode = '--find' then
    begin
      if Value > High(Cardinal) then
        raise Exception.Create(
          'Localization ID exceeds uint32'
        );

      FindID(
        FileName,
        Cardinal(Value)
      );
    end
    else if Mode = '--dump-table' then
    begin
      DumpTable(
        FileName,
        Int64(Value)
      );
    end
    else
    begin
      Usage;
      Halt(1);
    end;

  except
    on E: Exception do
    begin
      WriteLn(
        StdErr,
        'ERROR: ',
        E.Message
      );

      Halt(2);
    end;
  end;
end.
