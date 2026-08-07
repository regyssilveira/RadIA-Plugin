unit RadIA.Provider.GithubCopilot;

interface

uses  System.SyncObjs,
  RadIA.Core.Interfaces, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAGithubCopilotProvider = class(TRadIAOpenAICompatibleProvider)
  private
    class var FSessionLock: TCriticalSection;
    class var FSessionToken: string;
    class var FTokenExpiryTime: TDateTime;

    class constructor Create;
    class destructor Destroy;
  protected
    function GetBaseUrl: string; override;
    function GetAuthorizationHeader: string; override;
    function EnsureSessionToken: string;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;

    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;

    { Static OAuth Device Flow Authentication helper methods }
    class function RequestDeviceCode(out ADeviceCode, AUserCode, AVerificationUri: string;
      out AInterval, AExpiresIn: Integer; out AErrorMsg: string): Boolean; static;
    class function PollForAccessToken(const ADeviceCode: string; AInterval, AExpiresIn: Integer;
      const ACancelledRef: PBoolean; out AAccessToken, AErrorMsg: string): Boolean; static;
    class procedure ClearSessionToken; static;
  end;

implementation

uses
  System.JSON, System.DateUtils, System.Threading, RadIA.Core.ProviderRegistry, RadIA.Core.Logger, System.SysUtils,
      System.Classes, System.Net.HttpClient, System.Net.URLClient, RadIA.Core.Types, RadIA.Core.TokenUsage;

const
  COPILOT_CLIENT_ID = '01ab8ac9400c4e429b23'; // Official Client ID for VS Code Copilot

{ TRadIAGithubCopilotProvider }

class constructor TRadIAGithubCopilotProvider.Create;
begin
  FSessionLock := TCriticalSection.Create;
  FSessionToken := '';
  FTokenExpiryTime := 0;
end;

class destructor TRadIAGithubCopilotProvider.Destroy;
begin
  FSessionLock.Free;
end;

class procedure TRadIAGithubCopilotProvider.ClearSessionToken;
begin
  FSessionLock.Enter;
  try
    FSessionToken := '';
    FTokenExpiryTime := 0;
  finally
    FSessionLock.Leave;
  end;
end;

constructor TRadIAGithubCopilotProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'GithubCopilot';
end;

function TRadIAGithubCopilotProvider.GetBaseUrl: string;
begin
  Result := 'https://api.githubcopilot.com';
end;

function TRadIAGithubCopilotProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create('gpt-5.4', 'claude-sonnet-4.6');
end;

function TRadIAGithubCopilotProvider.GetName: string;
begin
  Result := 'GitHub Copilot';
end;

function TRadIAGithubCopilotProvider.EnsureSessionToken: string;
var
  LApiKey: string;
  LHeaders: TNetHeaders;
  LJson: TJSONObject;
  LValue: TJSONValue;
  LToken: string;
  LRefreshIn: Integer;
  LResponseStr: string;
