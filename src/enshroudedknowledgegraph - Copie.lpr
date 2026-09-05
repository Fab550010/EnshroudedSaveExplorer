program enshroudedknowledgegraph;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser, uLocalization;

type
  TUIntArray = array of QWord;

  TQueryCondition = record
    ActionType: string;
    Name: string;

    ID: QWord;

    CompareValue: QWord;
    CompareOperator: string;
    QueryType: string;

    QueryIndex: Integer;
    PlayerProgressionQueryIndex: Integer;

    InvertResult: Boolean;
    IsPlayerAction: Boolean;
    IsExplicitPlayerKnowledgeQuery: Boolean;
  end;

  TQueryConditionArray = array of TQueryCondition;

  TQueryInfo = record
    ID: QWord;
    Name: string;

    LogicType: string;
    QueryIndex: Integer;

    InvertResult: Boolean;
    IsPlayerQuery: Boolean;
    HasOptionalPlayerProgression: Boolean;

    Conditions: TQueryConditionArray;

    {
      Conservé pour le graphe de dépendances existant.
    }
    Dependencies: TUIntArray;
  end;

  TQueryArray = array of TQueryInfo;


  TKnowItem = record
    ID: Cardinal;
    Value: Cardinal;
  end;

  TKnowItems = array of TKnowItem;

  TEvalResult = (
    erFalse,
    erTrue,
    erUnknown
  );

var
  Queries: TQueryArray;
  Localization: TLocalizationItems;
  KnowItems: TKnowItems;

procedure LoadKnowKeys(
  const FileName: string;
  out Items: TKnowItems
);
var
  Lines: TStringList;
  Parts: TStringArray;
  I: Integer;
  ID, Value: QWord;
