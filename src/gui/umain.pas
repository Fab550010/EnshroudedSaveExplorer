unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Grids, uKnowledgeBlob, uKnowledge;

type

  { TMainForm }

  TMainForm = class(TForm)
    OpenSaveDialog: TOpenDialog;
    OpenSaveButton: TButton;
    QuestGrid: TStringGrid;
    TopPanel: TPanel;
    procedure OpenSaveButtonClick(Sender: TObject);
  private

  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.OpenSaveButtonClick(Sender: TObject);
var
  Owners: TOwnerIDArray;
  Blob: TBytes;
  Knowledge: TKnowledgeItems;
begin
  if not OpenSaveDialog.Execute then
    Exit;

  Caption := OpenSaveDialog.FileName;

  Owners :=
    ListKnowledgeOwners(
      OpenSaveDialog.FileName
    );

  if Length(Owners) = 0 then
  begin
    ShowMessage(
      'No character with KNOW data found.'
    );
    Exit;
  end;

  if Length(Owners) > 1 then
  begin
    ShowMessage(
      Format(
        '%d characters found. Character selection is not implemented yet.',
        [Length(Owners)]
      )
    );
    Exit;
  end;

  Blob :=
    ExtractKnowledgeBlob(
      OpenSaveDialog.FileName,
      Owners[0]
    );

  ParseKnowledgeBlob(
    Blob,
    Knowledge
  );

  ShowMessage(
    Format(
      'OwnerID: %s'#13#10 +
      'KNOW entries: %d',
      [
        IntToHex(Owners[0], 8),
        Length(Knowledge)
      ]
    )
  );
end;


end.

