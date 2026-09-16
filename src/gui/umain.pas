unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, ComCtrls,
  Grids, uKnowledgeBlob, uKnowledge, fpjson, uJournalEvaluator,
  uLocalization, USaveIndex, uSteamDiscovery, ucharacterdata, uBDB,
  uKFC, uJournalResource, uJournalJSON, Types;

type

  { TMainForm }

  TMainForm = class(TForm)
    CharacterComboBox: TComboBox;
    LoreSearchEdit: TEdit;
    QuestSearchEdit: TEdit;
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
    procedure GridMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure SearchEditChange(Sender: TObject);
    procedure QuestGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer; aState: TGridDrawState);
    procedure LoreGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer; aState: TGridDrawState);
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
    FGamePath: string;
    FCurrentOwnerID: Cardinal;
    procedure UpdateQuestSortIndicator;
    procedure UpdateLoreSortIndicator;
    procedure LoadJournal;
    procedure LoadLocalization;
    procedure PopulateQuestGrid;
    procedure PopulateLoreGrid;
    procedure LoadCharactersFile(const Filename : string);
    procedure RefreshSaveIfNeeded;
    function GetSaveFileSize(const FileName: string): Int64;
    procedure RestoreGridState(Grid: TStringGrid; OldTopRow: Integer; const SelectedID: string);
    function GetSelectedGridID(Grid: TStringGrid; IDColumn: Integer): string;
  public
    destructor Destroy; override;
  end;

const
    TEST_LOCALIZATION_SEED = $3F95ABE0;

var
  MainForm: TMainForm;


implementation

{$R *.lfm}

{ TMainForm }

function TMainForm.GetSelectedGridID(
  Grid: TStringGrid;
  IDColumn: Integer
): string;
begin
  Result := '';

  if Grid.Row < Grid.FixedRows then
    Exit;

  if Grid.Row >= Grid.RowCount then
    Exit;

  Result :=
    Grid.Cells[
      IDColumn,
      Grid.Row
    ];
end;

procedure TMainForm.RestoreGridState(
  Grid: TStringGrid;
  OldTopRow: Integer;
  const SelectedID: string
);
var
  I: Integer;
  IDColumn: Integer;
begin
  if Grid = QuestGrid then
    IDColumn := 4
  else if Grid = LoreGrid then
    IDColumn := 3
  else
    Exit;

  {
    Restore selected logical object.
  }
  if SelectedID <> '' then
  begin
    for I := Grid.FixedRows to Grid.RowCount - 1 do
    begin
      if Grid.Cells[IDColumn, I] = SelectedID then
      begin
        Grid.Row := I;
        Break;
      end;
    end;
  end;

  {
    Restore viewport position, clamped to the
    rebuilt grid.
  }
  if Grid.RowCount <= Grid.FixedRows then
    Exit;

  if OldTopRow < Grid.FixedRows then
    OldTopRow := Grid.FixedRows;

  if OldTopRow >= Grid.RowCount then
    OldTopRow := Grid.RowCount - 1;

  Grid.TopRow := OldTopRow;
end;


procedure TMainForm.QuestGridPrepareCanvas(
  Sender: TObject;
  aCol, aRow: Integer;
  aState: TGridDrawState
);
var
  Status: string;
begin
  if aRow < QuestGrid.FixedRows then
    Exit;

  if aCol <> 3 then
    Exit;

  if gdSelected in aState then
    Exit;

  Status := QuestGrid.Cells[aCol, aRow];

  if Status = 'Completed personally' then
    QuestGrid.Canvas.Brush.Color := RGBToColor(225, 245, 225)
  else if Status = 'Resolved - origin unknown' then
    QuestGrid.Canvas.Brush.Color := RGBToColor(255, 245, 210)
  else if Status = 'Not completed' then
    QuestGrid.Canvas.Brush.Color := RGBToColor(245, 245, 245);
end;

procedure TMainForm.LoreGridPrepareCanvas(
  Sender: TObject;
  aCol, aRow: Integer;
  aState: TGridDrawState
);
var
  Status: string;
begin
  if aRow < LoreGrid.FixedRows then
    Exit;

  if aCol <> 2 then
    Exit;

  if gdSelected in aState then
    Exit;

  Status := LoreGrid.Cells[aCol, aRow];

  if Status = 'Complete' then
    LoreGrid.Canvas.Brush.Color := RGBToColor(225, 245, 225)
  else if Status = 'Partial' then
    LoreGrid.Canvas.Brush.Color := RGBToColor(255, 245, 210)
  else if Status = 'Undiscovered' then
    LoreGrid.Canvas.Brush.Color := RGBToColor(245, 245, 245);
