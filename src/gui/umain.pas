unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Grids;

type

  { TMainForm }

  TMainForm = class(TForm)
    OpenSaveButton: TButton;
    QuestGrid: TStringGrid;
    TopPanel: TPanel;
  private

  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

end.

