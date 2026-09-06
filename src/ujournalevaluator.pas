unit uJournalEvaluator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpjson,
  uKnowledge,
  uQueryModel,
  uQueryEvaluator,
  uLocalization;

type
  TQuestStatus = (
    qsNotStarted,
    qsInProgress,
    qsCompleted,
    qsUnknown
  );

 type
  TJournalEntryState = record
    EntryID: Cardinal;
    Name: string;
    Text: string;

    AvailabilityExists: Boolean;
    Availability: TEvalResult;

    CompletionExists: Boolean;
    Completion: TEvalResult;
  end;

  TJournalEntryStates = array of TJournalEntryState;

  TQuestPersonalStatus = (
    qpsNotCompleted,
    qpsCompletedPersonally,
    qpsResolvedUnknownOrigin
  );

  TJournalQuestState = record
    QuestID: Cardinal;
    Name: string;

    Status: TQuestStatus;

    DirectKnowFound: Boolean;
    DirectKnowValue: Cardinal;

    LatestConfirmedIndex: Integer;
    NextUnresolvedIndex: Integer;

    Entries: TJournalEntryStates;
    RawType: string;
    PersonalStatus: TQuestPersonalStatus;
  end;

  type
  TJournalFamily = (
    jfUnknown,
    jfQuest,
    jfLore,
    jfTutorial
  );

type
   TQuestObjectArray = array of TJSONObject;


   type
   TJournalObjectMetadata = record
     ID: Cardinal;
     Name: string;

     Family: TJournalFamily;

     RawType: string;
     LoreCategory: string;
     IsTutorial: Boolean;
     Source: string;

     Priority: Integer;
     UnlockForAllPlayers: Boolean;
     ReferencedDocumentName: string;

     EntryCount: Integer;

     DirectKnowFound: Boolean;
     DirectKnowValue: Cardinal;
     PersonalStatus: TQuestPersonalStatus;
   end;

  TJournalObjectMetadataArray = array of TJournalObjectMetadata;

  type
  TStringCount = record
    Value: string;
    Count: Integer;
  end;

  TStringCountArray = array of TStringCount;

procedure DumpJournalQuestState(
  JournalRoot: TJSONData;
  QuestID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);

procedure CollectQuestObjects(
  Data: TJSONData;
  var Quests: TQuestObjectArray
);
procedure DumpAllJournalQuestStates(
  JournalRoot: TJSONData;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);

procedure DumpJournalInventory(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);

procedure DumpQuestJournalStates(
  JournalRoot: TJSONData;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);

procedure DumpQuestInventory(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);

procedure CollectJournalMetadata(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems;
  out Metadata: TJournalObjectMetadataArray
);

function ReadJournalObjectMetadata(
  Obj: TJSONObject;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
): TJournalObjectMetadata;

function QuestPersonalStatusText(
  Status: TQuestPersonalStatus
): string;

procedure DumpQuestPersonalProgress(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);

implementation


function InferQuestPersonalStatus(
  const RawType: string;
  DirectKnowFound: Boolean;
  DirectKnowValue: Cardinal
): TQuestPersonalStatus;
begin
  if
    (not DirectKnowFound) or
    (DirectKnowValue = 0)
  then
    Exit(qpsNotCompleted);

  if SameText(RawType, 'Auto') then
    Exit(qpsResolvedUnknownOrigin);

  Result := qpsCompletedPersonally;
end;



function GetStringField(
  Obj: TJSONObject;
  const FieldName: string;
  const DefaultValue: string = ''
): string;
var
  Node: TJSONData;
begin
  Result := DefaultValue;

  if Obj = nil then
    Exit;

  Node := Obj.Find(FieldName);

  if Node = nil then
    Exit;

  if Node.JSONType = jtString then
    Result := Node.AsString;
end;

function QuestPersonalStatusText(
  Status: TQuestPersonalStatus
): string;
begin
  case Status of
    qpsNotCompleted:
      Result := 'NOT_COMPLETED';

    qpsCompletedPersonally:
      Result := 'COMPLETED_PERSONALLY';

    qpsResolvedUnknownOrigin:
      Result := 'RESOLVED_UNKNOWN_ORIGIN';

  else
    Result := 'UNKNOWN';
  end;
end;



