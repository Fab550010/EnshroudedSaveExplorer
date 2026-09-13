unit uCharacterData;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes;

function ExtractCharacterName(
  const Data: TBytes
): string;

implementation

function ReadUInt16LE(
  const Data: TBytes;
  Offset: Integer
): Word;
begin
  if Offset + 1 >= Length(Data) then
    raise Exception.Create(
      'Unexpected end of CHAR data'
    );

  Result :=
    Word(Data[Offset]) or
    (Word(Data[Offset + 1]) shl 8);
end;


function ExtractCharacterName(
  const Data: TBytes
): string;
const
  NameKey: array[0..3] of Byte = (
    Ord('n'),
    Ord('a'),
    Ord('m'),
    Ord('e')
  );
var
  I, J: Integer;
  NameLength: Word;
  NameOffset: Integer;
begin
  Result := '';

  for I := 2 to Length(Data) - 8 do
  begin
    if ReadUInt16LE(Data, I - 2) <> 4 then
      Continue;

    for J := 0 to 3 do
      if Data[I + J] <> NameKey[J] then
        Break;

    if J < 3 then
      Continue;

    NameLength :=
      ReadUInt16LE(
        Data,
        I + 4
      );

    NameOffset :=
      I + 6;

    if
      (NameLength = 0) or
      (NameOffset + NameLength > Length(Data))
    then
      Continue;

    SetLength(
      Result,
      NameLength
    );

    for J := 0 to NameLength - 1 do
      Result[J + 1] :=
        Chr(
          Data[NameOffset + J]
        );

    Exit;
  end;
end;

end.
