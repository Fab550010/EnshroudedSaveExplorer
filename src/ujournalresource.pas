unit uJournalResource;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TJournalCompareOperator = (
    jcoGreaterThan,
    jcoLessThan,
    jcoEquals
  );

  TJournalRequirementType = (
    jrtExtern,
    jrtSimpleBool,
    jrtSimpleCount,
    jrtSimpleFlag
  );

  TJournalRequirement = record
    KnowledgeOrQueryID: Cardinal;
    CompareValue: Cardinal;
    CompareOperator: TJournalCompareOperator;
    RequirementType: TJournalRequirementType;
    IsExplicitPlayerKnowledgeQuery: Boolean;
  end;

  TJournalRequirementArray =
    array of TJournalRequirement;

  TJournalEntry = record
    EntryID: Cardinal;
    NameID: Cardinal;
    TextID: Cardinal;
    MapMarkerReferenceID: Cardinal;

    KnowledgeRequirement: TJournalRequirement;
    CompletionRequirement: TJournalRequirement;

    ProgressStepsRequirements:
      TJournalRequirementArray;

    ItemIconID: Cardinal;
    RecommendedLevel: Byte;
  end;

  type
  TJournalQuestSource = (
    jqsNone,
    jqsFlame,
    jqsBlacksmith,
    jqsAlchemist,
    jqsHuntress,
    jqsFarmer,
    jqsCarpenter,
    jqsCryptKeeper,
    jqsBard,
    jqsChineseNewYearTrader,
    jqsBarber,
    jqsFisher,
    jqsAncientResearcher,
    jqsGrassland,
    jqsDeepforest,
    jqsSteppes,
    jqsDesert,
    jqsColdHeights,
    jqsWetlands
  );

  TJournalQuestType = (
    jqtAuto,
    jqtWorldQuest,
    jqtPlayerQuest
  );

  type
  TJournalEntryArray =
    array of TJournalEntry;

  TJournalObject = record
    EntryID: Cardinal;
    LoreCategoryID: Cardinal;
    NameID: Cardinal;
    ReferencedDocumentNameID: Cardinal;

    Priority: Cardinal;
    IsTutorial: Boolean;

    Entries: TJournalEntryArray;
  end;



  type
  TJournalQuest = record
    Base: TJournalObject;

    Source: TJournalQuestSource;
    QuestType: TJournalQuestType;
    UnlockForAllPlayers: Boolean;
  end;

  TJournalCollection = record
    Base: TJournalObject;
  end;

  TJournalQuestArray =
    array of TJournalQuest;

  TJournalCollectionArray =
    array of TJournalCollection;





procedure ParseJournalCollections(
  const Data: TBytes;
  out Collections: TJournalCollectionArray
);
procedure ParseJournalQuests(
  const Data: TBytes;
  out Quests: TJournalQuestArray
);

function JournalQuestSourceText(
  Value: TJournalQuestSource
): string;

function JournalQuestTypeText(
  Value: TJournalQuestType
): string;

function JournalCompareOperatorText(
  Value: TJournalCompareOperator
): string;

function JournalRequirementTypeText(
  Value: TJournalRequirementType
): string;

implementation

function JournalQuestSourceText(
  Value: TJournalQuestSource
): string;
begin
  case Value of
    jqsNone:                 Result := 'None';
    jqsFlame:                Result := 'Flame';
    jqsBlacksmith:           Result := 'Blacksmith';
    jqsAlchemist:            Result := 'Alchemist';
    jqsHuntress:             Result := 'Huntress';
    jqsFarmer:               Result := 'Farmer';
    jqsCarpenter:            Result := 'Carpenter';
    jqsCryptKeeper:          Result := 'CryptKeeper';
    jqsBard:                 Result := 'Bard';
    jqsChineseNewYearTrader: Result := 'ChineseNewYearTrader';
    jqsBarber:               Result := 'Barber';
    jqsFisher:               Result := 'Fisher';
    jqsAncientResearcher:    Result := 'AncientResearcher';
    jqsGrassland:            Result := 'Grassland';
    jqsDeepforest:           Result := 'Deepforest';
    jqsSteppes:              Result := 'Steppes';
    jqsDesert:               Result := 'Desert';
    jqsColdHeights:          Result := 'ColdHeights';
    jqsWetlands:             Result := 'Wetlands';
  else
    Result := 'Unknown';
  end;
end;

function JournalQuestTypeText(
  Value: TJournalQuestType
): string;
begin
  case Value of
    jqtAuto:
      Result := 'Auto';

    jqtWorldQuest:
      Result := 'WorldQuest';

    jqtPlayerQuest:
      Result := 'PlayerQuest';

  else
    Result := 'Unknown';
  end;
end;

