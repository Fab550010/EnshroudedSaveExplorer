unit uReflection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPESection = record
    Name: string;
    VirtualAddress: Cardinal;
    SizeOfRawData: Cardinal;
    PointerToRawData: Cardinal;
  end;

  TPESectionArray = array of TPESection;

  TPEFile = record
    Data: TBytes;
    Sections: TPESectionArray;
    ImageBase: QWord;
  end;

procedure DumpReflectionType(
  const ExeFileName: string;
  QualifiedHash: Cardinal
);

procedure DumpBlobArrayElementStructOfField(
  const PE: TPEFile;
  ParentTypeOffset: QWord;
  const WantedField: string;
  const Title: string
);

implementation




function ReadUInt16LE(
  const Data: TBytes;
  Offset: QWord
): Word;
begin
  if Offset + 2 > QWord(Length(Data)) then
    raise Exception.Create('ReadUInt16LE out of bounds');

  Move(
    Data[Offset],
    Result,
    2
  );
end;

function ReadUInt32LE(
  const Data: TBytes;
  Offset: QWord
): Cardinal;
begin
  if Offset + 4 > QWord(Length(Data)) then
    raise Exception.Create('ReadUInt32LE out of bounds');

  Move(
    Data[Offset],
    Result,
    4
  );
end;

function ReadUInt64LE(
  const Data: TBytes;
  Offset: QWord
): QWord;
begin
  if Offset + 8 > QWord(Length(Data)) then
    raise Exception.Create('ReadUInt64LE out of bounds');

  Move(
    Data[Offset],
    Result,
    8
  );
end;

function LoadPEFile(
  const FileName: string
): TPEFile;
var
  Stream: TFileStream;
  PEOffset: Cardinal;
  NumberOfSections: Word;
  SizeOfOptionalHeader: Word;
  OptionalHeaderOffset: QWord;
  SectionOffset: QWord;
  Magic: Word;
  I, J: Integer;
  NameBytes: array[0..7] of Byte;
  S: string;
begin
  FillChar(
    Result,
    SizeOf(Result),
    0
  );

  Stream :=
    TFileStream.Create(
      FileName,
      fmOpenRead or fmShareDenyNone
    );

  try
    SetLength(
      Result.Data,
      Stream.Size
    );

    if Stream.Size > 0 then
      Stream.ReadBuffer(
        Result.Data[0],
        Stream.Size
      );
  finally
    Stream.Free;
  end;

  if ReadUInt16LE(Result.Data, 0) <> $5A4D then
    raise Exception.Create('Invalid DOS signature');

  PEOffset :=
    ReadUInt32LE(
      Result.Data,
      $3C
    );

  if ReadUInt32LE(Result.Data, PEOffset) <> $00004550 then
    raise Exception.Create('Invalid PE signature');

  NumberOfSections :=
    ReadUInt16LE(
      Result.Data,
      PEOffset + 6
    );

  SizeOfOptionalHeader :=
    ReadUInt16LE(
      Result.Data,
      PEOffset + 20
    );

  OptionalHeaderOffset :=
    PEOffset + 24;

  Magic :=
    ReadUInt16LE(
      Result.Data,
      OptionalHeaderOffset
    );

  if Magic <> $020B then
    raise Exception.Create(
      'Expected PE32+ executable'
    );

  Result.ImageBase :=
    ReadUInt64LE(
      Result.Data,
      OptionalHeaderOffset + 24
    );

  SectionOffset :=
    OptionalHeaderOffset +
    SizeOfOptionalHeader;

  SetLength(
    Result.Sections,
    NumberOfSections
  );

  for I := 0 to NumberOfSections - 1 do
  begin
    FillChar(
      NameBytes,
      SizeOf(NameBytes),
      0
    );

    Move(
      Result.Data[SectionOffset],
      NameBytes[0],
      8
    );

    S := '';

    for J := 0 to 7 do
    begin
      if NameBytes[J] = 0 then
        Break;

      S :=
        S +
        Chr(NameBytes[J]);
    end;

    Result.Sections[I].Name := S;

    Result.Sections[I].VirtualAddress :=
      ReadUInt32LE(
        Result.Data,
        SectionOffset + 12
      );

    Result.Sections[I].SizeOfRawData :=
      ReadUInt32LE(
        Result.Data,
        SectionOffset + 16
      );

    Result.Sections[I].PointerToRawData :=
      ReadUInt32LE(
        Result.Data,
        SectionOffset + 20
      );

    Inc(
      SectionOffset,
      40
    );
  end;