begin
  Lines := TStringList.Create;

  try
    Lines.LoadFromFile(FileName);

    SetLength(Items, 0);

    for I := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) = '' then
        Continue;

      Parts :=
        Lines[I].Split(
          [#9, ' '],
          TStringSplitOptions.ExcludeEmpty
        );

      {
        Expected format:

        Index KeyDecimal KeyHex Value
      }
      if Length(Parts) < 4 then
        Continue;

      try
        ID :=
          StrToQWord(
            Parts[1]
          );

        Value :=
          StrToQWord(
            Parts[3]
          );
      except
        Continue;
      end;

      if (ID > High(Cardinal)) or
         (Value > High(Cardinal)) then
        Continue;

      SetLength(
        Items,
        Length(Items) + 1
      );

      Items[High(Items)].ID :=
        Cardinal(ID);

      Items[High(Items)].Value :=
        Cardinal(Value);
    end;

  finally
    Lines.Free;
  end;
end;

function FindKnowValue(
  ID: Cardinal;
  out Value: Cardinal
): Boolean;
var
  L, R, M: Integer;
begin
  Result := False;
  Value := 0;

  L := 0;
  R := High(KnowItems);

  while L <= R do
  begin
    M := L + ((R - L) div 2);

    if KnowItems[M].ID = ID then
    begin
      Value := KnowItems[M].Value;
      Exit(True);
    end;

    if KnowItems[M].ID < ID then
      L := M + 1
    else
      R := M - 1;
  end;
end;

function CompareCardinal(
  ActualValue: Cardinal;
  const OperatorName: string;
  ExpectedValue: Cardinal
): Boolean;
begin
  if SameText(OperatorName, 'Equals') then
    Result := ActualValue = ExpectedValue

  else if SameText(OperatorName, 'NotEquals') then
    Result := ActualValue <> ExpectedValue

  else if SameText(OperatorName, 'GreaterThan') then
    Result := ActualValue > ExpectedValue

  else if SameText(OperatorName, 'GreaterThanOrEqual') then
    Result := ActualValue >= ExpectedValue

  else if SameText(OperatorName, 'LessThan') then
    Result := ActualValue < ExpectedValue

  else if SameText(OperatorName, 'LessThanOrEqual') then
    Result := ActualValue <= ExpectedValue

  else
    Result := False;
end;

function InvertEval(
  R: TEvalResult
): TEvalResult;
begin
  case R of
    erTrue:
      Result := erFalse;

    erFalse:
      Result := erTrue;

  else
    Result := erUnknown;
  end;
end;

function EvaluateQuery(
  QueryID: Cardinal;
  Depth: Integer = 0
): TEvalResult; forward;

function EvaluateCondition(
  const C: TQueryCondition;
  Depth: Integer
): TEvalResult;
var
  Value: Cardinal;
begin
  Result := erUnknown;

  if SameText(C.QueryType, 'SimpleBool') then
  begin
    {
      Missing Bool knowledge is treated as 0.
    }
    if not FindKnowValue(
         Cardinal(C.ID),
         Value
       ) then
      Value := 0;

    if CompareCardinal(
         Value,
         C.CompareOperator,
         Cardinal(C.CompareValue)
       ) then
      Result := erTrue
    else
      Result := erFalse;
  end

  else if SameText(C.QueryType, 'SimpleFlag') then
  begin
    if not FindKnowValue(
         Cardinal(C.ID),
         Value
       ) then
      Value := 0;

    {
      For Equals N, interpret N as required bits.

      Example:
        value=3, compareValue=2
        3 AND 2 = 2
    }
    if SameText(
         C.CompareOperator,
         'Equals'
       ) then
    begin
      if (Value and Cardinal(C.CompareValue)) =
         Cardinal(C.CompareValue) then
        Result := erTrue
      else
        Result := erFalse;
    end
    else
      Result := erUnknown;
  end

  else if SameText(C.QueryType, 'Extern') then
  begin
    Result :=
      EvaluateQuery(
        Cardinal(C.ID),
        Depth + 1
      );
  end;

  if C.InvertResult then
    Result :=
      InvertEval(Result);
end;



function EvalText(
  R: TEvalResult
): string;
begin
  case R of
    erFalse:
      Result := 'FALSE';

    erTrue:
      Result := 'TRUE';

  else
    Result := 'UNKNOWN';
  end;
end;




  function GetBoolField(
    Obj: TJSONObject;
    const FieldName: string;
    DefaultValue: Boolean = False
  ): Boolean;
  var
    D: TJSONData;
  begin
    Result := DefaultValue;

    D := Obj.Find(FieldName);

    if Assigned(D) then
      Result := D.AsBoolean;
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

    D := Obj.Find(FieldName);

    if Assigned(D) then
      Result := D.AsInteger;
  end;



  function Loca(ID: QWord): string;
  var
    S: UTF8String;
  begin
    if ID = 0 then
      Exit('');

    if (ID <= High(Cardinal)) and
       FindLocalization(
         Localization,
         Cardinal(ID),
         S
       ) then
      Result := string(S)
    else
      Result :=
        '<loca:$' +
        IntToHex(ID, 8) +
        '>';
  end;

function LoadJsonFile(const FileName: string): TJSONData;
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.LoadFromFile(FileName);
    Result := GetJSON(S.Text);
  finally
    S.Free;
  end;
end;

function FindPathData(Obj: TJSONObject; const Path: string): TJSONData;
begin
  Result := Obj.FindPath(Path);
end;

function GetUIntPath(Obj: TJSONObject; const Path: string;
  DefaultValue: QWord = 0): QWord;
var
  D: TJSONData;
begin
  Result := DefaultValue;
  D := FindPathData(Obj, Path);

  if Assigned(D) and
     (D.JSONType in [jtNumber, jtString]) then
  begin
    try
      if D.JSONType = jtString then
        Result := StrToQWord(D.AsString)
      else
        Result := QWord(D.AsInt64);
    except
      Result := DefaultValue;
    end;
  end;
end;

function GetStringField(Obj: TJSONObject; const FieldName: string;
  const DefaultValue: string = ''): string;
var
  D: TJSONData;
begin
  Result := DefaultValue;
  D := Obj.Find(FieldName);

  if Assigned(D) then
    Result := D.AsString;
end;

procedure AddUnique(var A: TUIntArray; Value: QWord);
var
  I: Integer;
begin
  if Value = 0 then
    Exit;

  for I := 0 to High(A) do
    if A[I] = Value then
      Exit;

  SetLength(A, Length(A) + 1);
  A[High(A)] := Value;
end;

procedure CollectKnowledgeRefs(Node: TJSONData; var Refs: TUIntArray);
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  D: TJSONData;
  V: QWord;
begin
  if not Assigned(Node) then
    Exit;

  case Node.JSONType of

    jtObject:
      begin
        Obj := TJSONObject(Node);

        D := Obj.Find('knowledgeOrQueryId');
        if Assigned(D) and (D.JSONType = jtObject) then
        begin
          V := GetUIntPath(TJSONObject(D), 'value', 0);
          AddUnique(Refs, V);
        end;

        for I := 0 to Obj.Count - 1 do
          CollectKnowledgeRefs(Obj.Items[I], Refs);
      end;

    jtArray:
      begin
        Arr := TJSONArray(Node);

        for I := 0 to Arr.Count - 1 do
          CollectKnowledgeRefs(Arr.Items[I], Refs);
      end;
  end;
end;

function FindQueryIndex(ID: QWord): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Queries) do
    if Queries[I].ID = ID then
      Exit(I);

  Result := -1;
