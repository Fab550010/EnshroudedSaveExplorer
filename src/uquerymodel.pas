unit uQueryModel;

{$mode objfpc}{$H+}

interface

type
  TUIntArray = array of QWord;

  TQueryCondition = record
    ActionType: string;
    Name: string;

    ID: QWord;
    CompareValue: QWord;
    CompareOperator: string;
    RequirementType: string;

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
    Dependencies: TUIntArray;
  end;

  TQueryArray = array of TQueryInfo;


function FindQueryIndexByID(
  const Queries: TQueryArray;
  ID: QWord
): Integer;


implementation


function FindQueryIndexByID(
  const Queries: TQueryArray;
  ID: QWord
): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Queries) do
  begin
    if Queries[I].ID = ID then
      Exit(I);
  end;

  Result := -1;
end;


end.