end;

function VAToFileOffset(
  const PE: TPEFile;
  VA: QWord;
  out FileOffset: QWord
): Boolean;
var
  RVA: QWord;
  I: Integer;
begin
  Result := False;

  if VA < PE.ImageBase then
    Exit;

  RVA :=
    VA -
    PE.ImageBase;

  for I := 0 to High(PE.Sections) do
  begin
    if
      (RVA >= PE.Sections[I].VirtualAddress) and
      (RVA <
        QWord(PE.Sections[I].VirtualAddress) +
        PE.Sections[I].SizeOfRawData)
    then
    begin
      FileOffset :=
        PE.Sections[I].PointerToRawData +
        (
          RVA -
          PE.Sections[I].VirtualAddress
        );

      Exit(True);
    end;
  end;
end;

function FileOffsetToVA(
  const PE: TPEFile;
  FileOffset: QWord;
  out VA: QWord
): Boolean;
var
  I: Integer;
begin
  Result := False;

  for I := 0 to High(PE.Sections) do
  begin
    if
      (FileOffset >= PE.Sections[I].PointerToRawData) and
      (FileOffset <
        QWord(PE.Sections[I].PointerToRawData) +
        PE.Sections[I].SizeOfRawData)
    then
    begin
      VA :=
        PE.ImageBase +
        PE.Sections[I].VirtualAddress +
        (
          FileOffset -
          PE.Sections[I].PointerToRawData
        );

      Exit(True);
    end;
  end;
end;

function FindBytes(
  const Data: TBytes;
  StartOffset: QWord;
  const Needle: array of Byte
): Int64;
var
  I, J: QWord;
  Match: Boolean;
begin
  Result := -1;

  if Length(Needle) = 0 then
    Exit;

  if
    StartOffset +
    QWord(Length(Needle)) >
    QWord(Length(Data))
  then
    Exit;

  for I :=
    StartOffset to
    QWord(Length(Data)) -
    QWord(Length(Needle))
  do
  begin
    Match := True;

    for J := 0 to High(Needle) do
      if Data[I + J] <> Needle[J] then
      begin
        Match := False;
        Break;
      end;

    if Match then
      Exit(I);
  end;
end;

function FindUInt64(
  const Data: TBytes;
  StartOffset: QWord;
  Value: QWord
): Int64;
var
  I: QWord;
begin
  Result := -1;

  for I :=
    StartOffset to
    QWord(Length(Data)) - 8
  do
    if ReadUInt64LE(Data, I) = Value then
      Exit(I);
end;

function FindSectionOffset(
  const PE: TPEFile;
  const SectionName: string
): QWord;
var
  I: Integer;
begin
  for I := 0 to High(PE.Sections) do
    if PE.Sections[I].Name = SectionName then
      Exit(
        PE.Sections[I].PointerToRawData
      );

  raise Exception.CreateFmt(
    'PE section not found: %s',
    [SectionName]
  );
end;

function FindUInt64Pair(
  const Data: TBytes;
  StartOffset: QWord;
  Value1, Value2: QWord
): Int64;
var
  I: QWord;
begin
  Result := -1;

  for I :=
    StartOffset to
    QWord(Length(Data)) - 16
  do
    if
      (ReadUInt64LE(Data, I) = Value1) and
      (ReadUInt64LE(Data, I + 8) = Value2)
    then
      Exit(I);
end;

function LocateReflectionTable(
  const PE: TPEFile;
  out TableFileOffset: QWord;
  out TableCount: QWord
): Boolean;
const
  BlobStringPattern: array[0..11] of Byte = (
    $00,
    Ord('B'), Ord('l'), Ord('o'), Ord('b'),
    Ord('S'), Ord('t'), Ord('r'), Ord('i'),
    Ord('n'), Ord('g'),
    $00
  );

  UInt32Pattern: array[0..7] of Byte = (
    $00,
    Ord('u'), Ord('i'), Ord('n'), Ord('t'),
    Ord('3'), Ord('2'),
    $00
  );