end;

procedure AddQuery(const Query: TQueryInfo);
var
  I: Integer;
begin
  if Query.ID = 0 then
    Exit;

  I := FindQueryIndex(Query.ID);

  if I >= 0 then
    Exit;

  SetLength(
    Queries,
    Length(Queries) + 1
  );

  Queries[High(Queries)] := Query;
end;

procedure ScanForQueries(Node: TJSONData);
var
  Obj: TJSONObject;
  Arr: TJSONArray;

  Query: TQueryInfo;
  Actions: TJSONArray;
  ActionObj: TJSONObject;
  QueryObj: TJSONObject;

  Condition: TQueryCondition;

  I, J: Integer;
begin
  if not Assigned(Node) then
    Exit;

  case Node.JSONType of

    jtObject:
      begin
        Obj := TJSONObject(Node);

        Query.ID :=
          GetUIntPath(
            Obj,
            'queryId.id.value',
            0
          );

        if Query.ID <> 0 then
        begin
          Query.Name :=
            GetStringField(
              Obj,
              'name',
              ''
            );

          Query.LogicType :=
            GetStringField(
              Obj,
              'type',
              ''
            );

          Query.QueryIndex :=
            GetIntField(
              Obj,
              'queryIndex',
              0
            );

          Query.InvertResult :=
            GetBoolField(
              Obj,
              'invertResult',
              False
            );

          Query.IsPlayerQuery :=
            GetBoolField(
              Obj,
              'isPlayerQuery',
              False
            );

          Query.HasOptionalPlayerProgression :=
            GetBoolField(
              Obj,
              'hasOptionalPlayerProgression',
              False
            );

          SetLength(
            Query.Conditions,
            0
          );

          SetLength(
            Query.Dependencies,
            0
          );

          if Assigned(Obj.Find('actions')) and
             (Obj.Find('actions').JSONType = jtArray) then
          begin
            Actions :=
              TJSONArray(
                Obj.Find('actions')
              );

            for J := 0 to Actions.Count - 1 do
            begin
              if Actions.Items[J].JSONType <> jtObject then
                Continue;

              ActionObj :=
                TJSONObject(
                  Actions.Items[J]
                );

              FillChar(
                Condition,
                SizeOf(Condition),
                0
              );

              Condition.ActionType :=
                GetStringField(
                  ActionObj,
                  'type',
                  ''
                );

              Condition.Name :=
                GetStringField(
                  ActionObj,
                  'name',
                  ''
                );

              Condition.QueryIndex :=
                GetIntField(
                  ActionObj,
                  'queryIndex',
                  0
                );

              Condition.PlayerProgressionQueryIndex :=
                GetIntField(
                  ActionObj,
                  'playerProgressionQueryIndex',
                  0
                );

              Condition.InvertResult :=
                GetBoolField(
                  ActionObj,
                  'invertResult',
                  False
                );

              Condition.IsPlayerAction :=
                GetBoolField(
                  ActionObj,
                  'isPlayerAction',
                  False
                );

              if Assigned(ActionObj.Find('query')) and
                 (ActionObj.Find('query').JSONType = jtObject) then
              begin
                QueryObj :=
                  TJSONObject(
                    ActionObj.Find('query')
                  );

                Condition.ID :=
                  GetUIntPath(
                    QueryObj,
                    'knowledgeOrQueryId.value',
                    0
                  );

                Condition.CompareValue :=
                  GetUIntPath(
                    QueryObj,
                    'compareValue',
                    0
                  );

                Condition.CompareOperator :=
                  GetStringField(
                    QueryObj,
                    'compareOperator',
                    ''
                  );

                Condition.QueryType :=
                  GetStringField(
                    QueryObj,
                    'type',
                    ''
                  );

                Condition.IsExplicitPlayerKnowledgeQuery :=
                  GetBoolField(
                    QueryObj,
                    'isExplicitPlayerKnowledgeQuery',
                    False
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
          end;

          AddQuery(Query);
        end;

        for I := 0 to Obj.Count - 1 do
          ScanForQueries(
            Obj.Items[I]
          );
      end;

    jtArray:
      begin
        Arr := TJSONArray(Node);

        for I := 0 to Arr.Count - 1 do
          ScanForQueries(
            Arr.Items[I]
          );
      end;
  end;
end;

function BoolText(B: Boolean): string;
begin
  if B then
    Result := 'true'
  else
    Result := 'false';
end;

procedure DumpQuery(QueryID: QWord);
var
  QI: Integer;
  I: Integer;
  C: TQueryCondition;
begin
  QI := FindQueryIndex(QueryID);

  if QI < 0 then
  begin
    WriteLn(
      'Query not found: ',
      QueryID,
      ' ($',
      IntToHex(QueryID, 8),
      ')'
    );

    Exit;
  end;

  WriteLn;
  WriteLn('=== QUERY ===');

  WriteLn(
    'ID                         : ',
    Queries[QI].ID,
    ' ($',
    IntToHex(Queries[QI].ID, 8),
    ')'
  );

  WriteLn(
    'Name                       : ',
    Queries[QI].Name
  );

  WriteLn(
    'Logic type                 : ',
    Queries[QI].LogicType
  );

  WriteLn(
    'Query index                : ',
    Queries[QI].QueryIndex
  );

  WriteLn(
    'Invert result              : ',
    BoolText(
      Queries[QI].InvertResult
    )
  );

  WriteLn(
    'Player query               : ',
    BoolText(
      Queries[QI].IsPlayerQuery
    )
  );

  WriteLn(
    'Optional player progression: ',
    BoolText(
      Queries[QI].HasOptionalPlayerProgression
    )
  );

  WriteLn(
    'Actions                    : ',
    Length(
      Queries[QI].Conditions
    )
  );

  for I := 0 to High(Queries[QI].Conditions) do
  begin
    C := Queries[QI].Conditions[I];

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
      C.ID,
      ' ($',
      IntToHex(C.ID, 8),
      ')'
    );

    WriteLn(
      '    Requirement type: ',
      C.QueryType
    );

    WriteLn(
      '    Compare         : ',
      C.CompareOperator,
      ' ',
      C.CompareValue
    );

    WriteLn(
      '    Invert          : ',
      BoolText(
        C.InvertResult
      )
    );

    WriteLn(
      '    Player action   : ',
      BoolText(
        C.IsPlayerAction
      )
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


function IsVisited(const Visited: TUIntArray; ID: QWord): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Visited) do
    if Visited[I] = ID then
      Exit(True);

  Result := False;
