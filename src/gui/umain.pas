unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Grids, uKnowledgeBlob, uKnowledge, fpjson, jsonparser, uJournalEvaluator;

type

  { TMainForm }

  TMainForm = class(TForm)
    CharacterComboBox: TComboBox;
    OpenSaveDialog: TOpenDialog;
    OpenSaveButton: TButton;
    QuestGrid: TStringGrid;
    TopPanel: TPanel;
    procedure CharacterComboBoxChange(Sender: TObject);
    procedure OpenSaveButtonClick(Sender: TObject);
    destructor Destroy; override;
  private
    FSaveFileName: string;
    FOwners: TOwnerIDArray;
    FJournalRoot: TJSONData;
    procedure LoadTestJournal;
  public

  end;

const
  TEST_JOURNAL_FILE = 'E:\EnshroudedSaveExplorer\extracted_data\JournalRegistryResource\33701b26-ec1d-423f-8e06-49f023b91b7f_60b5ed8a_0.json';

var
  MainForm: TMainForm;


implementation

{$R *.lfm}

{ TMainForm }


procedure TMainForm.LoadTestJournal;
var
  Stream: TFileStream;
begin
  FJournalRoot.Free;
  FJournalRoot := nil;

  Stream :=
    TFileStream.Create(
      TEST_JOURNAL_FILE,
      fmOpenRead or fmShareDenyNone
    );

  try
    FJournalRoot :=
      GetJSON(Stream);
  finally
    Stream.Free;
  end;
end;

destructor TMainForm.Destroy;
begin
  FJournalRoot.Free;
  inherited Destroy;
end;

procedure TMainForm.OpenSaveButtonClick(Sender: TObject);
var
  Blob: TBytes;
  Knowledge: TKnowledgeItems;
  I: Integer;
begin
  if not OpenSaveDialog.Execute then
    Exit;

  LoadTestJournal;

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

procedure TMainForm.CharacterComboBoxChange(Sender: TObject);
var
  Blob: TBytes;
  Knowledge: TKnowledgeItems;
  OwnerID: Cardinal;
begin
  if CharacterComboBox.ItemIndex < 0 then
    Exit;

  if CharacterComboBox.ItemIndex > High(FOwners) then
    Exit;

  OwnerID :=
    FOwners[
      CharacterComboBox.ItemIndex
    ];

  Blob :=
    ExtractKnowledgeBlob(
      FSaveFileName,
      OwnerID
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
        IntToHex(OwnerID, 8),
        Length(Knowledge)
      ]
    )
  );
end;

end.