function QuestStatusText(
  Status: TQuestStatus
): string;
begin
  case Status of
    qsNotStarted:
      Result := 'NOT_STARTED';

    qsInProgress:
      Result := 'IN_PROGRESS';

    qsCompleted:
      Result := 'COMPLETED';

  else
    Result := 'UNKNOWN';
  end;
end;


function FormatID(ID: QWord): string;
begin
  Result :=
    IntToStr(ID) +
    ' ($' +
    IntToHex(ID, 8) +
    ')';
end;


function GetNestedUInt(
  Obj: TJSONObject;
  const Field1: string;
  const Field2: string;
  DefaultValue: QWord
): QWord;
var
  Node1: TJSONData;
  Node2: TJSONData;
begin
  Result := DefaultValue;

  Node1 := Obj.Find(Field1);

  if
    (Node1 = nil) or
    (Node1.JSONType <> jtObject)
  then
    Exit;

  Node2 :=
    TJSONObject(Node1).Find(Field2);

  if Node2 = nil then
    Exit;

  Result :=
    StrToQWordDef(
      Node2.AsString,
      DefaultValue
    );
end;


function GetUIntField(
  Obj: TJSONObject;
  const FieldName: string;
  DefaultValue: QWord
): QWord;
var
  Node: TJSONData;
begin
  Result := DefaultValue;

  Node := Obj.Find(FieldName);

  if Node = nil then
    Exit;

  Result :=
    StrToQWordDef(
      Node.AsString,
      DefaultValue
    );
end;




function Localize(
  const Localization: TLocalizationItems;
  ID: QWord
): string;
var
  Text: UTF8String;
begin
  Result := '';

  if ID = 0 then
    Exit;

  if ID > High(Cardinal) then
    Exit;

  if FindLocalization(
       Localization,
       Cardinal(ID),
       Text
     ) then
    Result := string(Text);
end;


function FindQuestObject(
  Data: TJSONData;
  QuestID: Cardinal
): TJSONObject;
var
  Obj: TJSONObject;
  I: Integer;
  CandidateID: QWord;
  EntriesNode: TJSONData;
begin
  Result := nil;

  if Data = nil then
    Exit;


  if Data.JSONType = jtObject then
  begin
    Obj := TJSONObject(Data);

    CandidateID :=
      GetNestedUInt(
        Obj,
        'entryId',
        'value',
        0
      );

    EntriesNode :=
      Obj.Find('entries');

    {
      Quest objects have their own entryId
      and an entries array.
    }
    if
      (CandidateID = QuestID) and
      (EntriesNode <> nil) and
      (EntriesNode.JSONType = jtArray)
    then
      Exit(Obj);


    for I := 0 to Obj.Count - 1 do
    begin
      Result :=
        FindQuestObject(
          Obj.Items[I],
          QuestID
        );

      if Result <> nil then
        Exit;
    end;
  end

  else if Data.JSONType = jtArray then
  begin
    for I := 0 to TJSONArray(Data).Count - 1 do
    begin
      Result :=
        FindQuestObject(
          TJSONArray(Data).Items[I],
          QuestID
        );

      if Result <> nil then
        Exit;
    end;
  end;
end;


function EvaluateRequirementObject(
  Requirement: TJSONData;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  out Exists: Boolean
): TEvalResult;
var
  Obj: TJSONObject;
  ID: QWord;
  CompareValue: QWord;
  RequirementType: string;
  CompareOperator: string;
begin
  Exists := False;
  Result := erUnknown;

  if
    (Requirement = nil) or
    (Requirement.JSONType <> jtObject)
  then
    Exit;

  Obj :=
    TJSONObject(Requirement);

  ID :=
    GetNestedUInt(
      Obj,
      'knowledgeOrQueryId',
      'value',
      0
    );

  if ID = 0 then
    Exit;

  Exists := True;

  CompareValue :=
    GetUIntField(
      Obj,
      'compareValue',
      0
    );

  CompareOperator :=
    GetStringField(
      Obj,
      'compareOperator',
      ''
    );

  RequirementType :=
    GetStringField(
      Obj,
      'type',
      ''
    );

  if ID > High(Cardinal) then
    Exit(erUnknown);

  Result :=
    EvaluateRequirement(
      Cardinal(ID),
      RequirementType,
      CompareOperator,
      Cardinal(CompareValue),
      False,
      Queries,
      Knowledge
    );
end;