begin
  FSessionLock.Acquire;
  try
    { If token is still valid with more than 1 minute of margin, reuse it }
    if (not FSessionToken.IsEmpty) and (Now < FTokenExpiryTime) and (SecondsBetween(Now, FTokenExpiryTime) > 60) then
    begin
      Result := FSessionToken;
      Exit;
    end;

    LApiKey := GetApiKey;
    if LApiKey.IsEmpty then
      raise Exception.Create('GitHub Copilot token (ghu_... / gho_...) is missing. Please check settings.');

    TLogger.Log('Retrieving fresh GitHub Copilot session token...', 'Provider');

    SetLength(LHeaders, 2);
    LHeaders[0] := TNetHeader.Create('Authorization', 'token ' + LApiKey);
    LHeaders[1] := TNetHeader.Create('User-Agent', 'GithubCopilot/1.155.0');

    try
      LResponseStr := FHTTPClient.Get('https://api.github.com/copilot_internal/v2/token', LHeaders, 15000);
    except
      on E: ERadIAHttpException do
      begin
        var LDecodedError := FErrorDecoder.DecodeError(E.StatusCode, E.Content);
        raise Exception.Create(LDecodedError);
      end;
      on E: Exception do
        raise;
    end;

    LJson := TJSONObject.ParseJSONValue(LResponseStr) as TJSONObject;
    if not Assigned(LJson) then
      raise Exception.Create('Failed to parse token response JSON.');

    try
      LValue := LJson.GetValue('token');
      if Assigned(LValue) then
        LToken := LValue.Value
      else
        LToken := '';

      LValue := LJson.GetValue('refresh_in');
      if Assigned(LValue) then
        LRefreshIn := StrToIntDef(LValue.Value, 1500)
      else
        LRefreshIn := 1500;

      if LToken.IsEmpty then
        raise Exception.Create('Token field is missing in response.');

      FSessionToken := LToken;
      FTokenExpiryTime := IncSecond(Now, LRefreshIn);

      TLogger.Log('GitHub Copilot session token retrieved successfully. Valid for ' + LRefreshIn.ToString + ' ' +
          'seconds.', 'Provider');
      Result := FSessionToken;
    finally
      LJson.Free;
    end;
  finally
    FSessionLock.Release;
  end;
end;

function TRadIAGithubCopilotProvider.GetAuthorizationHeader: string;
begin
  Result := 'Bearer ' + FSessionToken;
end;

procedure TRadIAGithubCopilotProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(
    procedure
    var
      LSessionToken: string;
      LUrl, LRequestBody: string;
      LHeaders: TNetHeaders;
    begin
      try
        try
          LSessionToken := EnsureSessionToken;
        except
          on E: Exception do
          begin
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback('', 'Failed to obtain session token: ' + E.Message, False, TTokenUsage.Empty);
                end);
            end;
            Exit;
          end;
        end;

        LUrl := GetBaseUrl.TrimRight(['/']) + '/chat/completions';

        SetLength(LHeaders, 5);
        LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + LSessionToken);
        LHeaders[1] := TNetHeader.Create('User-Agent', 'GithubCopilot/1.155.0');
        LHeaders[2] := TNetHeader.Create('Editor-Version', 'vscode/1.80.0');
        LHeaders[3] := TNetHeader.Create('Editor-Plugin-Version', 'copilot-chat/0.4.1');
        LHeaders[4] := TNetHeader.Create('X-Request-Id', TGUID.NewGuid.ToString.ToLower.Replace('{',
            '').Replace('}', ''));

        try
          LRequestBody := BuildOpenAICompatibleRequestBody(APrompt, AHistory, False, ATemperature, AMaxTokens);
        except
          on E: Exception do
          begin
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback('', 'Error building request JSON: ' + E.Message, False, TTokenUsage.Empty);
                end);
            end;
            Exit;
          end;
        end;

        ExecuteRequestAsync(LUrl, LHeaders, LRequestBody,
          function(const AResponseJson: string; out AUsage: TTokenUsage): string
          begin
            Result := ParseOpenAICompatibleResponse(AResponseJson, AUsage);
          end, ACallback);
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end);
end;

procedure TRadIAGithubCopilotProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(
    procedure
    var
      LSessionToken: string;
      LUrl, LRequestBody: string;
      LHeaders: TNetHeaders;
    begin
      try
        try
          LSessionToken := EnsureSessionToken;
        except
          on E: Exception do
          begin
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback('', True, 'Failed to obtain session token: ' + E.Message);
                end);
            end;
            Exit;
          end;
        end;

        LUrl := GetBaseUrl.TrimRight(['/']) + '/chat/completions';

        SetLength(LHeaders, 5);
        LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + LSessionToken);
        LHeaders[1] := TNetHeader.Create('User-Agent', 'GithubCopilot/1.155.0');
        LHeaders[2] := TNetHeader.Create('Editor-Version', 'vscode/1.80.0');
        LHeaders[3] := TNetHeader.Create('Editor-Plugin-Version', 'copilot-chat/0.4.1');
        LHeaders[4] := TNetHeader.Create('X-Request-Id', TGUID.NewGuid.ToString.ToLower.Replace('{',
            '').Replace('}', ''));

        try
          LRequestBody := BuildOpenAICompatibleRequestBody(APrompt, AHistory, True, ATemperature, AMaxTokens);
        except
          on E: Exception do
          begin
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback('', True, 'Error building request JSON: ' + E.Message);
                end);
            end;
            Exit;
          end;
        end;

        ExecuteRequestStreamAsync(LUrl, LHeaders, LRequestBody,
          function(const ABuffer: string): string
          var
            LTemp: string;
          begin
            LTemp := ABuffer;
            ProcessOpenAICompatibleStreamBuffer(LTemp, ACallback);
            Result := LTemp;
          end, ACallback);
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end);
end;

class function TRadIAGithubCopilotProvider.RequestDeviceCode(out ADeviceCode, AUserCode,
  AVerificationUri: string; out AInterval, AExpiresIn: Integer; out AErrorMsg: string): Boolean;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
  LSourceStream: TStringStream;
  LJson: TJSONObject;
  LVal: TJSONValue;
  LRequestBody: string;
begin
  Result := False;
  AErrorMsg := '';
  ADeviceCode := '';
  AUserCode := '';
  AVerificationUri := '';
  AInterval := 5;
  AExpiresIn := 900;

  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 10000;
    LClient.SendTimeout := 10000;
    LClient.ResponseTimeout := 10000;
    LClient.AcceptCharSet := 'utf-8';

    SetLength(LHeaders, 2);
    LHeaders[0] := TNetHeader.Create('Accept', 'application/json');
    LHeaders[1] := TNetHeader.Create('Content-Type', 'application/x-www-form-urlencoded');

    LRequestBody := 'client_id=' + COPILOT_CLIENT_ID + '&scope=read:user';
    LSourceStream := TStringStream.Create(LRequestBody, TEncoding.UTF8);
    try
      try
        LResponse := LClient.Post('https://github.com/login/device/code', LSourceStream, nil, LHeaders);
        if LResponse.StatusCode <> 200 then
        begin
          AErrorMsg := Format('HTTP %d: %s', [LResponse.StatusCode, LResponse.StatusText]);
          Exit;
        end;

        LJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;
        if not Assigned(LJson) then
        begin
          AErrorMsg := 'Invalid response format from GitHub.';
          Exit;
        end;

        try
          LVal := LJson.GetValue('device_code');
          if Assigned(LVal) then ADeviceCode := LVal.Value;

          LVal := LJson.GetValue('user_code');
          if Assigned(LVal) then AUserCode := LVal.Value;

          LVal := LJson.GetValue('verification_uri');
          if Assigned(LVal) then AVerificationUri := LVal.Value;

          LVal := LJson.GetValue('interval');
          if Assigned(LVal) then AInterval := StrToIntDef(LVal.Value, 5);

          LVal := LJson.GetValue('expires_in');
          if Assigned(LVal) then AExpiresIn := StrToIntDef(LVal.Value, 900);

          Result := (not ADeviceCode.IsEmpty) and (not AUserCode.IsEmpty);
          if not Result then
            AErrorMsg := 'GitHub response did not contain required authentication codes.';
        finally
          LJson.Free;
        end;
      except
        on E: Exception do
        begin
          AErrorMsg := E.Message;
        end;
      end;
    finally
      LSourceStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

function ProcessPollResponse(const AJsonStr: string; var AIntervalMs: Integer;
  out AAccessToken, AErrorMsg: string; out AAbort: Boolean): Boolean;
var
  LJson: TJSONObject;
  LVal, LErrVal: TJSONValue;