end;

function QueryDependsOn(QueryID, TargetID: QWord;
  var Visited: TUIntArray): Boolean;
var
  QI, I: Integer;
  Dep: QWord;
begin
  Result := False;

  if QueryID = TargetID then
    Exit(True);

  if IsVisited(Visited, QueryID) then
    Exit(False);

  AddUnique(Visited, QueryID);

  QI := FindQueryIndex(QueryID);

  if QI < 0 then
    Exit(False);

  for I := 0 to High(Queries[QI].Dependencies) do
  begin
    Dep := Queries[QI].Dependencies[I];

    if Dep = TargetID then
      Exit(True);

    if FindQueryIndex(Dep) >= 0 then
      if QueryDependsOn(Dep, TargetID, Visited) then
        Exit(True);
  end;
end;

function RequirementDependsOn(Req: TJSONData;
  TargetID: QWord): Boolean;
var
  Obj: TJSONObject;
  ReqID: QWord;
  Visited: TUIntArray;
begin
  Result := False;

  if not Assigned(Req) then
    Exit;

  if Req.JSONType <> jtObject then
    Exit;

  Obj := TJSONObject(Req);

  ReqID := GetUIntPath(
    Obj,
    'knowledgeOrQueryId.value',
    0
  );

  if ReqID = 0 then
    Exit;

  if ReqID = TargetID then
    Exit(True);

  SetLength(Visited, 0);

  Result := QueryDependsOn(
    ReqID,
    TargetID,
    Visited
  );
