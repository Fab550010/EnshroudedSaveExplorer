unit uKFC;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function ExtractKFCResource(
  const KFCFileName: string;
  const ResourcesFileName: string;
  const ResourceGuid: string;
  TypeHash: Cardinal;
  PartIndex: Cardinal
): TBytes;

implementation

uses uZstd;

type
  TKFCLocation = record
    Offset: QWord;
    Count: Cardinal;
  end;

  TKFCResourceEntry = record
    Offset: Cardinal;
    Size: Cardinal;
  end;

  TKFCResourceChunk = record
    Offset: Cardinal;
    Size: Cardinal;
    CompressedSize: Cardinal;
    UncompressedOffset: Cardinal;
    UncompressedSize: Cardinal;
  end;

  TKFCHeader = record
    ResourceKeys: TKFCLocation;
    ResourceValues: TKFCLocation;
    ResourceChunks: TKFCLocation;
  end;

  TKFCResourceChunkArray =
    array of TKFCResourceChunk;

const
  JOURNAL_GUID: array[0..15] of Byte = (
    $26, $1B, $70, $33,
    $1D, $EC,
    $3F, $42,
    $8E, $06,
    $49, $F0, $23, $B9, $1B, $7F
  );


function SameGuid(
  const A, B: array of Byte
): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);

  for I := 0 to High(A) do
    if A[I] <> B[I] then
      Exit(False);

  Result := True;
end;

function ReadUInt32LE(
  Stream: TStream
): Cardinal;
begin
  Stream.ReadBuffer(
    Result,
    SizeOf(Result)
  );
end;

function ReadKFCLocation(
  Stream: TStream
): TKFCLocation;
var
  Pos: Int64;
  RelativeOffset: Cardinal;
begin
  Pos := Stream.Position;

  RelativeOffset :=
    ReadUInt32LE(Stream);

  Result.Offset :=
    QWord(Pos) +
    RelativeOffset;

  Result.Count :=
    ReadUInt32LE(Stream);
end;

function ReadKFCHeader(
  Stream: TStream
): TKFCHeader;
var
  Magic: Cardinal;
  Dummy: Cardinal;
  L: TKFCLocation;
  I: Integer;
begin
  FillChar(
    Result,
    SizeOf(Result),
    0
  );

  Magic :=
    ReadUInt32LE(Stream);

  if Magic <> $3343464B then
    raise Exception.CreateFmt(
      'Invalid KFC magic: $%s',
      [IntToHex(Magic, 8)]
    );

  { size }
  ReadUInt32LE(Stream);

  { unk0 }
  Dummy := ReadUInt32LE(Stream);

  { padding }
  ReadUInt32LE(Stream);

  {
    Locations 0..15:

     0 version
     1 containers
     2 unused0
     3 unused1
     4 resource_locations
     5 resource_indices

     6 content_buckets
     7 content_keys
     8 content_values

     9 resource_buckets
    10 resource_keys
    11 resource_values

    12 resource_bundle_buckets
    13 resource_bundle_keys
    14 resource_bundle_values

    15 resource_chunks
  }

  for I := 0 to 15 do
  begin
    L :=
      ReadKFCLocation(Stream);

    case I of
      10:
        Result.ResourceKeys := L;

      11:
        Result.ResourceValues := L;

      15:
        Result.ResourceChunks := L;
    end;
  end;
end;

function ReadResourceChunks(
  Stream: TStream;
  const Header: TKFCHeader
): TKFCResourceChunkArray;
var
  I: Integer;
begin
  SetLength(
    Result,
    Header.ResourceChunks.Count
  );

  Stream.Position :=
    Header.ResourceChunks.Offset;

  for I := 0 to High(Result) do
  begin
    Result[I].Offset :=
      ReadUInt32LE(Stream);

    Result[I].Size :=
      ReadUInt32LE(Stream);

    Result[I].CompressedSize :=
      ReadUInt32LE(Stream);

    Result[I].UncompressedOffset :=
      ReadUInt32LE(Stream);

    Result[I].UncompressedSize :=
      ReadUInt32LE(Stream);
  end;
end;

function ReadAndDecompressChunk(
  ResourcesStream: TStream;
  const Chunk: TKFCResourceChunk
): TBytes;
var
  CompressedData: TBytes;
begin
  SetLength(
    CompressedData,
    Chunk.CompressedSize
  );

  ResourcesStream.Position :=
    Chunk.Offset;

  ResourcesStream.ReadBuffer(
    CompressedData[0],
    Length(CompressedData)
  );

  Result :=
    DecompressZstd(
      CompressedData
    );

  if Length(Result) <> Chunk.UncompressedSize then
    raise Exception.CreateFmt(
      'Unexpected decompressed chunk size: got %d, expected %d',
      [
        Length(Result),
        Chunk.UncompressedSize
      ]
    );
