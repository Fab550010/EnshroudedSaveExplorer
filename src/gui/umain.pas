unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, ComCtrls,
  Grids, uKnowledgeBlob, uKnowledge, fpjson, uJournalEvaluator,
  uLocalization, USaveIndex, uSteamDiscovery, ucharacterdata, uBDB,
  uKFC, uJournalResource, uJournalJSON;

type

  { TMainForm }

  TMainForm = class(TForm)
    CharacterComboBox: TComboBox;
    QuestsStatusFilterComboBox: TComboBox;
    QuestsSummaryLabel: TLabel;
    LoreSummaryLabel: TLabel;
    LoreStatusFilterComboBox: TComboBox;
    MainPageControl: TPageControl;
    LoreControlPanel: TPanel;
    QuestsControlPanel: TPanel;
    QuestTypeFilterCombobox: TComboBox;
    OpenSaveDialog: TOpenDialog;
    OpenSaveButton: TButton;
    QuestGrid: TStringGrid;
    QuestTabSheet: TTabSheet;
    LoreTabSheet: TTabSheet;
    LoreGrid: TStringGrid;
    SaveRefreshTimer: TTimer;
    TopPanel: TPanel;
    procedure CharacterComboBoxChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LoreFilterChange(Sender: TObject);
    procedure OpenSaveButtonClick(Sender: TObject);
    procedure QuestGridHeaderClick(Sender: TObject; IsColumn: Boolean; Index: Integer);
    procedure LoreGridHeaderClick(Sender: TObject; IsColumn: Boolean; Index: Integer);
    procedure QuestsFilterChange(Sender: TObject);
    procedure SaveRefreshTimerTimer(Sender: TObject);
  private
    FSaveFileName: string;
    FOwners: TOwnerIDArray;
    FJournalRoot: TJSONData;
    FLocalization: TLocalizationItems;
    FKnowledge: TKnowledgeItems;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    FLoreSortColumn: Integer;
    FLoreSortAscending: Boolean;
    FIndexFileName: string;
    FSaveFileStamp: LongInt;
    FSaveFileSize: Int64;
    FRefreshingSave: Boolean;
    procedure LoadTestJournal;
    procedure LoadTestLocalization;
    procedure PopulateQuestGrid;
    procedure PopulateLoreGrid;
    procedure LoadCharactersFile(const Filename : string);
    procedure RefreshSaveIfNeeded;
    function GetSaveFileSize(const FileName: string): Int64;
  public
    destructor Destroy; override;
  end;

const
  TEST_LOCALIZATION_FILE = 'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded_016.dat';
  TEST_LOCALIZATION_SEED = $3F95ABE0;

var
  MainForm: TMainForm;


implementation

{$R *.lfm}

{ TMainForm }

function TMainForm.GetSaveFileSize(
  const FileName: string
): Int64;
var
  SR: TSearchRec;
begin
  Result := -1;

  if FindFirst(
       FileName,
       faAnyFile,
       SR
     ) = 0
  then
  begin
    try
      Result := SR.Size;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure TMainForm.LoadCharactersFile(
  const FileName: string
);
var
  KnowBlob: TBytes;
  CharBlob : TBytes;
  I: Integer;
  Knowledge: TKnowledgeItems;
  CharacterName: string;
  LastPlayTime: Cardinal;
  BestLastPlayTime: Cardinal;
  BestIndex: Integer;
begin
  FSaveFileName := FileName;

  Caption := FSaveFileName;

  FOwners :=
    ListKnowledgeOwners(
      FSaveFileName
    );

  CharacterComboBox.Clear;

  BestLastPlayTime := 0;
  BestIndex := -1;

  for I := 0 to High(FOwners) do begin
      KnowBlob := ExtractKnowledgeBlob(FSaveFileName, FOwners[I]);
      CharBlob := ExtractCharacterBlob(FSaveFileName, FOwners[I]);

      CharacterName := ExtractCharacterName(CharBlob);
      lastPlayTime := 0;
      ExtractBDBLastPlayTime(CharBlob, LastPlayTime);
      if (BestIndex = -1) or (LastPlayTime > BestLastPlayTime)
      then
          begin
               BestLastPlayTime := LastPlayTime;
               BestIndex := I;
          end;


      ParseKnowledgeBlob(KnowBlob, Knowledge);

    CharacterComboBox.Items.Add(
      Format(
        '%s (%d KNOW entries)',
        [
          CharacterName,
          Length(Knowledge)
        ]
      )
    );

  end;

  if BestIndex >= 0 then
  begin
       CharacterComboBox.ItemIndex := BestIndex;
       CharacterComboBoxChange(CharacterComboBox);
  end
  else begin
    QuestGrid.RowCount := 1;
    LoreGrid.RowCount := 1;
  end;