end;

procedure PrintRequirement(const LabelText: string;
  Req: TJSONData);
var
  Obj: TJSONObject;
  ID: QWord;
  ReqType: string;
  CompareValue: QWord;
  CompareOperator: string;
begin
  if not Assigned(Req) then
    Exit;

  if Req.JSONType <> jtObject then
    Exit;

  Obj := TJSONObject(Req);

  ID := GetUIntPath(
    Obj,
    'knowledgeOrQueryId.value',
    0
  );

  ReqType := GetStringField(
    Obj,
    'type',
    ''
  );

  CompareOperator := GetStringField(
    Obj,
    'compareOperator',
    ''
  );

  CompareValue := GetUIntPath(
    Obj,
    'compareValue',
    0
  );

  WriteLn(
    '    ', LabelText, ': ',
    ID,
    ' ($', IntToHex(ID, 8), ') ',
    ReqType, ' ',
    CompareOperator, ' ',
    CompareValue
  );
end;

procedure FindJournalReferences(JournalRoot: TJSONData;
  TargetID: QWord);
var
  RootObj: TJSONObject;
  Quests: TJSONArray;
  Quest, Entry: TJSONObject;
  Entries: TJSONArray;
  KnowledgeReq, CompletionReq: TJSONData;
  Q, E: Integer;
  QuestID, QuestName: QWord;
  EntryID, EntryName, EntryText: QWord;
  MatchKnowledge, MatchCompletion: Boolean;
begin
  if JournalRoot.JSONType <> jtObject then
    raise Exception.Create('Journal root is not an object');

  RootObj := TJSONObject(JournalRoot);

  if RootObj.Find('quests') = nil then
    raise Exception.Create('Journal has no "quests" array');

  Quests := RootObj.Arrays['quests'];

  WriteLn;
  WriteLn('=== JOURNAL REFERENCES ===');

  for Q := 0 to Quests.Count - 1 do
  begin
    if Quests.Items[Q].JSONType <> jtObject then
      Continue;

    Quest := TJSONObject(Quests.Items[Q]);

    QuestID := GetUIntPath(
      Quest,
      'entryId.value',
      0
    );

    QuestName := GetUIntPath(
      Quest,
      'name.value',
      0
    );

    if Quest.Find('entries') = nil then
      Continue;

    Entries := Quest.Arrays['entries'];

    for E := 0 to Entries.Count - 1 do
    begin
      if Entries.Items[E].JSONType <> jtObject then
        Continue;

      Entry := TJSONObject(Entries.Items[E]);

      KnowledgeReq :=
        Entry.Find('knowledgeRequirement');

      CompletionReq :=
        Entry.Find('completionRequirement');

      MatchKnowledge :=
        RequirementDependsOn(
          KnowledgeReq,
          TargetID
        );

      MatchCompletion :=
        RequirementDependsOn(
          CompletionReq,
          TargetID
        );

      if MatchKnowledge or MatchCompletion then
      begin
        EntryID := GetUIntPath(
          Entry,
          'entryId.value',
          0
        );

        EntryName := GetUIntPath(
          Entry,
          'name.value',
          0
        );

        EntryText := GetUIntPath(
          Entry,
          'text.value',
          0
        );

        WriteLn;
        WriteLn(
  '  Quest: ',
  Loca(QuestName),
  '  [ID $', IntToHex(QuestID, 8), ']'
);
        WriteLn(
  '  Entry: ',
  Loca(EntryName),
  '  [ID $', IntToHex(EntryID, 8), ']'
);
        WriteLn(
  '  Text: ',
  Loca(EntryText)
);

        WriteLn(
          '  Quest name ID: ',
          QuestName,
          ' ($', IntToHex(QuestName, 8), ')'
        );

        WriteLn(
          '  Entry: ',
          EntryID,
          ' ($', IntToHex(EntryID, 8), ')'
        );

        WriteLn(
          '  Entry name ID: ',
          EntryName,
          ' ($', IntToHex(EntryName, 8), ')'
        );

        WriteLn(
          '  Entry text ID: ',
          EntryText,
          ' ($', IntToHex(EntryText, 8), ')'
        );

        if MatchKnowledge then
          WriteLn('  MATCH: knowledgeRequirement');

        if MatchCompletion then
          WriteLn('  MATCH: completionRequirement');

        PrintRequirement(
          'knowledgeRequirement',
          KnowledgeReq
        );

        PrintRequirement(
          'completionRequirement',
          CompletionReq
        );
      end;
    end;
  end;
