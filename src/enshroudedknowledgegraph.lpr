program EnshroudedKnowledgeGraph;

{$mode objfpc}{$H+}

uses
  SysUtils,
  Classes,
  fpjson,
  jsonparser,
  uLocalization, uKnowledge, uQueryModel, uQueryEvaluator, uJournalEvaluator;

var
  Queries: TQueryArray;
  Localization: TLocalizationItems;


{ ---------------------------------------------------------------------------
  Generic helpers
  --------------------------------------------------------------------------- }

  function QuestStatusText(Status: TQuestStatus): string;
begin
  case Status of
    qsCompleted:
      Result := 'RESOLVED';

    qsInProgress:
      Result := 'IN_PROGRESS';

    qsNotStarted:
      Result := 'NOT_STARTED';

  else
    Result := 'UNKNOWN';
  end;
end;

function ParseID(const S: string): QWord;
var
  T: string;
begin
  T := Trim(S);

  if Pos('0x', LowerCase(T)) = 1 then
    Exit(StrToQWord('$' + Copy(T, 3, MaxInt)));

  if Pos('$', T) = 1 then
    Exit(StrToQWord(T));

  if
    (Pos('A', UpperCase(T)) > 0) or
    (Pos('B', UpperCase(T)) > 0) or
    (Pos('C', UpperCase(T)) > 0) or
    (Pos('D', UpperCase(T)) > 0) or
    (Pos('E', UpperCase(T)) > 0) or
    (Pos('F', UpperCase(T)) > 0)
  then
    Exit(StrToQWord('$' + T));

  Result := StrToQWord(T);
end;


function BoolText(B: Boolean): string;
begin
  if B then
    Result := 'true'
  else
    Result := 'false';
end;


function FormatID(ID: QWord): string;
begin
  Result :=
    UIntToStr(ID) +
    ' ($' +
    IntToHex(ID, 8) +
    ')';
end;


procedure AddUnique(var Values: TUIntArray; Value: QWord);
var
  I: Integer;
begin
  if Value = 0 then
    Exit;

  for I := 0 to High(Values) do
    if Values[I] = Value then
      Exit;

  SetLength(Values, Length(Values) + 1);
  Values[High(Values)] := Value;
end;


{ ---------------------------------------------------------------------------
  JSON helpers
  --------------------------------------------------------------------------- }

function LoadJsonFile(const FileName: string): TJSONData;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(
    FileName,
    fmOpenRead or fmShareDenyNone
  );

  try
    Result := GetJSON(Stream);
  finally
    Stream.Free;
  end;
end;


function GetStringField(
  Obj: TJSONObject;
  const FieldName: string;
  const DefaultValue: string = ''
): string;
var
  D: TJSONData;
begin
  D := Obj.Find(FieldName);

  if Assigned(D) then
    Result := D.AsString
  else
    Result := DefaultValue;
end;


function GetBoolField(
  Obj: TJSONObject;
  const FieldName: string;
  DefaultValue: Boolean = False
): Boolean;
var
  D: TJSONData;
begin
  D := Obj.Find(FieldName);

  if Assigned(D) then
    Result := D.AsBoolean
  else
    Result := DefaultValue;
end;


function GetIntField(
  Obj: TJSONObject;
  const FieldName: string;
  DefaultValue: Integer = 0
): Integer;
var
  D: TJSONData;
begin
  D := Obj.Find(FieldName);

  if Assigned(D) then
    Result := D.AsInteger
  else
    Result := DefaultValue;
end;


function GetUIntPath(
  Obj: TJSONObject;
  const Path: string;
  DefaultValue: QWord = 0
): QWord;
var
  Parts: TStringArray;
  Current: TJSONData;
  I: Integer;
begin
  Result := DefaultValue;

  Parts := Path.Split(['.']);
  Current := Obj;

  for I := 0 to High(Parts) do
  begin
    if not Assigned(Current) then
      Exit;

    if Current.JSONType <> jtObject then
      Exit;

    Current :=
      TJSONObject(Current).Find(Parts[I]);
  end;

  if Assigned(Current) then
    Result := Current.AsQWord;
