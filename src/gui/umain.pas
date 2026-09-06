unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Grids, uKnowledgeBlob, uKnowledge;

type

  { TMainForm }

  TMainForm = class(TForm)
    CharacterComboBox: TComboBox;
    OpenSaveDialog: TOpenDialog;
    OpenSaveButton: TButton;
    QuestGrid: TStringGrid;
    TopPanel: TPanel;
    procedure OpenSaveButtonClick(Sender: TObject);
  private
    FSaveFileName: string;
    FOwners: TOwnerIDArray;

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
  I: Integer;
  Info: string;
begin
  if not OpenSaveDialog.Execute then
    Exit;

  Caption := OpenSaveDialog.FileName;

  FSaveFileName :=
  OpenSaveDialog.FileName;

FOwners :=
  ListKnowledgeOwners(
    FSaveFileName
  );

CharacterComboBox.Clear;

for I := 0 to High(FOwners) do
begin
  Blob :=
    ExtractKnowledgeBlob(
      FSaveFileName,
      FOwners[I]
    );

  ParseKnowledgeBlob(
    Blob,
    Knowledge
  );

  CharacterComboBox.Items.Add(
    Format(
      '%s (%d KNOW entries)',
      [
        IntToHex(FOwners[I], 8),
        Length(Knowledge)
      ]
    )
  );
end;

if CharacterComboBox.Items.Count > 0 then
  CharacterComboBox.ItemIndex := 0;


end;


end.

