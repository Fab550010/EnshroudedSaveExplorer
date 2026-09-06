unit uKnowledgeBlob;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  uZstd;

function ExtractKnowledgeBlob(
  const FileName: string;
  OwnerID: Cardinal
): TBytes;

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

function ExtractKnowledgeBlob(
  const FileName: string;
  OwnerID: Cardinal
): TBytes;
var
  F: TFileStream;
  Header: TKSCHeader;
  Entries: TKSCBlobEntryArray;
  I: Integer;
  DataOffset: Int64;
  CompressedData: TBytes;
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
      if
        (Entries[I].OwnerID = OwnerID) and
        IsKnowBlob(
          Entries[I].BlobType
        )
      then
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
      'KNOW blob not found for OwnerID %s',
      [
        IntToHex(
          OwnerID,
          8
        )
      ]
    );

  finally
    F.Free;
  end;
end;

end.