var
  RDataOffset: QWord;

  BlobPos: Int64;
  UIntPos: Int64;

  BlobVA: QWord;
  UIntVA: QWord;

  Ref1Pos: Int64;
  Ref2Pos: Int64;

  Ref1VA: QWord;
  Ref2VA: QWord;

  PairPos: Int64;
  PairVA: QWord;

  FinalRefPos: Int64;

  TableVA: QWord;
begin
  Result := False;

  RDataOffset :=
    FindSectionOffset(
      PE,
      '.rdata'
    );

  BlobPos :=
    FindBytes(
      PE.Data,
      RDataOffset,
      BlobStringPattern
    );

  UIntPos :=
    FindBytes(
      PE.Data,
      RDataOffset,
      UInt32Pattern
    );

  if
    (BlobPos < 0) or
    (UIntPos < 0)
  then
    Exit;

  if not FileOffsetToVA(
           PE,
           BlobPos + 1,
           BlobVA
         )
  then
    Exit;

  if not FileOffsetToVA(
           PE,
           UIntPos + 1,
           UIntVA
         )
  then
    Exit;

  Ref1Pos :=
    FindUInt64(
      PE.Data,
      RDataOffset,
      BlobVA
    );

  Ref2Pos :=
    FindUInt64(
      PE.Data,
      RDataOffset,
      UIntVA
    );

  if
    (Ref1Pos < 0) or
    (Ref2Pos < 0)
  then
    Exit;

  if not FileOffsetToVA(
           PE,
           Ref1Pos,
           Ref1VA
         )
  then
    Exit;

  if not FileOffsetToVA(
           PE,
           Ref2Pos,
           Ref2VA
         )
  then
    Exit;
    PairPos :=
    FindUInt64Pair(
      PE.Data,
      RDataOffset,
      Ref1VA,
      Ref2VA
    );

  if PairPos < 0 then
    Exit;

  if not FileOffsetToVA(
           PE,
           PairPos,
           PairVA
         )
  then
    Exit;

  FinalRefPos :=
    FindUInt64(
      PE.Data,
      RDataOffset,
      PairVA
    );

  if FinalRefPos < 0 then
    Exit;

  {
    FinalRefPos pointe sur la structure :

      TypeMetadata** table;
      uint64 count;
  }

  TableVA :=
    ReadUInt64LE(
      PE.Data,
      FinalRefPos
    );

  TableCount :=
    ReadUInt64LE(
      PE.Data,
      FinalRefPos + 8
    );

  if not VAToFileOffset(
           PE,
           TableVA,
           TableFileOffset
         )
  then
    Exit;

  Result := True;
end;



function ReadStringAtVA(
  const PE: TPEFile;
  VA: QWord;
  Len: QWord
): string;
var
  Offset: QWord;
begin
  Result := '';

  if Len = 0 then
    Exit;

  if not VAToFileOffset(
           PE,
           VA,
           Offset
         )
  then
    raise Exception.Create(
      'Unable to resolve string VA'
    );

  if Offset + Len > QWord(Length(PE.Data)) then
    raise Exception.Create(
      'String exceeds executable'
    );

  SetLength(
    Result,
    Len
  );

  Move(
    PE.Data[Offset],
    Result[1],
    Len
  );
end;



procedure DumpStructFields(
  const PE: TPEFile;
  TypeOffset: QWord;
  const Prefix: string
);
var
  FieldCount: Cardinal;
  StructFieldsVA: QWord;
  StructFieldsOffset: QWord;

  J: Cardinal;
  FieldOffset: QWord;

  FieldNameVA: QWord;
  FieldNameLen: QWord;
  FieldName: string;

  FieldTypeVA: QWord;
  FieldTypeOffset: QWord;
  FieldDataOffset: QWord;

  FieldTypeHash: Cardinal;
  FieldTypeSize: Cardinal;
  FieldPrimitive: Byte;

  InnerTypeVA: QWord;
  InnerTypeOffset: QWord;
  InnerHash: Cardinal;
  InnerSize: Cardinal;
  InnerPrimitive: Byte;
