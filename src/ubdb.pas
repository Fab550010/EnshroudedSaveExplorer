unit uBDB;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBDBHeader = record
    HeaderSize: Cardinal;

    Unknown08: Cardinal;
    Unknown0C: Cardinal;
    Unknown10: Cardinal;
    Unknown14: Cardinal;
    Unknown18: Cardinal;

    Unknown1C: Cardinal;
    Unknown20: Cardinal;
    Unknown24: Cardinal;
    Unknown28: Cardinal;

    Unknown2C: Cardinal;
    Unknown30: Cardinal;
    Unknown34: Cardinal;
    Unknown38: Cardinal;

    RootOffset: Cardinal;
    StringPoolSize: Cardinal;

    Unknown44: Cardinal;
    Unknown48: Cardinal;
    Unknown4C: Cardinal;
    Unknown50: Cardinal;

    Unknown54: Cardinal;
    Unknown58: Cardinal;

    Unknown5C: Cardinal;
    Unknown60: Cardinal;
    Unknown64: Cardinal;
    Unknown68: Cardinal;
    Unknown6C: Cardinal;
  end;


type
  TBDBStringArray = array of string;


function ParseBDBHeader(
    const Data: TBytes;
    out Header: TBDBHeader
  ): Boolean;

{procedure DumpBDBSections(
  const Data: TBytes;
  const Header: TBDBHeader
);}

procedure DumpUInt32Pairs(
  const Data: TBytes;
  Offset: Cardinal;
  Count: Cardinal;
  MaxCount: Cardinal
);

procedure FindUInt32Occurrences(
  const Data: TBytes;
  Value: Cardinal
);

procedure DumpUInt32Block(
  const Data: TBytes;
  Offset: Cardinal;
  Count: Cardinal
);

procedure DumpStringPool(
  const Data: TBytes;
  StartOffset: Cardinal;
  MaxBytes: Cardinal
);

function ParseBDBStringPool(
  const Data: TBytes;
  StartOffset: Cardinal;
  out Strings: TBDBStringArray;
  out EndOffset: Cardinal
): Boolean;

procedure DumpUInt32Values(
  const Data: TBytes;
  Offset: Cardinal;
  Count: Cardinal
);

procedure DumpUInt32RegionStats(
  const Data: TBytes;
  StartOffset: Cardinal;
  EndOffset: Cardinal
);

function ValidateBDBStringPool(
  const Data: TBytes;
  const Header: TBDBHeader
): Boolean;

function BDBDataAfterStringPoolOffset(
  const Header: TBDBHeader
): Cardinal;

function ReadUInt32LE(
  const Data: TBytes;
  Offset: Integer
): Cardinal;

procedure FindPlausibleUnixTimestamps(
  const Data: TBytes;
  MinTimestamp: Cardinal;
  MaxTimestamp: Cardinal
);

procedure FindRecentAlignedUnixTimestamps(
  const Data: TBytes
);

function ExtractBDBLastPlayTime(
  const Data: TBytes;
  out Timestamp: Cardinal
): Boolean;

implementation

function ReadUInt32LE(
  const Data: TBytes;
  Offset: Integer
): Cardinal;
begin
  if Offset + 3 >= Length(Data) then
    raise Exception.Create('Unexpected end of BDB data');

  Move(
    Data[Offset],
    Result,
    SizeOf(Result)
  );
end;

function ExtractBDBLastPlayTime(
  const Data: TBytes;
  out Timestamp: Cardinal
): Boolean;
var
  Pos: Cardinal;
begin
  Result := False;
  Timestamp := 0;

  Pos := 0;

  while Pos + 31 < Cardinal(Length(Data)) do
  begin
    if
      (ReadUInt32LE(Data, Pos)      = 12) and
      (ReadUInt32LE(Data, Pos + 4)  = 1) and
      (ReadUInt32LE(Data, Pos + 8)  = 1) and
      (ReadUInt32LE(Data, Pos + 12) = 13) and
      (ReadUInt32LE(Data, Pos + 20) = 0) and
      (ReadUInt32LE(Data, Pos + 24) = 1) and
      (ReadUInt32LE(Data, Pos + 28) = 14)
    then
    begin
      Timestamp :=
        ReadUInt32LE(
          Data,
          Pos + 16
        );

      Result := True;
      Exit;
    end;

    Inc(Pos, 4);
  end;
