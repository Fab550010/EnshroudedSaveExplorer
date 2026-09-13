unit uCharacterData;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes;

function ExtractCharacterName(
  const Data: TBytes
): string;

function FindTextOffset(
  const Data: TBytes;
  const Text: string
): Integer;

procedure DumpCharacterFieldNames(
  const Data: TBytes
);

procedure DumpBDBHeader(
  const Data: TBytes
);

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

function FindTextOffset(
  const Data: TBytes;
  const Text: string
): Integer;
var
  I, J: Integer;
  Match: Boolean;
begin
  Result := -1;

  if (Text = '') or
     (Length(Data) < Length(Text)) then
    Exit;

  for I := 0 to Length(Data) - Length(Text) do
  begin
    Match := True;

    for J := 1 to Length(Text) do
      if Data[I + J - 1] <> Ord(Text[J]) then
      begin
        Match := False;
        Break;
      end;

    if Match then
      Exit(I);
  end;
end;

procedure DumpCharacterFieldNames(
  const Data: TBytes
);
var
  I, J: Integer;
  L: Word;
  S: string;
  Printable: Boolean;
  Seen: TStringList;
begin
  Seen := TStringList.Create;

  try
    Seen.Sorted := True;
    Seen.Duplicates := dupIgnore;

    I := 0;

    while I + 2 < Length(Data) do
    begin
      L :=
        Word(Data[I]) or
        (Word(Data[I + 1]) shl 8);

      if
        (L >= 2) and
        (L <= 64) and
        (I + 2 + L <= Length(Data))
      then
      begin
        Printable := True;

        for J := 0 to L - 1 do
          if
            (Data[I + 2 + J] < 32) or
            (Data[I + 2 + J] > 126)
          then
          begin
            Printable := False;
            Break;
          end;

        if Printable then
        begin
          SetLength(S, L);

          for J := 0 to L - 1 do
            S[J + 1] :=
              Chr(
                Data[I + 2 + J]
              );

          Seen.Add(S);
        end;
      end;

      Inc(I);
    end;

    for I := 0 to Seen.Count - 1 do
      WriteLn(Seen[I]);

  finally
    Seen.Free;
  end;
end;


procedure DumpBDBHeader(
  const Data: TBytes
);
var
  Offset: Integer;
  Value: Cardinal;
begin
  if Length(Data) < $70 then
    raise Exception.Create(
      'CHAR blob too small for BDB header'
    );

  WriteLn('=== BDB1 HEADER ===');

  Offset := 4;

  while Offset < $70 do
  begin
    Move(
      Data[Offset],
      Value,
      SizeOf(Value)
    );

    WriteLn(
      '$',
      IntToHex(Offset, 2),
      ' : $',
      IntToHex(Value, 8),
      '  (',
      Value,
      ')'
    );

    Inc(
      Offset,
      4
    );
  end;
end;
end.