begin
  FieldCount :=
    ReadUInt32LE(
      PE.Data,
      TypeOffset + $48
    );

  StructFieldsVA :=
    ReadUInt64LE(
      PE.Data,
      TypeOffset + $58
    );

  if StructFieldsVA = 0 then
    Exit;

  if not VAToFileOffset(
           PE,
           StructFieldsVA,
           StructFieldsOffset
         )
  then
    raise Exception.Create(
      'Unable to resolve struct fields'
    );

  for J := 0 to FieldCount - 1 do
  begin
    FieldOffset :=
      StructFieldsOffset +
      QWord(J) * 48;

    FieldNameVA :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset
      );

    FieldNameLen :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset + 8
      );

    FieldName :=
      ReadStringAtVA(
        PE,
        FieldNameVA,
        FieldNameLen
      );

    FieldTypeVA :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset + 16
      );

    FieldDataOffset :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset + 24
      );

    if not VAToFileOffset(
             PE,
             FieldTypeVA,
             FieldTypeOffset
           )
    then
      raise Exception.CreateFmt(
        'Unable to resolve type of field %s',
        [FieldName]
      );

    FieldTypeHash :=
      ReadUInt32LE(
        PE.Data,
        FieldTypeOffset + $50
      );

    FieldTypeSize :=
      ReadUInt32LE(
        PE.Data,
        FieldTypeOffset + $40
      );

    FieldPrimitive :=
      PE.Data[
        FieldTypeOffset + $4C
      ];

    WriteLn(
      Prefix,
      J,
      ': ',
      FieldName,
      ' @',
      FieldDataOffset,
      ' hash=$',
      IntToHex(FieldTypeHash, 8),
      ' size=',
      FieldTypeSize,
      ' primitive=$',
      IntToHex(FieldPrimitive, 2)
    );

    InnerTypeVA :=
      ReadUInt64LE(
        PE.Data,
        FieldTypeOffset + $38
      );

    if
      (InnerTypeVA <> 0) and
      VAToFileOffset(
        PE,
        InnerTypeVA,
        InnerTypeOffset
      )
    then
    begin
      InnerHash :=
        ReadUInt32LE(
          PE.Data,
          InnerTypeOffset + $50
        );

      InnerSize :=
        ReadUInt32LE(
          PE.Data,
          InnerTypeOffset + $40
        );

      InnerPrimitive :=
        PE.Data[
          InnerTypeOffset + $4C
        ];

      WriteLn(
        Prefix,
        '    inner hash=$',
        IntToHex(InnerHash, 8),
        ' size=',
        InnerSize,
        ' primitive=$',
        IntToHex(InnerPrimitive, 2)
      );
    end;
  end;
end;

function FindTypeOffsetByHash(
  const PE: TPEFile;
  TableOffset: QWord;
  TableCount: QWord;
  QualifiedHash: Cardinal;
  out TypeOffset: QWord
): Boolean;
var
  I: QWord;
  TypeVA: QWord;
  CandidateOffset: QWord;
begin
  Result := False;

  for I := 0 to TableCount - 1 do
  begin
    TypeVA :=
      ReadUInt64LE(
        PE.Data,
        TableOffset + I * 8
      );

    if not VAToFileOffset(
             PE,
             TypeVA,
             CandidateOffset
           )
    then
      Continue;

    if
      ReadUInt32LE(
        PE.Data,
        CandidateOffset + $50
      ) = QualifiedHash
    then
    begin
      TypeOffset := CandidateOffset;
      Exit(True);
    end;
  end;
end;


procedure DumpEnumFields(
  const PE: TPEFile;
  TypeOffset: QWord;
  const Title: string
);
var
  FieldCount: Cardinal;
  EnumFieldsVA: QWord;
  EnumFieldsOffset: QWord;

  I: Cardinal;
  EntryOffset: QWord;

  NameVA: QWord;
  NameLen: QWord;
  Name: string;
  Value: QWord;