end;

procedure TMainForm.UpdateQuestSortIndicator;
const
  COLUMN_NAMES: array[0..4] of string = (
    'Name',
    'Type',
    'Source',
    'Status',
    'ID'
  );
var
  I: Integer;
begin
  for I := 0 to High(COLUMN_NAMES) do
    QuestGrid.Columns[I].Title.Caption :=
      COLUMN_NAMES[I];

  if
    (FSortColumn >= 0) and
    (FSortColumn <= High(COLUMN_NAMES))
  then
  begin
    if FSortAscending then
      QuestGrid.Columns[FSortColumn].Title.Caption :=
        COLUMN_NAMES[FSortColumn] + ' ▲'
    else
      QuestGrid.Columns[FSortColumn].Title.Caption :=
        COLUMN_NAMES[FSortColumn] + ' ▼';
  end;
end;

procedure TMainForm.UpdateLoreSortIndicator;
const
  COLUMN_NAMES: array[0..3] of string = (
    'Name',
    'Progress',
    'Status',
    'ID'
  );
var
  I: Integer;
begin
  for I := 0 to High(COLUMN_NAMES) do
    LoreGrid.Columns[I].Title.Caption :=
      COLUMN_NAMES[I];

  if
    (FLoreSortColumn >= 0) and
    (FLoreSortColumn <= High(COLUMN_NAMES))
  then
  begin
    if FLoreSortAscending then
      LoreGrid.Columns[FLoreSortColumn].Title.Caption :=
        COLUMN_NAMES[FLoreSortColumn] + ' ▲'
    else
      LoreGrid.Columns[FLoreSortColumn].Title.Caption :=
        COLUMN_NAMES[FLoreSortColumn] + ' ▼';
  end;
end;

procedure TMainForm.GridMouseWheel(
  Sender: TObject;
  Shift: TShiftState;
  WheelDelta: Integer;
  MousePos: TPoint;
  var Handled: Boolean
);
const
  ROWS_PER_WHEEL_STEP = 5;
var
  Grid: TStringGrid;
  NewTopRow: Integer;
begin
  if not (Sender is TStringGrid) then
    Exit;

  Grid := TStringGrid(Sender);

  NewTopRow := Grid.TopRow;

  if WheelDelta > 0 then
    Dec(
      NewTopRow,
      ROWS_PER_WHEEL_STEP
    )
  else if WheelDelta < 0 then
    Inc(
      NewTopRow,
      ROWS_PER_WHEEL_STEP
    );

  if NewTopRow < Grid.FixedRows then
    NewTopRow := Grid.FixedRows;

  if NewTopRow >= Grid.RowCount then
    NewTopRow := Grid.RowCount - 1;

  Grid.TopRow := NewTopRow;

  Handled := True;
end;

procedure TMainForm.SearchEditChange(Sender: TObject);
begin
     if Sender = QuestSearchEdit then
     begin
          if Length(FKnowledge) = 0 then
             Exit;
          PopulateQuestGrid;
     end
     else if Sender = LoreSearchEdit then
     begin
          if Length(FKnowledge) = 0 then
             Exit;
          PopulateLoreGrid;
     end;
end;

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

    // Name
    0:
      begin
        Result := CompareText(A.Name, B.Name);

        if Result = 0 then
          Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareText(A.Source, B.Source);
      end;

    // Type
    1:
      begin
        Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareText(A.Source, B.Source);

        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
      end;

    // Source
    2:
      begin
        Result := CompareText(A.Source, B.Source);

        if Result = 0 then
          Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
      end;

    // Status
    3:
      begin
        Result :=
          CompareQuestStatus(
            A.PersonalStatus,
            B.PersonalStatus
          );

        if Result = 0 then
          Result := CompareText(A.RawType, B.RawType);

        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
      end;

    // ID
    4:
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

function SameKnowledge(
  const A, B: TKnowledgeItems
): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);

  for I := 0 to High(A) do
  begin
    if A[I].ID <> B[I].ID then
      Exit(False);

    if A[I].Value <> B[I].Value then
      Exit(False);
  end;

  Result := True;
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

  UpdateQuestSortIndicator;
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

  UpdateLoreSortIndicator;
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
  QuestTopRow: Integer;
  LoreTopRow: Integer;
  SelectedQuestID: string;
  SelectedLoreID: string;
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
        QuestTopRow := QuestGrid.TopRow;
        LoreTopRow := LoreGrid.TopRow;
        SelectedQuestID := GetSelectedGridID(QuestGrid, 4);
        SelectedLoreID := GetSelectedGridID(LoreGrid, 3);

        LoadCharactersFile(CharactersFileName);

        RestoreGridState(QuestGrid, QuestTopRow, SelectedQuestID);
        RestoreGridState(LoreGrid, LoreTopRow, SelectedLoreID);

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