end;


{ ---------------------------------------------------------------------------
  Localization
  --------------------------------------------------------------------------- }

function Loca(ID: QWord): string;
var
  S: UTF8String;
begin
  if ID = 0 then
    Exit('');

  if
    (ID <= High(Cardinal)) and
    FindLocalization(
      Localization,
      Cardinal(ID),
      S
    )
  then
    Result := string(S)
  else
    Result :=
      '<loca:$' +
      IntToHex(ID, 8) +
      '>';
end;


procedure LoadEnglishLocalization;
const
  DAT_FILE =
    'E:\SteamLibrary\steamapps\common\Enshrouded\enshrouded_016.dat';

  ENGLISH_SEED_OFFSET = $3F95ABE0;
begin
  if not FileExists(DAT_FILE) then
  begin
    WriteLn(
      'Warning: localization DAT not found: ',
      DAT_FILE
    );

    SetLength(Localization, 0);
    Exit;
  end;

  if not LoadLocalizationTable(
       DAT_FILE,
       ENGLISH_SEED_OFFSET,
       Localization
     ) then
    raise Exception.Create(
      'Unable to load English localization table'
    );

  WriteLn(
    'Localization entries: ',
    Length(Localization)
  );
end;


{ ---------------------------------------------------------------------------
  Query database
  --------------------------------------------------------------------------- }

function FindQueryIndexByIDLocal(
  ID: QWord
): Integer;
begin
  Result :=
    uQueryModel.FindQueryIndexByID(
      Queries,
      ID
    );
end;

procedure AddQuery(const Query: TQueryInfo);
begin
  if Query.ID = 0 then
    Exit;

  if FindQueryIndexByIDLocal(Query.ID) >= 0 then
    Exit;

  SetLength(Queries, Length(Queries) + 1);
  Queries[High(Queries)] := Query;
end;


procedure ParseQueryObject(Obj: TJSONObject);
var
  Query: TQueryInfo;

  Actions: TJSONArray;
  ActionObj: TJSONObject;
  RequirementObj: TJSONObject;

  Condition: TQueryCondition;

  I: Integer;
begin
  Query.ID :=
    GetUIntPath(
      Obj,
      'queryId.id.value',
      0
    );

  if Query.ID = 0 then
    Exit;

  Query.Name :=
    GetStringField(
      Obj,
      'name'
    );

  Query.LogicType :=
    GetStringField(
      Obj,
      'type'
    );

  Query.QueryIndex :=
    GetIntField(
      Obj,
      'queryIndex'
    );

  Query.InvertResult :=
    GetBoolField(
      Obj,
      'invertResult'
    );

  Query.IsPlayerQuery :=
    GetBoolField(
      Obj,
      'isPlayerQuery'
    );

  Query.HasOptionalPlayerProgression :=
    GetBoolField(
      Obj,
      'hasOptionalPlayerProgression'
    );

  SetLength(Query.Conditions, 0);
  SetLength(Query.Dependencies, 0);

  if
    not Assigned(Obj.Find('actions')) or
    (Obj.Find('actions').JSONType <> jtArray)
  then
  begin
    AddQuery(Query);
    Exit;
  end;

  Actions :=
    TJSONArray(
      Obj.Find('actions')
    );

  for I := 0 to Actions.Count - 1 do
  begin
    if Actions.Items[I].JSONType <> jtObject then
      Continue;

    ActionObj :=
      TJSONObject(
        Actions.Items[I]
      );

    Condition.ActionType :=
      GetStringField(
        ActionObj,
        'type'
      );

    Condition.Name :=
      GetStringField(
        ActionObj,
        'name'
      );

    Condition.ID := 0;
    Condition.CompareValue := 0;
    Condition.CompareOperator := '';
    Condition.RequirementType := '';

    Condition.QueryIndex :=
      GetIntField(
        ActionObj,
        'queryIndex'
      );

    Condition.PlayerProgressionQueryIndex :=
      GetIntField(
        ActionObj,
        'playerProgressionQueryIndex'
      );

    Condition.InvertResult :=
      GetBoolField(
        ActionObj,
        'invertResult'
      );

    Condition.IsPlayerAction :=
      GetBoolField(
        ActionObj,
        'isPlayerAction'
      );

    Condition.IsExplicitPlayerKnowledgeQuery := False;

    if
      Assigned(ActionObj.Find('query')) and
      (ActionObj.Find('query').JSONType = jtObject)
    then
    begin
      RequirementObj :=
        TJSONObject(
          ActionObj.Find('query')
        );

      Condition.ID :=
        GetUIntPath(
          RequirementObj,
          'knowledgeOrQueryId.value'
        );

      Condition.CompareValue :=
        GetUIntPath(
          RequirementObj,
          'compareValue'
        );

      Condition.CompareOperator :=
        GetStringField(
          RequirementObj,
          'compareOperator'
        );

      Condition.RequirementType :=
        GetStringField(
          RequirementObj,
          'type'
        );

      Condition.IsExplicitPlayerKnowledgeQuery :=
        GetBoolField(
          RequirementObj,
          'isExplicitPlayerKnowledgeQuery'
        );
    end;

    SetLength(
      Query.Conditions,
      Length(Query.Conditions) + 1
    );

    Query.Conditions[
      High(Query.Conditions)
    ] := Condition;

    AddUnique(
      Query.Dependencies,
      Condition.ID
    );
  end;

  AddQuery(Query);
