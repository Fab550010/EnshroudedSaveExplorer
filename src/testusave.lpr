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

  procedure FindAlignedUInt32Occurrences(
  const Data: TBytes;
  Value: Cardinal;
  MaxOffset: Cardinal
);
var
  Pos: Cardinal;
  V: Cardinal;
begin
  WriteLn(
    '=== ALIGNED OCCURRENCES OF ',
    Value,
    ' ==='
  );

  Pos := 0;

  while
    (Pos + 3 < Cardinal(Length(Data))) and
    (Pos < MaxOffset)
  do
  begin
    V := ReadUInt32LE(Data, Pos);

    if V = Value then
      WriteLn(
        '$',
        IntToHex(Pos, 8)
      );

    Inc(Pos, 4);
  end;
end;

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

procedure DumpDifferenceRanges(
  const BeforeData: TBytes;
  const AfterData: TBytes
);
var
  I: Integer;
  StartDiff: Integer;
  InDiff: Boolean;
begin
  if Length(BeforeData) <> Length(AfterData) then
  begin
    WriteLn(
      'Size mismatch: ',
      Length(BeforeData),
      ' -> ',
      Length(AfterData)
    );
    Exit;
  end;

  InDiff := False;
  StartDiff := -1;

  WriteLn('=== DIFFERENCE RANGES ===');

  for I := 0 to High(BeforeData) do
  begin
    if BeforeData[I] <> AfterData[I] then
    begin
      if not InDiff then
      begin
        StartDiff := I;
        InDiff := True;
      end;
    end
    else
    begin
      if InDiff then
      begin
        WriteLn(
          '$',
          IntToHex(StartDiff, 8),
          ' - $',
          IntToHex(I - 1, 8),
          '  size=',
          I - StartDiff
        );

        InDiff := False;
      end;
    end;
  end;

  if InDiff then
  begin
    WriteLn(
      '$',
      IntToHex(StartDiff, 8),
      ' - $',
      IntToHex(High(BeforeData), 8),
      '  size=',
      Length(BeforeData) - StartDiff
    );
  end;
end;

procedure DumpUInt32Comparison(
  const BeforeData: TBytes;
  const AfterData: TBytes;
  StartOffset: Cardinal;
  Count: Cardinal
);
var
  I: Cardinal;
  Offset: Cardinal;
  A, B: Cardinal;
begin
  WriteLn(
    '=== UINT32 COMPARISON FROM $',
    IntToHex(StartOffset, 8),
    ' ==='
  );

  for I := 0 to Count - 1 do
  begin
    Offset :=
      StartOffset + I * 4;

    if Offset + 3 >= Cardinal(Length(BeforeData)) then
      Exit;

    if Offset + 3 >= Cardinal(Length(AfterData)) then
      Exit;

    Move(
      BeforeData[Offset],
      A,
      SizeOf(A)
    );

    Move(
      AfterData[Offset],
      B,
      SizeOf(B)
    );

    Write(
      '$',
      IntToHex(Offset, 8),
      '  ',
      IntToHex(A, 8),
      ' -> ',
      IntToHex(B, 8)
    );

    if A <> B then
      Write(
        '  delta=',
        Int64(B) - Int64(A)
      );

    WriteLn;
  end;
end;

procedure FindLastPlayTimePattern(
  const Data: TBytes
);
var
  Pos: Cardinal;
  A, B, C, D, E, F, G: Cardinal;