procedure TMainForm.LoadJournal;
var
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

  KFCFileName :=
  IncludeTrailingPathDelimiter(
    FGamePath
  ) +
  'enshrouded.kfc';

KFCResourcesFileName :=
  IncludeTrailingPathDelimiter(
    FGamePath
  ) +
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

  UpdateQuestSortIndicator;
  UpdateLoreSortIndicator;
end;

procedure TMainForm.LoadLocalization;
var
  SearchRec: TSearchRec;
  CandidateFileName: string;

  CandidateItems: TLocalizationItems;
  BestItems: TLocalizationItems;

  BestFileName: string;
begin
  SetLength(FLocalization, 0);
  SetLength(BestItems, 0);

  BestFileName := '';

  if FindFirst(
       IncludeTrailingPathDelimiter(FGamePath) +
       'enshrouded_*.dat',
       faAnyFile,
       SearchRec
     ) <> 0
  then
    raise Exception.CreateFmt(
      'No Enshrouded .dat files found in %s',
      [FGamePath]
    );

  try
    repeat
      if
        (SearchRec.Attr and faDirectory) <> 0
      then
        Continue;

      CandidateFileName :=
        IncludeTrailingPathDelimiter(
          FGamePath
        ) +
        SearchRec.Name;

      SetLength(
        CandidateItems,
        0
      );

      if LoadLocalizationTable(
           CandidateFileName,
           TEST_LOCALIZATION_SEED,
           CandidateItems
         )
      then
      begin
        {
          If more than one .dat happens to contain
          a plausible table at this offset, keep the
          one containing the most localization entries.
        }
        if
          Length(CandidateItems) >
          Length(BestItems)
        then
        begin
          BestItems :=
            CandidateItems;

          BestFileName :=
            CandidateFileName;
        end;
      end;

    until FindNext(SearchRec) <> 0;

  finally
    FindClose(SearchRec);
  end;

  if BestFileName = '' then
    raise Exception.CreateFmt(
      'Unable to locate the Enshrouded localization table in %s',
      [FGamePath]
    );

  FLocalization :=
    BestItems;
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

      if (QuestSearchEdit.Text <> '') and (Pos(LowerCase(QuestSearchEdit.Text), LowerCase(Metadata[I].Name) ) = 0)
         then Continue;

      QuestGrid.RowCount := Row + 1;

      QuestGrid.Cells[0, Row] := Metadata[I].Name;
      QuestGrid.Cells[1, Row] := Metadata[I].RawType;
      QuestGrid.Cells[2, Row] := Metadata[I].Source;
      QuestGrid.Cells[3, Row] := StatusText;
      QuestGrid.Cells[4, Row] :=
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
  NewKnowledge: TKnowledgeItems;
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
    NewKnowledge
  );

  if (OwnerID = FCurrentOwnerID) and SameKnowledge(FKnowledge,NewKnowledge)
  then
      Exit;

  FCurrentOwnerID := OwnerID;
  FKnowledge := NewKnowledge;

  PopulateQuestGrid;
  PopulateLoreGrid;
end;

procedure TMainForm.FormCreate(
  Sender: TObject
);
var
  CharactersFileName: string;
begin
     FCurrentOwnerID := 0;
  if not FindEnshroudedInstallPath(
           FGamePath
         )
  then
  begin
    ShowMessage(
      'Unable to locate the Enshrouded installation.'
    );

    Exit;
  end;

  try
    LoadJournal;
    LoadLocalization;
  except
    on E: Exception do
    begin
      ShowMessage(
        'Unable to load Enshrouded game data:' +
        LineEnding +
        E.Message
      );

      Exit;
    end;
  end;

  FRefreshingSave := False;

  if not FindEnshroudedCharactersIndex(
           FIndexFileName
         )
  then
    Exit;

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

      if (LoreSearchEdit.Text <> '') and (Pos(LowerCase(LoreSearchEdit.Text), LowerCase(Metadata[I].Name) ) = 0)
         then Continue;

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