procedure DumpRequirement(
  const LabelText: string;
  Requirement: TJSONData;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
);
var
  Exists: Boolean;
  Value: TEvalResult;
  Obj: TJSONObject;
  ID: QWord;
  RequirementType: string;
  CompareOperator: string;
  CompareValue: QWord;
begin
  Value :=
    EvaluateRequirementObject(
      Requirement,
      Queries,
      Knowledge,
      Exists
    );

  Write('  ', LabelText, ': ');

  if not Exists then
  begin
    WriteLn('(none)');
    Exit;
  end;

  Obj :=
    TJSONObject(Requirement);

  ID :=
    GetNestedUInt(
      Obj,
      'knowledgeOrQueryId',
      'value',
      0
    );

  RequirementType :=
    GetStringField(
      Obj,
      'type',
      ''
    );

  CompareOperator :=
    GetStringField(
      Obj,
      'compareOperator',
      ''
    );

  CompareValue :=
    GetUIntField(
      Obj,
      'compareValue',
      0
    );

  WriteLn(
    EvalResultText(Value),
    '   ',
    FormatID(ID),
    ' ',
    RequirementType,
    ' ',
    CompareOperator,
    ' ',
    CompareValue
  );
end;



function EvaluateJournalEntry(
  Entry: TJSONObject;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
): TJournalEntryState;
var
  NameID: QWord;
  TextID: QWord;
begin
  FillChar(Result, SizeOf(Result), 0);

  Result.EntryID :=
    Cardinal(
      GetNestedUInt(
        Entry,
        'entryId',
        'value',
        0
      )
    );

  NameID :=
    GetNestedUInt(
      Entry,
      'name',
      'value',
      0
    );

  TextID :=
    GetNestedUInt(
      Entry,
      'text',
      'value',
      0
    );

  Result.Name :=
    Localize(
      Localization,
      NameID
    );

  Result.Text :=
    Localize(
      Localization,
      TextID
    );

  Result.Availability :=
    EvaluateRequirementObject(
      Entry.Find('knowledgeRequirement'),
      Queries,
      Knowledge,
      Result.AvailabilityExists
    );

  if not Result.AvailabilityExists then
    Result.Availability := erTrue;

  Result.Completion :=
    EvaluateRequirementObject(
      Entry.Find('completionRequirement'),
      Queries,
      Knowledge,
      Result.CompletionExists
    );
end;

procedure InferQuestProgress(
  var State: TJournalQuestState
);
var
  I: Integer;
begin
  State.LatestConfirmedIndex := -1;
  State.NextUnresolvedIndex := -1;

  if
    State.DirectKnowFound and
    (State.DirectKnowValue <> 0)
  then
  begin
    State.Status := qsCompleted;
    Exit;
  end;

  for I := 0 to High(State.Entries) do
  begin
    if State.Entries[I].Availability = erTrue then
      State.LatestConfirmedIndex := I;
  end;

  if State.LatestConfirmedIndex < 0 then
  begin
    State.Status := qsNotStarted;
    Exit;
  end;

  State.Status := qsInProgress;

  for I :=
    State.LatestConfirmedIndex + 1
    to High(State.Entries)
  do
  begin
    case State.Entries[I].Availability of

      erUnknown:
      begin
        State.NextUnresolvedIndex := I;
        Break;
      end;

      erFalse:
        Break;

    end;
  end;
end;

function EvaluateJournalQuest(
  Quest: TJSONObject;
  QuestID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
): TJournalQuestState;
var
  EntriesNode: TJSONData;
  Entries: TJSONArray;

  QuestNameID: QWord;

  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  Result.QuestID := QuestID;

  Result.LatestConfirmedIndex := -1;
  Result.NextUnresolvedIndex := -1;

  QuestNameID :=
    GetNestedUInt(
      Quest,
      'name',
      'value',
      0
    );

  Result.Name :=
    Localize(
      Localization,
      QuestNameID
    );

  Result.DirectKnowFound :=
    FindKnowledgeValue(
      Knowledge,
      QuestID,
      Result.DirectKnowValue
    );

  Result.RawType := GetStringField(Quest, 'type');

  Result.PersonalStatus :=
                        InferQuestPersonalStatus(
                            Result.RawType,
                            Result.DirectKnowFound,
                            Result.DirectKnowValue
                        );

  EntriesNode :=
    Quest.Find('entries');

  if
    (EntriesNode <> nil) and
    (EntriesNode.JSONType = jtArray)
  then
  begin
    Entries :=
      TJSONArray(EntriesNode);

    SetLength(
      Result.Entries,
      Entries.Count
    );

    for I := 0 to Entries.Count - 1 do
    begin
      if Entries.Items[I].JSONType = jtObject then
      begin
        Result.Entries[I] :=
          EvaluateJournalEntry(
            TJSONObject(Entries.Items[I]),
            Queries,
            Knowledge,
            Localization
          );
      end;
    end;
  end;

  InferQuestProgress(Result);