end;

procedure FindDirectQueries(TargetID: QWord);
var
  I, J: Integer;
begin
  WriteLn;
  WriteLn('=== DIRECT QUERY REFERENCES ===');

  for I := 0 to High(Queries) do
    for J := 0 to High(Queries[I].Dependencies) do
      if Queries[I].Dependencies[J] = TargetID then
      begin
        WriteLn(
          Queries[I].ID,
          ' ($', IntToHex(Queries[I].ID, 8), ')',
          '  ',
          Queries[I].Name
        );
        Break;
      end;
end;

procedure FindAllDependentQueries(TargetID: QWord);
var
  I: Integer;
  Visited: TUIntArray;
begin
  WriteLn;
  WriteLn('=== ALL DEPENDENT QUERIES ===');

  for I := 0 to High(Queries) do
  begin
    SetLength(Visited, 0);

    if QueryDependsOn(
      Queries[I].ID,
      TargetID,
      Visited
    ) then
      WriteLn(
        Queries[I].ID,
        ' ($', IntToHex(Queries[I].ID, 8), ')',
        '  ',
        Queries[I].Name
      );
  end;
end;

function ParseID(const S: string): QWord;
var
  T: string;
begin
  T := Trim(S);

  if Pos('$', T) = 1 then
    Result := StrToQWord(T)
  else if Pos('0x', LowerCase(T)) = 1 then
    Result := StrToQWord('$' + Copy(T, 3, Length(T)))
  else
  begin
    { An 8-character value containing A-F is treated as hex }
    if (Length(T) <= 8) and
       ((Pos('A', UpperCase(T)) > 0) or
        (Pos('B', UpperCase(T)) > 0) or
        (Pos('C', UpperCase(T)) > 0) or
        (Pos('D', UpperCase(T)) > 0) or
        (Pos('E', UpperCase(T)) > 0) or
        (Pos('F', UpperCase(T)) > 0)) then
      Result := StrToQWord('$' + T)
    else
      Result := StrToQWord(T);
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
end;

procedure EvalQueryCommand(
  const QueryFileName,
        KnowFileName: string;
  QueryID: Cardinal
);
var
  Root: TJSONData;
  R: TEvalResult;
begin
  Root :=
    LoadJsonFile(
      QueryFileName
    );

  try
    SetLength(Queries, 0);

    ScanForQueries(Root);

    LoadKnowKeys(
      KnowFileName,
      KnowItems
    );

    WriteLn(
      'Queries indexed : ',
      Length(Queries)
    );

    WriteLn(
      'KNOW entries    : ',
      Length(KnowItems)
    );

    R :=
      EvaluateQuery(
        QueryID
      );

    WriteLn;
    WriteLn(
      '$',
      IntToHex(QueryID, 8),
      ' -> ',
      EvalText(R)
    );
  finally
    Root.Free;
  end;