function JournalCompareOperatorText(
  Value: TJournalCompareOperator
): string;
begin
  case Value of
    jcoGreaterThan:
      Result := 'GreaterThan';

    jcoLessThan:
      Result := 'LessThan';

    jcoEquals:
      Result := 'Equals';

  else
    Result := 'Unknown';
  end;
end;

function JournalRequirementTypeText(
  Value: TJournalRequirementType
): string;
begin
  case Value of
    jrtExtern:
      Result := 'Extern';

    jrtSimpleBool:
      Result := 'SimpleBool';

    jrtSimpleCount:
      Result := 'SimpleCount';

    jrtSimpleFlag:
      Result := 'SimpleFlag';

  else
    Result := 'Unknown';
  end;
end;

function DecodeQuestSource(
  Value: Byte
): TJournalQuestSource;
begin
  if Value > Ord(High(TJournalQuestSource)) then
    raise Exception.CreateFmt(
      'Unknown quest source: %d',
      [Value]
    );

  Result :=
    TJournalQuestSource(Value);
end;

function DecodeQuestType(
  Value: Byte
): TJournalQuestType;
begin
  if Value > Ord(High(TJournalQuestType)) then
    raise Exception.CreateFmt(
      'Unknown quest type: %d',
      [Value]
    );

  Result :=
    TJournalQuestType(Value);
end;

function ReadU32(
  const Data: TBytes;
  Offset: QWord
): Cardinal;
begin
  if Offset + 4 > QWord(Length(Data)) then
    raise Exception.Create(
      'ReadU32 out of bounds'
    );

  Move(
    Data[Offset],
    Result,
    4
  );
end;

function ReadU8(
  const Data: TBytes;
  Offset: QWord
): Byte;
begin
  if Offset >= QWord(Length(Data)) then
    raise Exception.Create(
      'ReadU8 out of bounds'
    );

  Result := Data[Offset];
end;

function DecodeCompareOperator(
  Value: Byte
): TJournalCompareOperator;
begin
  case Value of
    0:
      Result := jcoGreaterThan;

    1:
      Result := jcoLessThan;

    2:
      Result := jcoEquals;

  else
    raise Exception.CreateFmt(
      'Unknown compare operator: %d',
      [Value]
    );
  end;
end;

function DecodeRequirementType(
  Value: Byte
): TJournalRequirementType;
begin
  case Value of
    0:
      Result := jrtExtern;

    1:
      Result := jrtSimpleBool;

    2:
      Result := jrtSimpleCount;

    3:
      Result := jrtSimpleFlag;

  else
    raise Exception.CreateFmt(
      'Unknown requirement type: %d',
      [Value]
    );
  end;
end;

function ParseRequirement(
  const Data: TBytes;
  Offset: QWord
): TJournalRequirement;
begin
  Result.KnowledgeOrQueryID :=
    ReadU32(
      Data,
      Offset
    );

  Result.CompareValue :=
    ReadU32(
      Data,
      Offset + 4
    );

  Result.CompareOperator :=
    DecodeCompareOperator(
      ReadU8(
        Data,
        Offset + 8
      )
    );

  Result.RequirementType :=
    DecodeRequirementType(
      ReadU8(
        Data,
        Offset + 9
      )
    );

  Result.IsExplicitPlayerKnowledgeQuery :=
    ReadU8(
      Data,
      Offset + 10
    ) <> 0;
end;



function ParseJournalEntry(
  const Data: TBytes;
  EntryOffset: QWord
): TJournalEntry;
var
  ProgressFieldOffset: QWord;
  ProgressRelativeOffset: Cardinal;
  ProgressCount: Cardinal;
  ProgressOffset: QWord;
  I: Cardinal;
begin
  Result.EntryID :=
    ReadU32(
      Data,
      EntryOffset
    );

  Result.NameID :=
    ReadU32(
      Data,
      EntryOffset + 4
    );

  Result.TextID :=
    ReadU32(
      Data,
      EntryOffset + 8
    );

  Result.MapMarkerReferenceID :=
    ReadU32(
      Data,
      EntryOffset + 12
    );

  Result.KnowledgeRequirement :=
    ParseRequirement(
      Data,
      EntryOffset + 16
    );

  Result.CompletionRequirement :=
    ParseRequirement(
      Data,
      EntryOffset + 28
    );

  ProgressFieldOffset :=
    EntryOffset + 40;

  ProgressRelativeOffset :=
    ReadU32(
      Data,
      ProgressFieldOffset
    );

  ProgressCount :=
    ReadU32(
      Data,
      ProgressFieldOffset + 4
    );

  SetLength(
    Result.ProgressStepsRequirements,
    ProgressCount
  );

  if ProgressCount > 0 then
  begin
    ProgressOffset :=
      ProgressFieldOffset +
      ProgressRelativeOffset;

    for I := 0 to ProgressCount - 1 do
      Result.ProgressStepsRequirements[I] :=
        ParseRequirement(
          Data,
          ProgressOffset +
          QWord(I) * 12
        );
  end;

  Result.ItemIconID :=
    ReadU32(
      Data,
      EntryOffset + 64
    );

  Result.RecommendedLevel :=
    ReadU8(
      Data,
      EntryOffset + 68
    );
