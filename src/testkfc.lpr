program testkfc;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes
  { you can add units after this }, SysUtils, uKFC, uReflection,
  uJournalResource, uJournalJSON, fpjson, uJournalEvaluator, uSteamDiscovery;

var
  Data: TBytes;
  F: TFileStream;
  Collections: TJournalCollectionArray;
  Quests: TJournalQuestArray;
  JournalRoot: TJSONObject;
  Objects: TQuestObjectArray;
  AutoCount: Integer;
  WorldQuestCount: Integer;
  PlayerQuestCount: Integer;
  LoreCount: Integer;
  TutorialCount: Integer;
  I: Integer;
  InstallPath: string;

  function ReadU32(
    const Data: TBytes;
    Offset: QWord
  ): Cardinal;
  begin
    if Offset + 4 > QWord(Length(Data)) then
      raise Exception.Create('ReadU32 out of bounds');

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
      raise Exception.Create('ReadU8 out of bounds');

    Result := Data[Offset];
  end;


procedure DumpRequirement(
  const Data: TBytes;
  Offset: QWord;
  const Name: string
);
begin
  WriteLn(Name, ':');

  WriteLn(
    '  knowledgeOrQueryId=$',
    IntToHex(
      ReadU32(Data, Offset),
      8
    )
  );

  WriteLn(
    '  compareValue=',
    ReadU32(
      Data,
      Offset + 4
    )
  );

  WriteLn(
    '  compareOperator=',
    ReadU8(
      Data,
      Offset + 8
    )
  );

  WriteLn(
    '  type=',
    ReadU8(
      Data,
      Offset + 9
    )
  );

  WriteLn(
    '  explicit=',
    ReadU8(
      Data,
      Offset + 10
    )
  );
end;

procedure DumpFirstCollection(
  const Data: TBytes
);
var
  CollectionsField: QWord;
  CollectionsRelativeOffset: Cardinal;
  CollectionsCount: Cardinal;

  CollectionOffset: QWord;

  EntriesField: QWord;
  EntriesRelativeOffset: Cardinal;
  EntriesCount: Cardinal;

  EntryOffset: QWord;

  ProgressField: QWord;
  ProgressRelativeOffset: Cardinal;
  ProgressCount: Cardinal;
begin
  {
    JournalRegistryResource:
      collections field @8
  }

  CollectionsField := 8;

  CollectionsRelativeOffset :=
    ReadU32(
      Data,
      CollectionsField
    );

  CollectionsCount :=
    ReadU32(
      Data,
      CollectionsField + 4
    );

  CollectionOffset :=
    CollectionsField +
    CollectionsRelativeOffset;

  WriteLn;
  WriteLn('=== FIRST COLLECTION ===');

  WriteLn(
    'collections count=',
    CollectionsCount
  );

  WriteLn(
    'collection offset=$',
    IntToHex(
      CollectionOffset,
      8
    )
  );

  {
    Collection struct, size 32
  }

  WriteLn(
    'entryId=$',
    IntToHex(
      ReadU32(
        Data,
        CollectionOffset
      ),
      8
    )
  );

  WriteLn(
    'loreCategory=$',
    IntToHex(
      ReadU32(
        Data,
        CollectionOffset + 4
      ),
      8
    )
  );

  WriteLn(
    'name=$',
    IntToHex(
      ReadU32(
        Data,
        CollectionOffset + 8
      ),
      8
    )
  );

  WriteLn(
    'referencedDocumentName=$',
    IntToHex(
      ReadU32(
        Data,
        CollectionOffset + 12
      ),
      8
    )
  );

  WriteLn(
    'priority=',
    ReadU32(
      Data,
      CollectionOffset + 16
    )
  );

  WriteLn(
    'isTutorial=',
    ReadU8(
      Data,
      CollectionOffset + 20
    )
  );

  {
    entries BlobArray @24
  }

  EntriesField :=
    CollectionOffset + 24;

  EntriesRelativeOffset :=
    ReadU32(
      Data,
      EntriesField
    );

  EntriesCount :=
    ReadU32(
      Data,
      EntriesField + 4
    );

  EntriesField :=
    EntriesField +
    EntriesRelativeOffset;

  WriteLn(
    'entries count=',
    EntriesCount
  );

  WriteLn(
    'entries offset=$',
    IntToHex(
      EntriesField,
      8
    )
  );

  if EntriesCount = 0 then
    Exit;

  {
    First journal entry, size 72
  }

  EntryOffset :=
    EntriesField;

  WriteLn;
  WriteLn('--- FIRST ENTRY ---');

  WriteLn(
    'entryId=$',
    IntToHex(
      ReadU32(
        Data,
        EntryOffset
      ),
      8
    )
  );

  WriteLn(
    'name=$',
    IntToHex(
      ReadU32(
        Data,
        EntryOffset + 4
      ),
      8
    )
  );

  WriteLn(
    'text=$',
    IntToHex(
      ReadU32(
        Data,
        EntryOffset + 8
      ),
      8
    )
  );

  WriteLn(
    'mapMarkerReference=$',
    IntToHex(
      ReadU32(
        Data,
        EntryOffset + 12
      ),
      8
    )
  );

  DumpRequirement(
    Data,
    EntryOffset + 16,
    'knowledgeRequirement'
  );

  DumpRequirement(
    Data,
    EntryOffset + 28,
    'completionRequirement'
  );

  {
    progressStepsRequirement @40
  }

  ProgressField :=
    EntryOffset + 40;

  ProgressRelativeOffset :=
    ReadU32(
      Data,
      ProgressField
    );

  ProgressCount :=
    ReadU32(
      Data,
      ProgressField + 4
    );

  WriteLn(
    'progressStepsRequirement count=',
    ProgressCount
  );

  if ProgressCount > 0 then
  begin
    ProgressField :=
      ProgressField +
      ProgressRelativeOffset;

    WriteLn(
      'progressStepsRequirement offset=$',
      IntToHex(
        ProgressField,
        8
      )
    );

    DumpRequirement(
      Data,
      ProgressField,
      'first progress requirement'
    );
  end;

  WriteLn(
    'itemIconId=$',
    IntToHex(
      ReadU32(
        Data,
        EntryOffset + 64
      ),
      8
    )
  );

  WriteLn(
    'recommendedLevel=',
    ReadU8(
      Data,
      EntryOffset + 68
    )
  );
