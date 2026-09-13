unit uSteamDiscovery;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes;

function FindEnshroudedCharactersIndex(
  out IndexFileName: string
): Boolean;

implementation

uses

  Registry;

const
  ENSHROUDED_APP_ID = '1203620';

  STEAM_ID64_BASE: QWord =
    76561197960265728;


function ReadRegistryString(
  RootKey: HKEY;
  const KeyName: string;
  const ValueName: string;
  out Value: string
): Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Value := '';

  Reg := TRegistry.Create(KEY_READ);

  try
    Reg.RootKey := RootKey;

    if not Reg.OpenKeyReadOnly(KeyName) then
      Exit;

    if not Reg.ValueExists(ValueName) then
      Exit;

    Value :=
      Reg.ReadString(
        ValueName
      );

    Result :=
      Value <> '';

  finally
    Reg.Free;
  end;
end;


function FindSteamPath(
  out SteamPath: string
): Boolean;
begin
  SteamPath := '';

  {
    Per-user Steam installation/configuration.
  }
  if ReadRegistryString(
       HKEY_CURRENT_USER,
       '\Software\Valve\Steam',
       'SteamPath',
       SteamPath
     )
  then
    Exit(True);

  {
    Typical 64-bit Windows installation of the
    32-bit Steam client.
  }
  if ReadRegistryString(
       HKEY_LOCAL_MACHINE,
       '\SOFTWARE\WOW6432Node\Valve\Steam',
       'InstallPath',
       SteamPath
     )
  then
    Exit(True);

  {
    Fallback for other configurations.
  }
  if ReadRegistryString(
       HKEY_LOCAL_MACHINE,
       '\SOFTWARE\Valve\Steam',
       'InstallPath',
       SteamPath
     )
  then
    Exit(True);

  Result := False;
end;


function GetQuotedValue(
  const S: string;
  Index: Integer
): string;
var
  I: Integer;
  StartPos: Integer;
  TokenIndex: Integer;
begin
  Result := '';

  I := 1;
  TokenIndex := 0;

  while I <= Length(S) do
  begin
    while
      (I <= Length(S)) and
      (S[I] <> '"')
    do
      Inc(I);

    if I > Length(S) then
      Exit;

    Inc(I);
    StartPos := I;

    while
      (I <= Length(S)) and
      (S[I] <> '"')
    do
      Inc(I);

    if I > Length(S) then
      Exit;

    if TokenIndex = Index then
    begin
      Result :=
        Copy(
          S,
          StartPos,
          I - StartPos
        );

      Exit;
    end;

    Inc(TokenIndex);
    Inc(I);
  end;
end;


function FindMostRecentSteamID64(
  const LoginUsersFileName: string;
  out SteamID64: QWord
): Boolean;
var
  Lines: TStringList;
  I: Integer;

  KeyText: string;
  ValueText: string;

  CandidateID: QWord;
  CurrentSteamID64: QWord;
begin
  Result := False;
  SteamID64 := 0;
  CurrentSteamID64 := 0;

  if not FileExists(LoginUsersFileName) then
    Exit;

  Lines := TStringList.Create;

  try
    Lines.LoadFromFile(
      LoginUsersFileName
    );

    for I := 0 to Lines.Count - 1 do
    begin
      KeyText :=
        GetQuotedValue(
          Trim(Lines[I]),
          0
        );

      if KeyText = '' then
        Continue;

      {
        A Steam user block starts with its SteamID64:
          "7656119..."
      }
      if
        TryStrToQWord(
          KeyText,
          CandidateID
        ) and
        (CandidateID >= STEAM_ID64_BASE)
      then
      begin
        CurrentSteamID64 :=
          CandidateID;

        Continue;
      end;

      ValueText :=
        GetQuotedValue(
          Trim(Lines[I]),
          1
        );

      if
        SameText(
          KeyText,
          'MostRecent'
        ) and
        (ValueText = '1') and
        (CurrentSteamID64 <> 0)
      then
      begin
        SteamID64 :=
          CurrentSteamID64;

        Exit(True);
      end;
    end;

  finally
    Lines.Free;
  end;
end;


function SteamID64ToAccountID(
  SteamID64: QWord
): QWord;
begin
  if SteamID64 < STEAM_ID64_BASE then
    Exit(0);

  Result :=
    SteamID64 -
    STEAM_ID64_BASE;
end;


