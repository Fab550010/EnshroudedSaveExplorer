program testusave;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, uSaveIndex
  { you can add units after this };

begin
  WriteLn(
  ResolveCharactersSave(
    'C:\Program Files (x86)\Steam\userdata\161173229\1203620\remote\characters-index'
  )
);

end.

