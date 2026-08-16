unit RadIA.Semantic.Client;

interface

uses
  System.SysUtils,
  RadIA.Core.ExternalMcpTransport,
  RadIA.Semantic.Workspace;

type
  TRadIASemanticEngineProbe = record
  private
    FErrorMessage: string;
    FName: string;
    FProtocolVersion: string;
    FReady: Boolean;
  public
    constructor Create(
      const AReady: Boolean;
      const AName: string;
      const AProtocolVersion: string;
      const AErrorMessage: string
    );
    property ErrorMessage: string read FErrorMessage;
    property Name: string read FName;
    property ProtocolVersion: string read FProtocolVersion;
    property Ready: Boolean read FReady;
  end;

  TRadIASemanticEngineClient = class
  public
    class function DefaultExecutablePath: string; static;
    class function Probe(
      const AExecutablePath: string;
      const ATimeoutMs: Cardinal = 5000
    ): TRadIASemanticEngineProbe; static;
  end;

  TRadIASemanticEngineSupervisor = class(
    TInterfacedObject,
    IRadIASemanticRequestClient,
    IRadIASemanticCancelableRequestClient,
    IRadIASemanticEngineLifecycle,
    IRadIASemanticEngineDiagnostics
  )
  private
    FCircuitOpenUntil: UInt64;
    FConsecutiveFailureCount: Integer;
    FExecutablePath: string;
    FFailureCount: Integer;
    FLastError: string;
    FLastLatencyMs: Int64;
    FNextRequestId: Integer;
    FRequestLock: TObject;
    FRequestCount: Integer;
    FRestartCount: Integer;
    FTimeoutMs: Cardinal;
    FTransport: IRadIAExternalMcpTransport;
    function BuildRequest(
      const AId: Integer;
      const AMethod: string;
      const AParameters: string
    ): string;
    function Exchange(
      const ARequest: string;
      const AIsCancelled: TFunc<Boolean>;
      out AResponse: string;
      out AError: string
    ): Boolean;
    function Initialize(out AError: string): Boolean;
    function EnsureTransport(
      const AAttempt: Integer;
      out AError: string
    ): Boolean;
    function WaitForResponse(
      const AIsCancelled: TFunc<Boolean>;
      out AResponse: string;
      out AError: string
    ): Boolean;
    function StartTransport(out AError: string): Boolean;
  public
    constructor Create(
      const AExecutablePath: string;
      const ATimeoutMs: Cardinal = 5000;
      const ATransport: IRadIAExternalMcpTransport = nil
    );
    destructor Destroy; override;
    function Request(
      const AMethod: string;
      const AParameters: string;
      out AResponse: string;
      out AError: string
    ): Boolean;
    function RequestCancelable(
      const AMethod: string;
      const AParameters: string;
      const AIsCancelled: TFunc<Boolean>;
      out AResponse: string;
      out AError: string
    ): Boolean;
    function GetRestartCount: Integer;
    function GetDiagnosticsJson: string;
    procedure Stop;
    property RestartCount: Integer read FRestartCount;
  end;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  Winapi.Windows,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliProcess,
  RadIA.Core.ExternalMcp;

type
  TRadIASemanticProbeState = class
  private
    FCompleted: TEvent;
    FResult: TRadIACliProcessResult;
    FStdErr: string;
    FStdOut: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendError(const AText: string);
    procedure AppendOutput(const AText: string);
    procedure Complete(const AResult: TRadIACliProcessResult);
    property Completed: TEvent read FCompleted;
    property Result: TRadIACliProcessResult read FResult;
    property StdErr: string read FStdErr;
    property StdOut: string read FStdOut;
  end;

const
  CCircuitCooldownMs = 5000;
  CFailureThreshold = 3;
  CInitializeRequest = '{"id":1,"method":"initialize","params":{}}';
  CRestartBackoffMs = 100;
  CShutdownRequest = '{"id":2,"method":"shutdown","params":{}}';

{ TRadIASemanticEngineProbe }

constructor TRadIASemanticEngineProbe.Create(
  const AReady: Boolean;
  const AName: string;
  const AProtocolVersion: string;
  const AErrorMessage: string
);
begin
  FReady := AReady;
  FName := AName;
  FProtocolVersion := AProtocolVersion;
  FErrorMessage := AErrorMessage;
end;

{ TRadIASemanticProbeState }