begin
  FieldCount :=
    ReadUInt32LE(
      PE.Data,
      TypeOffset + $48
    );

  EnumFieldsVA :=
    ReadUInt64LE(
      PE.Data,
      TypeOffset + $60
    );

  WriteLn;
  WriteLn('--- ', Title, ' ---');

  if EnumFieldsVA = 0 then
  begin
    WriteLn('No enum fields');
    Exit;
  end;

  if not VAToFileOffset(
           PE,
           EnumFieldsVA,
           EnumFieldsOffset
         )
  then
    raise Exception.Create(
      'Unable to resolve enum fields'
    );

  for I := 0 to FieldCount - 1 do
  begin
    {
      EnumFieldMetadata:
        +00 char* name
        +08 uint64 name_len
        +10 uint64 value
        +18 padding[16]

      Total = 40 bytes
    }

    EntryOffset :=
      EnumFieldsOffset +
      QWord(I) * 40;

    NameVA :=
      ReadUInt64LE(
        PE.Data,
        EntryOffset
      );

    NameLen :=
      ReadUInt64LE(
        PE.Data,
        EntryOffset + 8
      );

    Name :=
      ReadStringAtVA(
        PE,
        NameVA,
        NameLen
      );

    Value :=
      ReadUInt64LE(
        PE.Data,
        EntryOffset + 16
      );

    WriteLn(
      Value,
      ' = ',
      Name
    );
  end;
end;

procedure DumpReflectionType(
  const ExeFileName: string;
  QualifiedHash: Cardinal
);
var
  PE: TPEFile;
  TableOffset: QWord;
  TableCount: QWord;

  I: QWord;
  TypeVA: QWord;
  TypeOffset: QWord;

  Hash: Cardinal;
  Size: Cardinal;
  FieldCount: Cardinal;
  PrimitiveType: Byte;
  Flags: Byte;

    StructFieldsVA: QWord;
  StructFieldsOffset: QWord;

  FieldOffset: QWord;
  FieldNameVA: QWord;
  FieldNameLen: QWord;
  FieldName: string;

  FieldTypeVA: QWord;
  FieldTypeOffset: QWord;
  FieldDataOffset: QWord;

  FieldTypeHash: Cardinal;
  FieldTypeSize: Cardinal;
  FieldPrimitiveType: Byte;

  InnerTypeVA: QWord;
  InnerTypeOffset: QWord;
  InnerTypeHash: Cardinal;
  InnerTypeSize: Cardinal;
  InnerPrimitiveType: Byte;

  J : integer;

  RequirementTypeOffset: QWord;
  EnumTypeOffset: QWord;
begin
  PE := LoadPEFile(ExeFileName);

  if not LocateReflectionTable(PE, TableOffset, TableCount)
  then
    raise Exception.Create(
      'Unable to locate reflection table'
    );

  WriteLn(
    'Reflection table offset=$',
    IntToHex(TableOffset, 8),
    ' count=',
    TableCount
  );

  for I := 0 to TableCount - 1 do
  begin
    TypeVA :=
      ReadUInt64LE(
        PE.Data,
        TableOffset + I * 8
      );

    if not VAToFileOffset(
             PE,
             TypeVA,
             TypeOffset
           )
    then
      Continue;

    Hash :=
      ReadUInt32LE(
        PE.Data,
        TypeOffset + $50
      );

    if Hash <> QualifiedHash then
      Continue;

    Size :=
      ReadUInt32LE(
        PE.Data,
        TypeOffset + $40
      );

    FieldCount :=
      ReadUInt32LE(
        PE.Data,
        TypeOffset + $48
      );

    PrimitiveType :=
      PE.Data[
        TypeOffset + $4C
      ];

    Flags :=
      PE.Data[
        TypeOffset + $4D
      ];

    WriteLn(
      'FOUND index=',
      I
    );

    WriteLn(
      'Type offset=$',
      IntToHex(TypeOffset, 8)
    );

    WriteLn(
      'Qualified hash=$',
      IntToHex(Hash, 8)
    );

    WriteLn(
      'Size=',
      Size
    );

    WriteLn(
      'FieldCount=',
      FieldCount
    );

    WriteLn(
      'PrimitiveType=$',
      IntToHex(PrimitiveType, 2)
    );

    WriteLn(
      'Flags=$',
      IntToHex(Flags, 2)
    );


        StructFieldsVA :=
      ReadUInt64LE(
        PE.Data,
        TypeOffset + $58
      );

    if StructFieldsVA = 0 then
      raise Exception.Create(
        'Struct has no field metadata'
      );

    if not VAToFileOffset(
             PE,
             StructFieldsVA,
             StructFieldsOffset
           )
    then
      raise Exception.Create(
        'Unable to resolve struct field table'
      );

    if FindTypeOffsetByHash(
     PE,
     TableOffset,
     TableCount,
     $C542456E,
     RequirementTypeOffset
   )