end;


function LoreStatusSortRank(
  Status: TLoreStatus
): Integer;
begin
  case Status of
    lsComplete:
      Result := 0;

    lsPartial:
      Result := 1;

    lsUndiscovered:
      Result := 2;

  else
    Result := 3;
  end;
end;

function CompareLoreStatus(
  A, B: TLoreStatus
): Integer;
var
  RankA, RankB: Integer;
begin
  RankA := LoreStatusSortRank(A);
  RankB := LoreStatusSortRank(B);

  if RankA < RankB then
    Result := -1
  else if RankA > RankB then
    Result := 1
  else
    Result := 0;
end;

function QuestStatusSortRank(
  Status: TQuestPersonalStatus
): Integer;
begin
  case Status of
    qpsCompletedPersonally:
      Result := 0;

    qpsResolvedUnknownOrigin:
      Result := 1;

    qpsNotCompleted:
      Result := 2;

  else
    Result := 3;
  end;
end;

function CompareQuestStatus(
  A, B: TQuestPersonalStatus
): Integer;
var
  RankA, RankB: Integer;
begin
  RankA := QuestStatusSortRank(A);
  RankB := QuestStatusSortRank(B);

  if RankA < RankB then
    Result := -1
  else if RankA > RankB then
    Result := 1
  else
    Result := 0;
end;

function CompareCardinal(
  A, B: Cardinal
): Integer;
begin
  if A < B then
    Result := -1
  else if A > B then
    Result := 1
  else
    Result := 0;
end;

function CompareLoreMetadata(
  const A, B: TJournalObjectMetadata;
  SortColumn: Integer
): Integer;
begin
  case SortColumn of

    // Name
    0:
      Result := CompareText(A.Name, B.Name);

    // Progress
    1:
      begin
        if A.LoreDiscoveredEntries < B.LoreDiscoveredEntries then
          Result := -1
        else if A.LoreDiscoveredEntries > B.LoreDiscoveredEntries then
          Result := 1
        else if A.EntryCount < B.EntryCount then
          Result := -1
        else if A.EntryCount > B.EntryCount then
          Result := 1
        else
          Result := CompareText(A.Name, B.Name);
      end;

    // Status
    2:
      begin
        Result := CompareLoreStatus(
          A.LoreStatus,
          B.LoreStatus
        );

        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
      end;

    // ID
    3:
      Result := CompareCardinal(A.ID, B.ID);

  else
    Result := 0;
  end;
end;

procedure SortLoreMetadata(
  var Metadata: TJournalObjectMetadataArray;
  SortColumn: Integer;
  Ascending: Boolean
);

  procedure QuickSort(L, R: Integer);
  var
    I, J: Integer;
    Pivot: TJournalObjectMetadata;
    Temp: TJournalObjectMetadata;
    C: Integer;
  begin
    I := L;
    J := R;
    Pivot := Metadata[(L + R) div 2];

    repeat
      repeat
        C := CompareLoreMetadata(
          Metadata[I],
          Pivot,
          SortColumn
        );

        if not Ascending then
          C := -C;

        if C < 0 then
          Inc(I);
      until C >= 0;

      repeat
        C := CompareLoreMetadata(
          Metadata[J],
          Pivot,
          SortColumn
        );

        if not Ascending then
          C := -C;

        if C > 0 then
          Dec(J);
      until C <= 0;

      if I <= J then
      begin
        Temp := Metadata[I];
        Metadata[I] := Metadata[J];
        Metadata[J] := Temp;

        Inc(I);
        Dec(J);
      end;

    until I > J;

    if L < J then
      QuickSort(L, J);

    if I < R then
      QuickSort(I, R);
  end;

begin
  if Length(Metadata) <= 1 then
    Exit;

  QuickSort(0, High(Metadata));
end;

function CompareJournalMetadata(
  const A, B: TJournalObjectMetadata;
  SortColumn: Integer
): Integer;
begin
  case SortColumn of

    // Name -> Type -> Status
    0:
      begin
        Result := CompareText(A.Name, B.Name);

        if Result = 0 then
          Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareQuestStatus(
            A.PersonalStatus,
            B.PersonalStatus
          );
      end;

    // Type -> Status -> Name
    1:
      begin
        Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareQuestStatus(
            A.PersonalStatus,
            B.PersonalStatus
          );

        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
      end;

    // Status -> Type -> Name
    2:
      begin
        Result := CompareQuestStatus(
          A.PersonalStatus,
          B.PersonalStatus
        );

        if Result = 0 then
          Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
      end;

    // ID
    3:
      Result := CompareCardinal(A.ID, B.ID);

  else
    Result := 0;
  end;
