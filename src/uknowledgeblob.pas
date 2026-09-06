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

end.
