unit uQueryEvaluator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  uKnowledge,
  uQueryModel;

type
  TEvalResult = (
    erFalse,
    erTrue,
    erUnknown
  );


function EvalResultText(
  Value: TEvalResult
): string;


function EvaluateQuery(
  QueryID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
): TEvalResult;


procedure TraceQueryEvaluation(
  QueryID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
);

function EvaluateRequirement(
  ID: Cardinal;
  const RequirementType: string;
  const CompareOperator: string;
  CompareValue: Cardinal;
  InvertResult: Boolean;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
): TEvalResult;


implementation

const
  MAX_QUERY_DEPTH = 64;


function EvalResultText(
  Value: TEvalResult
): string;
begin
  case Value of
    erFalse:
      Result := 'FALSE';

    erTrue:
      Result := 'TRUE';

  else
    Result := 'UNKNOWN';
  end;
end;


function FormatID(
  ID: QWord
): string;
begin
  Result :=
    IntToStr(ID) +
    ' ($' +
    IntToHex(ID, 8) +
    ')';
end;


function Indent(
  Depth: Integer
): string;
begin
  Result :=
    StringOfChar(
      ' ',
      Depth * 2
    );
end;


function InvertEvalResult(
  Value: TEvalResult
): TEvalResult;
begin
  case Value of
    erFalse:
      Result := erTrue;

    erTrue:
      Result := erFalse;

  else
    Result := erUnknown;
  end;
end;


function CompareValue(
  ActualValue: Cardinal;
  const OperatorName: string;
  ExpectedValue: Cardinal
): Boolean;
begin
  if SameText(OperatorName, 'Equals') then
    Exit(
      ActualValue = ExpectedValue
    );

  if SameText(OperatorName, 'NotEquals') then
    Exit(
      ActualValue <> ExpectedValue
    );

  if SameText(OperatorName, 'GreaterThan') then
    Exit(
      ActualValue > ExpectedValue
    );

  if SameText(OperatorName, 'GreaterThanOrEqual') then
    Exit(
      ActualValue >= ExpectedValue
    );

  if SameText(OperatorName, 'LessThan') then
    Exit(
      ActualValue < ExpectedValue
    );

  if SameText(OperatorName, 'LessThanOrEqual') then
    Exit(
      ActualValue <= ExpectedValue
    );

  Result := False;
end;


function EvaluateQueryInternal(
  QueryID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  Depth: Integer;
  Trace: Boolean
): TEvalResult; forward;


function EvaluateCondition(
  const Condition: TQueryCondition;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  Depth: Integer;
  Trace: Boolean
): TEvalResult;
var
  ActualValue: Cardinal;
  Found: Boolean;
begin
  Result := erUnknown;

  if Trace then
  begin
    WriteLn(
      Indent(Depth),
      Condition.ActionType,
      ': ',
      Condition.Name
    );

    WriteLn(
      Indent(Depth + 1),
      'ID: ',
      FormatID(Condition.ID)
    );

    WriteLn(
      Indent(Depth + 1),
      'Requirement: ',
      Condition.RequirementType,
      ' ',
      Condition.CompareOperator,
      ' ',
      Condition.CompareValue
    );
  end;


  {
    SimpleBool
  }
  if SameText(
       Condition.RequirementType,
       'SimpleBool'
     ) then
  begin
    Found :=
      FindKnowledgeValue(
        Knowledge,
        Cardinal(Condition.ID),
        ActualValue
      );

    if not Found then
      ActualValue := 0;

    if Trace then
    begin
      if Found then
        WriteLn(
          Indent(Depth + 1),
          'KNOW value: ',
          ActualValue
        )
      else
        WriteLn(
          Indent(Depth + 1),
          'KNOW value: missing -> 0'
        );
    end;

    if CompareValue(
         ActualValue,
         Condition.CompareOperator,
         Cardinal(Condition.CompareValue)
       ) then
      Result := erTrue
    else
      Result := erFalse;
  end

  {
    SimpleFlag
  }
  else if SameText(
            Condition.RequirementType,
            'SimpleFlag'
          ) then
  begin
    Found :=
      FindKnowledgeValue(
        Knowledge,
        Cardinal(Condition.ID),
        ActualValue
      );

    if not Found then
      ActualValue := 0;

    if Trace then
    begin
      if Found then
        WriteLn(
          Indent(Depth + 1),
          'KNOW flags: ',
          ActualValue,
          ' ($',
          IntToHex(ActualValue, 8),
          ')'
        )
      else
        WriteLn(
          Indent(Depth + 1),
          'KNOW flags: missing -> 0'
        );
    end;

    if SameText(
         Condition.CompareOperator,
         'Equals'
       ) then
    begin
      if
        (ActualValue and Cardinal(Condition.CompareValue)) =
        Cardinal(Condition.CompareValue)
      then
        Result := erTrue
      else
        Result := erFalse;
    end
    else
      Result := erUnknown;
  end

  {
    External query
  }
  else if SameText(
            Condition.RequirementType,
            'Extern'
          ) then
  begin
    Result :=
      EvaluateQueryInternal(
        Cardinal(Condition.ID),
        Queries,
        Knowledge,
        Depth + 1,
        Trace
      );
  end;


  if Condition.InvertResult then
  begin
    Result :=
      InvertEvalResult(Result);

    if Trace then
      WriteLn(
        Indent(Depth + 1),
        'Condition inverted'
      );
  end;


  if Trace then
    WriteLn(
      Indent(Depth + 1),
      '=> ',
      EvalResultText(Result)
    );
