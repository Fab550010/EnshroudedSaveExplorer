program testusave;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, uSaveIndex, uSteamDiscovery, uKnowledgeBlob, uCharacterData, uBDB, Math, SysUtils
  { you can add units after this };

var
  IndexFileName: string;

procedure DumpByteDifferences(
  const BeforeData: TBytes;
  const AfterData: TBytes;
  MaxDiffs: Integer
);
var
  I: Integer;
  DiffCount: Integer;
begin
  DiffCount := 0;

  WriteLn('=== BYTE DIFFERENCES ===');

  if Length(BeforeData) <> Length(AfterData) then
    WriteLn(
      'Size changed: ',
      Length(BeforeData),
      ' -> ',
      Length(AfterData)
    );

  for I := 0 to Min(Length(BeforeData), Length(AfterData)) - 1 do
  begin
    if BeforeData[I] <> AfterData[I] then
    begin
      WriteLn(
        '$',
        IntToHex(I, 8),
        ': ',
        IntToHex(BeforeData[I], 2),
        ' -> ',
        IntToHex(AfterData[I], 2)
      );

      Inc(DiffCount);

      if DiffCount >= MaxDiffs then
        Break;
    end;
  end;

  WriteLn('Differences shown: ', DiffCount);
end;

begin

  if FindEnshroudedCharactersIndex(IndexFileName) then
    WriteLn(
      'Found: ',
      IndexFileName
    )
  else
    WriteLn(
      'No Enshrouded characters-index found'
    );

  WriteLn(
  ResolveCharactersSave(
    IndexFileName
  )
);

  DumpBlobInventory(ResolveCharactersSave(IndexFileName));

  DumpCharacterNames(ResolveCharactersSave(IndexFileName));

  WriteLn('Diff');
  DumpByteDifferences(
                      getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_before\characters-7', 'Virgin'),
                      getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                      300
                      );


end.

