unit RadIA.Core.Sessions;

interface

uses
  System.Generics.Collections, RadIA.Core.Interfaces, System.JSON;

type
  TSessionInfo = record
    Id: string;
    Name: string;
    CreatedAt: TDateTime;
    LastActive: TDateTime;
    CliClientId: string;
    CliExternalSessionId: string;
    CliWorkingDirectory: string;
    CliModel: string;

    class function CreateNew(const AId, AName: string): TSessionInfo; static;
    class function ParseFromJSON(const AObj: TJSONObject): TSessionInfo; static;
  end;

  TRadIASessionManager = class
  private
    FSessionsDir: string;
    FIndexFile: string;
    FSessions: TList<TSessionInfo>;
    FActiveSessionId: string;

    procedure LoadIndex;
    procedure SaveIndex;
    function FindSessionIndex(const AId: string): Integer;

    procedure ParseIndexJsonArray(AArr: TJSONArray);
    procedure ParseHistoryJsonArray(AArr: TJSONArray; var AHistory: TArray<IRadIAChatMessage>);
    function ParseChatMessage(const AObj: TJSONObject; out AMsg: IRadIAChatMessage): Boolean;
  public
    constructor Create(const ASessionsDir: string = '');
    destructor Destroy; override;

    function CreateSession(const AName: string = ''): TSessionInfo;
    procedure DeleteSession(const AId: string);
    procedure RenameSession(const AId: string; const ANewName: string);
    procedure UpdateSessionActivity(const AId: string);
    procedure ClearCliConversation(const AId: string);
    procedure SetCliConversation(
      const AId: string;
      const AClientId: string;
      const AExternalSessionId: string;
      const AWorkingDirectory: string;
      const AModel: string
    );
    function TryGetSession(
      const AId: string;
      out ASession: TSessionInfo
    ): Boolean;

    function GetSessionFilePath(const AId: string): string;
    function SessionHasHistory(const AId: string): Boolean;
    function LoadSessionHistory(const AId: string): TArray<IRadIAChatMessage>;
    procedure SaveSessionHistory(const AId: string; const AHistory: TArray<IRadIAChatMessage>);

    property Sessions: TList<TSessionInfo> read FSessions;
    property ActiveSessionId: string read FActiveSessionId write FActiveSessionId;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.DateUtils, System.Generics.Defaults,
  RadIA.Core.Types, RadIA.Core.Logger, RadIA.Core.ChatMessage;

procedure LogSession(const AMsg: string);
begin
  TLogger.Log(AMsg, 'Sessions');
end;

{ TSessionInfo }

class function TSessionInfo.CreateNew(const AId, AName: string): TSessionInfo;
begin
  Result.Id := AId;
  Result.Name := AName;
  Result.CreatedAt := Now;
  Result.LastActive := Now;
  Result.CliClientId := '';
  Result.CliExternalSessionId := '';
  Result.CliWorkingDirectory := '';
  Result.CliModel := '';
end;

class function TSessionInfo.ParseFromJSON(const AObj: TJSONObject): TSessionInfo;
begin
  if AObj.GetValue('id') <> nil then
    Result.Id := AObj.GetValue('id').Value
  else
    Result.Id := '';

  if AObj.GetValue('name') <> nil then
    Result.Name := AObj.GetValue('name').Value
  else
    Result.Name := '';

  if AObj.GetValue('createdAt') <> nil then
  begin
    try
      Result.CreatedAt := ISO8601ToDate(AObj.GetValue('createdAt').Value);
    except
      Result.CreatedAt := Now;
    end;
  end
  else
    Result.CreatedAt := Now;

  if AObj.GetValue('lastActive') <> nil then
  begin
    try
      Result.LastActive := ISO8601ToDate(AObj.GetValue('lastActive').Value);
    except
      Result.LastActive := Now;
    end;
  end
  else
    Result.LastActive := Now;

  Result.CliClientId := AObj.GetValue<string>('cliClientId', '');
  Result.CliExternalSessionId := AObj.GetValue<string>(
    'cliExternalSessionId',
    ''
  );
  Result.CliWorkingDirectory := AObj.GetValue<string>(
    'cliWorkingDirectory',
    ''
  );
  Result.CliModel := AObj.GetValue<string>('cliModel', '');