end;

function EvaluateRequirement(
  ID: Cardinal;
  const RequirementType: string;
  const CompareOperator: string;
  CompareValue: Cardinal;
  InvertResult: Boolean;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
): TEvalResult;
var
  Condition: TQueryCondition;
begin
  Condition.ActionType := '';
  Condition.Name := '';
  Condition.ID := ID;
  Condition.CompareValue := CompareValue;
  Condition.CompareOperator := CompareOperator;
  Condition.RequirementType := RequirementType;
  Condition.QueryIndex := 0;
  Condition.PlayerProgressionQueryIndex := 0;
  Condition.InvertResult := InvertResult;
  Condition.IsPlayerAction := False;
  Condition.IsExplicitPlayerKnowledgeQuery := False;

  Result :=
    EvaluateCondition(
      Condition,
      Queries,
      Knowledge,
      0,
      False
    );
end;

function EvaluateQueryInternal(
  QueryID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems;
  Depth: Integer;
  Trace: Boolean
): TEvalResult;
var
  QueryArrayIndex: Integer;
  I: Integer;

  ChildResult: TEvalResult;
  HasUnknown: Boolean;

  Query: TQueryInfo;
begin
  Result := erUnknown;

  if Depth > MAX_QUERY_DEPTH then
  begin
    if Trace then
      WriteLn(
        Indent(Depth),
        'Maximum recursion depth reached'
      );

    Exit;
  end;


  QueryArrayIndex :=
    FindQueryIndexByID(
      Queries,
      QueryID
    );

  if QueryArrayIndex < 0 then
  begin
    if Trace then
      WriteLn(
        Indent(Depth),
        FormatID(QueryID),
        ' QUERY NOT FOUND -> UNKNOWN'
      );

    Exit;
  end;


  Query :=
    Queries[QueryArrayIndex];


  if Trace then
  begin
    WriteLn(
      Indent(Depth),
      FormatID(Query.ID),
      ' ',
      Query.Name,
      ' [',
      Query.LogicType,
      ']'
    );
  end;


  {
    Runtime query / primitive.
  }
  if Length(Query.Conditions) = 0 then
  begin
    if Trace then
    begin
      WriteLn(
        Indent(Depth + 1),
        'No decomposable actions'
      );

      WriteLn(
        Indent(Depth + 1),
        'Runtime/engine query -> UNKNOWN'
      );
    end;

    Result := erUnknown;
  end

  else if SameText(
            Query.LogicType,
            'AND'
          ) then
  begin
    HasUnknown := False;
    Result := erTrue;

    for I := 0 to High(Query.Conditions) do
    begin
      ChildResult :=
        EvaluateCondition(
          Query.Conditions[I],
          Queries,
          Knowledge,
          Depth + 1,
          Trace
        );

      if ChildResult = erFalse then
      begin
        Result := erFalse;
        Break;
      end;

      if ChildResult = erUnknown then
        HasUnknown := True;
    end;

    if
      (Result <> erFalse) and
      HasUnknown
    then
      Result := erUnknown;
  end

  else if SameText(
            Query.LogicType,
            'OR'
          ) then
  begin
    HasUnknown := False;
    Result := erFalse;

    for I := 0 to High(Query.Conditions) do
    begin
      ChildResult :=
        EvaluateCondition(
          Query.Conditions[I],
          Queries,
          Knowledge,
          Depth + 1,
          Trace
        );

      if ChildResult = erTrue then
      begin
        Result := erTrue;
        Break;
      end;

      if ChildResult = erUnknown then
        HasUnknown := True;
    end;

    if
      (Result <> erTrue) and
      HasUnknown
    then
      Result := erUnknown;
  end

  else
  begin
    {
      Unknown/runtime logic type.
    }
    if Trace then
      WriteLn(
        Indent(Depth + 1),
        'Unsupported/runtime logic type: ',
        Query.LogicType
      );

    Result := erUnknown;
  end;


  if Query.InvertResult then
  begin
    Result :=
      InvertEvalResult(Result);

    if Trace then
      WriteLn(
        Indent(Depth + 1),
        'Query result inverted'
      );
  end;


  if Trace then
  begin
    WriteLn(
      Indent(Depth),
      '=> ',
      EvalResultText(Result)
    );

    WriteLn;
  end;
end;


function EvaluateQuery(
  QueryID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
): TEvalResult;
begin
  Result :=
    EvaluateQueryInternal(
      QueryID,
      Queries,
      Knowledge,
      0,
      False
    );
end;


procedure TraceQueryEvaluation(
  QueryID: Cardinal;
  const Queries: TQueryArray;
  const Knowledge: TKnowledgeItems
);
begin
  EvaluateQueryInternal(
    QueryID,
    Queries,
    Knowledge,
    0,
    True
  );
end;



end.
