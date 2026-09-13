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

procedure DumpBDBHeaderComparison(
  const BeforeData: TBytes;
  const AfterData: TBytes
);
var
  A, B: TBDBHeader;

  procedure Diff(
    const Name: string;
    VA, VB: Cardinal
  );
begin
    WriteLn(
      Name:16,
      '  ',
      VA:10,
      ' -> ',
      VB:10,
      '  delta=',
      Int64(VB) - Int64(VA)
    );
  end;

begin
  if not ParseBDBHeader(BeforeData, A) then
  begin
    WriteLn('Invalid BEFORE BDB');
    Exit;
  end;

  if not ParseBDBHeader(AfterData, B) then
  begin
    WriteLn('Invalid AFTER BDB');
    Exit;
  end;

  WriteLn('=== BDB HEADER COMPARISON ===');

  Diff('Unknown08', A.Unknown08, B.Unknown08);
  Diff('Unknown0C', A.Unknown0C, B.Unknown0C);
  Diff('Unknown10', A.Unknown10, B.Unknown10);

  Diff('Unknown1C', A.Unknown1C, B.Unknown1C);
  Diff('Unknown20', A.Unknown20, B.Unknown20);
  Diff('Unknown24', A.Unknown24, B.Unknown24);
  Diff('Unknown28', A.Unknown28, B.Unknown28);

  Diff('RootOffset', A.RootOffset, B.RootOffset);
  Diff(
    'StringPoolSize',
    A.StringPoolSize,
    B.StringPoolSize
  );

  Diff('Unknown44', A.Unknown44, B.Unknown44);
  Diff('Unknown48', A.Unknown48, B.Unknown48);
  Diff('Unknown4C', A.Unknown4C, B.Unknown4C);
  Diff('Unknown50', A.Unknown50, B.Unknown50);

  Diff('Unknown5C', A.Unknown5C, B.Unknown5C);
  Diff('Unknown60', A.Unknown60, B.Unknown60);
  Diff('Unknown64', A.Unknown64, B.Unknown64);
  Diff('Unknown68', A.Unknown68, B.Unknown68);
  Diff('Unknown6C', A.Unknown6C, B.Unknown6C);

  WriteLn(
    'Total size       ',
    Length(BeforeData):10,
    ' -> ',
    Length(AfterData):10,
    '  delta=',
    Length(AfterData) - Length(BeforeData)
  );
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
{  DumpByteDifferences(
                      getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                      getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin'),
                      300
                      );}
   DumpBDBHeaderComparison(
             getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
             getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin')
             );

end.

