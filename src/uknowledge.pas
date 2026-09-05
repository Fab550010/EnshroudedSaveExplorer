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

end.
