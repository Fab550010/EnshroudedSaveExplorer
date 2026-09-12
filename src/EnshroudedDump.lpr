program EnshroudedDump;

{$mode objfpc}{$H+}

uses
  SysUtils,
  Classes,
  Generics.Collections,
  uZstd, uKnowledgeBlob;

type

  TKnowHeader = packed record
    Version: LongWord;
    Unknown1: LongWord;
    EntryCount: LongWord;
  end;

  TKnowDictionary = specialize TDictionary<LongWord, LongWord>;

function ParseHexLongWord(const S: string): LongWord;
var
  Temp: QWord;
begin
  if not TryStrToQWord('$' + S, Temp) then
    raise Exception.CreateFmt('Invalid hex value: %s', [S]);

  if Temp > High(LongWord) then
    raise Exception.CreateFmt('Value out of range: %s', [S]);

  Result := LongWord(Temp);
end;


procedure ValidateKnow(
  const Data: TBytes;
  out Header: TKnowHeader
);
var
  ExpectedSize: Int64;
begin
  if Length(Data) < SizeOf(TKnowHeader) then
    raise Exception.Create('KNOW blob too small');

  Move(
    Data[0],
    Header,
    SizeOf(Header)
  );

  ExpectedSize :=
    SizeOf(TKnowHeader) +
    Int64(Header.EntryCount) * 8;

  if Length(Data) <> ExpectedSize then
    raise Exception.CreateFmt(
      'Unexpected KNOW size: got %d, expected %d',
      [
        Length(Data),
        ExpectedSize
      ]
    );
end;

function ParseKnow(
  const Data: TBytes
): TKnowDictionary;
var
  Header: TKnowHeader;
  IDsOffset: Int64;
  ValuesOffset: Int64;
  I: LongWord;
  IDValue: LongWord;
  StateValue: LongWord;
begin
  Result := TKnowDictionary.Create;

  ValidateKnow(Data, Header);

  IDsOffset := SizeOf(TKnowHeader);

  ValuesOffset :=
    IDsOffset +
    Int64(Header.EntryCount) * SizeOf(LongWord);

  for I := 0 to Header.EntryCount - 1 do
  begin
    Move(
      Data[IDsOffset + Int64(I) * 4],
      IDValue,
      SizeOf(IDValue)
    );

    Move(
      Data[ValuesOffset + Int64(I) * 4],
      StateValue,
      SizeOf(StateValue)
    );

    Result.AddOrSetValue(
      IDValue,
      StateValue
    );
  end;
end;

procedure DumpKnow(
  const FileName: string;
  OwnerID: LongWord;
  MaxEntries: Integer
);
var
  Data: TBytes;
  Header: TKnowHeader;
  IDsOffset: Int64;
  ValuesOffset: Int64;
  I, Count: Integer;
  IDValue, StateValue: LongWord;
begin
  Data := ExtractKnowledgeBlob(
    FileName,
    OwnerID
  );

  ValidateKnow(Data, Header);

  WriteLn('File       : ', FileName);
  WriteLn('Owner      : ', IntToHex(OwnerID, 8));
  WriteLn('Version    : ', Header.Version);
  WriteLn('Unknown1   : ', Header.Unknown1);
  WriteLn('EntryCount : ', Header.EntryCount);
  WriteLn;

  IDsOffset := SizeOf(TKnowHeader);

  ValuesOffset :=
    IDsOffset +
    Int64(Header.EntryCount) * 4;

  Count := Header.EntryCount;

  if (MaxEntries > 0) and (Count > MaxEntries) then
    Count := MaxEntries;

  WriteLn('Index        Key     Value');
  WriteLn('-----  --------  --------');

  for I := 0 to Count - 1 do
  begin
    Move(
      Data[IDsOffset + Int64(I) * 4],
      IDValue,
      SizeOf(IDValue)
    );

    Move(
      Data[ValuesOffset + Int64(I) * 4],
      StateValue,
      SizeOf(StateValue)
    );

    WriteLn(
      I:5,
      '  ',
      IntToHex(IDValue, 8),
      '  ',
      IntToHex(StateValue, 8)
    );
  end;

end;

procedure ExportKnowKeys(
  const FileName: string;
  OwnerID: LongWord;
  const OutputFile: string
);
var
  Data: TBytes;
  Header: TKnowHeader;
  IDsOffset: Int64;
  ValuesOffset: Int64;
  I: LongWord;
  EncodedKey: LongWord;
  StateValue: LongWord;
  F: TextFile;
begin
  Data := ExtractKnowledgeBlob(
    FileName,
    OwnerID
  );

  ValidateKnow(Data, Header);

  IDsOffset := SizeOf(TKnowHeader);

  ValuesOffset :=
    IDsOffset +
    Int64(Header.EntryCount) * 4;

  AssignFile(F, OutputFile);
  Rewrite(F);

  try
    WriteLn(
      F,
      'Index',
      #9,
      'KeyDecimal',
      #9,
      'KeyHex',
      #9,
      'Value'
    );

    for I := 0 to Header.EntryCount - 1 do
    begin
      Move(
        Data[IDsOffset + Int64(I) * 4],
        EncodedKey,
        SizeOf(EncodedKey)
      );

      Move(
        Data[ValuesOffset + Int64(I) * 4],
        StateValue,
        SizeOf(StateValue)
      );

      WriteLn(
        F,
        I,
        #9,
        EncodedKey,
        #9,
        IntToHex(EncodedKey, 8),
        #9,
        StateValue
      );
    end;

  finally
    CloseFile(F);
  end;

  WriteLn(
    'Exported ',
    Header.EntryCount,
    ' KNOW entries to ',
    OutputFile
  );
