unit uKnowledgeBlob;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  uZstd, uCharacterData, uBDB;

type
    TOwnerIDArray = array of Cardinal;

function ListKnowledgeOwners(const FileName: string): TOwnerIDArray;

function ExtractKnowledgeBlob(const FileName: string; OwnerID: Cardinal): TBytes;

procedure DumpBlobInventory(const FileName: string);

function ExtractCharacterBlob(const FileName: string; OwnerID: Cardinal): TBytes;

procedure DumpCharacterNames(const FileName: string);



implementation

type
  TKSCHeader = packed record
    Magic: array[0..3] of AnsiChar;
    BlobCount: LongWord;
    SaveID: array[0..15] of Byte;
  end;

  TKSCBlobEntry = packed record
    OwnerID: LongWord;
    BlobType: array[0..3] of AnsiChar;
    CompressedSize: LongWord;
  end;

  TKSCBlobEntryArray = array of TKSCBlobEntry;

  function IsKSC1(
  const Header: TKSCHeader
): Boolean;
begin
  Result :=
    (Header.Magic[0] = 'K') and
    (Header.Magic[1] = 'S') and
    (Header.Magic[2] = 'C') and
    (Header.Magic[3] = '1');
end;

function IsKnowBlob(
  const T: array of AnsiChar
): Boolean;
begin
  Result :=
    (Ord(T[0]) = $DC) and
    (Ord(T[1]) = $8E) and
    (Ord(T[2]) = $D5) and
    (Ord(T[3]) = $F0);
end;

function IsCharBlob(
  const T: array of AnsiChar
): Boolean;
begin
  Result :=
    (T[0] = 'C') and
    (T[1] = 'H') and
    (T[2] = 'A') and
    (T[3] = 'R');
end;

function ExtractBlob(
  const FileName: string;
  OwnerID: Cardinal;
  BlobKind: Integer
): TBytes;
var
  F: TFileStream;
  Header: TKSCHeader;
  Entries: TKSCBlobEntryArray;
  I: Integer;
  DataOffset: Int64;
  CompressedData: TBytes;
  Matches: Boolean;
begin
  SetLength(Result, 0);

  F :=
    TFileStream.Create(
      FileName,
      fmOpenRead or fmShareDenyNone
    );

  try
    if F.Size < SizeOf(TKSCHeader) then
      raise Exception.Create(
        'File too small'
      );

    F.ReadBuffer(
      Header,
      SizeOf(Header)
    );

    if not IsKSC1(Header) then
      raise Exception.Create(
        'Not a KSC1 file'
      );

    SetLength(
      Entries,
      Header.BlobCount
    );

    for I := 0 to Header.BlobCount - 1 do
      F.ReadBuffer(
        Entries[I],
        SizeOf(TKSCBlobEntry)
      );

    DataOffset :=
      SizeOf(TKSCHeader) +
      Int64(Header.BlobCount) *
      SizeOf(TKSCBlobEntry);

    for I := 0 to Header.BlobCount - 1 do
    begin
      Matches := False;

      if Entries[I].OwnerID = OwnerID then
      begin
        case BlobKind of
          0:
            Matches :=
              IsKnowBlob(
                Entries[I].BlobType
              );

          1:
            Matches :=
              IsCharBlob(
                Entries[I].BlobType
              );
        end;
      end;

      if Matches then
      begin
        SetLength(
          CompressedData,
          Entries[I].CompressedSize
        );

        F.Position := DataOffset;

        if Entries[I].CompressedSize > 0 then
          F.ReadBuffer(
            CompressedData[0],
            Entries[I].CompressedSize
          );

        Result :=
          DecompressZstd(
            CompressedData
          );

        Exit;
      end;

      Inc(
        DataOffset,
        Entries[I].CompressedSize
      );
    end;

    raise Exception.CreateFmt(
      'Blob not found for OwnerID %s',
      [IntToHex(OwnerID, 8)]
    );

  finally
    F.Free;
  end;
end;

function ExtractKnowledgeBlob(
  const FileName: string;
  OwnerID: Cardinal
): TBytes;
begin
  Result :=
    ExtractBlob(
      FileName,
      OwnerID,
      0
    );
end;


function ExtractCharacterBlob(
  const FileName: string;
  OwnerID: Cardinal
): TBytes;
begin
  Result :=
    ExtractBlob(
      FileName,
      OwnerID,
      1
    );
