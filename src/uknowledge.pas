unit uKnowledge;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes;

type
  TKnowledgeItem = record
    ID: Cardinal;
    Value: Cardinal;
  end;

  TKnowledgeItems = array of TKnowledgeItem;

procedure LoadKnowledgeFile(
  const FileName: string;
  out Items: TKnowledgeItems
);

function FindKnowledgeValue(
  const Items: TKnowledgeItems;
  ID: Cardinal;
  out Value: Cardinal
): Boolean;

procedure ParseKnowledgeBlob(
  const Data: TBytes;
  out Items: TKnowledgeItems
);

implementation

procedure LoadKnowledgeFile(
  const FileName: string;
  out Items: TKnowledgeItems
);
var
  Lines: TStringList;
  Parts: TStringArray;
  I: Integer;
  IDValue: QWord;
  StateValue: QWord;
begin
  SetLength(Items, 0);

  Lines := TStringList.Create;

  try
    Lines.LoadFromFile(FileName);

    for I := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) = '' then
        Continue;

      Parts :=
        Lines[I].Split(
          [#9, ' '],
          TStringSplitOptions.ExcludeEmpty
        );

      {
        EnshroudedDump --dump-keys format:

        Index  KeyDecimal  KeyHex  Value
      }

      if Length(Parts) < 4 then
        Continue;

      try
        IDValue :=
          StrToQWord(
            Parts[1]
          );

        StateValue :=
          StrToQWord(
            Parts[3]
          );
      except
        Continue;
      end;

      if IDValue > High(Cardinal) then
        Continue;

      if StateValue > High(Cardinal) then
        Continue;

      SetLength(
        Items,
        Length(Items) + 1
      );

      Items[High(Items)].ID :=
        Cardinal(IDValue);

      Items[High(Items)].Value :=
        Cardinal(StateValue);
    end;

  finally
    Lines.Free;
  end;
end;


function FindKnowledgeValue(
  const Items: TKnowledgeItems;
  ID: Cardinal;
  out Value: Cardinal
): Boolean;
var
  I: Integer;
begin
  Value := 0;

  for I := 0 to High(Items) do
  begin
    if Items[I].ID = ID then
    begin
      Value := Items[I].Value;
      Exit(True);
    end;
  end;

  Result := False;
end;

type
  TKnowledgeHeader = packed record
    Version: LongWord;
    Unknown1: LongWord;
    EntryCount: LongWord;
  end;

procedure ParseKnowledgeBlob(
  const Data: TBytes;
  out Items: TKnowledgeItems
);
var
  Header: TKnowledgeHeader;
  ExpectedSize: Int64;
  IDsOffset: Int64;
  ValuesOffset: Int64;
  I: LongWord;
begin
  SetLength(Items, 0);

  if Length(Data) < SizeOf(TKnowledgeHeader) then
    raise Exception.Create(
      'KNOW blob too small'
    );

  Move(
    Data[0],
    Header,
    SizeOf(Header)
  );

  ExpectedSize :=
    SizeOf(TKnowledgeHeader) +
    Int64(Header.EntryCount) * 8;

  if Length(Data) <> ExpectedSize then
    raise Exception.CreateFmt(
      'Unexpected KNOW size: got %d, expected %d',
      [
        Length(Data),
        ExpectedSize
      ]
    );

  SetLength(
    Items,
    Header.EntryCount
  );

  IDsOffset :=
    SizeOf(TKnowledgeHeader);

  ValuesOffset :=
    IDsOffset +
    Int64(Header.EntryCount) * 4;

  for I := 0 to Header.EntryCount - 1 do
  begin
    Move(
      Data[
        IDsOffset +
        Int64(I) * 4
      ],
      Items[I].ID,
      SizeOf(Cardinal)
    );

    Move(
      Data[
        ValuesOffset +
        Int64(I) * 4
      ],
      Items[I].Value,
      SizeOf(Cardinal)
    );
  end;
end;

end.
