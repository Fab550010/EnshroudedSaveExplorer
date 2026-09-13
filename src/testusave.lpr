program testusave;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, uSaveIndex, uSteamDiscovery, uKnowledgeBlob, uCharacterData, uBDB
  { you can add units after this };

var
  IndexFileName: string;

begin

  if FindEnshroudedCharactersIndex(IndexFileName) then
    WriteLn(
      'Found: ',
      IndexFileName
    )
  else
    WriteLn(
      'No Enshrouded characters-index found'
    );

  WriteLn(
  ResolveCharactersSave(
    IndexFileName
  )
);

  DumpBlobInventory(ResolveCharactersSave(IndexFileName));

  DumpCharacterNames(ResolveCharactersSave(IndexFileName));


end.