end;

procedure DumpJournalQuestStateResult(
  const State: TJournalQuestState
);
var
  I: Integer;
begin
  WriteLn('=== JOURNAL QUEST STATE ===');
  WriteLn;

  WriteLn(
    'Quest: ',
    State.Name,
    ' [',
    FormatID(State.QuestID),
    ']'
  );

  WriteLn(
    'Status: ',
    QuestStatusText(State.Status)
  );

  if State.DirectKnowFound then
  begin
    WriteLn(
      'Direct quest KNOW: ',
      State.DirectKnowValue,
      ' ($',
      IntToHex(State.DirectKnowValue, 8),
      ')'
    );
  end
  else
    WriteLn('Direct quest KNOW: absent');

  case State.Status of

    qsCompleted:
      WriteLn(
        'Latest confirmed step: (quest completed)'
      );

    qsInProgress:
    begin
      if State.LatestConfirmedIndex >= 0 then
      begin
        WriteLn(
          'Latest confirmed step: ',
          State.Entries[
            State.LatestConfirmedIndex
          ].Name
        );
      end;

      if State.NextUnresolvedIndex >= 0 then
      begin
        WriteLn(
          'Next unresolved step: ',
          State.Entries[
            State.NextUnresolvedIndex
          ].Name
        );
      end;
    end;

    qsNotStarted:
      WriteLn(
        'Latest confirmed step: none'
      );

    qsUnknown:
      WriteLn(
        'Latest confirmed step: unknown'
      );
  end;

  for I := 0 to High(State.Entries) do
  begin
    WriteLn;

    WriteLn(
      'Entry #',
      I,
      ': ',
      State.Entries[I].Name,
      ' [',
      FormatID(State.Entries[I].EntryID),
      ']'
    );

    if State.Entries[I].AvailabilityExists then
      WriteLn(
        '  availability: ',
        EvalResultText(
          State.Entries[I].Availability
        )
      )
    else
      WriteLn(
        '  availability: TRUE (no requirement)'
      );

    if State.Entries[I].CompletionExists then
      WriteLn(
        '  completion requirement: ',
        EvalResultText(
          State.Entries[I].Completion
        )
      )
    else
      WriteLn(
        '  completion requirement: (none)'
      );

    if
      I = State.LatestConfirmedIndex
    then
      WriteLn(
        '  latest confirmed step: YES'
      );

    if
      I = State.NextUnresolvedIndex
    then
      WriteLn(
        '  next unresolved step: YES'
      );

    if State.Entries[I].Text <> '' then
      WriteLn(
        '  Text: ',
        State.Entries[I].Text
      );
  end;
end;

procedure DumpJournalQuestState(
  JournalRoot: TJSONData;
  QuestID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);
var
  Quest: TJSONObject;
  State: TJournalQuestState;
begin
  Quest :=
    FindQuestObject(
      JournalRoot,
      QuestID
    );

  if Quest = nil then
  begin
    WriteLn(
      'Quest not found: ',
      FormatID(QuestID)
    );

    Exit;
  end;

  State :=
    EvaluateJournalQuest(
      Quest,
      QuestID,
      Queries,
      Knowledge,
      Localization
    );

  DumpJournalQuestStateResult(
    State
  );
end;

procedure AddQuestObject(
  var Quests: TQuestObjectArray;
  Quest: TJSONObject
);
begin
  SetLength(Quests, Length(Quests) + 1);
  Quests[High(Quests)] := Quest;
end;

procedure CollectQuestObjects(
  Data: TJSONData;
  var Quests: TQuestObjectArray
);
var
  Obj: TJSONObject;
  EntriesNode: TJSONData;
  EntryID: QWord;
  I: Integer;