end;


procedure ScanQueries(Node: TJSONData);
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  if not Assigned(Node) then
    Exit;

  case Node.JSONType of

    jtObject:
      begin
        Obj := TJSONObject(Node);

        ParseQueryObject(Obj);

        for I := 0 to Obj.Count - 1 do
          ScanQueries(
            Obj.Items[I]
          );
      end;

    jtArray:
      begin
        Arr := TJSONArray(Node);

        for I := 0 to Arr.Count - 1 do
          ScanQueries(
            Arr.Items[I]
          );
      end;
  end;
end;


procedure LoadQueryDatabase(
  const FileName: string;
  out Root: TJSONData
);
begin
  WriteLn('Loading query database...');

  SetLength(Queries, 0);

  Root :=
    LoadJsonFile(
      FileName
    );

  ScanQueries(Root);

  WriteLn(
    'Indexed queries: ',
    Length(Queries)
  );
end;


{ ---------------------------------------------------------------------------
  Query dependency graph
  --------------------------------------------------------------------------- }

function QueryDirectlyDependsOn(
  QueryIndex: Integer;
  TargetID: QWord
): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Queries[QueryIndex].Dependencies) do
    if Queries[QueryIndex].Dependencies[I] = TargetID then
      Exit(True);

  Result := False;
end;


function QueryDependsOn(
  QueryIndex: Integer;
  TargetID: QWord;
  Depth: Integer
): Boolean;
var
  I: Integer;
  ChildIndex: Integer;
  DependencyID: QWord;
begin
  Result := False;

  if Depth > 64 then
    Exit;

  for I := 0 to High(Queries[QueryIndex].Dependencies) do
  begin
    DependencyID :=
      Queries[QueryIndex].Dependencies[I];

    if DependencyID = TargetID then
      Exit(True);

    ChildIndex :=
      FindQueryIndexByIDLocal(
        DependencyID
      );

    if
      (ChildIndex >= 0) and
      QueryDependsOn(
        ChildIndex,
        TargetID,
        Depth + 1
      )
    then
      Exit(True);
  end;
end;


procedure DumpDirectQueryReferences(TargetID: QWord);
var
  I: Integer;
begin
  WriteLn;
  WriteLn('=== DIRECT QUERY REFERENCES ===');

  for I := 0 to High(Queries) do
    if QueryDirectlyDependsOn(I, TargetID) then
      WriteLn(
        FormatID(Queries[I].ID),
        '  ',
        Queries[I].Name
      );
end;


procedure DumpAllDependentQueries(TargetID: QWord);
var
  I: Integer;