end;

  function ListKnowledgeOwners(
    const FileName: string
  ): TOwnerIDArray;
  var
    F: TFileStream;
    Header: TKSCHeader;
    Entry: TKSCBlobEntry;
    I: Integer;
    J: Integer;
    AlreadyPresent: Boolean;
  begin
    SetLength(Result, 0);

    F := TFileStream.Create(
      FileName,
      fmOpenRead or fmShareDenyNone
    );

    try
      if F.Size < SizeOf(TKSCHeader) then
        raise Exception.Create(
          'File too small'
        );

      F.ReadBuffer(
        Header,
        SizeOf(Header)
      );

      if not IsKSC1(Header) then
        raise Exception.Create(
          'Not a KSC1 file'
        );

      for I := 0 to Header.BlobCount - 1 do
      begin
        F.ReadBuffer(
          Entry,
          SizeOf(Entry)
        );

        if not IsKnowBlob(
          Entry.BlobType
        ) then
          Continue;

        AlreadyPresent := False;

        for J := 0 to High(Result) do
          if Result[J] = Entry.OwnerID then
          begin
            AlreadyPresent := True;
            Break;
          end;

        if AlreadyPresent then
          Continue;

        SetLength(
          Result,
          Length(Result) + 1
        );

        Result[High(Result)] :=
          Entry.OwnerID;
      end;

    finally
      F.Free;
    end;
  end;

  function BytesContainText(
    const Data: TBytes;
    const Text: string
  ): Boolean;
  var
    I, J: Integer;
  begin
    Result := False;

    if (Text = '') or
       (Length(Data) < Length(Text)) then
      Exit;

    for I := 0 to Length(Data) - Length(Text) do
    begin
      Result := True;

      for J := 1 to Length(Text) do
        if Data[I + J - 1] <> Ord(Text[J]) then
        begin
          Result := False;
          Break;
        end;

      if Result then
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

  procedure DumpBytesAround(
    const Data: TBytes;
    Offset: Integer;
    BeforeCount: Integer;
    AfterCount: Integer
  );
  var
    I, FirstPos, LastPos: Integer;
  begin
    FirstPos := Offset - BeforeCount;

    if FirstPos < 0 then
      FirstPos := 0;

    LastPos := Offset + AfterCount;

    if LastPos > High(Data) then
      LastPos := High(Data);

    Write('Offset=$', IntToHex(Offset, 8), ' | ');

    for I := FirstPos to LastPos do
    begin
      if I = Offset then
        Write('[');

      Write(
        IntToHex(Data[I], 2),
        ' '
      );

      if I = Offset - 1 then
        Write('| ');

      if I = Offset + 15 then
        Write(']');
    end;

    WriteLn;
  end;


procedure DumpCharacterNames(
  const FileName: string
);
const
  Names: array[0..3] of string = (
    'testperso',
    'Virgin',
    'Virgin2',
    'Fabrice'
  );
var
  Owners: TOwnerIDArray;
  Blob: TBytes;
  I, J: Integer;
  Offset : Integer;
  Name : string;
  Header: TBDBHeader;
  StringPoolStart, AfterStringPool : Cardinal;
  Strings : TBDBStringArray;