end;

procedure SortJournalMetadata(
  var Metadata: TJournalObjectMetadataArray;
  SortColumn: Integer;
  Ascending: Boolean
);

  procedure QuickSort(L, R: Integer);
  var
    I, J: Integer;
    Pivot: TJournalObjectMetadata;
    Temp: TJournalObjectMetadata;
    C: Integer;
  begin
    I := L;
    J := R;
    Pivot := Metadata[(L + R) div 2];

    repeat
      repeat
        C := CompareJournalMetadata(
          Metadata[I],
          Pivot,
          SortColumn
        );

        if not Ascending then
          C := -C;

        if C < 0 then
          Inc(I);
      until C >= 0;

      repeat
        C := CompareJournalMetadata(
          Metadata[J],
          Pivot,
          SortColumn
        );

        if not Ascending then
          C := -C;

        if C > 0 then
          Dec(J);
      until C <= 0;

      if I <= J then
      begin
        Temp := Metadata[I];
        Metadata[I] := Metadata[J];
        Metadata[J] := Temp;

        Inc(I);
        Dec(J);
      end;

    until I > J;

    if L < J then
      QuickSort(L, J);

    if I < R then
      QuickSort(I, R);
  end;

begin
  if Length(Metadata) <= 1 then
    Exit;

  QuickSort(0, High(Metadata));
end;

procedure TMainForm.QuestGridHeaderClick(
  Sender: TObject;
  IsColumn: Boolean;
  Index: Integer
);
begin
  if not IsColumn then
    Exit;

  if Index = FSortColumn then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := Index;
    FSortAscending := True;
  end;

  PopulateQuestGrid;
end;

procedure TMainForm.LoreGridHeaderClick(
  Sender: TObject;
  IsColumn: Boolean;
  Index: Integer
);
begin
  if not IsColumn then
    Exit;

  if Index = FLoreSortColumn then
    FLoreSortAscending := not FLoreSortAscending
  else
  begin
    FLoreSortColumn := Index;
    FLoreSortAscending := True;
  end;

  PopulateLoreGrid;
end;

procedure TMainForm.QuestsFilterChange(Sender: TObject);
begin
     if Length(FKnowledge) = 0 then
        Exit;

     PopulateQuestGrid;
end;

procedure TMainForm.SaveRefreshTimerTimer(Sender: TObject);
begin
     RefreshSaveIfNeeded;
end;

procedure TMainForm.RefreshSaveIfNeeded;
var
  CharactersFileName: string;
  NewStamp: LongInt;
  NewSize: Int64;
begin
  if FRefreshingSave then
    Exit;

  if FIndexFileName = '' then
    Exit;

  FRefreshingSave := True;

  try
    try
      CharactersFileName :=
        ResolveCharactersSave(
          FIndexFileName
        );

      NewStamp :=
        FileAge(
          CharactersFileName
        );

      NewSize :=
        GetSaveFileSize(
          CharactersFileName
        );

      if
        (CharactersFileName <> FSaveFileName) or
        (NewStamp <> FSaveFileStamp) or
        (NewSize <> FSaveFileSize)
      then
      begin
        LoadCharactersFile(
          CharactersFileName
        );

        FSaveFileStamp := NewStamp;
        FSaveFileSize := NewSize;
      end;

    except
      {
        Enshrouded peut être précisément en train de remplacer
        characters-N ou characters-index.
        On ne fait rien : le prochain tick réessaiera.
      }
    end;

  finally
    FRefreshingSave := False;
  end;
end;

procedure TMainForm.LoadTestJournal;
var
  GamePath: string;
  KFCFileName: string;
  KFCResourcesFileName: string;

  Data: TBytes;

  Quests: TJournalQuestArray;
  Collections: TJournalCollectionArray;