end;


function EvaluateQuery(
  QueryID: Cardinal;
  Depth: Integer
): TEvalResult;
var
  QI, I: Integer;
  R: TEvalResult;
  HasUnknown: Boolean;
begin
  Result := erUnknown;

  if Depth > 64 then
    Exit;

  QI :=
    FindQueryIndex(
      QueryID
    );

  if QI < 0 then
    Exit;

  {
    Queries implemented directly by the game engine,
    e.g. FlameAltarCount.
  }
  if Length(Queries[QI].Conditions) = 0 then
    Exit(erUnknown);

  HasUnknown := False;

  if SameText(
       Queries[QI].LogicType,
       'AND'
     ) then
  begin
    for I := 0 to High(Queries[QI].Conditions) do
    begin
      R :=
        EvaluateCondition(
          Queries[QI].Conditions[I],
          Depth
        );

      if R = erFalse then
        Exit(erFalse);

      if R = erUnknown then
        HasUnknown := True;
    end;

    if HasUnknown then
      Result := erUnknown
    else
      Result := erTrue;
  end

  else if SameText(
       Queries[QI].LogicType,
       'OR'
     ) then
  begin
    for I := 0 to High(Queries[QI].Conditions) do
    begin
      R :=
        EvaluateCondition(
          Queries[QI].Conditions[I],
          Depth
        );

      if R = erTrue then
        Exit(erTrue);

      if R = erUnknown then
        HasUnknown := True;
    end;

    if HasUnknown then
      Result := erUnknown
    else
      Result := erFalse;
  end

  else
  begin
    {
      FlameAltarCount and other runtime query types.
    }
    Result := erUnknown;
  end;

  if Queries[QI].InvertResult then
    Result :=
      InvertEval(Result);
end;


var
  JournalRoot: TJSONData;
  QueryRoot: TJSONData;

  TargetID: QWord;

  QueryMode: Boolean;
  evalQueryMode: Boolean;
  QueryFileName: string;

begin
  JournalRoot := nil;
  QueryRoot := nil;

  try
    QueryMode :=
      (ParamCount = 3) and
      (LowerCase(ParamStr(1)) = '--query');

    evalQueryMode :=
      (ParamCount = 4) and
      (LowerCase(ParamStr(1)) = '--eval-query');

    if evalQueryMode then
    begin
         WriteLn('eval query');
           EvalQueryCommand(ParamStr(2), ParamStr(3), ParseID(ParamStr(4)));
           Halt(1);
    end;

    if QueryMode then
    begin
      QueryFileName :=
        ParamStr(2);

      TargetID :=
        ParseID(
          ParamStr(3)
        );

      WriteLn(
        'Loading query database...'
      );

      QueryRoot :=
        LoadJsonFile(
          QueryFileName
        );

      ScanForQueries(
        QueryRoot
      );

      WriteLn(
        'Indexed queries: ',
        Length(Queries)
      );

      DumpQuery(
        TargetID
      );

      QueryRoot.Free;
      Halt(0);
    end;

    {
      Normal graph mode
    }

    if (ParamCount <> 3) and (ParamCount <> 4) then
    begin
      Usage;
      Halt(1);
    end;

    {
      Keep your existing localization loading here.
    }

    TargetID :=
      ParseID(
        ParamStr(3)
      );

    WriteLn(
      'Target ID: ',
      TargetID,
      ' ($',
      IntToHex(TargetID, 8),
      ')'
    );

    WriteLn(
      'Loading query database...'
    );

    QueryRoot :=
      LoadJsonFile(
        ParamStr(2)
      );

    ScanForQueries(
      QueryRoot
    );

    WriteLn(
      'Indexed queries: ',
      Length(Queries)
    );

    WriteLn(
      'Loading journal...'
    );

    JournalRoot :=
      LoadJsonFile(
        ParamStr(1)
      );

    FindDirectQueries(
      TargetID
    );

    FindAllDependentQueries(
      TargetID
    );

    FindJournalReferences(
      JournalRoot,
      TargetID
    );

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

  JournalRoot.Free;
  QueryRoot.Free;
end.