begin
  Result := False;
  AAbort := False;
  AAccessToken := '';
  AErrorMsg := '';
  LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  if not Assigned(LJson) then Exit;
  try
    LVal := LJson.GetValue('access_token');
    if Assigned(LVal) then
    begin
      AAccessToken := LVal.Value;
      Result := not AAccessToken.IsEmpty;
      AAbort := True;
      Exit;
    end;

    LErrVal := LJson.GetValue('error');
    if Assigned(LErrVal) then
    begin
      if SameText(LErrVal.Value, 'authorization_pending') then
      begin
        { Still waiting, continue loop }
      end
      else if SameText(LErrVal.Value, 'slow_down') then
      begin
        AIntervalMs := AIntervalMs + 5000;
      end
      else
      begin
        LVal := LJson.GetValue('error_description');
        if Assigned(LVal) then
          AErrorMsg := LVal.Value
        else
          AErrorMsg := LErrVal.Value;
        AAbort := True;
      end;
    end;
  finally
    LJson.Free;
  end;
end;

class function TRadIAGithubCopilotProvider.PollForAccessToken(const ADeviceCode: string;
  AInterval, AExpiresIn: Integer; const ACancelledRef: PBoolean; out AAccessToken,
  AErrorMsg: string): Boolean;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
  LSourceStream: TStringStream;
  LElapsed: Integer;
  LIntervalMs: Integer;
  LRequestBody: string;
  LAbort: Boolean;
begin
  Result := False;
  AAccessToken := '';
  AErrorMsg := '';
  LElapsed := 0;
  LIntervalMs := AInterval * 1000;
  if LIntervalMs <= 0 then LIntervalMs := 5000;

  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 10000;
    LClient.SendTimeout := 10000;
    LClient.ResponseTimeout := 10000;
    LClient.AcceptCharSet := 'utf-8';

    SetLength(LHeaders, 2);
    LHeaders[0] := TNetHeader.Create('Accept', 'application/json');
    LHeaders[1] := TNetHeader.Create('Content-Type', 'application/x-www-form-urlencoded');

    LRequestBody := 'client_id=' + COPILOT_CLIENT_ID +
                    '&device_code=' + ADeviceCode +
                    '&grant_type=urn:ietf:params:oauth:grant-type:device_code';

    while LElapsed < AExpiresIn do
    begin
      { Check for manual cancellation from UI }
      if Assigned(ACancelledRef) and ACancelledRef^ then
      begin
        AErrorMsg := 'Authentication cancelled by user.';
        Exit;
      end;

      LSourceStream := TStringStream.Create(LRequestBody, TEncoding.UTF8);
      try
        try
          LResponse := LClient.Post('https://github.com/login/oauth/access_token', LSourceStream, nil, LHeaders);
          if LResponse.StatusCode = 200 then
          begin
            LAbort := False;
            Result := ProcessPollResponse(LResponse.ContentAsString(TEncoding.UTF8),
              LIntervalMs, AAccessToken, AErrorMsg, LAbort);
            if LAbort then Exit;
          end
          else
          begin
            AErrorMsg := Format('HTTP error %d: %s', [LResponse.StatusCode, LResponse.StatusText]);
            Exit;
          end;
        except
          on E: Exception do
          begin
            { Network issues, wait and retry }
            TLogger.Log('PollForAccessToken: Network error, retrying: ' + E.Message, 'Provider');
          end;
        end;
      finally
        LSourceStream.Free;
      end;

      { Wait for the next poll interval }
      Sleep(LIntervalMs);
      LElapsed := LElapsed + (LIntervalMs div 1000);
    end;

    AErrorMsg := 'Authentication request expired. Please try again.';
  finally
    LClient.Free;
  end;
end;

initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'GithubCopilot',
      'GitHub Copilot',
      'https://api.githubcopilot.com',
      True,  { Requer API Key (ghu_... / gho_...) }
      False, { NÃƒÂ£o permite URL customizada }
      ['gpt-5.4', 'claude-sonnet-4.6'],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAGithubCopilotProvider.Create(ACfg);
      end
    )
  );

end.