begin
  WriteLn('=== LASTPLAYTIME PATTERN ===');

  Pos := 0;

  while Pos + 31 < Cardinal(Length(Data)) do
  begin
    A := ReadUInt32LE(Data, Pos);
    B := ReadUInt32LE(Data, Pos + 4);
    C := ReadUInt32LE(Data, Pos + 8);
    D := ReadUInt32LE(Data, Pos + 12);
    E := ReadUInt32LE(Data, Pos + 20);
    F := ReadUInt32LE(Data, Pos + 24);
    G := ReadUInt32LE(Data, Pos + 28);

    if
      (A = 12) and
      (B = 1) and
      (C = 1) and
      (D = 13) and
      (E = 0) and
      (F = 1) and
      (G = 14)
    then
    begin
      WriteLn(
        'Pattern at $',
        IntToHex(Pos, 8),
        ' timestamp=$',
        IntToHex(
          ReadUInt32LE(Data, Pos + 16),
          8
        ),
        ' ',
        ReadUInt32LE(Data, Pos + 16)
      );
    end;

    Inc(Pos, 4);
  end;
end;

var blob, virginblob : TBytes;
  header : TBDBHeader;
  timestamp : cardinal;

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

   DumpDifferenceRanges(
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin')
                        );

   DumpUInt32Comparison(
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin'),
                        $000111E0,
                        20
                        );

   DumpUInt32Comparison(
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin'),
                        $00014210,
                        12
                        );

   DumpUInt32Comparison(
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin'),
                        $00015440,
                        64
                        );

   DumpUInt32Comparison(
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after\characters-8', 'Virgin'),
                        getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin'),
                        $0004E4C0,
                        24
                        );

   virginblob := getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin');
   FindRecentAlignedUnixTimestamps(
                                   virginblob
                               );


   WriteLn('Fabrice');

   blob := getblobfromname(ResolveCharactersSave(IndexFileName), 'Fabrice');
   if not ParseBDBHeader(blob, header)
      then WriteLn('Erreur au parse du header');
   WriteLn(
           'Candidate lastPlayTime: ',
           ReadUInt32LE(
                        blob,
                        Header.RootOffset - $3C
                        )
           );
   FindRecentAlignedUnixTimestamps(
                               Blob
                               );

   WriteLn('=== Virgin lastPlayTime context ===');
DumpBytesAround(
  VirginBlob,
  $0004E4D8,
  64,
  64
);
DumpUInt32Block(
  VirginBlob,
  $0004E498,
  32
);

WriteLn('=== Fabrice lastPlayTime context ===');
DumpBytesAround(
  Blob,
  $00059A18,
  64,
  64
);



DumpUInt32Block(
  Blob,
  $000599D8,
  32
);

writeln('alignement');
FindAlignedUInt32Occurrences(
  virginBlob,
  29,
  Header.RootOffset
);
FindAlignedUInt32Occurrences(
  Blob,
  31,
  Header.RootOffset
);

writeln('pattern');
FindLastPlayTimePattern(virginblob);
FindLastPlayTimePattern(blob);

writeln('validation lastplaytime');
   if ExtractBDBLastPlayTime(Blob, Timestamp)
   then
     WriteLn('Fabrice', ' lastPlayTime = ', Timestamp, ' ($', IntToHex(Timestamp, 8),')')
   else
     WriteLn('Fabrice', ' : lastPlayTime not found');
   if ExtractBDBLastPlayTime(virginBlob, Timestamp)
   then
     WriteLn('Virgin', ' lastPlayTime = ', Timestamp, ' ($', IntToHex(Timestamp, 8),')')
   else
     WriteLn('Virgin', ' : lastPlayTime not found');
   if ExtractBDBLastPlayTime(getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'Virgin2'), Timestamp)
   then
     WriteLn('Virgin2', ' lastPlayTime = ', Timestamp, ' ($', IntToHex(Timestamp, 8),')')
   else
     WriteLn('Virgin2', ' : lastPlayTime not found');
   if ExtractBDBLastPlayTime(getblobfromname('E:\EnshroudedSaveExplorer\samples\virgin_playtime_after2\characters-9', 'testperso'), Timestamp)
   then
     WriteLn('testperso', ' lastPlayTime = ', Timestamp, ' ($', IntToHex(Timestamp, 8),')')
   else
     WriteLn('testperso', ' : lastPlayTime not found');
end.