begin
  WriteLn;
  WriteLn('=== ALL DEPENDENT QUERIES ===');

  for I := 0 to High(Queries) do
    if QueryDependsOn(I, TargetID, 0) then
      WriteLn(
        FormatID(Queries[I].ID),
        '  ',
        Queries[I].Name
      );
end;


{ ---------------------------------------------------------------------------
  Query inspection
  --------------------------------------------------------------------------- }

procedure DumpQuery(QueryID: QWord);
var
  Index: Integer;
  I: Integer;
  C: TQueryCondition;
begin
  Index :=
    FindQueryIndexByIDLocal(
      QueryID
    );

  if Index < 0 then
  begin
    WriteLn(
      'Query not found: ',
      FormatID(QueryID)
    );
    Exit;
  end;

  WriteLn;
  WriteLn('=== QUERY ===');

  WriteLn(
    'ID                         : ',
    FormatID(Queries[Index].ID)
  );

  WriteLn(
    'Name                       : ',
    Queries[Index].Name
  );

  WriteLn(
    'Logic type                 : ',
    Queries[Index].LogicType
  );

  WriteLn(
    'Query index                : ',
    Queries[Index].QueryIndex
  );

  WriteLn(
    'Invert result              : ',
    BoolText(Queries[Index].InvertResult)
  );

  WriteLn(
    'Player query               : ',
    BoolText(Queries[Index].IsPlayerQuery)
  );

  WriteLn(
    'Optional player progression: ',
    BoolText(
      Queries[Index].HasOptionalPlayerProgression
    )
  );

  WriteLn(
    'Actions                    : ',
    Length(Queries[Index].Conditions)
  );

  for I := 0 to High(Queries[Index].Conditions) do
  begin
    C :=
      Queries[Index].Conditions[I];

    WriteLn;
    WriteLn(
      '  Action #',
      I
    );

    WriteLn(
      '    Action type     : ',
      C.ActionType
    );

    WriteLn(
      '    Name            : ',
      C.Name
    );

    WriteLn(
      '    ID              : ',
      FormatID(C.ID)
    );

    WriteLn(
      '    Requirement type: ',
      C.RequirementType
    );

    WriteLn(
      '    Compare         : ',
      C.CompareOperator,
      ' ',
      C.CompareValue
    );

    WriteLn(
      '    Invert          : ',
      BoolText(C.InvertResult)
    );

    WriteLn(
      '    Player action   : ',
      BoolText(C.IsPlayerAction)
    );

    WriteLn(
      '    Explicit player : ',
      BoolText(
        C.IsExplicitPlayerKnowledgeQuery
      )
    );

    WriteLn(
      '    Query index     : ',
      C.QueryIndex
    );

    WriteLn(
      '    Player prog idx : ',
      C.PlayerProgressionQueryIndex
    );
  end;
end;


{ ---------------------------------------------------------------------------
  Journal
  --------------------------------------------------------------------------- }

function RequirementDependsOn(
  RequirementObj: TJSONObject;
  TargetID: QWord
): Boolean;
var
  ID: QWord;
  QueryIndex: Integer;
begin
  Result := False;

  ID :=
    GetUIntPath(
      RequirementObj,
      'knowledgeOrQueryId.value'
    );

  if ID = 0 then
    Exit;

  if ID = TargetID then
    Exit(True);

  QueryIndex :=
    FindQueryIndexByIDLocal(
      ID
    );

  if QueryIndex >= 0 then
    Result :=
      QueryDependsOn(
        QueryIndex,
        TargetID,
        0
      );
end;


procedure DumpRequirement(
  const LabelName: string;
  RequirementObj: TJSONObject
);
var
  ID: QWord;
  CompareValue: QWord;
  CompareOperator: string;
  RequirementType: string;
