unit uZstd;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  ZSTD_DLL = 'libzstd.dll';

function ZSTD_getFrameContentSize(
  Src: Pointer;
  SrcSize: SizeUInt
): QWord; cdecl; external ZSTD_DLL;

function ZSTD_decompress(
  Dst: Pointer;
  DstCapacity: SizeUInt;
  Src: Pointer;
  CompressedSize: SizeUInt
): SizeUInt; cdecl; external ZSTD_DLL;

function ZSTD_isError(
  Code: SizeUInt
): LongWord; cdecl; external ZSTD_DLL;

function ZSTD_getErrorName(
  Code: SizeUInt
): PAnsiChar; cdecl; external ZSTD_DLL;

function DecompressZstd(const Data: TBytes): TBytes;

implementation

const
  ZSTD_CONTENTSIZE_UNKNOWN = QWord(-1);
  ZSTD_CONTENTSIZE_ERROR   = QWord(-2);

function DecompressZstd(const Data: TBytes): TBytes;
var
  OutputSize: QWord;
  ResultSize: SizeUInt;
begin
  SetLength(Result, 0);

  if Length(Data) = 0 then
    Exit;

  OutputSize := ZSTD_getFrameContentSize(
    @Data[0],
    Length(Data)
  );

  if OutputSize = ZSTD_CONTENTSIZE_ERROR then
    raise Exception.Create('Invalid ZSTD frame');

  if OutputSize = ZSTD_CONTENTSIZE_UNKNOWN then
    raise Exception.Create(
      'ZSTD frame does not contain decompressed size'
    );

  if OutputSize > High(SizeInt) then
    raise Exception.Create(
      'Decompressed blob is too large'
    );

  SetLength(Result, OutputSize);

  ResultSize := ZSTD_decompress(
    @Result[0],
    OutputSize,
    @Data[0],
    Length(Data)
  );

  if ZSTD_isError(ResultSize) <> 0 then
    raise Exception.CreateFmt(
      'ZSTD error: %s',
      [string(ZSTD_getErrorName(ResultSize))]
    );

  SetLength(Result, ResultSize);
end;

end.
