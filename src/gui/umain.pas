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
  Blob: TBytes;
  Knowledge: TKnowledgeItems;
begin
  if not OpenSaveDialog.Execute then
    Exit;

  Caption := OpenSaveDialog.FileName;

  Blob :=
    ExtractKnowledgeBlob(
      OpenSaveDialog.FileName,
      $2AF68BE4
    );

  ParseKnowledgeBlob(
    Blob,
    Knowledge
  );

  ShowMessage(
    Format(
      'KNOW entries: %d',
      [Length(Knowledge)]
    )
  );
end;

end.