begin
  ID :=
    GetUIntPath(
      RequirementObj,
      'knowledgeOrQueryId.value'
    );

  CompareValue :=
    GetUIntPath(
      RequirementObj,
      'compareValue'
    );

  CompareOperator :=
    GetStringField(
      RequirementObj,
      'compareOperator'
    );

  RequirementType :=
    GetStringField(
      RequirementObj,
      'type'
    );

  WriteLn(
    '    ',
    LabelName,
    ': ',
    FormatID(ID),
    ' ',
    RequirementType,
    ' ',
    CompareOperator,
    ' ',
    CompareValue
  );
end;


procedure ScanJournal(
  JournalRoot: TJSONData;
  TargetID: QWord
);
var
  RootObj: TJSONObject;
  Quests: TJSONArray;
  QuestObj: TJSONObject;
  Entries: TJSONArray;
  EntryObj: TJSONObject;

  KnowledgeRequirement: TJSONObject;
  CompletionRequirement: TJSONObject;

  QuestID: QWord;
  QuestNameID: QWord;

  EntryID: QWord;
  EntryNameID: QWord;
  EntryTextID: QWord;

  MatchKnowledge: Boolean;
  MatchCompletion: Boolean;

  I, J: Integer;
begin
  WriteLn;
  WriteLn('=== JOURNAL REFERENCES ===');

  if
    not Assigned(JournalRoot) or
    (JournalRoot.JSONType <> jtObject)
  then
    Exit;

  RootObj :=
    TJSONObject(JournalRoot);

  if
    not Assigned(RootObj.Find('quests')) or
    (RootObj.Find('quests').JSONType <> jtArray)
  then
    Exit;

  Quests :=
    TJSONArray(
      RootObj.Find('quests')
    );

  for I := 0 to Quests.Count - 1 do
  begin
    if Quests.Items[I].JSONType <> jtObject then
      Continue;

    QuestObj :=
      TJSONObject(
        Quests.Items[I]
      );

    QuestID :=
      GetUIntPath(
        QuestObj,
        'entryId.value'
      );

    QuestNameID :=
      GetUIntPath(
        QuestObj,
        'name.value'
      );

    if
      not Assigned(QuestObj.Find('entries')) or
      (QuestObj.Find('entries').JSONType <> jtArray)
    then
      Continue;

    Entries :=
      TJSONArray(
        QuestObj.Find('entries')
      );

    for J := 0 to Entries.Count - 1 do
    begin
      if Entries.Items[J].JSONType <> jtObject then
        Continue;

      EntryObj :=
        TJSONObject(
          Entries.Items[J]
        );

      EntryID :=
        GetUIntPath(
          EntryObj,
          'entryId.value'
        );

      EntryNameID :=
        GetUIntPath(
          EntryObj,
          'name.value'
        );

      EntryTextID :=
        GetUIntPath(
          EntryObj,
          'text.value'
        );

      KnowledgeRequirement := nil;
      CompletionRequirement := nil;

      if
        Assigned(EntryObj.Find('knowledgeRequirement')) and
        (EntryObj.Find('knowledgeRequirement').JSONType = jtObject)
      then
        KnowledgeRequirement :=
          TJSONObject(
            EntryObj.Find('knowledgeRequirement')
          );

      if
        Assigned(EntryObj.Find('completionRequirement')) and
        (EntryObj.Find('completionRequirement').JSONType = jtObject)
      then
        CompletionRequirement :=
          TJSONObject(
            EntryObj.Find('completionRequirement')
          );

      MatchKnowledge :=
        Assigned(KnowledgeRequirement) and
        RequirementDependsOn(
          KnowledgeRequirement,
          TargetID
        );

      MatchCompletion :=
        Assigned(CompletionRequirement) and
        RequirementDependsOn(
          CompletionRequirement,
          TargetID
        );

      if not MatchKnowledge and not MatchCompletion then
        Continue;

      WriteLn;

      WriteLn(
        'Quest: ',
        Loca(QuestNameID),
        '  [ID $',
        IntToHex(QuestID, 8),
        ']'
      );

      WriteLn(
        'Entry: ',
        Loca(EntryNameID),
        '  [ID $',
        IntToHex(EntryID, 8),
        ']'
      );

      WriteLn(
        'Text: ',
        Loca(EntryTextID)
      );

      if MatchKnowledge then
        WriteLn(
          'MATCH: knowledgeRequirement'
        );

      if MatchCompletion then
        WriteLn(
          'MATCH: completionRequirement'
        );

      if Assigned(KnowledgeRequirement) then
        DumpRequirement(
          'knowledgeRequirement',
          KnowledgeRequirement
        );

      if Assigned(CompletionRequirement) then
        DumpRequirement(
          'completionRequirement',
          CompletionRequirement
        );
    end;
  end;
