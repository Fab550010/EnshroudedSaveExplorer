program extractknowledgeids;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser;

var
  InputFile, OutputFile: string;
  JSONText: TStringList;
  Root: TJSONData;
  Arr: TJSONArray;
  Obj, IdObj, InnerIdObj: TJSONObject;
  I: Integer;
  V: Int64;
  OutFile: TextFile;

begin
  if ParamCount <> 2 then
  begin
    WriteLn('Usage: ExtractKnowledgeIds <input.json> <output.txt>');
    Halt(1);
  end;

  InputFile := ParamStr(1);
  OutputFile := ParamStr(2);

  JSONText := TStringList.Create;
  try
    JSONText.LoadFromFile(InputFile);

    Root := GetJSON(JSONText.Text);
    try
      if Root.JSONType <> jtObject then
        raise Exception.Create('Root JSON is not an object');

      Arr := TJSONObject(Root).Arrays['worldKnowledge'];

      AssignFile(OutFile, OutputFile);
      Rewrite(OutFile);
      try
        for I := 0 to Arr.Count - 1 do
        begin
          Obj := Arr.Objects[I];
          IdObj := Obj.Objects['id'];
          InnerIdObj := IdObj.Objects['id'];

          V := InnerIdObj.Get('value', Int64(-1));

          if V >= 0 then
            WriteLn(
              OutFile,
              V,
              #9,
              IntToHex(QWord(V), 8)
            );
        end;
      finally
        CloseFile(OutFile);
      end;

    finally
      Root.Free;
    end;

  finally
    JSONText.Free;
  end;

  WriteLn('Done.');
end.