then
begin
  WriteLn;
  WriteLn('--- requirement fields ---');

  WriteLn(
    'hash=$',
    IntToHex(
      ReadUInt32LE(
        PE.Data,
        RequirementTypeOffset + $50
      ),
      8
    )
  );

  WriteLn(
    'size=',
    ReadUInt32LE(
      PE.Data,
      RequirementTypeOffset + $40
    )
  );

  DumpStructFields(
    PE,
    RequirementTypeOffset,
    '  '
  );
end
else
  WriteLn(
    'Requirement type $C542456E not found'
  );

writeln('------findtype------');

  if FindTypeOffsetByHash(
     PE,
     TableOffset,
     TableCount,
     $EF782BD5,
     EnumTypeOffset
   )
then
  DumpEnumFields(
    PE,
    EnumTypeOffset,
    'compareOperator enum'
  );

if FindTypeOffsetByHash(
     PE,
     TableOffset,
     TableCount,
     $437364EE,
     EnumTypeOffset
   )
then
  DumpEnumFields(
    PE,
    EnumTypeOffset,
    'requirement type enum'
  );

    for j := 0 to FieldCount - 1 do
    begin
      FieldOffset :=
        StructFieldsOffset +
        j * 48;

      FieldNameVA :=
        ReadUInt64LE(
          PE.Data,
          FieldOffset
        );

      FieldNameLen :=
        ReadUInt64LE(
          PE.Data,
          FieldOffset + 8
        );

      FieldName :=
        ReadStringAtVA(
          PE,
          FieldNameVA,
          FieldNameLen
        );

      FieldTypeVA :=
        ReadUInt64LE(
          PE.Data,
          FieldOffset + 16
        );

      FieldDataOffset :=
        ReadUInt64LE(
          PE.Data,
          FieldOffset + 24
        );

      if not VAToFileOffset(
               PE,
               FieldTypeVA,
               FieldTypeOffset
             )
      then
        raise Exception.CreateFmt(
          'Unable to resolve type of field %s',
          [FieldName]
        );

      FieldTypeSize :=
        ReadUInt32LE(
          PE.Data,
          FieldTypeOffset + $40
        );

      FieldPrimitiveType :=
        PE.Data[
          FieldTypeOffset + $4C
        ];

      FieldTypeHash :=
        ReadUInt32LE(
          PE.Data,
          FieldTypeOffset + $50
        );

      WriteLn;
      WriteLn(
        'FIELD ',
        J,
        ': ',
        FieldName
      );

      WriteLn(
        '  dataOffset=',
        FieldDataOffset
      );

      WriteLn(
        '  typeHash=$',
        IntToHex(FieldTypeHash, 8)
      );

      WriteLn(
        '  typeSize=',
        FieldTypeSize
      );

      WriteLn(
        '  primitive=$',
        IntToHex(FieldPrimitiveType, 2)
      );

            InnerTypeVA :=
        ReadUInt64LE(
          PE.Data,
          FieldTypeOffset + $38
        );

      if
        (InnerTypeVA <> 0) and
        VAToFileOffset(
          PE,
          InnerTypeVA,
          InnerTypeOffset
        )
      then
      begin
        InnerTypeHash :=
          ReadUInt32LE(
            PE.Data,
            InnerTypeOffset + $50
          );

        InnerTypeSize :=
          ReadUInt32LE(
            PE.Data,
            InnerTypeOffset + $40
          );

        InnerPrimitiveType :=
          PE.Data[
            InnerTypeOffset + $4C
          ];

        WriteLn(
          '  elementHash=$',
          IntToHex(InnerTypeHash, 8)
        );

        WriteLn(
          '  elementSize=',
          InnerTypeSize
        );

        WriteLn(
          '  elementPrimitive=$',
          IntToHex(InnerPrimitiveType, 2)
        );
      end;

      if (FieldName = 'quests') or (FieldName = 'collections')
      then begin
           WriteLn;
           WriteLn('--- ', FieldName, ' element fields ---');
           DumpStructFields(PE, InnerTypeOffset, '  ');
      end;

      if (FieldName = 'quests' )
      then begin
           InnerTypeVA :=
           ReadUInt64LE(
                        PE.Data,
                        InnerTypeOffset + $38
                        );

           if (InnerTypeVA <> 0) and VAToFileOffset(PE, InnerTypeVA, FieldTypeOffset)
             then begin
                  WriteLn;
                  WriteLn('--- quests base type fields ---');

                  WriteLn('base hash=$', IntToHex(ReadUInt32LE(PE.Data, FieldTypeOffset + $50), 8));

                  WriteLn('base size=', ReadUInt32LE(PE.Data, FieldTypeOffset + $40));

                  DumpStructFields(PE, FieldTypeOffset, '  ');
             end;

      end;
      if FieldName = 'collections' then
      begin
           DumpBlobArrayElementStructOfField(PE, InnerTypeOffset, 'entries', 'collection entry fields');
      end;
    end;


    Exit;
  end;

  raise Exception.CreateFmt(
    'Type $%s not found',
    [
      IntToHex(
        QualifiedHash,
        8
      )
    ]
  );