constructor TRadIASemanticProbeState.Create;
begin
  inherited Create;
  FCompleted := TEvent.Create(nil, True, False, '');
end;

destructor TRadIASemanticProbeState.Destroy;
begin
  FCompleted.Free;
  inherited Destroy;
end;

procedure TRadIASemanticProbeState.AppendError(const AText: string);
begin
  FStdErr := FStdErr + AText;
end;

procedure TRadIASemanticProbeState.AppendOutput(const AText: string);
begin
  FStdOut := FStdOut + AText;
end;

procedure TRadIASemanticProbeState.Complete(
  const AResult: TRadIACliProcessResult
);
begin
  FResult := AResult;
  FCompleted.SetEvent;
end;

function ParseProbeOutput(
  const AOutput: string
): TRadIASemanticEngineProbe;
var
  LDocument: TJSONObject;
  LLines: TStringList;
  LResult: TJSONObject;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    if LLines.Count = 0 then
      Exit(TRadIASemanticEngineProbe.Create(
        False,
        '',
        '',
        'The semantic engine returned no handshake response.'
      ));
    LDocument := TJSONObject.ParseJSONValue(LLines[0]) as TJSONObject;
    try
      if not Assigned(LDocument) then
        Exit(TRadIASemanticEngineProbe.Create(
          False,
          '',
          '',
          'The semantic engine returned an invalid handshake response.'
        ));
      LResult := LDocument.GetValue<TJSONObject>('result');
      if not Assigned(LResult) then
        Exit(TRadIASemanticEngineProbe.Create(
          False,
          '',
          '',
          'The semantic engine rejected the handshake.'
        ));
      Result := TRadIASemanticEngineProbe.Create(
        LResult.GetValue<string>('protocolVersion', '') = '1.0',
        LResult.GetValue<string>('name', ''),
        LResult.GetValue<string>('protocolVersion', ''),
        ''
      );
      if not Result.Ready then
        Result := TRadIASemanticEngineProbe.Create(
          False,
          Result.Name,
          Result.ProtocolVersion,
          'The semantic engine protocol is incompatible.'
        );
    finally
      LDocument.Free;
    end;
  finally
    LLines.Free;
  end;
end;

{ TRadIASemanticEngineSupervisor }

constructor TRadIASemanticEngineSupervisor.Create(
  const AExecutablePath: string;
  const ATimeoutMs: Cardinal;
  const ATransport: IRadIAExternalMcpTransport
);
begin
  inherited Create;
  FExecutablePath := AExecutablePath;
  FTimeoutMs := ATimeoutMs;
  FRequestLock := TObject.Create;
  FTransport := ATransport;
  if not Assigned(FTransport) then
    FTransport := TRadIAExternalMcpStdioTransport.Create;
end;

destructor TRadIASemanticEngineSupervisor.Destroy;
begin
  Stop;
  FRequestLock.Free;
  inherited Destroy;
end;

function TRadIASemanticEngineSupervisor.GetRestartCount: Integer;
begin
  Result := FRestartCount;
end;

function TRadIASemanticEngineSupervisor.GetDiagnosticsJson: string;
var
  LRoot: TJSONObject;
begin
  TMonitor.Enter(FRequestLock);
  try
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('running', TJSONBool.Create(FTransport.Running));
      LRoot.AddPair('requestCount', TJSONNumber.Create(FRequestCount));
      LRoot.AddPair('failureCount', TJSONNumber.Create(FFailureCount));
      LRoot.AddPair('restartCount', TJSONNumber.Create(FRestartCount));
      LRoot.AddPair(
        'consecutiveFailureCount',
        TJSONNumber.Create(FConsecutiveFailureCount)
      );
      LRoot.AddPair('lastLatencyMs', TJSONNumber.Create(FLastLatencyMs));
      LRoot.AddPair(
        'circuitOpen',
        TJSONBool.Create(GetTickCount64 < FCircuitOpenUntil)
      );
      LRoot.AddPair('lastError', FLastError);
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  finally
    TMonitor.Exit(FRequestLock);
  end;
end;

function TRadIASemanticEngineSupervisor.BuildRequest(
  const AId: Integer;
  const AMethod: string;
  const AParameters: string
): string;
var
  LDocument: TJSONObject;
  LParameters: TJSONValue;
