unit uSaveIndex;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  fpjson,
  jsonparser;

function ResolveCharactersSave(
  const IndexFileName: string
): string;

implementation

function ResolveCharactersSave(
  const IndexFileName: string
): string;
var
  Stream: TFileStream;
  Root: TJSONData;
  Obj: TJSONObject;
  Latest: Integer;
  SaveDir: string;
begin
  Result := '';

  Stream :=
    TFileStream.Create(
      IndexFileName,
      fmOpenRead or fmShareDenyNone
    );

  try
    Root := GetJSON(Stream);

    try
      if Root.JSONType <> jtObject then
        raise Exception.Create(
          'Invalid characters-index file'
        );

      Obj := TJSONObject(Root);

      Latest :=
        Obj.Get(
          'latest',
          -1
        );

      if (Latest < 0) or (Latest > 9) then
        raise Exception.CreateFmt(
          'Invalid characters save index: %d',
          [Latest]
        );

      SaveDir :=
        ExtractFilePath(
          IndexFileName
        );

      if Latest = 0 then
        Result :=
          SaveDir + 'characters'
      else
        Result :=
          SaveDir +
          'characters-' +
          IntToStr(Latest);

      if not FileExists(Result) then
        raise Exception.CreateFmt(
          'Character save file not found: %s',
          [Result]
        );

    finally
      Root.Free;
    end;

  finally
    Stream.Free;
  end;
end;

end.