begin
  Owners :=
    ListKnowledgeOwners(
      FileName
    );

  for I := 0 to High(Owners) do
  begin
    Blob :=
      ExtractCharacterBlob(
        FileName,
        Owners[I]
      );

    Write(
      'Owner=$',
      IntToHex(Owners[I], 8)
    );

    for J := Low(Names) to High(Names) do begin
      if BytesContainText(
           Blob,
           Names[J]
         )
      then begin
        WriteLn(
          ' | ',
          Names[J]
        );
        Offset := FindTextOffset(Blob,Names[J]);
        WriteLn('offset: ', Offset);
        DumpBytesAround(Blob, Offset, 16, 32);
        Name := Names[J];
      end;
    end;

    WriteLn;
    WriteLn('Nom extrait proprement : ', ExtractCharacterName(Blob));
    Offset := FindTextOffset(Blob, 'lastPlayTime');
    WriteLn('lastPlayTime offset: ', Offset);
    DumpBytesAround(Blob, Offset, 8, 200);
    WriteLn('Field names :');
    DumpCharacterFieldNames(Blob);
    WriteLn('Dump CHAR');
    DumpBytesAround(Blob, 0, 0, 256);
    WriteLn('Dump BDB Header');
    DumpBDBHeader(Blob);
    if (Name = 'Fabrice' )
    then begin
         WriteLn('Dump Fabrice');
         DumpBytesAround(Blob, $00059D9C, 0, 128);
         DumpBytesAround(Blob, $00059EB8, 0, 128);
         DumpBytesAround(Blob, $0005A350, 0, 128);
         DumpBytesAround(Blob, $000A1BC4, 0, 128);
         DumpBytesAround(Blob, $000A23BC, 0, 128);
         DumpBytesAround(Blob, $000A2854, 0, 128);
         if ParseBDBHeader(Blob, Header)
            then  begin
                  {DumpBDBSections(Blob, Header);}
                   WriteLn('Pairs Dump');
                   DumpUInt32Pairs(Blob, Header.Unknown1C, Header.Unknown20, 30);
                   DumpUInt32Pairs(Blob, Header.Unknown44, Header.Unknown48, 30);
                   DumpUInt32Pairs(Blob, Header.Unknown5C, Header.Unknown60, 30);
                   DumpUInt32Pairs(Blob, Header.Unknown64, Header.Unknown68, 30);
                   WriteLn('Dump occ');
                   FindUInt32Occurrences(Blob, $00059DE0);
                   FindUInt32Occurrences(Blob, $00059DD8);
                   FindUInt32Occurrences(Blob, Header.Unknown08);
{                   WriteLn('Root block:');
                   DumpUInt32Block(Blob, Header.Unknown3C, 16);
                   WriteLn('=== ROOT STRING POOL ===');
                   DumpStringPool(Blob, Header.Unknown3C + $3C, 1024);
                   StringPoolStart := Header.Unknown3C + $3C;
                   if ParseBDBStringPool(Blob, StringPoolStart, Strings, AfterStringPool)
                      then
                          begin
                               WriteLn('String pool ends at $', IntToHex(AfterStringPool, 8));
                               WriteLn('String count: ', Length(Strings));
                          end;
                   DumpUInt32Values(Blob, AfterStringPool, 80);}
            end;
    end else if (Name = 'Virgin')
    then begin
         WriteLn('Dump Virgin');
         DumpBytesAround(Blob, $4E8F4, 0, 128);
         DumpBytesAround(Blob, $4E9E4, 0, 128);
         DumpBytesAround(Blob, $4EA84, 0, 128);
         DumpBytesAround(Blob, $8D710, 0, 128);
         DumpBytesAround(Blob, $8D80C, 0, 128);
         DumpBytesAround(Blob, $8D8AC, 0, 128);
        if ParseBDBHeader(Blob, Header)
            then begin
                 {DumpBDBSections(Blob, Header);}
                 WriteLn('Pairs Dump');
                 DumpUInt32Pairs(Blob, Header.Unknown1C, Header.Unknown20, 30);
                 DumpUInt32Pairs(Blob, Header.Unknown44, Header.Unknown48, 30);
                 DumpUInt32Pairs(Blob, Header.Unknown5C, Header.Unknown60, 30);
                 DumpUInt32Pairs(Blob, Header.Unknown64, Header.Unknown68, 30);
                 WriteLn('Root block:');
{                 DumpUInt32Block(Blob, Header.Unknown3C, 16);
                 StringPoolStart := Header.Unknown3C + $3C;
                   if ParseBDBStringPool(Blob, StringPoolStart, Strings, AfterStringPool)
                      then
                          begin
                               WriteLn('String pool ends at $', IntToHex(AfterStringPool, 8));
                               WriteLn('String count: ', Length(Strings));
                          end;
                   DumpUInt32Values(Blob, AfterStringPool, 80);}
            end;
    end;
  end;
end;


procedure DumpBlobInventory(
  const FileName: string
);
var
  F: TFileStream;
  Header: TKSCHeader;
  Entry: TKSCBlobEntry;
  I: Integer;
begin
  F :=
    TFileStream.Create(
      FileName,
      fmOpenRead or fmShareDenyNone
    );

  try
    F.ReadBuffer(
      Header,
      SizeOf(Header)
    );

    if not IsKSC1(Header) then
      raise Exception.Create(
        'Not a KSC1 file'
      );

    WriteLn(
      'Blob count: ',
      Header.BlobCount
    );

    for I := 0 to Header.BlobCount - 1 do
    begin
      F.ReadBuffer(
        Entry,
        SizeOf(Entry)
      );

      WriteLn(
        'Owner=$',
        IntToHex(Entry.OwnerID, 8),
        ' Type=$',
        IntToHex(Ord(Entry.BlobType[3]), 2),
        IntToHex(Ord(Entry.BlobType[2]), 2),
        IntToHex(Ord(Entry.BlobType[1]), 2),
        IntToHex(Ord(Entry.BlobType[0]), 2),
        ' Size=',
        Entry.CompressedSize
      );
    end;

  finally
    F.Free;
  end;
end;

end.