end;

procedure DumpBlobArrayElementStructOfField(
  const PE: TPEFile;
  ParentTypeOffset: QWord;
  const WantedField: string;
  const Title: string
);
var
  FieldCount: Cardinal;
  StructFieldsVA: QWord;
  StructFieldsOffset: QWord;

  J: Cardinal;
  FieldOffset: QWord;

  FieldNameVA: QWord;
  FieldNameLen: QWord;
  FieldName: string;

  FieldTypeVA: QWord;
  FieldTypeOffset: QWord;

  ElementTypeVA: QWord;
  ElementTypeOffset: QWord;
begin
  FieldCount :=
    ReadUInt32LE(
      PE.Data,
      ParentTypeOffset + $48
    );

  StructFieldsVA :=
    ReadUInt64LE(
      PE.Data,
      ParentTypeOffset + $58
    );

  if StructFieldsVA = 0 then
    Exit;

  if not VAToFileOffset(
           PE,
           StructFieldsVA,
           StructFieldsOffset
         )
  then
    raise Exception.Create(
      'Unable to resolve struct fields'
    );

  for J := 0 to FieldCount - 1 do
  begin
    FieldOffset :=
      StructFieldsOffset +
      QWord(J) * 48;

    FieldNameVA :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset
      );

    FieldNameLen :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset + 8
      );

    FieldName :=
      ReadStringAtVA(
        PE,
        FieldNameVA,
        FieldNameLen
      );

    if FieldName <> WantedField then
      Continue;

    FieldTypeVA :=
      ReadUInt64LE(
        PE.Data,
        FieldOffset + 16
      );

    if not VAToFileOffset(
             PE,
             FieldTypeVA,
             FieldTypeOffset
           )
    then
      raise Exception.CreateFmt(
        'Unable to resolve type of field %s',
        [FieldName]
      );

    {
      FieldTypeOffset désigne ici le BlobArray.
      Son inner_type est le type de l'élément.
    }

    ElementTypeVA :=
      ReadUInt64LE(
        PE.Data,
        FieldTypeOffset + $38
      );

    if ElementTypeVA = 0 then
      raise Exception.CreateFmt(
        'Field %s has no inner type',
        [FieldName]
      );

    if not VAToFileOffset(
             PE,
             ElementTypeVA,
             ElementTypeOffset
           )
    then
      raise Exception.CreateFmt(
        'Unable to resolve inner type of field %s',
        [FieldName]
      );

    WriteLn;
    WriteLn('--- ', Title, ' ---');

    WriteLn(
      'hash=$',
      IntToHex(
        ReadUInt32LE(
          PE.Data,
          ElementTypeOffset + $50
        ),
        8
      )
    );

    WriteLn(
      'size=',
      ReadUInt32LE(
        PE.Data,
        ElementTypeOffset + $40
      )
    );

    WriteLn(
      'primitive=$',
      IntToHex(
        PE.Data[
          ElementTypeOffset + $4C
        ],
        2
      )
    );

    DumpStructFields(
      PE,
      ElementTypeOffset,
      '  '
    );

    Exit;
  end;

  raise Exception.CreateFmt(
    'Field %s not found',
    [WantedField]
  );
end;

end.