begin
  FSortColumn := 0;
  FSortAscending := True;

  FJournalRoot.Free;
  FJournalRoot := nil;

  FLoreSortColumn := 0;
  FLoreSortAscending := True;

  {
    Temporairement, on déduit le répertoire du jeu
    depuis le fichier de localisation déjà connu.
  }
  GamePath :=
    ExtractFilePath(
      TEST_LOCALIZATION_FILE
    );

  KFCFileName :=
    GamePath +
    'enshrouded.kfc';

  KFCResourcesFileName :=
    GamePath +
    'enshrouded.kfc_resources';

  Data :=
    ExtractKFCResource(
      KFCFileName,
      KFCResourcesFileName,
      '33701b26-ec1d-423f-8e06-49f023b91b7f',
      $60B5ED8A,
      0
    );

  ParseJournalQuests(
    Data,
    Quests
  );

  ParseJournalCollections(
    Data,
    Collections
  );

  FJournalRoot :=
    BuildJournalJSON(
      Quests,
      Collections
    );
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

procedure TMainForm.PopulateQuestGrid();
var
  Metadata: TJournalObjectMetadataArray;
  I: Integer;
  Row: Integer;
  StatusText: string;
  QuestCount: Integer;
  CompletedCount: Integer;
  NotCompletedCount: Integer;
  ResolvedUnknownCount: Integer;
  PlayerQuestCount: Integer;
  PlayerQuestCompletedCount: Integer;

  WorldQuestCount: Integer;
  WorldQuestCompletedCount: Integer;

  AutoQuestCount: Integer;
  AutoQuestResolvedCount: Integer;
begin
  CollectJournalMetadata(
    FJournalRoot,
    FKnowledge,
    FLocalization,
    Metadata
  );

  SortJournalMetadata(
                      Metadata,
                      FSortColumn,
                      FSortAscending
                      );

  QuestGrid.BeginUpdate;
  try
    QuestGrid.RowCount := 1;
    Row := 1;
    QuestCount := 0;
    CompletedCount := 0;
    NotCompletedCount := 0;
    ResolvedUnknownCount := 0;
    PlayerQuestCount := 0;
    PlayerQuestCompletedCount := 0;

    WorldQuestCount := 0;
    WorldQuestCompletedCount := 0;

    AutoQuestCount := 0;
    AutoQuestResolvedCount := 0;

    for I := 0 to High(Metadata) do
    begin
      if Metadata[I].Family <> jfQuest then
        Continue;

      Inc(QuestCount);

      case Metadata[I].PersonalStatus of
           qpsCompletedPersonally: Inc(CompletedCount);
           qpsNotCompleted: Inc(NotCompletedCount);
           qpsResolvedUnknownOrigin: Inc(ResolvedUnknownCount);
      end;

      if SameText(Metadata[I].RawType, 'PlayerQuest') then
         begin
              Inc(PlayerQuestCount);

              if Metadata[I].PersonalStatus = qpsCompletedPersonally then
                 Inc(PlayerQuestCompletedCount);
         end
         else if SameText(Metadata[I].RawType, 'WorldQuest') then
              begin
                   Inc(WorldQuestCount);

                   if Metadata[I].PersonalStatus = qpsCompletedPersonally then
                      Inc(WorldQuestCompletedCount);
              end
         else if SameText(Metadata[I].RawType, 'Auto') then
              begin
                   Inc(AutoQuestCount);

                   if Metadata[I].PersonalStatus = qpsResolvedUnknownOrigin then
                      Inc(AutoQuestResolvedCount);
              end;

      case QuestTypeFilterComboBox.ItemIndex of
           1:
             if not SameText(Metadata[I].RawType, 'Auto') then
                Continue;

           2:
             if not SameText(Metadata[I].RawType, 'PlayerQuest') then
                Continue;

           3:
             if not SameText(Metadata[I].RawType, 'WorldQuest') then
                Continue;
      end;
      case QuestsStatusFilterComboBox.ItemIndex of
           1:
             if Metadata[I].PersonalStatus <> qpsNotCompleted then
                Continue;

           2:
             if Metadata[I].PersonalStatus <> qpsCompletedPersonally then
                Continue;

           3:
             if Metadata[I].PersonalStatus <> qpsResolvedUnknownOrigin then
                Continue;
      end;

      case Metadata[I].PersonalStatus of
        qpsNotCompleted:
          StatusText := 'Not completed';

        qpsCompletedPersonally:
          StatusText := 'Completed personally';

        qpsResolvedUnknownOrigin:
          StatusText := 'Resolved - origin unknown';
      else
        StatusText := 'Unknown';
      end;

      QuestGrid.RowCount := Row + 1;

      QuestGrid.Cells[0, Row] := Metadata[I].Name;
      QuestGrid.Cells[1, Row] := Metadata[I].RawType;
      QuestGrid.Cells[2, Row] := StatusText;
      QuestGrid.Cells[3, Row] :=
        '$' + IntToHex(Metadata[I].ID, 8);

      Inc(Row);
    end;
    QuestsSummaryLabel.Caption :=
                              Format(
                                     'PlayerQuest %d/%d - WorldQuest %d/%d - Auto %d/%d',
                                     [
                                      PlayerQuestCompletedCount,
                                      PlayerQuestCount,
                                      WorldQuestCompletedCount,
                                      WorldQuestCount,
                                      AutoQuestResolvedCount,
                                      AutoQuestCount
                                     ]
                              );
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
begin
  if not OpenSaveDialog.Execute then
    Exit;

  LoadCharactersFile(
    OpenSaveDialog.FileName
  );