end;


{ ---------------------------------------------------------------------------
  Commands
  --------------------------------------------------------------------------- }

procedure RunQueryMode(
  const QueryFileName: string;
  QueryID: QWord
);
var
  QueryRoot: TJSONData;
begin
  QueryRoot := nil;

  try
    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    DumpQuery(
      QueryID
    );

  finally
    QueryRoot.Free;
  end;
end;


procedure RunGraphMode(
  const JournalFileName: string;
  const QueryFileName: string;
  TargetID: QWord
);
var
  QueryRoot: TJSONData;
  JournalRoot: TJSONData;
begin
  QueryRoot := nil;
  JournalRoot := nil;

  try
    LoadEnglishLocalization;

    WriteLn(
      'Target ID: ',
      FormatID(TargetID)
    );

    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    WriteLn(
      'Loading journal...'
    );

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    DumpDirectQueryReferences(
      TargetID
    );

    DumpAllDependentQueries(
      TargetID
    );

    ScanJournal(
      JournalRoot,
      TargetID
    );

  finally
    JournalRoot.Free;
    QueryRoot.Free;
  end;
end;


procedure Usage;
begin
  WriteLn('Usage:');
  WriteLn;

  WriteLn(
    '  EnshroudedKnowledgeGraph ',
    '<JournalRegistry.json> ',
    '<GameKnowledgeQueryResourceDb.json> ',
    '<ID>'
  );

  WriteLn;

  WriteLn(
    '  EnshroudedKnowledgeGraph ',
    '--query ',
    '<GameKnowledgeQueryResourceDb.json> ',
    '<QueryID>'
  );

  WriteLn;
  WriteLn('Examples:');

  WriteLn(
    '  EnshroudedKnowledgeGraph ',
    'journal.json querydb.json 4E7CCCFE'
  );

  WriteLn(
    '  EnshroudedKnowledgeGraph ',
    '--query querydb.json 9BB81DE8'
  );

  WriteLn;
WriteLn(
  '  EnshroudedKnowledgeGraph ',
  '--eval-query ',
  '<QueryDb.json> ',
  '<know_keys.txt> ',
  '<QueryID>'
);

WriteLn(
  '  EnshroudedKnowledgeGraph ',
  '--eval-query-trace ',
  '<QueryDb.json> ',
  '<know_keys.txt> ',
  '<QueryID>'
);

WriteLn(
  '  EnshroudedKnowledgeGraph ',
  '--journal-state ',
  '<Journal.json> ',
  '<QueryDb.json> ',
  '<know_keys.txt> ',
  '<QuestID>'
);

WriteLn(
  '  EnshroudedKnowledgeGraph ',
  '--journal-all ',
  '<Journal.json> ',
  '<QueryDb.json> ',
  '<know_keys.txt>'
);

WriteLn(
  '  EnshroudedKnowledgeGraph ',
  '--journal-inventory ',
  '<Journal.json> ',
  '<know_keys.txt>'
);

WriteLn('  EnshroudedKnowledgeGraph --journal-quests <Journal.json> <QueryDb.json> <know_keys.txt>');
WriteLn('  EnshroudedKnowledgeGraph --journal-quest-inventory <Journal.json> <know_keys.txt>');
WriteLn(
  '  EnshroudedKnowledgeGraph ',
  '--quest-progress ',
  '<Journal.json> ',
  '<know_keys.txt>'
);

end;


