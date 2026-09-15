unit uJournalJSON;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpjson,
  uJournalResource;

function BuildJournalJSON(
  const Quests: TJournalQuestArray;
  const Collections: TJournalCollectionArray
): TJSONObject;

implementation

function IDObject(
  Value: Cardinal
): TJSONObject;
begin
  Result := TJSONObject.Create;

  Result.Add(
    'value',
    Int64(Value)
  );
end;

function RequirementJSON(
  const R: TJournalRequirement
): TJSONObject;
begin
  Result := TJSONObject.Create;

  Result.Add(
    'knowledgeOrQueryId',
    IDObject(R.KnowledgeOrQueryID)
  );

  Result.Add(
    'compareValue',
    Int64(R.CompareValue)
  );

  Result.Add(
    'compareOperator',
    JournalCompareOperatorText(
      R.CompareOperator
    )
  );

  Result.Add(
    'type',
    JournalRequirementTypeText(
      R.RequirementType
    )
  );

  Result.Add(
    'isExplicitPlayerKnowledgeQuery',
    R.IsExplicitPlayerKnowledgeQuery
  );
end;

function EntryJSON(
  const Entry: TJournalEntry
): TJSONObject;
var
  Progress: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;

  Result.Add(
    'entryId',
    IDObject(Entry.EntryID)
  );

  Result.Add(
    'name',
    IDObject(Entry.NameID)
  );

  Result.Add(
    'text',
    IDObject(Entry.TextID)
  );

  {
    Un requirement nul reste présent dans les données binaires.
    C'est compatible avec EvaluateRequirementObject :
    ID=0 => Exists=False.
  }

  Result.Add(
    'knowledgeRequirement',
    RequirementJSON(
      Entry.KnowledgeRequirement
    )
  );

  Result.Add(
    'completionRequirement',
    RequirementJSON(
      Entry.CompletionRequirement
    )
  );

  Progress := TJSONArray.Create;

  for I := 0 to High(Entry.ProgressStepsRequirements) do
    Progress.Add(
      RequirementJSON(
        Entry.ProgressStepsRequirements[I]
      )
    );

  Result.Add(
    'progressStepsRequirement',
    Progress
  );
end;

function ObjectJSON(
  const Obj: TJournalObject
): TJSONObject;
var
  Entries: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;

  Result.Add(
    'entryId',
    IDObject(Obj.EntryID)
  );

  Result.Add(
    'name',
    IDObject(Obj.NameID)
  );

  Result.Add(
    'priority',
    Int64(Obj.Priority)
  );

  Result.Add(
    'isTutorial',
    Obj.IsTutorial
  );

  Entries := TJSONArray.Create;

  for I := 0 to High(Obj.Entries) do
    Entries.Add(
      EntryJSON(
        Obj.Entries[I]
      )
    );

  Result.Add(
    'entries',
    Entries
  );
end;

function QuestJSON(
  const Quest: TJournalQuest
): TJSONObject;
begin
  Result :=
    ObjectJSON(
      Quest.Base
    );

  Result.Add(
    'source',
    JournalQuestSourceText(
      Quest.Source
    )
  );

  Result.Add(
    'type',
    JournalQuestTypeText(
      Quest.QuestType
    )
  );

  Result.Add(
    'unlockForAllPlayers',
    Quest.UnlockForAllPlayers
  );
end;

function CollectionJSON(
  const Collection: TJournalCollection
): TJSONObject;
begin
  Result :=
    ObjectJSON(
      Collection.Base
    );
end;

function BuildJournalJSON(
  const Quests: TJournalQuestArray;
  const Collections: TJournalCollectionArray
): TJSONObject;
var
  QuestArray: TJSONArray;
  CollectionArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;

  QuestArray := TJSONArray.Create;

  for I := 0 to High(Quests) do
    QuestArray.Add(
      QuestJSON(
        Quests[I]
      )
    );

  Result.Add(
    'quests',
    QuestArray
  );

  CollectionArray := TJSONArray.Create;

  for I := 0 to High(Collections) do
    CollectionArray.Add(
      CollectionJSON(
        Collections[I]
      )
    );

  Result.Add(
    'collections',
    CollectionArray
  );
end;

end.