end;

procedure TMainForm.CharacterComboBoxChange(Sender: TObject);
var
  Blob: TBytes;
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
    FKnowledge
  );

  PopulateQuestGrid;
  PopulateLoreGrid;
end;

procedure TMainForm.FormCreate(
  Sender: TObject
);
var
  CharactersFileName: string;
begin
  LoadTestJournal;
  LoadTestLocalization;
  FRefreshingSave := False;

  if not FindEnshroudedCharactersIndex(FIndexFileName)
  then
    Exit;

  try
    CharactersFileName := ResolveCharactersSave(FIndexFileName);

    LoadCharactersFile(CharactersFileName);

    FSaveFileStamp := FileAge(CharactersFileName);

    FSaveFileSize := GetSaveFileSize(CharactersFileName);

    SaveRefreshTimer.Enabled := True;

  except
    on E: Exception do
      ShowMessage(
        'Unable to automatically load Enshrouded save:' +
        LineEnding +
        E.Message
      );
  end;
end;

procedure TMainForm.LoreFilterChange(Sender: TObject);
begin
     if Length(FKnowledge) = 0 then
        Exit;

     PopulateLoreGrid;
end;

procedure TMainForm.PopulateLoreGrid;
var
  Metadata: TJournalObjectMetadataArray;
  I: Integer;
  Row: Integer;
  StatusText: string;
  LoreCount: Integer;
  UndiscoveredCount: Integer;
  PartialCount: Integer;
  CompleteCount: Integer;
begin
  CollectJournalMetadata(
    FJournalRoot,
    FKnowledge,
    FLocalization,
    Metadata
  );

  SortLoreMetadata(
                   Metadata,
                   FLoreSortColumn,
                   FLoreSortAscending
                   );

  LoreGrid.BeginUpdate;
  try
    LoreGrid.RowCount := 1;
    Row := 1;
    LoreCount := 0;
    UndiscoveredCount := 0;
    PartialCount := 0;
    CompleteCount := 0;

    for I := 0 to High(Metadata) do
    begin
      if Metadata[I].Family <> jfLore then
        Continue;

      Inc(LoreCount);

      case Metadata[I].LoreStatus of
           lsUndiscovered: Inc(UndiscoveredCount);
           lsPartial: Inc(PartialCount);
           lsComplete: Inc(CompleteCount);
      end;
      case LoreStatusFilterComboBox.ItemIndex of
           1: if Metadata[I].LoreStatus <> lsUndiscovered then Continue;
           2: if Metadata[I].LoreStatus <> lsPartial then Continue;
           3: if Metadata[I].LoreStatus <> lsComplete then Continue;
      end;

      case Metadata[I].LoreStatus of
        lsUndiscovered:
          StatusText := 'Undiscovered';

        lsPartial:
          StatusText := 'Partial';

        lsComplete:
          StatusText := 'Complete';

      else
        StatusText := 'Unknown';
      end;

      LoreGrid.RowCount := Row + 1;

      LoreGrid.Cells[0, Row] :=
        Metadata[I].Name;

      LoreGrid.Cells[1, Row] :=
        Format(
          '%d/%d',
          [
            Metadata[I].LoreDiscoveredEntries,
            Metadata[I].EntryCount
          ]
        );

      LoreGrid.Cells[2, Row] :=
        StatusText;

      LoreGrid.Cells[3, Row] :=
        '$' + IntToHex(Metadata[I].ID, 8);

      Inc(Row);
    end;
    LoreSummaryLabel.Caption :=
                             Format(
                                    'Lore: %d complete / %d partial / %d undiscovered - %d total',
                                    [
                                           CompleteCount,
                                           PartialCount,
                                           UndiscoveredCount,
                                           LoreCount
                                    ]
                             );
  finally
    LoreGrid.EndUpdate;
  end;
end;

end.