procedure RunEvalQueryMode(
  const QueryFileName: string;
  const KnowledgeFileName: string;
  QueryID: Cardinal
);
var
  QueryRoot: TJSONData;
  Knowledge: TKnowledgeItems;
  ResultValue: TEvalResult;
begin
  QueryRoot := nil;

  try
    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );

    ResultValue :=
      EvaluateQuery(
        QueryID,
        Queries,
        Knowledge
      );

    WriteLn;
    WriteLn(
      FormatID(QueryID),
      ' -> ',
      EvalResultText(ResultValue)
    );

  finally
    QueryRoot.Free;
  end;
end;


procedure RunEvalQueryTraceMode(
  const QueryFileName: string;
  const KnowledgeFileName: string;
  QueryID: Cardinal
);
var
  QueryRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  QueryRoot := nil;

  try
    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );

    WriteLn;
    WriteLn('=== EVALUATION TRACE ===');
    WriteLn;

    TraceQueryEvaluation(
      QueryID,
      Queries,
      Knowledge
    );

  finally
    QueryRoot.Free;
  end;
end;

procedure RunJournalStateMode(
  const JournalFileName: string;
  const QueryFileName: string;
  const KnowledgeFileName: string;
  QuestID: Cardinal
);
var
  JournalRoot: TJSONData;
  QueryRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  JournalRoot := nil;
  QueryRoot := nil;

  try
    LoadEnglishLocalization;

    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );

    WriteLn;

    DumpJournalQuestState(
      JournalRoot,
      QuestID,
      Queries,
      Knowledge,
      Localization
    );

  finally
    JournalRoot.Free;
    QueryRoot.Free;
  end;
end;


procedure RunJournalAllMode(
  const JournalFileName: string;
  const QueryFileName: string;
  const KnowledgeFileName: string
);
var
  JournalRoot: TJSONData;
  QueryRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  JournalRoot := nil;
  QueryRoot := nil;

  try
    LoadEnglishLocalization;

    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );

    WriteLn;

    DumpAllJournalQuestStates(
      JournalRoot,
      Queries,
      Knowledge,
      Localization
    );

  finally
    JournalRoot.Free;
    QueryRoot.Free;
  end;
end;

procedure RunJournalInventoryMode(
  const JournalFileName: string;
  const KnowledgeFileName: string
);
var
  JournalRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  JournalRoot := nil;

  try
    LoadEnglishLocalization;

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );

    WriteLn;

    DumpJournalInventory(
      JournalRoot,
      Knowledge,
      Localization
    );

    WriteLn;

    DumpLoreRequirementStats(
      JournalRoot,
      Knowledge,
      Localization
    );

  finally
    JournalRoot.Free;
  end;
end;

procedure RunJournalQuestsMode(
  const JournalFileName: string;
  const QueryFileName: string;
  const KnowledgeFileName: string
);
var
  JournalRoot: TJSONData;
  QueryRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  JournalRoot := nil;
  QueryRoot := nil;

  try
    LoadEnglishLocalization;

    LoadQueryDatabase(
      QueryFileName,
      QueryRoot
    );

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );
    WriteLn;

    DumpQuestJournalStates(
      JournalRoot,
      Queries,
      Knowledge,
      Localization
    );

  finally
    JournalRoot.Free;
    QueryRoot.Free;
  end;
end;

procedure RunQuestProgressMode(
  const JournalFileName: string;
  const KnowledgeFileName: string
);
var
  JournalRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  JournalRoot := nil;

  try
    LoadEnglishLocalization;

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );

    WriteLn;

    DumpQuestPersonalProgress(
      JournalRoot,
      Knowledge,
      Localization
    );

  finally
    JournalRoot.Free;
  end;
end;

procedure RunJournalQuestInventoryMode(
  const JournalFileName: string;
  const KnowledgeFileName: string
);
var
  JournalRoot: TJSONData;
  Knowledge: TKnowledgeItems;