begin
  LDocument := TJSONObject.Create;
  try
    LDocument.AddPair('id', TJSONNumber.Create(AId));
    LDocument.AddPair('method', AMethod);
    LParameters := TJSONObject.ParseJSONValue(AParameters);
    if not Assigned(LParameters) then
      LParameters := TJSONObject.Create;
    LDocument.AddPair('params', LParameters);
    Result := LDocument.ToJSON;
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticEngineSupervisor.Exchange(
  const ARequest: string;
  const AIsCancelled: TFunc<Boolean>;
  out AResponse: string;
  out AError: string
): Boolean;
begin
  AResponse := '';
  AError := '';
  if not FTransport.Send(ARequest) then
  begin
    AError := FTransport.LastError;
    if AError = '' then
      AError := 'The semantic engine request could not be sent.';
    Exit(False);
  end;
  Result := WaitForResponse(AIsCancelled, AResponse, AError);
end;

function TRadIASemanticEngineSupervisor.WaitForResponse(
  const AIsCancelled: TFunc<Boolean>;
  out AResponse: string;
  out AError: string
): Boolean;
const
  CPollIntervalMs = 25;
var
  LElapsedMs: Cardinal;
  LWaitMs: Cardinal;
begin
  LElapsedMs := 0;
  while LElapsedMs < FTimeoutMs do
  begin
    if Assigned(AIsCancelled) and AIsCancelled() then
    begin
      AError := 'The semantic engine request was cancelled.';
      Stop;
      Exit(False);
    end;
    LWaitMs := CPollIntervalMs;
    if FTimeoutMs - LElapsedMs < LWaitMs then
      LWaitMs := FTimeoutMs - LElapsedMs;
    if FTransport.Receive(LWaitMs, AResponse) then
      Exit(True);
    if not FTransport.Running then
    begin
      AError := FTransport.LastError;
      if AError = '' then
        AError := 'The semantic engine process stopped unexpectedly.';
      Exit(False);
    end;
    Inc(LElapsedMs, LWaitMs);
  end;
  AError := 'The semantic engine response timed out.';
  Result := False;
end;

function TRadIASemanticEngineSupervisor.EnsureTransport(
  const AAttempt: Integer;
  out AError: string
): Boolean;
begin
  if FTransport.Running then
    Exit(True);
  Result := StartTransport(AError);
  if not Result and (AAttempt = 0) then
    Inc(FRestartCount);
end;

function TRadIASemanticEngineSupervisor.Initialize(
  out AError: string
): Boolean;
var
  LDocument: TJSONObject;
  LResponse: string;
  LResult: TJSONObject;
begin
  Result := Exchange(
    BuildRequest(0, 'initialize', '{}'),
    nil,
    LResponse,
    AError
  );
  if not Result then
    Exit;
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    if not Assigned(LDocument) then
    begin
      AError := 'The semantic engine handshake was not valid JSON.';
      Exit(False);
    end;
    LResult := LDocument.GetValue<TJSONObject>('result');
    Result := Assigned(LResult) and
      (LResult.GetValue<string>('protocolVersion', '') = '1.0');
    if not Result then
      AError := 'The semantic engine protocol is incompatible.';
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticEngineSupervisor.Request(
  const AMethod: string;
  const AParameters: string;
  out AResponse: string;
  out AError: string
): Boolean;
begin
  Result := RequestCancelable(
    AMethod,
    AParameters,
    nil,
    AResponse,
    AError
  );
end;

function TRadIASemanticEngineSupervisor.RequestCancelable(
  const AMethod: string;
  const AParameters: string;
  const AIsCancelled: TFunc<Boolean>;
  out AResponse: string;
  out AError: string
): Boolean;
var
  LAttempt: Integer;
  LRequest: string;
  LStopwatch: TStopwatch;