end;

procedure FindRecentAlignedUnixTimestamps(
  const Data: TBytes
);
const
  { Environ août-octobre 2026 }
  MinTimestamp: Cardinal = 1785500000;
  MaxTimestamp: Cardinal = 1792000000;
var
  I: Cardinal;
  V: Cardinal;
  Count: Integer;
begin
  WriteLn('=== RECENT ALIGNED UNIX TIMESTAMPS ===');

  Count := 0;
  I := 0;

  while I + 3 < Cardinal(Length(Data)) do
  begin
    V := ReadUInt32LE(Data, I);

    if
      (V >= MinTimestamp) and
      (V <= MaxTimestamp)
    then
    begin
      WriteLn(
        '$',
        IntToHex(I, 8),
        '  $',
        IntToHex(V, 8),
        '  ',
        V
      );

      Inc(Count);

      if Count >= 100 then
      begin
        WriteLn('Stopped after 100 matches');
        Exit;
      end;
    end;

    Inc(I, 4);
  end;

  WriteLn('Matches: ', Count);
end;

procedure FindPlausibleUnixTimestamps(
  const Data: TBytes;
  MinTimestamp: Cardinal;
  MaxTimestamp: Cardinal
);
var
  I: Integer;
  V: Cardinal;
begin
  WriteLn('=== PLAUSIBLE UNIX TIMESTAMPS ===');

  for I := 0 to Length(Data) - 4 do
  begin
    Move(
      Data[I],
      V,
      SizeOf(V)
    );

    if
      (V >= MinTimestamp) and
      (V <= MaxTimestamp)
    then
      WriteLn(
        '$',
        IntToHex(I, 8),
        '  $',
        IntToHex(V, 8),
        '  ',
        V
      );
  end;
end;

procedure DumpUInt32Pairs(
  const Data: TBytes;
  Offset: Cardinal;
  Count: Cardinal;
  MaxCount: Cardinal
);
var
  I, N: Cardinal;
  A, B: Cardinal;
begin
  N := Count;

  if N > MaxCount then
    N := MaxCount;

  for I := 0 to N - 1 do
  begin
    A := ReadUInt32LE(
      Data,
      Offset + I * 8
    );

    B := ReadUInt32LE(
      Data,
      Offset + I * 8 + 4
    );

    WriteLn(
      I:4,
      ': ',
      IntToHex(A, 8),
      '  ',
      IntToHex(B, 8),
      '  (',
      A,
      ', ',
      B,
      ')'
    );
  end;
end;

procedure DumpStringPool(
  const Data: TBytes;
  StartOffset: Cardinal;
  MaxBytes: Cardinal
);
var
  Pos: Cardinal;
  EndPos: Cardinal;
  L: Word;
  I: Cardinal;
  S: string;
  Printable: Boolean;
