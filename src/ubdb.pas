unit uBDB;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBDBHeader = record
    HeaderSize: Cardinal;

    Value08: Cardinal;
    Value0C: Cardinal;
    Value10: Cardinal;

    Section1Offset: Cardinal;
    Section1Count: Cardinal;

    Section2Offset: Cardinal;
    Section2Count: Cardinal;

    Section3Offset: Cardinal;
    Section3Count: Cardinal;

    Section4Offset: Cardinal;
    Section4Count: Cardinal;

    Section5Offset: Cardinal;
    Section5Count: Cardinal;

    Section6Offset: Cardinal;
    Section6Count: Cardinal;

    Section7Offset: Cardinal;
    Section7Count: Cardinal;

    Section8Offset: Cardinal;
  end;

function ParseBDBHeader(
    const Data: TBytes;
    out Header: TBDBHeader
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

  Header.Value08 := ReadUInt32LE(Data, $08);
  Header.Value0C := ReadUInt32LE(Data, $0C);
  Header.Value10 := ReadUInt32LE(Data, $10);

  Header.Section1Offset := ReadUInt32LE(Data, $1C);
  Header.Section1Count  := ReadUInt32LE(Data, $20);

  Header.Section2Offset := ReadUInt32LE(Data, $24);
  Header.Section2Count  := ReadUInt32LE(Data, $28);

  Header.Section3Offset := ReadUInt32LE(Data, $3C);
  Header.Section3Count  := ReadUInt32LE(Data, $40);

  Header.Section4Offset := ReadUInt32LE(Data, $44);
  Header.Section4Count  := ReadUInt32LE(Data, $48);

  Header.Section5Offset := ReadUInt32LE(Data, $4C);
  Header.Section5Count  := ReadUInt32LE(Data, $50);

  Header.Section6Offset := ReadUInt32LE(Data, $5C);
  Header.Section6Count  := ReadUInt32LE(Data, $60);

  Header.Section7Offset := ReadUInt32LE(Data, $64);
  Header.Section7Count  := ReadUInt32LE(Data, $68);

  Header.Section8Offset := ReadUInt32LE(Data, $6C);

  Result := True;
end;

end.