begin
  JournalRoot := nil;

  try
    LoadEnglishLocalization;

    JournalRoot :=
      LoadJsonFile(
        JournalFileName
      );

    LoadKnowledgeFile(
      KnowledgeFileName,
      Knowledge
    );

    WriteLn(
      'KNOW entries: ',
      Length(Knowledge)
    );
    WriteLn;

    writeln('***********yo**************');

    DumpQuestInventory(
      JournalRoot,
      Knowledge,
      Localization
    );

    DumpLoreProgress(
                     JournalRoot,
                     Knowledge,
                     Localization
                     );

  finally
    JournalRoot.Free;
  end;
end;


{ ---------------------------------------------------------------------------
  Main
  --------------------------------------------------------------------------- }

var
  TargetID: QWord;

begin
  try

    if
  (ParamCount = 3) and
  SameText(
    ParamStr(1),
    '--quest-progress'
  )
then
begin
  RunQuestProgressMode(
    ParamStr(2),
    ParamStr(3)
  );

  Halt(0);
end;

    if
      (ParamCount = 4) and
      SameText(
        ParamStr(1),
        '--journal-quests'
      )
    then
    begin
      RunJournalQuestsMode(
        ParamStr(2),
        ParamStr(3),
        ParamStr(4)
      );

      Halt(0);
    end;

    if
      (ParamCount = 3) and
      SameText(
        ParamStr(1),
        '--journal-quest-inventory'
      )
    then
    begin
      RunJournalQuestInventoryMode(
        ParamStr(2),
        ParamStr(3)
      );

      Halt(0);
    end;

    if
      (ParamCount = 4) and
      SameText(
        ParamStr(1),
        '--eval-query'
      )
    then
    begin
      TargetID :=
        ParseID(
          ParamStr(4)
        );

      if TargetID > High(Cardinal) then
        raise Exception.Create(
          'Query ID exceeds uint32'
        );

      RunEvalQueryMode(
        ParamStr(2),
        ParamStr(3),
        Cardinal(TargetID)
      );

      Halt(0);
    end;

    if
  (ParamCount = 3) and
  SameText(
    ParamStr(1),
    '--journal-inventory'
  )
then
begin
  RunJournalInventoryMode(
    ParamStr(2),
    ParamStr(3)
  );

  Halt(0);
end;

    if
  (ParamCount = 4) and
  SameText(
    ParamStr(1),
    '--journal-all'
  )
then
begin
  RunJournalAllMode(
    ParamStr(2),
    ParamStr(3),
    ParamStr(4)
  );

  Halt(0);
end;


    if
  (ParamCount = 4) and
  SameText(
    ParamStr(1),
    '--eval-query-trace'
  )
then
begin
  TargetID :=
    ParseID(
      ParamStr(4)
    );

  if TargetID > High(Cardinal) then
    raise Exception.Create(
      'Query ID exceeds uint32'
    );

  RunEvalQueryTraceMode(
    ParamStr(2),
    ParamStr(3),
    Cardinal(TargetID)
  );

  Halt(0);
end;

    if
  (ParamCount = 5) and
  SameText(
    ParamStr(1),
    '--journal-state'
  )
then
begin
  TargetID :=
    ParseID(
      ParamStr(5)
    );

  if TargetID > High(Cardinal) then
    raise Exception.Create(
      'Quest ID exceeds uint32'
    );

  RunJournalStateMode(
    ParamStr(2),
    ParamStr(3),
    ParamStr(4),
    Cardinal(TargetID)
  );

  Halt(0);
end;

    if
      (ParamCount = 3) and
      SameText(
        ParamStr(1),
        '--query'
      )
    then
    begin
      TargetID :=
        ParseID(
          ParamStr(3)
        );

      RunQueryMode(
        ParamStr(2),
        TargetID
      );

      Halt(0);
    end;


    if ParamCount = 3 then
    begin
      TargetID :=
        ParseID(
          ParamStr(3)
        );

      RunGraphMode(
        ParamStr(1),
        ParamStr(2),
        TargetID
      );

      Halt(0);
    end;


    Usage;
    Halt(1);

  except
    on E: Exception do
    begin
      WriteLn(
        StdErr,
        'ERROR: ',
        E.Message
      );

      Halt(2);
    end;
  end;
end.