begin
  Pos := StartOffset;

  EndPos := StartOffset + MaxBytes;
  if EndPos > Cardinal(Length(Data)) then
    EndPos := Length(Data);

  while Pos + 2 <= EndPos do
  begin
    L :=
      Word(Data[Pos]) or
      (Word(Data[Pos + 1]) shl 8);

    if L = 0 then
    begin
      WriteLn(
        '$',
        IntToHex(Pos, 8),
        '  len=0'
      );

      Inc(Pos, 2);
      Continue;
    end;

    if Pos + 2 + L > EndPos then
    begin
      WriteLn(
        '$',
        IntToHex(Pos, 8),
        '  invalid length=',
        L
      );
      Break;
    end;

    Printable := True;

    for I := 0 to L - 1 do
      if
        (Data[Pos + 2 + I] < 32) or
        (Data[Pos + 2 + I] > 126)
      then
      begin
        Printable := False;
        Break;
      end;

    if not Printable then
    begin
      WriteLn(
        '$',
        IntToHex(Pos, 8),
        '  non-string, length candidate=',
        L
      );
      Break;
    end;

    SetLength(S, L);

    for I := 0 to L - 1 do
      S[I + 1] :=
        Chr(
          Data[Pos + 2 + I]
        );

    WriteLn(
      '$',
      IntToHex(Pos, 8),
      '  len=',
      L:2,
      '  "',
      S,
      '"'
    );

    Inc(
      Pos,
      2 + L
    );

    { les chaînes impaires sont alignées sur 2 octets }
    if Odd(L) then
    begin
      WriteLn(
        '           padding=$',
        IntToHex(Data[Pos], 2)
      );

      Inc(Pos);
    end;
  end;

  WriteLn(
    'String parsing stopped at $',
    IntToHex(Pos, 8)
  );
end;

procedure DumpUInt32Values(
  const Data: TBytes;
  Offset: Cardinal;
  Count: Cardinal
);
var
  I: Cardinal;
  V: Cardinal;
begin
  for I := 0 to Count - 1 do
  begin
    if Offset + I * 4 + 3 >= Cardinal(Length(Data)) then
      Exit;

    V :=
      ReadUInt32LE(
        Data,
        Offset + I * 4
      );

    WriteLn(
      I:4,
      '  $',
      IntToHex(
        Offset + I * 4,
        8
      ),
      '  ',
      V,
      '  ($',
      IntToHex(V, 8),
      ')'
    );
  end;
end;

function ParseBDBStringPool(
  const Data: TBytes;
  StartOffset: Cardinal;
  out Strings: TBDBStringArray;
  out EndOffset: Cardinal
): Boolean;
var
  Pos: Cardinal;
  L: Word;
  I: Cardinal;
  S: string;
begin
  Result := False;

  SetLength(Strings, 0);
  EndOffset := StartOffset;
  Pos := StartOffset;

  while Pos + 2 <= Cardinal(Length(Data)) do
  begin
    L :=
      Word(Data[Pos]) or
      (Word(Data[Pos + 1]) shl 8);

    Inc(Pos, 2);

    { chaîne vide = fin du pool }
    if L = 0 then
    begin
      EndOffset := Pos;
      Result := True;
      Exit;
    end;

    if Pos + L > Cardinal(Length(Data)) then
      Exit;

    SetLength(S, L);

    for I := 0 to L - 1 do
    begin
      if
        (Data[Pos + I] < 32) or
        (Data[Pos + I] > 126)
      then
        Exit;

      S[I + 1] :=
        Chr(Data[Pos + I]);
    end;

    SetLength(
      Strings,
      Length(Strings) + 1
    );

    Strings[High(Strings)] := S;

    Inc(Pos, L);

    if Odd(L) then
    begin
      if Pos >= Cardinal(Length(Data)) then
        Exit;

      Inc(Pos);
    end;
  end;
end;

procedure DumpUInt32Block(
  const Data: TBytes;
  Offset: Cardinal;
  Count: Cardinal
);
var
  I: Cardinal;
  V: Cardinal;
begin
  for I := 0 to Count - 1 do
  begin
    V :=
      ReadUInt32LE(
        Data,
        Offset + I * 4
      );

    WriteLn(
      I:2,
      ' +$',
      IntToHex(I * 4, 2),
      ': $',
      IntToHex(V, 8),
      ' (',
      V,
      ')'
    );
  end;
end;

procedure FindUInt32Occurrences(
  const Data: TBytes;
  Value: Cardinal
);
var
  I: Integer;
  V: Cardinal;