end;

function ExtractKFCResource(
  const KFCFileName: string;
  const ResourcesFileName: string;
  const ResourceGuid: string;
  TypeHash: Cardinal;
  PartIndex: Cardinal
): TBytes;
var
  Stream: TFileStream;
  Header: TKFCHeader;
  Guid: array[0..15] of Byte;
  EntryTypeHash: Cardinal;
  EntryPartIndex: Cardinal;
  I: Integer;
  ResourceIndex: Integer;
  Resource: TKFCResourceEntry;
  Chunks: TKFCResourceChunkArray;
  ResourceEnd: QWord;
  ChunkStart: QWord;
  ChunkEnd: QWord;
  ResourcesStream: TFileStream;
  ChunkData: TBytes;
  OffsetInChunk: QWord;
begin
  SetLength(Result, 0);

  Stream :=
    TFileStream.Create(
      KFCFileName,
      fmOpenRead or fmShareDenyNone
    );

  try
    Header :=
      ReadKFCHeader(Stream);

    WriteLn(
      'Resource keys: offset=$',
      IntToHex(Header.ResourceKeys.Offset, 8),
      ' count=',
      Header.ResourceKeys.Count
    );

    WriteLn(
      'Resource values: offset=$',
      IntToHex(Header.ResourceValues.Offset, 8),
      ' count=',
      Header.ResourceValues.Count
    );

    WriteLn(
      'Resource chunks: offset=$',
      IntToHex(Header.ResourceChunks.Offset, 8),
      ' count=',
      Header.ResourceChunks.Count
    );

    ResourceIndex := -1;

    Stream.Position :=
      Header.ResourceKeys.Offset;

    for I := 0 to Header.ResourceKeys.Count - 1 do
    begin
      Stream.ReadBuffer(
        Guid[0],
        SizeOf(Guid)
      );

      EntryTypeHash :=
        ReadUInt32LE(Stream);

      EntryPartIndex :=
        ReadUInt32LE(Stream);

      { reserved_0 }
      ReadUInt32LE(Stream);

      { reserved_1 }
      ReadUInt32LE(Stream);

      if
        SameGuid(Guid, JOURNAL_GUID) and
        (EntryTypeHash = TypeHash) and
        (EntryPartIndex = PartIndex)
      then
      begin
        ResourceIndex := I;
        Break;
      end;
    end;

    if ResourceIndex < 0 then
      raise Exception.Create(
        'JournalRegistryResource not found'
      );

    WriteLn(
      'Resource found at index ',
      ResourceIndex
    );

    Stream.Position :=
      Header.ResourceValues.Offset +
      Int64(ResourceIndex) * 8;

    Resource.Offset :=
      ReadUInt32LE(Stream);

    Resource.Size :=
      ReadUInt32LE(Stream);

    WriteLn(
      'Resource offset=$',
      IntToHex(Resource.Offset, 8),
      ' size=',
      Resource.Size,
      ' ($',
      IntToHex(Resource.Size, 8),
      ')'
    );

    Chunks :=
  ReadResourceChunks(
    Stream,
    Header
  );

ResourceEnd :=
  QWord(Resource.Offset) +
  Resource.Size;

WriteLn(
  'Resource range=$',
  IntToHex(Resource.Offset, 8),
  '..$',
  IntToHex(ResourceEnd, 8)
);

for I := 0 to High(Chunks) do
begin
  ChunkStart :=
    Chunks[I].UncompressedOffset;

  ChunkEnd :=
    ChunkStart +
    Chunks[I].UncompressedSize;

  if
  (Resource.Offset >= ChunkStart) and
  (ResourceEnd <= ChunkEnd)
then
begin
  ResourcesStream :=
    TFileStream.Create(
      ResourcesFileName,
      fmOpenRead or fmShareDenyNone
    );

  try
    ChunkData :=
      ReadAndDecompressChunk(
        ResourcesStream,
        Chunks[I]
      );

    OffsetInChunk :=
      QWord(Resource.Offset) -
      Chunks[I].UncompressedOffset;

    if
      OffsetInChunk +
      Resource.Size >
      QWord(Length(ChunkData))
    then
      raise Exception.Create(
        'Resource exceeds decompressed chunk'
      );

    SetLength(
      Result,
      Resource.Size
    );

    Move(
      ChunkData[OffsetInChunk],
      Result[0],
      Resource.Size
    );

    WriteLn(
      'Extracted resource bytes: ',
      Length(Result)
    );

    Exit;
  finally
    ResourcesStream.Free;
  end;
end;
end;

  finally
    Stream.Free;
  end;
end;


end.
