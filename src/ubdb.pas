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

    Unknown3C: Cardinal;
    Unknown40: Cardinal;
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

  Header.Unknown3C := ReadUInt32LE(Data, $3C);
  Header.Unknown40 := ReadUInt32LE(Data, $40);
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