begin
  WriteLn(
    'Searching uint32 $',
    IntToHex(Value, 8),
    ' (',
    Value,
    ')'
  );

  for I := 0 to Length(Data) - 4 do
  begin
    Move(
      Data[I],
      V,
      SizeOf(V)
    );

    if V = Value then
      WriteLn(
        '  offset=$',
        IntToHex(I, 8)
      );
  end;
end;

procedure DumpUInt32RegionStats(
  const Data: TBytes;
  StartOffset: Cardinal;
  EndOffset: Cardinal
);
var
  Pos: Cardinal;
  Count: Cardinal;
  MinValue: Cardinal;
  MaxValue: Cardinal;
  V: Cardinal;
  Previous: Cardinal;
  ConsecutiveLinks: Cardinal;
  UniqueValues: TStringList;
begin
  if EndOffset <= StartOffset then
  begin
    WriteLn('Invalid uint32 region');
    Exit;
  end;

  if EndOffset > Cardinal(Length(Data)) then
  begin
    WriteLn('Region exceeds blob size');
    Exit;
  end;

  Count :=
    (EndOffset - StartOffset) div 4;

  if Count = 0 then
  begin
    WriteLn('Empty uint32 region');
    Exit;
  end;

  UniqueValues := TStringList.Create;

  try
    UniqueValues.Sorted := True;
    UniqueValues.Duplicates := dupIgnore;

    MinValue := High(Cardinal);
    MaxValue := 0;
    ConsecutiveLinks := 0;
    Previous := 0;

    for Pos := 0 to Count - 1 do
    begin
      V :=
        ReadUInt32LE(
          Data,
          StartOffset + Pos * 4
        );

      if V < MinValue then
        MinValue := V;

      if V > MaxValue then
        MaxValue := V;

      UniqueValues.Add(
        IntToHex(V, 8)
      );

      if
        (Pos > 0) and
        (V = Previous + 1)
      then
        Inc(ConsecutiveLinks);

      Previous := V;
    end;

    WriteLn('=== UINT32 REGION STATS ===');

    WriteLn(
      'Start: $',
      IntToHex(StartOffset, 8)
    );

    WriteLn(
      'End:   $',
      IntToHex(EndOffset, 8)
    );

    WriteLn(
      'Bytes: ',
      EndOffset - StartOffset
    );

    WriteLn(
      'UInt32 count: ',
      Count
    );

    WriteLn(
      'Min: ',
      MinValue,
      ' ($',
      IntToHex(MinValue, 8),
      ')'
    );

    WriteLn(
      'Max: ',
      MaxValue,
      ' ($',
      IntToHex(MaxValue, 8),
      ')'
    );

    WriteLn(
      'Unique values: ',
      UniqueValues.Count
    );

    WriteLn(
      'Consecutive links: ',
      ConsecutiveLinks
    );

  finally
    UniqueValues.Free;
  end;
end;

function BDBStringPoolOffset(
  const Header: TBDBHeader
): Cardinal;
begin
  Result :=
    Header.RootOffset + $3C;
end;


function BDBDataAfterStringPoolOffset(
  const Header: TBDBHeader
): Cardinal;
begin
  Result :=
    BDBStringPoolOffset(Header) +
    Header.StringPoolSize +
    2;
end;

function ValidateBDBStringPool(
  const Data: TBytes;
  const Header: TBDBHeader
): Boolean;
var
  TerminatorOffset: Cardinal;
begin
  Result := False;

  TerminatorOffset :=
    BDBStringPoolOffset(Header) +
    Header.StringPoolSize;

  if TerminatorOffset + 1 >= Cardinal(Length(Data)) then
    Exit;

  Result :=
    (Data[TerminatorOffset] = 0) and
    (Data[TerminatorOffset + 1] = 0);
end;