end;

function ParseJournalObject(
  const Data: TBytes;
  ObjectOffset: QWord
): TJournalObject;
var
  EntriesFieldOffset: QWord;
  EntriesRelativeOffset: Cardinal;
  EntriesCount: Cardinal;
  EntriesOffset: QWord;
  I: Cardinal;
begin
  Result.EntryID :=
    ReadU32(
      Data,
      ObjectOffset
    );

  Result.LoreCategoryID :=
    ReadU32(
      Data,
      ObjectOffset + 4
    );

  Result.NameID :=
    ReadU32(
      Data,
      ObjectOffset + 8
    );

  Result.ReferencedDocumentNameID :=
    ReadU32(
      Data,
      ObjectOffset + 12
    );

  Result.Priority :=
    ReadU32(
      Data,
      ObjectOffset + 16
    );

  Result.IsTutorial :=
    ReadU8(
      Data,
      ObjectOffset + 20
    ) <> 0;

  EntriesFieldOffset :=
    ObjectOffset + 24;

  EntriesRelativeOffset :=
    ReadU32(
      Data,
      EntriesFieldOffset
    );

  EntriesCount :=
    ReadU32(
      Data,
      EntriesFieldOffset + 4
    );

  SetLength(
    Result.Entries,
    EntriesCount
  );

  if EntriesCount = 0 then
    Exit;

  EntriesOffset :=
    EntriesFieldOffset +
    EntriesRelativeOffset;

  for I := 0 to EntriesCount - 1 do
    Result.Entries[I] :=
      ParseJournalEntry(
        Data,
        EntriesOffset +
        QWord(I) * 72
      );
end;

function ParseJournalCollection(
  const Data: TBytes;
  CollectionOffset: QWord
): TJournalCollection;
begin
  Result.Base :=
    ParseJournalObject(
      Data,
      CollectionOffset
    );
end;

procedure ParseJournalCollections(
  const Data: TBytes;
  out Collections: TJournalCollectionArray
);
var
  CollectionsFieldOffset: QWord;
  CollectionsRelativeOffset: Cardinal;
  CollectionsCount: Cardinal;
  CollectionsOffset: QWord;
  I: Cardinal;
begin
  {
    JournalRegistryResource.collections @8
  }

  CollectionsFieldOffset := 8;

  CollectionsRelativeOffset :=
    ReadU32(
      Data,
      CollectionsFieldOffset
    );

  CollectionsCount :=
    ReadU32(
      Data,
      CollectionsFieldOffset + 4
    );

  SetLength(
    Collections,
    CollectionsCount
  );

  CollectionsOffset :=
    CollectionsFieldOffset +
    CollectionsRelativeOffset;

  for I := 0 to CollectionsCount - 1 do
    Collections[I] :=
      ParseJournalCollection(
        Data,
        CollectionsOffset +
        QWord(I) * 32
      );
end;

function ParseJournalQuest(
  const Data: TBytes;
  QuestOffset: QWord
): TJournalQuest;
begin
  Result.Base :=
    ParseJournalObject(
      Data,
      QuestOffset
    );

  Result.Source :=
    DecodeQuestSource(
      ReadU8(
        Data,
        QuestOffset + 32
      )
    );

  Result.QuestType :=
    DecodeQuestType(
      ReadU8(
        Data,
        QuestOffset + 33
      )
    );

  Result.UnlockForAllPlayers :=
    ReadU8(
      Data,
      QuestOffset + 34
    ) <> 0;
end;

procedure ParseJournalQuests(
  const Data: TBytes;
  out Quests: TJournalQuestArray
);
var
  QuestsFieldOffset: QWord;
  QuestsRelativeOffset: Cardinal;
  QuestsCount: Cardinal;
  QuestsOffset: QWord;
  I: Cardinal;
begin
  {
    JournalRegistryResource.quests @0
  }

  QuestsFieldOffset := 0;

  QuestsRelativeOffset :=
    ReadU32(
      Data,
      QuestsFieldOffset
    );

  QuestsCount :=
    ReadU32(
      Data,
      QuestsFieldOffset + 4
    );

  SetLength(
    Quests,
    QuestsCount
  );

  QuestsOffset :=
    QuestsFieldOffset +
    QuestsRelativeOffset;

  for I := 0 to QuestsCount - 1 do
    Quests[I] :=
      ParseJournalQuest(
        Data,
        QuestsOffset +
        QWord(I) * 44
      );
end;

end.