end;

begin

  if FindEnshroudedInstallPath(
     InstallPath
   )
then
  WriteLn(
    'Enshrouded install path: ',
    InstallPath
  )
else
  WriteLn(
    'Enshrouded install path not found'
  );

  try
    Data :=
      ExtractKFCResource(
        'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded.kfc',
        'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded.kfc_resources',
        '33701b26-ec1d-423f-8e06-49f023b91b7f',
        $60B5ED8A,
        0
      );

    DumpFirstCollection(Data);

    ParseJournalCollections(
  Data,
  Collections
);

WriteLn;
WriteLn(
  'Parsed collections: ',
  Length(Collections)
);

if Length(Collections) > 0 then
begin
  WriteLn(
    'First collection ID=$',
    IntToHex(
      Collections[0].Base.EntryID,
      8
    )
  );

  WriteLn(
    'First collection entries=',
    Length(
      Collections[0].Base.Entries
    )
  );

  if Length(Collections[0].Base.Entries) > 0 then
  begin
    WriteLn(
      'First entry ID=$',
      IntToHex(
        Collections[0].Base.Entries[0].EntryID,
        8
      )
    );

    WriteLn(
      'First entry KNOW requirement=$',
      IntToHex(
        Collections[0].
          Base.Entries[0].
          KnowledgeRequirement.
          KnowledgeOrQueryID,
        8
      )
    );
  end;
end;


ParseJournalQuests(
  Data,
  Quests
);

WriteLn;
WriteLn(
  'Parsed quests: ',
  Length(Quests)
);

if Length(Quests) > 0 then
begin
  WriteLn(
    'First quest ID=$',
    IntToHex(
      Quests[0].Base.EntryID,
      8
    )
  );

  WriteLn(
    'First quest entries=',
    Length(
      Quests[0].Base.Entries
    )
  );

  WriteLn(
  'First quest source=',
  JournalQuestSourceText(
    Quests[0].Source
  )
);

WriteLn(
  'First quest type=',
  JournalQuestTypeText(
    Quests[0].QuestType
  )
);

  WriteLn(
    'First quest unlockForAllPlayers=',
    Ord(
      Quests[0].UnlockForAllPlayers
    )
  );
end;

    JournalRoot :=
  BuildJournalJSON(
    Quests,
    Collections
  );

try
  SetLength(
    Objects,
    0
  );

  CollectQuestObjects(
    JournalRoot,
    Objects
  );

  WriteLn;
  WriteLn(
    'Journal JSON objects: ',
    Length(Objects)
  );

finally
  JournalRoot.Free;
end;

    AutoCount := 0;
WorldQuestCount := 0;
PlayerQuestCount := 0;

for I := 0 to High(Quests) do
begin
  case Quests[I].QuestType of
    jqtAuto:
      Inc(AutoCount);

    jqtWorldQuest:
      Inc(WorldQuestCount);

    jqtPlayerQuest:
      Inc(PlayerQuestCount);
  end;
end;

LoreCount := 0;
TutorialCount := 0;

for I := 0 to High(Collections) do
begin
  if Collections[I].Base.IsTutorial then
    Inc(TutorialCount)
  else
    Inc(LoreCount);
end;

WriteLn;
WriteLn('=== JOURNAL CLASSIFICATION ===');
WriteLn('Auto quests        : ', AutoCount);
WriteLn('World quests       : ', WorldQuestCount);
WriteLn('Player quests      : ', PlayerQuestCount);
WriteLn('Lore collections   : ', LoreCount);
WriteLn('Tutorials          : ', TutorialCount);


    if Length(Data) > 0 then
begin
  F :=
    TFileStream.Create(
      'journal_resource.bin',
      fmCreate
    );

  try
    F.WriteBuffer(
      Data[0],
      Length(Data)
    );
  finally
    F.Free;
  end;
end;

  except
    on E: Exception do
    begin
      WriteLn(
        'ERROR: ',
        E.Message
      );
      Halt(1);
    end;
  end;
end.
