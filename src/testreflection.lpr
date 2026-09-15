program testreflection;

{$mode objfpc}{$H+}

uses
  SysUtils,
  uReflection;

begin
  try
    DumpReflectionType(
      'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded.exe',
      $60B5ED8A
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
