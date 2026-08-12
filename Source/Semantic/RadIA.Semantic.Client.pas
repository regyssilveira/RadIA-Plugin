unit RadIA.Semantic.Client;

interface

uses
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
    IRadIASemanticRequestClient
  )
  private
    FExecutablePath: string;
    FNextRequestId: Integer;
    FRequestLock: TObject;
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
      out AResponse: string;
      out AError: string
    ): Boolean;
    function Initialize(out AError: string): Boolean;
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
    function GetRestartCount: Integer;
    procedure Stop;
    property RestartCount: Integer read FRestartCount;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  System.SysUtils,
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
  CInitializeRequest = '{"id":1,"method":"initialize","params":{}}';
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
  if not FTransport.Receive(FTimeoutMs, AResponse) then
  begin
    AError := FTransport.LastError;
    if AError = '' then
      AError := 'The semantic engine response timed out.';
    Exit(False);
  end;
  Result := True;
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
var
  LAttempt: Integer;
  LRequest: string;
begin
  AResponse := '';
  AError := '';
  TMonitor.Enter(FRequestLock);
  try
    for LAttempt := 0 to 1 do
    begin
      if not FTransport.Running then
        if not StartTransport(AError) then
        begin
          if LAttempt = 0 then
          begin
            Inc(FRestartCount);
            Continue;
          end;
          Exit(False);
        end;
      Inc(FNextRequestId);
      LRequest := BuildRequest(FNextRequestId, AMethod, AParameters);
      if Exchange(LRequest, AResponse, AError) then
        Exit(True);
      Stop;
      if LAttempt = 0 then
        Inc(FRestartCount);
    end;
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