begin
  if Data = nil then
    Exit;

  if Data.JSONType = jtObject then
  begin
    Obj := TJSONObject(Data);

    EntryID :=
      GetNestedUInt(
        Obj,
        'entryId',
        'value',
        0
      );

    EntriesNode :=
      Obj.Find('entries');

    if
      (EntryID <> 0) and
      (EntriesNode <> nil) and
      (EntriesNode.JSONType = jtArray)
    then
      AddQuestObject(
        Quests,
        Obj
      );

    for I := 0 to Obj.Count - 1 do
      CollectQuestObjects(
        Obj.Items[I],
        Quests
      );
  end

  else if Data.JSONType = jtArray then
  begin
    for I := 0 to TJSONArray(Data).Count - 1 do
      CollectQuestObjects(
        TJSONArray(Data).Items[I],
        Quests
      );
  end;
end;


procedure DumpAllJournalQuestStates(
  JournalRoot: TJSONData;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);
var
  QuestObjects: TQuestObjectArray;
  State: TJournalQuestState;

  QuestID: QWord;

  I: Integer;

  CompletedCount: Integer;
  InProgressCount: Integer;
  NotStartedCount: Integer;
  UnknownCount: Integer;
begin
  SetLength(QuestObjects, 0);

  CollectQuestObjects(
    JournalRoot,
    QuestObjects
  );

  CompletedCount := 0;
  InProgressCount := 0;
  NotStartedCount := 0;
  UnknownCount := 0;

  WriteLn(
    'Journal quests found: ',
    Length(QuestObjects)
  );

  WriteLn;

  for I := 0 to High(QuestObjects) do
  begin
    QuestID :=
      GetNestedUInt(
        QuestObjects[I],
        'entryId',
        'value',
        0
      );

    if
      (QuestID = 0) or
      (QuestID > High(Cardinal))
    then
      Continue;

    State :=
      EvaluateJournalQuest(
        QuestObjects[I],
        Cardinal(QuestID),
        Queries,
        Knowledge,
        Localization
      );

    case State.Status of

      qsCompleted:
      begin
        Inc(CompletedCount);

        WriteLn(
          'COMPLETED    ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );
      end;

      qsInProgress:
      begin
        Inc(InProgressCount);

        Write(
          'IN_PROGRESS  ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );

        if State.LatestConfirmedIndex >= 0 then
          Write(
            '  latest="',
            State.Entries[
              State.LatestConfirmedIndex
            ].Name,
            '"'
          );

        if State.NextUnresolvedIndex >= 0 then
          Write(
            '  unresolved="',
            State.Entries[
              State.NextUnresolvedIndex
            ].Name,
            '"'
          );

        WriteLn;
      end;

      qsNotStarted:
      begin
        Inc(NotStartedCount);

        WriteLn(
          'NOT_STARTED  ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );
      end;

    else
      begin
        Inc(UnknownCount);

        WriteLn(
          'UNKNOWN      ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );
      end;

    end;
  end;

  WriteLn;
  WriteLn('=== SUMMARY ===');

  WriteLn(
    'Completed   : ',
    CompletedCount
  );

  WriteLn(
    'In progress : ',
    InProgressCount
  );

  WriteLn(
    'Not started : ',
    NotStartedCount
  );

  WriteLn(
    'Unknown     : ',
    UnknownCount
  );
end;




function GetBoolField(
  Obj: TJSONObject;
  const FieldName: string;
  DefaultValue: Boolean = False
): Boolean;
var
  Node: TJSONData;
begin
  Result := DefaultValue;

  if Obj = nil then
    Exit;

  Node := Obj.Find(FieldName);

  if Node = nil then
    Exit;

  if Node.JSONType = jtBoolean then
    Result := Node.AsBoolean;
end;

function GetIntField(
  Obj: TJSONObject;
  const FieldName: string;
  DefaultValue: Integer = 0
): Integer;
var
  D: TJSONData;
begin
  Result := DefaultValue;

  if Obj = nil then
    Exit;

  D := Obj.Find(FieldName);

  if D = nil then
    Exit;

  try
    Result := D.AsInteger;
  except
    Result := DefaultValue;
  end;
end;

function ClassifyJournalObject(
  const RawType: string;
  IsTutorial: Boolean
): TJournalFamily;
begin
  if SameText(RawType, 'Auto') or
     SameText(RawType, 'WorldQuest') or
     SameText(RawType, 'PlayerQuest') then
    Exit(jfQuest);

  if RawType = '' then
  begin
    if IsTutorial then
      Exit(jfTutorial)
    else
      Exit(jfLore);
  end;

  Result := jfUnknown;
end;


function ReadJournalObjectMetadata(
  Obj: TJSONObject;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
): TJournalObjectMetadata;
var
  NameID: QWord;
  EntryID: QWord;
  EntriesData: TJSONData;
begin
  FillChar(Result, SizeOf(Result), 0);

  if Obj = nil then
    Exit;

  EntryID :=
    GetNestedUInt(
      Obj,
      'entryId',
      'value',
      0
    );

  if EntryID <= High(Cardinal) then
    Result.ID := Cardinal(EntryID)
  else
    Result.ID := 0;

  NameID :=
    GetNestedUInt(
      Obj,
      'name',
      'value',
      0
    );

  Result.Name :=
    Localize(
      Localization,
      NameID
    );

  Result.RawType :=
    GetStringField(Obj, 'type');

  Result.LoreCategory :=
    GetStringField(Obj, 'loreCategory');

  Result.IsTutorial :=
    GetBoolField(Obj, 'isTutorial', False);

  Result.Source :=
    GetStringField(Obj, 'source');

  Result.Priority :=
    GetIntField(Obj, 'priority', 0);

  Result.UnlockForAllPlayers :=
    GetBoolField(
      Obj,
      'unlockForAllPlayers',
      False
    );

  Result.ReferencedDocumentName :=
    GetStringField(
      Obj,
      'referencedDocumentName'
    );

  Result.Family :=
    ClassifyJournalObject(
      Result.RawType,
      Result.IsTutorial
    );

  EntriesData := Obj.Find('entries');

  if (EntriesData <> nil) and
     (EntriesData.JSONType = jtArray) then
    Result.EntryCount := TJSONArray(EntriesData).Count
  else
    Result.EntryCount := 0;

  Result.DirectKnowFound := False;
  Result.DirectKnowValue := 0;

  if Result.ID <> 0 then
    Result.DirectKnowFound :=
      FindKnowledgeValue(
        Knowledge,
        Result.ID,
        Result.DirectKnowValue
      );

  if Result.Family = jfQuest then
     Result.PersonalStatus :=
                           InferQuestPersonalStatus(
                                                    Result.RawType,
                                                    Result.DirectKnowFound,
                                                    Result.DirectKnowValue
                                                    )
  else
      Result.PersonalStatus := qpsNotCompleted;

end;


procedure CollectJournalMetadata(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems;
  out Metadata: TJournalObjectMetadataArray
);
var
  QuestObjects: TQuestObjectArray;
  I: Integer;
begin
  SetLength(QuestObjects, 0);

  CollectQuestObjects(
    JournalRoot,
    QuestObjects
  );

  SetLength(
    Metadata,
    Length(QuestObjects)
  );

  for I := 0 to High(QuestObjects) do
  begin
    Metadata[I] :=
      ReadJournalObjectMetadata(
        QuestObjects[I],
        Knowledge,
        Localization
      );
  end;
end;

procedure DumpQuestPersonalProgress(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);
var
  Metadata: TJournalObjectMetadataArray;
  I: Integer;

  QuestCount: Integer;
  CompletedPersonallyCount: Integer;
  NotCompletedCount: Integer;
  ResolvedUnknownOriginCount: Integer;
begin
  CollectJournalMetadata(
    JournalRoot,
    Knowledge,
    Localization,
    Metadata
  );

  QuestCount := 0;
  CompletedPersonallyCount := 0;
  NotCompletedCount := 0;
  ResolvedUnknownOriginCount := 0;

  WriteLn('=== QUEST PERSONAL PROGRESS ===');
  WriteLn;

  for I := 0 to High(Metadata) do
  begin
    if Metadata[I].Family <> jfQuest then
      Continue;

    Inc(QuestCount);

    case Metadata[I].PersonalStatus of
      qpsCompletedPersonally:
        Inc(CompletedPersonallyCount);

      qpsNotCompleted:
        Inc(NotCompletedCount);

      qpsResolvedUnknownOrigin:
        Inc(ResolvedUnknownOriginCount);
    end;

    WriteLn(
      QuestPersonalStatusText(
        Metadata[I].PersonalStatus
      ),
      ' | ',
      Metadata[I].RawType,
      ' | ',
      Metadata[I].Name,
      ' | $',
      IntToHex(Metadata[I].ID, 8)
    );
  end;

  WriteLn;
  WriteLn('=== SUMMARY ===');
  WriteLn('Quest objects                  : ', QuestCount);
  WriteLn('Personally completed           : ', CompletedPersonallyCount);
  WriteLn('Not completed personally       : ', NotCompletedCount);
  WriteLn('Auto resolved / origin unknown : ', ResolvedUnknownOriginCount);
end;

procedure IncrementStringCount(
  var Counts: TStringCountArray;
  const Value: string
);
var
  I: Integer;
  Key: string;
begin
  Key := Value;

  if Key = '' then
    Key := '(empty)';

  for I := 0 to High(Counts) do
  begin
    if SameText(
      Counts[I].Value,
      Key
    ) then
    begin
      Inc(Counts[I].Count);
      Exit;
    end;
  end;

  SetLength(
    Counts,
    Length(Counts) + 1
  );

  Counts[High(Counts)].Value := Key;
  Counts[High(Counts)].Count := 1;
end;

procedure DumpStringCounts(
  const Title: string;
  const Counts: TStringCountArray
);
var
  I: Integer;
begin
  WriteLn;
  WriteLn('=== ', Title, ' ===');

  for I := 0 to High(Counts) do
  begin
    WriteLn(
      Counts[I].Value,
      ': ',
      Counts[I].Count
    );
  end;
end;


procedure DumpJournalInventory(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);
var
  Metadata: TJournalObjectMetadataArray;

  TypeCounts: TStringCountArray;
  LoreCategoryCounts: TStringCountArray;
  SourceCounts: TStringCountArray;

  I: Integer;

  TutorialTrueCount: Integer;
  TutorialFalseCount: Integer;

  DirectKnowCount: Integer;
  DirectKnowNonZeroCount: Integer;
begin
  CollectJournalMetadata(
    JournalRoot,
    Knowledge,
    Localization,
    Metadata
  );

  SetLength(TypeCounts, 0);
  SetLength(LoreCategoryCounts, 0);
  SetLength(SourceCounts, 0);

  TutorialTrueCount := 0;
  TutorialFalseCount := 0;

  DirectKnowCount := 0;
  DirectKnowNonZeroCount := 0;

  WriteLn(
    'Journal objects found: ',
    Length(Metadata)
  );

  WriteLn;

  for I := 0 to High(Metadata) do
  begin
    Write(
      '$',
      IntToHex(Metadata[I].ID, 8),
      ' | ',
      Metadata[I].Name
    );

    Write(
      ' | type="',
      Metadata[I].RawType,
      '"'
    );

    Write(
      ' | loreCategory="',
      Metadata[I].LoreCategory,
      '"'
    );

    Write(
      ' | tutorial=',
      BoolToStr(
        Metadata[I].IsTutorial,
        True
      )
    );

    Write(
      ' | source="',
      Metadata[I].Source,
      '"'
    );

    Write(
      ' | entries=',
      Metadata[I].EntryCount
    );

    if Metadata[I].DirectKnowFound then
    begin
      Write(
        ' | KNOW=',
        Metadata[I].DirectKnowValue
      );

      Inc(DirectKnowCount);

      if Metadata[I].DirectKnowValue <> 0 then
        Inc(DirectKnowNonZeroCount);
    end
    else
      Write(
        ' | KNOW=absent'
      );

    WriteLn;

    IncrementStringCount(
      TypeCounts,
      Metadata[I].RawType
    );

    IncrementStringCount(
      LoreCategoryCounts,
      Metadata[I].LoreCategory
    );

    IncrementStringCount(
      SourceCounts,
      Metadata[I].Source
    );

    if Metadata[I].IsTutorial then
      Inc(TutorialTrueCount)
    else
      Inc(TutorialFalseCount);
  end;

  WriteLn;
  WriteLn('=== GLOBAL ===');

  WriteLn(
    'Objects              : ',
    Length(Metadata)
  );

  WriteLn(
    'Tutorial=true        : ',
    TutorialTrueCount
  );

  WriteLn(
    'Tutorial=false       : ',
    TutorialFalseCount
  );

  WriteLn(
    'Direct KNOW present  : ',
    DirectKnowCount
  );

  WriteLn(
    'Direct KNOW non-zero : ',
    DirectKnowNonZeroCount
  );

  DumpStringCounts(
    'TYPE VALUES',
    TypeCounts
  );

  DumpStringCounts(
    'LORE CATEGORY VALUES',
    LoreCategoryCounts
  );

  DumpStringCounts(
    'SOURCE VALUES',
    SourceCounts
  );
end;



procedure DumpQuestJournalStates(
  JournalRoot: TJSONData;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);
var
  QuestObjects: TQuestObjectArray;
  Meta: TJournalObjectMetadata;
  State: TJournalQuestState;
  I: Integer;
  CompletedCount: Integer;
  InProgressCount: Integer;
  NotStartedCount: Integer;
  UnknownCount: Integer;
begin
  SetLength(QuestObjects, 0);
  CollectQuestObjects(JournalRoot, QuestObjects);

  CompletedCount := 0;
  InProgressCount := 0;
  NotStartedCount := 0;
  UnknownCount := 0;

  for I := 0 to High(QuestObjects) do
  begin
    Meta :=
      ReadJournalObjectMetadata(
        QuestObjects[I],
        Knowledge,
        Localization
      );

    if Meta.Family <> jfQuest then
      Continue;

    State :=
      EvaluateJournalQuest(
        QuestObjects[I],
        Meta.ID,
        Queries,
        Knowledge,
        Localization
      );

    case State.Status of
      qsCompleted:
      begin
        Inc(CompletedCount);
        WriteLn(
          'RESOLVED     ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );
      end;

      qsInProgress:
      begin
        Inc(InProgressCount);
        Write(
          'IN_PROGRESS  ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );

        if State.LatestConfirmedIndex >= 0 then
          Write(
            '  latest="',
            State.Entries[State.LatestConfirmedIndex].Name,
            '"'
          );

        if State.NextUnresolvedIndex >= 0 then
          Write(
            '  unresolved="',
            State.Entries[State.NextUnresolvedIndex].Name,
            '"'
          );

        WriteLn;
      end;

      qsNotStarted:
      begin
        Inc(NotStartedCount);
        WriteLn(
          'NOT_STARTED  ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );
      end;

    else
      begin
        Inc(UnknownCount);
        WriteLn(
          'UNKNOWN      ',
          State.Name,
          '  [$',
          IntToHex(State.QuestID, 8),
          ']'
        );
      end;
    end;
  end;

  WriteLn;
  WriteLn('=== QUEST SUMMARY ===');
  WriteLn('Resolved marker : ', CompletedCount);
  WriteLn('In progress     : ', InProgressCount);
  WriteLn('Not started     : ', NotStartedCount);
  WriteLn('Unknown         : ', UnknownCount);
end;


procedure DumpQuestInventory(
  JournalRoot: TJSONData;
  const Knowledge: TKnowledgeItems;
  const Localization: TLocalizationItems
);
var
  QuestObjects: TQuestObjectArray;
  Meta: TJournalObjectMetadata;
  I: Integer;
begin
  SetLength(QuestObjects, 0);
  CollectQuestObjects(JournalRoot, QuestObjects);

  WriteLn(
    'ID', #9,
    'Type', #9,
    'KNOW', #9,
    'AllPlayers', #9,
    'Priority', #9,
    'Entries', #9,
    'Document', #9,
    'Name'
  );

  for I := 0 to High(QuestObjects) do
  begin
    Meta :=
      ReadJournalObjectMetadata(
        QuestObjects[I],
        Knowledge,
        Localization
      );

    if Meta.Family <> jfQuest then
      Continue;

    WriteLn(
      IntToHex(Meta.ID, 8), #9,
      Meta.RawType, #9,
      Ord(
        Meta.DirectKnowFound and
        (Meta.DirectKnowValue <> 0)
      ), #9,
      BoolToStr(
        Meta.UnlockForAllPlayers,
        True
      ), #9,
      Meta.Priority, #9,
      Meta.EntryCount, #9,
      Meta.ReferencedDocumentName, #9,
      Meta.Name
    );
  end;
end;



function JournalFamilyText(Family: TJournalFamily): string;
begin
  case Family of
    jfQuest:    Result := 'QUEST';
    jfLore:     Result := 'LORE';
    jfTutorial: Result := 'TUTORIAL';
  else
    Result := 'UNKNOWN';
  end;
end;



end.
