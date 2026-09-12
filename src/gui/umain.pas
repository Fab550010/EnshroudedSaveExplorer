unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Grids, uKnowledgeBlob, uKnowledge, fpjson, jsonparser, uJournalEvaluator,
  uLocalization;

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
    FLocalization: TLocalizationItems;
    procedure LoadTestJournal;
    procedure LoadTestLocalization;
    procedure PopulateQuestGrid(const Knowledge: TKnowledgeItems);
  public

  end;

const
  TEST_JOURNAL_FILE = 'E:\EnshroudedSaveExplorer\extracted_data\JournalRegistryResource\33701b26-ec1d-423f-8e06-49f023b91b7f_60b5ed8a_0.json';
  TEST_LOCALIZATION_FILE = 'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded_016.dat';
  TEST_LOCALIZATION_SEED = $3F95ABE0;

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

procedure TMainForm.LoadTestLocalization;
begin
  SetLength(FLocalization, 0);

  if not LoadLocalizationTable(
           TEST_LOCALIZATION_FILE,
           TEST_LOCALIZATION_SEED,
           FLocalization
         ) then
    raise Exception.CreateFmt(
      'Unable to load localization table from %s',
      [TEST_LOCALIZATION_FILE]
    );
end;

procedure TMainForm.PopulateQuestGrid(
  const Knowledge: TKnowledgeItems
);
var
  Metadata: TJournalObjectMetadataArray;
  I: Integer;
  Row: Integer;
begin
  CollectJournalMetadata(
    FJournalRoot,
    Knowledge,
    FLocalization,
    Metadata
  );

  QuestGrid.BeginUpdate;
  try
    QuestGrid.RowCount := 1;
    Row := 1;

    for I := 0 to High(Metadata) do
    begin
      if Metadata[I].Family <> jfQuest then
        Continue;

      QuestGrid.RowCount := Row + 1;

      QuestGrid.Cells[0, Row] := Metadata[I].Name;
      QuestGrid.Cells[1, Row] := Metadata[I].RawType;
      QuestGrid.Cells[2, Row] :=
        QuestPersonalStatusText(Metadata[I].PersonalStatus);
      QuestGrid.Cells[3, Row] :=
        '$' + IntToHex(Metadata[I].ID, 8);

      Inc(Row);
    end;
  finally
    QuestGrid.EndUpdate;
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
  LoadTestLocalization;

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
  begin
    CharacterComboBox.ItemIndex := 0;
    CharacterComboBoxChange(CharacterComboBox);
  end
  else
    QuestGrid.RowCount := 1;
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

  PopulateQuestGrid(Knowledge);
end;

end.
