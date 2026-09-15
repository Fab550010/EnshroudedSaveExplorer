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

const
  JOURNAL_GUID: array[0..15] of Byte = (
    $26, $1B, $70, $33,
    $1D, $EC,
    $3F, $42,
    $8E, $06,
    $49, $F0, $23, $B9, $1B, $7F
  );

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



end.