end;

{ TRadIASessionManager }

constructor TRadIASessionManager.Create(const ASessionsDir: string);
begin
  inherited Create;
  FSessions := TList<TSessionInfo>.Create;
  if ASessionsDir.IsEmpty then
    FSessionsDir := TPath.Combine(TPath.GetHomePath, 'RadIA\sessions')
  else
    FSessionsDir := ASessionsDir;
  FIndexFile := TPath.Combine(FSessionsDir, 'sessions_index.json');
  ForceDirectories(FSessionsDir);
  LoadIndex;
end;

destructor TRadIASessionManager.Destroy;
begin
  FSessions.Free;
  inherited Destroy;
end;

function TRadIASessionManager.FindSessionIndex(const AId: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FSessions.Count - 1 do
  begin
    if SameText(FSessions[I].Id, AId) then
    begin
      Result := I;
      Break;
    end;
  end;
end;

procedure TRadIASessionManager.ParseIndexJsonArray(AArr: TJSONArray);
var
  LVal: TJSONValue;

  LInfo: TSessionInfo;
begin
  for LVal in AArr do
  begin
    if LVal is TJSONObject then
    begin
      LInfo := TSessionInfo.ParseFromJSON(LVal as TJSONObject);
      if not LInfo.Id.IsEmpty then
        FSessions.Add(LInfo);
    end;
  end;
end;

procedure TRadIASessionManager.LoadIndex;
var
  LContent: string;
  LVal: TJSONValue;
begin
  FSessions.Clear;
  if not TFile.Exists(FIndexFile) then
  begin
    LogSession('LoadIndex: Index file not found, initializing empty.');
    Exit;
  end;

  try
    LContent := TFile.ReadAllText(FIndexFile, TEncoding.UTF8);
    if LContent.IsEmpty then
      Exit;

    LVal := TJSONObject.ParseJSONValue(LContent);
    if Assigned(LVal) then
    begin
      if LVal is TJSONArray then
        ParseIndexJsonArray(LVal as TJSONArray);
      LVal.Free;
    end;

    { Sort by LastActive descending to show recent first }
    FSessions.Sort(TComparer<TSessionInfo>.Construct(
      function(const LLeft, LRight: TSessionInfo): Integer
      begin
        if LLeft.LastActive > LRight.LastActive then
          Result := -1
        else if LLeft.LastActive < LRight.LastActive then
          Result := 1
        else
          Result := 0;
      end));

    LogSession(Format('LoadIndex: Loaded %d sessions.', [FSessions.Count]));
  except
    on E: Exception do
      LogSession('LoadIndex error: ' + E.Message);
  end;
end;

procedure TRadIASessionManager.SaveIndex;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  LInfo: TSessionInfo;
begin
  LArr := TJSONArray.Create;
  try
    for LInfo in FSessions do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('id', LInfo.Id);
      LObj.AddPair('name', LInfo.Name);
      LObj.AddPair('createdAt', DateToISO8601(LInfo.CreatedAt));
      LObj.AddPair('lastActive', DateToISO8601(LInfo.LastActive));
      if LInfo.CliExternalSessionId <> '' then
      begin
        LObj.AddPair('cliClientId', LInfo.CliClientId);
        LObj.AddPair('cliExternalSessionId', LInfo.CliExternalSessionId);
        LObj.AddPair('cliWorkingDirectory', LInfo.CliWorkingDirectory);
        LObj.AddPair('cliModel', LInfo.CliModel);
      end;
      LArr.AddElement(LObj);
    end;

    TFile.WriteAllText(FIndexFile, LArr.ToJSON, TEncoding.UTF8);
  finally
    LArr.Free;
  end;
end;

procedure TRadIASessionManager.ClearCliConversation(const AId: string);
var
  LIndex: Integer;
  LInfo: TSessionInfo;
begin
  LIndex := FindSessionIndex(AId);
  if LIndex < 0 then
    Exit;
  LInfo := FSessions[LIndex];
  LInfo.CliClientId := '';
  LInfo.CliExternalSessionId := '';
  LInfo.CliWorkingDirectory := '';
  LInfo.CliModel := '';
  FSessions[LIndex] := LInfo;
  SaveIndex;
end;

function TRadIASessionManager.CreateSession(const AName: string): TSessionInfo;
var
  LGuid: TGUID;
  LSessionName: string;
begin
  CreateGUID(LGuid);
  if AName.Trim.IsEmpty then
    LSessionName := 'New Chat Session'
  else
    LSessionName := AName.Trim;

  Result := TSessionInfo.CreateNew(LGuid.ToString.Replace('{', '').Replace('}', ''), LSessionName);
  FSessions.Insert(0, Result);
  SaveIndex;

  LogSession('CreateSession: Created ' + Result.Id);
end;

procedure TRadIASessionManager.DeleteSession(const AId: string);
var
  LIndex: Integer;
  LFile: string;
begin
  LIndex := FindSessionIndex(AId);
  if LIndex <> -1 then
  begin
    FSessions.Delete(LIndex);
    SaveIndex;

    LFile := GetSessionFilePath(AId);
    if TFile.Exists(LFile) then
    begin
      try
        TFile.Delete(LFile);
      except
        on E: Exception do
          LogSession('DeleteSession: Error deleting file ' + LFile + ': ' + E.Message);
      end;
    end;

    if SameText(FActiveSessionId, AId) then
      FActiveSessionId := '';

    LogSession('DeleteSession: Deleted ' + AId);
  end;
end;

procedure TRadIASessionManager.RenameSession(const AId: string; const ANewName: string);
var
  LIndex: Integer;
  LInfo: TSessionInfo;
begin
  LIndex := FindSessionIndex(AId);
  if (LIndex <> -1) and not ANewName.Trim.IsEmpty then
  begin
    LInfo := FSessions[LIndex];
    LInfo.Name := ANewName.Trim;
    FSessions[LIndex] := LInfo;
    SaveIndex;
    LogSession('RenameSession: Renamed ' + AId + ' to ' + ANewName);
  end;
end;

procedure TRadIASessionManager.UpdateSessionActivity(const AId: string);
var
  LIndex: Integer;
  LInfo: TSessionInfo;
begin
  LIndex := FindSessionIndex(AId);
  if LIndex <> -1 then
  begin
    LInfo := FSessions[LIndex];
    LInfo.LastActive := Now;
    FSessions[LIndex] := LInfo;
    SaveIndex;
  end;
end;

procedure TRadIASessionManager.SetCliConversation(
  const AId: string;
  const AClientId: string;
  const AExternalSessionId: string;
  const AWorkingDirectory: string;
  const AModel: string
);
var
  LIndex: Integer;
  LInfo: TSessionInfo;
begin
  if Trim(AExternalSessionId) = '' then
    raise EArgumentException.Create('The external CLI session id is required.');
  LIndex := FindSessionIndex(AId);
  if LIndex < 0 then
    raise EArgumentException.Create('The RadIA chat session was not found.');
  LInfo := FSessions[LIndex];
  LInfo.CliClientId := LowerCase(Trim(AClientId));
  LInfo.CliExternalSessionId := Trim(AExternalSessionId);
  LInfo.CliWorkingDirectory := Trim(AWorkingDirectory);
  LInfo.CliModel := Trim(AModel);
  LInfo.LastActive := Now;
  FSessions[LIndex] := LInfo;
  SaveIndex;
end;

function TRadIASessionManager.TryGetSession(
  const AId: string;
  out ASession: TSessionInfo
): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindSessionIndex(AId);
  Result := LIndex >= 0;
  if Result then
    ASession := FSessions[LIndex]
  else
    ASession := Default(TSessionInfo);
end;

function TRadIASessionManager.GetSessionFilePath(const AId: string): string;
begin
  Result := TPath.Combine(FSessionsDir, AId + '.json');
end;

function TRadIASessionManager.SessionHasHistory(const AId: string): Boolean;
var
  LFile: string;
  LContent: string;
begin
  Result := False;
  LFile := GetSessionFilePath(AId);
  if not TFile.Exists(LFile) then
    Exit;

  try
    LContent := TFile.ReadAllText(LFile, TEncoding.UTF8).Trim;
    Result := (not LContent.IsEmpty) and (not SameText(LContent, '[]'));
  except
    on E: Exception do
    begin
      LogSession('SessionHasHistory error: ' + E.Message);
      Result := True;
    end;
  end;
end;

function TRadIASessionManager.ParseChatMessage(const AObj: TJSONObject; out AMsg: IRadIAChatMessage): Boolean;
var
  LRoleStr, LContentStr, LProviderStr, LModelStr: string;
begin
  Result := False;
  if AObj.GetValue('role') <> nil then
    LRoleStr := AObj.GetValue('role').Value
  else
    LRoleStr := '';

  if AObj.GetValue('content') <> nil then
    LContentStr := AObj.GetValue('content').Value
  else
    LContentStr := '';

  if AObj.GetValue('provider') <> nil then
    LProviderStr := AObj.GetValue('provider').Value
  else
    LProviderStr := '';

  if AObj.GetValue('model') <> nil then
    LModelStr := AObj.GetValue('model').Value
  else
    LModelStr := '';

  if not LContentStr.IsEmpty then
  begin
    AMsg := TRadIAChatMessage.CreateMessage(StringToMessageRole(LRoleStr), LContentStr, LProviderStr, LModelStr);
    Result := True;
  end;
end;

procedure TRadIASessionManager.ParseHistoryJsonArray(AArr: TJSONArray; var AHistory: TArray<IRadIAChatMessage>);
var
  LVal: TJSONValue;
  LMsg: IRadIAChatMessage;
begin
  for LVal in AArr do
  begin
    if LVal is TJSONObject then
    begin
      if ParseChatMessage(LVal as TJSONObject, LMsg) then
        AHistory := AHistory + [LMsg];
    end;
  end;
end;

function TRadIASessionManager.LoadSessionHistory(const AId: string): TArray<IRadIAChatMessage>;
var
  LFile: string;
  LContent: string;
  LParsedVal: TJSONValue;
begin
  Result := [];
  LFile := GetSessionFilePath(AId);
  if not TFile.Exists(LFile) then
    Exit;

  try
    LContent := TFile.ReadAllText(LFile, TEncoding.UTF8);
    if LContent.IsEmpty then
      Exit;

    LParsedVal := TJSONObject.ParseJSONValue(LContent);
    if Assigned(LParsedVal) then
    begin
      if LParsedVal is TJSONArray then
        ParseHistoryJsonArray(LParsedVal as TJSONArray, Result);
      LParsedVal.Free;
    end;
  except
    on E: Exception do
      LogSession('LoadSessionHistory error: ' + E.Message);
  end;
end;

procedure TRadIASessionManager.SaveSessionHistory(const AId: string; const AHistory: TArray<IRadIAChatMessage>);
var
  LFile: string;
  LJsonArr: TJSONArray;
  LMsgObj: TJSONObject;
  LMsg: IRadIAChatMessage;
begin
  if AId.IsEmpty then
    Exit;

  LFile := GetSessionFilePath(AId);
  LJsonArr := TJSONArray.Create;
  try
    for LMsg in AHistory do
    begin
      if LMsg.Role = mrSystem then
        Continue;

      LMsgObj := TJSONObject.Create;
      LMsgObj.AddPair('role', MessageRoleToString(LMsg.Role));
      LMsgObj.AddPair('content', LMsg.Content);
      if not LMsg.Provider.IsEmpty then
        LMsgObj.AddPair('provider', LMsg.Provider);
      if not LMsg.Model.IsEmpty then
        LMsgObj.AddPair('model', LMsg.Model);
      LJsonArr.AddElement(LMsgObj);
    end;

    TFile.WriteAllText(LFile, LJsonArr.ToJSON, TEncoding.UTF8);
  finally
    LJsonArr.Free;
  end;
end;

end.