begin
  AResponse := '';
  AError := '';
  TMonitor.Enter(FRequestLock);
  try
    Inc(FRequestCount);
    if GetTickCount64 < FCircuitOpenUntil then
    begin
      AError :=
        'The semantic engine circuit is temporarily open. ' +
        'The caller must use its bounded fallback.';
      FLastError := AError;
      Exit(False);
    end;
    if FCircuitOpenUntil <> 0 then
    begin
      FCircuitOpenUntil := 0;
      FConsecutiveFailureCount := 0;
    end;
    LStopwatch := TStopwatch.StartNew;
    for LAttempt := 0 to 1 do
    begin
      if not EnsureTransport(LAttempt, AError) then
        Continue;
      Inc(FNextRequestId);
      LRequest := BuildRequest(FNextRequestId, AMethod, AParameters);
      if Exchange(LRequest, AIsCancelled, AResponse, AError) then
      begin
        LStopwatch.Stop;
        FLastLatencyMs := LStopwatch.ElapsedMilliseconds;
        FConsecutiveFailureCount := 0;
        FLastError := '';
        Exit(True);
      end;
      if Assigned(AIsCancelled) and AIsCancelled() then
      begin
        LStopwatch.Stop;
        FLastLatencyMs := LStopwatch.ElapsedMilliseconds;
        FLastError := AError;
        Exit(False);
      end;
      Stop;
      if LAttempt = 0 then
      begin
        Inc(FRestartCount);
        Sleep(CRestartBackoffMs);
      end;
    end;
    LStopwatch.Stop;
    FLastLatencyMs := LStopwatch.ElapsedMilliseconds;
    Inc(FFailureCount);
    Inc(FConsecutiveFailureCount);
    FLastError := AError;
    if FConsecutiveFailureCount >= CFailureThreshold then
      FCircuitOpenUntil := GetTickCount64 + CCircuitCooldownMs;
    Result := False;
  finally
    TMonitor.Exit(FRequestLock);
  end;
end;

function TRadIASemanticEngineSupervisor.StartTransport(
  out AError: string
): Boolean;
var
  LConfig: TRadIAExternalMcpServerConfig;
begin
  if not TFile.Exists(FExecutablePath) then
  begin
    AError := 'RadIA.Semantic.Engine.exe was not found.';
    Exit(False);
  end;
  LConfig := TRadIAExternalMcpServerConfig.Create(
    'radia-semantic-engine',
    'RadIA Semantic Engine',
    FExecutablePath,
    nil,
    ExtractFilePath(FExecutablePath),
    True,
    FTimeoutMs
  );
  Result := FTransport.Start(LConfig, AError);
  if Result then
  begin
    Result := Initialize(AError);
    if not Result then
      Stop;
  end;
end;

procedure TRadIASemanticEngineSupervisor.Stop;
begin
  FTransport.Stop;
end;

{ TRadIASemanticEngineClient }

class function TRadIASemanticEngineClient.DefaultExecutablePath: string;
var
  LBuffer: array[0..MAX_PATH] of Char;
begin
  if GetModuleFileName(HInstance, LBuffer, Length(LBuffer)) = 0 then
    Exit('');
  Result := TPath.Combine(
    ExtractFilePath(LBuffer),
    'RadIA.Semantic.Engine.exe'
  );
end;

class function TRadIASemanticEngineClient.Probe(
  const AExecutablePath: string;
  const ATimeoutMs: Cardinal
): TRadIASemanticEngineProbe;
var
  LInput: string;
  LInvocation: TRadIACliInvocation;
  LSession: IRadIACliProcessSession;
  LState: TRadIASemanticProbeState;
begin
  if not TFile.Exists(AExecutablePath) then
    Exit(TRadIASemanticEngineProbe.Create(
      False,
      '',
      '',
      'RadIA.Semantic.Engine.exe was not found.'
    ));
  LState := TRadIASemanticProbeState.Create;
  try
    LInput := CInitializeRequest + sLineBreak + CShutdownRequest + sLineBreak;
    LInvocation := TRadIACliInvocation.Create(
      AExecutablePath,
      nil,
      ExtractFilePath(AExecutablePath),
      'jsonl'
    );
    LSession := TRadIACliProcessRunner.StartWithInput(
      LInvocation,
      LInput,
      ATimeoutMs,
      procedure(AText: string)
      begin
        LState.AppendOutput(AText);
      end,
      procedure(AText: string)
      begin
        LState.AppendError(AText);
      end,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LState.Complete(AResult);
      end
    );
    if LState.Completed.WaitFor(ATimeoutMs + 1000) <> wrSignaled then
    begin
      LSession.Cancel;
      LState.Completed.WaitFor(1000);
      Exit(TRadIASemanticEngineProbe.Create(
        False,
        '',
        '',
        'The semantic engine handshake timed out.'
      ));
    end;
    if not LState.Result.Succeeded then
      Exit(TRadIASemanticEngineProbe.Create(
        False,
        '',
        '',
        Trim(LState.StdErr)
      ));
    Result := ParseProbeOutput(LState.StdOut);
  finally
    LState.Free;
  end;
end;

end.