function ParseBDBHeader(
  const Data: TBytes;
  out Header: TBDBHeader
): Boolean;
begin
  Result := False;

  if Length(Data) < $70 then
    Exit;

  if
    (Data[0] <> Ord('B')) or
    (Data[1] <> Ord('D')) or
    (Data[2] <> Ord('B')) or
    (Data[3] <> Ord('1'))
  then
    Exit;

  Header.HeaderSize := ReadUInt32LE(Data, $04);

  Header.Unknown08 := ReadUInt32LE(Data, $08);
  Header.Unknown0C := ReadUInt32LE(Data, $0C);
  Header.Unknown10 := ReadUInt32LE(Data, $10);

  Header.Unknown14 := ReadUInt32LE(Data, $14);
  Header.Unknown18 := ReadUInt32LE(Data, $18);

  Header.Unknown1C := ReadUInt32LE(Data, $1C);
  Header.Unknown20 := ReadUInt32LE(Data, $20);
  Header.Unknown24 := ReadUInt32LE(Data, $24);
  Header.Unknown28 := ReadUInt32LE(Data, $28);

  Header.Unknown2C := ReadUInt32LE(Data, $2C);
  Header.Unknown30 := ReadUInt32LE(Data, $30);
  Header.Unknown34 := ReadUInt32LE(Data, $34);
  Header.Unknown38 := ReadUInt32LE(Data, $38);

  Header.RootOffset := ReadUInt32LE(Data, $3C);
  Header.StringPoolSize := ReadUInt32LE(Data, $40);

  Header.Unknown44 := ReadUInt32LE(Data, $44);
  Header.Unknown48 := ReadUInt32LE(Data, $48);
  Header.Unknown4C := ReadUInt32LE(Data, $4C);
  Header.Unknown50 := ReadUInt32LE(Data, $50);

  Header.Unknown54 := ReadUInt32LE(Data, $54);
  Header.Unknown58 := ReadUInt32LE(Data, $58);

  Header.Unknown5C := ReadUInt32LE(Data, $5C);
  Header.Unknown60 := ReadUInt32LE(Data, $60);
  Header.Unknown64 := ReadUInt32LE(Data, $64);
  Header.Unknown68 := ReadUInt32LE(Data, $68);
  Header.Unknown6C := ReadUInt32LE(Data, $6C);

  Result := True;
end;
procedure DumpSection(
  const Name: string;
  Offset: Cardinal;
  Count: Cardinal;
  NextOffset: Cardinal
);
var
  Size: Int64;
  BytesPerItem: Double;
begin
  Size :=
    Int64(NextOffset) -
    Int64(Offset);

  Write(
    Name,
    ': offset=$',
    IntToHex(Offset, 8),
    ' count=',
    Count,
    ' size=',
    Size
  );

  if Count > 0 then
  begin
    BytesPerItem :=
      Size / Count;

    Write(
      ' bytes/item=',
      FormatFloat(
        '0.000',
        BytesPerItem
      )
    );
  end;

  WriteLn;
end;

{procedure DumpBDBSections(
  const Data: TBytes;
  const Header: TBDBHeader
);
begin
  WriteLn('=== BDB1 SECTIONS ===');

  DumpSection(
    'Section1',
    Header.Section1Offset,
    Header.Section1Count,
    Header.Section2Offset
  );

  DumpSection(
    'Section2',
    Header.Section2Offset,
    Header.Section2Count,
    Header.Section3Offset
  );

  DumpSection(
    'Section3',
    Header.Section3Offset,
    Header.Section3Count,
    Header.Section4Offset
  );

  DumpSection(
    'Section4',
    Header.Section4Offset,
    Header.Section4Count,
    Header.Section5Offset
  );

  DumpSection(
    'Section5',
    Header.Section5Offset,
    Header.Section5Count,
    Header.Section6Offset
  );

  DumpSection(
    'Section6',
    Header.Section6Offset,
    Header.Section6Count,
    Header.Section7Offset
  );

  DumpSection(
    'Section7',
    Header.Section7Offset,
    Header.Section7Count,
    Header.Section8Offset
  );

  WriteLn(
    'Section8: offset=$',
    IntToHex(
      Header.Section8Offset,
      8
    ),
    ' remaining=',
    Length(Data) -
      Header.Section8Offset
  );
end;}


end.