function BuildSteamCharactersIndexPath(
  const SteamPath: string;
  AccountID: QWord
): string;
begin
  Result :=
    IncludeTrailingPathDelimiter(
      SteamPath
    ) +
    'userdata' +
    PathDelim +
    UIntToStr(AccountID) +
    PathDelim +
    ENSHROUDED_APP_ID +
    PathDelim +
    'remote' +
    PathDelim +
    'characters-index';
end;


function FindFromMostRecentSteamUser(
  const SteamPath: string;
  out IndexFileName: string
): Boolean;
var
  LoginUsersFileName: string;
  SteamID64: QWord;
  AccountID: QWord;
begin
  Result := False;
  IndexFileName := '';

  LoginUsersFileName :=
    IncludeTrailingPathDelimiter(
      SteamPath
    ) +
    'config' +
    PathDelim +
    'loginusers.vdf';

  if not FindMostRecentSteamID64(
           LoginUsersFileName,
           SteamID64
         )
  then
    Exit;

  AccountID :=
    SteamID64ToAccountID(
      SteamID64
    );

  if AccountID = 0 then
    Exit;

  IndexFileName :=
    BuildSteamCharactersIndexPath(
      SteamPath,
      AccountID
    );

  Result :=
    FileExists(
      IndexFileName
    );

  if not Result then
    IndexFileName := '';
end;


function FindSingleSteamUserSave(
  const SteamPath: string;
  out IndexFileName: string
): Boolean;
var
  UserDataPath: string;
  SearchRec: TSearchRec;
  Candidate: string;

  CandidateCount: Integer;
begin
  Result := False;
  IndexFileName := '';

  UserDataPath :=
    IncludeTrailingPathDelimiter(
      SteamPath
    ) +
    'userdata';

  if not DirectoryExists(UserDataPath) then
    Exit;

  CandidateCount := 0;

  if FindFirst(
       IncludeTrailingPathDelimiter(UserDataPath) + '*',
       faDirectory,
       SearchRec
     ) <> 0
  then
    Exit;

  try
    repeat
      if
        (SearchRec.Name = '.') or
        (SearchRec.Name = '..')
      then
        Continue;

      if
        (SearchRec.Attr and faDirectory) = 0
      then
        Continue;

      Candidate :=
        IncludeTrailingPathDelimiter(
          UserDataPath
        ) +
        SearchRec.Name +
        PathDelim +
        ENSHROUDED_APP_ID +
        PathDelim +
        'remote' +
        PathDelim +
        'characters-index';

      if not FileExists(Candidate) then
        Continue;

      Inc(CandidateCount);

      IndexFileName :=
        Candidate;

    until FindNext(SearchRec) <> 0;

  finally
    FindClose(SearchRec);
  end;

  {
    We only select automatically when there is
    exactly one Enshrouded account candidate.
  }
  Result :=
    CandidateCount = 1;

  if not Result then
    IndexFileName := '';
end;


function FindLocalCharactersIndex(
  out IndexFileName: string
): Boolean;
var
  UserProfile: string;
begin
  Result := False;
  IndexFileName := '';

  UserProfile :=
    GetEnvironmentVariable(
      'USERPROFILE'
    );

  if UserProfile = '' then
    Exit;

  IndexFileName :=
    IncludeTrailingPathDelimiter(
      UserProfile
    ) +
    'Saved Games' +
    PathDelim +
    'Enshrouded' +
    PathDelim +
    'characters-index';

  Result :=
    FileExists(
      IndexFileName
    );

  if not Result then
    IndexFileName := '';
end;


function FindEnshroudedCharactersIndex(
  out IndexFileName: string
): Boolean;
var
  SteamPath: string;
begin
  Result := False;
  IndexFileName := '';

  if FindSteamPath(SteamPath) then
  begin
    {
      Preferred method:
      Steam's most recently used account.
    }
    if FindFromMostRecentSteamUser(
         SteamPath,
         IndexFileName
       )
    then
      Exit(True);

    {
      Fallback:
      if exactly one Steam account has Enshrouded saves,
      it is safe to use it.
    }
    if FindSingleSteamUserSave(
         SteamPath,
         IndexFileName
       )
    then
      Exit(True);
  end;

  {
    Non-Steam-Cloud/local-save fallback.
  }
  if FindLocalCharactersIndex(
       IndexFileName
     )
  then
    Exit(True);
end;

end.