end;

procedure DiffKnow(
  const File1: string;
  const File2: string;
  OwnerID: LongWord
);
var
  Blob1, Blob2: TBytes;
  Know1, Know2: TKnowDictionary;

  ID: LongWord;
  Value1, Value2: LongWord;

  AddedCount: Integer;
  RemovedCount: Integer;
  ChangedCount: Integer;
begin
  Blob1 := ExtractKnowledgeBlob(
    File1,
    OwnerID
  );

  Blob2 := ExtractKnowledgeBlob(
    File2,
    OwnerID
  );

  Know1 := ParseKnow(Blob1);
  Know2 := ParseKnow(Blob2);

  try
    WriteLn('File 1 : ', File1);
    WriteLn('File 2 : ', File2);
    WriteLn('Owner  : ', IntToHex(OwnerID, 8));
    WriteLn;

    WriteLn(
      'Entries: ',
      Know1.Count,
      ' -> ',
      Know2.Count
    );

    WriteLn;

    AddedCount := 0;
    RemovedCount := 0;
    ChangedCount := 0;

    WriteLn('ADDED');
    WriteLn('-----');

    for ID in Know2.Keys do
    begin
      if not Know1.ContainsKey(ID) then
      begin
        Know2.TryGetValue(
          ID,
          Value2
        );

        WriteLn(
          IntToHex(ID, 8),
          ' = ',
          Value2,
          ' ($',
          IntToHex(Value2, 8),
          ')'
        );

        Inc(AddedCount);
      end;
    end;

    if AddedCount = 0 then
      WriteLn('(none)');

    WriteLn;
    WriteLn('REMOVED');
    WriteLn('-------');

    for ID in Know1.Keys do
    begin
      if not Know2.ContainsKey(ID) then
      begin
        Know1.TryGetValue(
          ID,
          Value1
        );

        WriteLn(
          IntToHex(ID, 8),
          ' = ',
          Value1,
          ' ($',
          IntToHex(Value1, 8),
          ')'
        );

        Inc(RemovedCount);
      end;
    end;

    if RemovedCount = 0 then
      WriteLn('(none)');

    WriteLn;
    WriteLn('CHANGED');
    WriteLn('-------');

    for ID in Know1.Keys do
    begin
      if Know2.ContainsKey(ID) then
      begin
        Know1.TryGetValue(
          ID,
          Value1
        );

        Know2.TryGetValue(
          ID,
          Value2
        );

        if Value1 <> Value2 then
        begin
          WriteLn(
            IntToHex(ID, 8),
            ' : ',
            Value1,
            ' -> ',
            Value2,
            '  ($',
            IntToHex(Value1, 8),
            ' -> $',
            IntToHex(Value2, 8),
            ')'
          );

          Inc(ChangedCount);
        end;
      end;
    end;

    if ChangedCount = 0 then
      WriteLn('(none)');

    WriteLn;
    WriteLn('SUMMARY');
    WriteLn('-------');
    WriteLn('Added   : ', AddedCount);
    WriteLn('Removed : ', RemovedCount);
    WriteLn('Changed : ', ChangedCount);

  finally
    Know1.Free;
    Know2.Free;
  end;
end;

procedure ShowUsage;
begin
  WriteLn('Usage:');
  WriteLn;

  WriteLn(
    '  EnshroudedDump --dump <characters-file> <OwnerID> [max entries]'
  );

  WriteLn(
    '  EnshroudedDump --dump-keys <characters-file> <OwnerID> <output.txt>'
  );

  WriteLn(
    '  EnshroudedDump --diff <file1> <file2> <OwnerID>'
  );

  WriteLn;
  WriteLn('Examples:');

  WriteLn(
    '  EnshroudedDump --dump ',
    '.\samples\characters-3 ',
    '1B551646 30'
  );

  WriteLn(
    '  EnshroudedDump --dump-keys ',
    '.\samples\characters-3 ',
    '1B551646 ',
    'know_keys.txt'
  );

  WriteLn(
    '  EnshroudedDump --diff ',
    '.\samples\before\characters-5 ',
    '.\samples\after\characters-6 ',
    '2AF68BE4'
  );
end;

var
  OwnerID: LongWord;
  MaxEntries: Integer;

begin
  try

    { --dump }

    if
      ((ParamCount = 3) or (ParamCount = 4)) and
      (ParamStr(1) = '--dump')
    then
    begin
      OwnerID :=
        ParseHexLongWord(
          ParamStr(3)
        );

      MaxEntries := 30;

      if ParamCount = 4 then
      begin
        if not TryStrToInt(
          ParamStr(4),
          MaxEntries
        ) then
          raise Exception.Create(
            'Invalid max entries value'
          );
      end;

      DumpKnow(
        ParamStr(2),
        OwnerID,
        MaxEntries
      );

      Exit;
    end;

    { --dump-keys }

    if
      (ParamCount = 4) and
      (ParamStr(1) = '--dump-keys')
    then
    begin
      OwnerID :=
        ParseHexLongWord(
          ParamStr(3)
        );

      ExportKnowKeys(
        ParamStr(2),
        OwnerID,
        ParamStr(4)
      );

      Exit;
    end;

    { --diff }

    if
      (ParamCount = 4) and
      (ParamStr(1) = '--diff')
    then
    begin
      OwnerID :=
        ParseHexLongWord(
          ParamStr(4)
        );

      DiffKnow(
        ParamStr(2),
        ParamStr(3),
        OwnerID
      );

      Exit;
    end;

    ShowUsage;
    Halt(1);

  except
    on E: Exception do
    begin
      WriteLn(
        'ERROR: ',
        E.Message
      );

      Halt(2);
    end;
  end;
end.
