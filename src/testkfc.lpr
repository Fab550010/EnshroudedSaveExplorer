program testkfc;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes
  { you can add units after this }, SysUtils, uKFC;

var
  Data: TBytes;

begin
  try
    Data :=
      ExtractKFCResource(
        'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded.kfc',
        'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded.kfc_resources',
        '33701b26-ec1d-423f-8e06-49f023b91b7f',
        $60B5ED8A,
        0
      );

  except
    on E: Exception do
    begin
      WriteLn(
        'ERROR: ',
        E.Message
      );
      Halt(1);
    end;
  end;
end.
