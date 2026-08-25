unit RadIA.Core.BuildTools;

interface

uses
  RadIA.Core.Build,
  RadIA.Core.Tools;

procedure RegisterRadIABuildTools(
  const ARegistry: IRadIAToolRegistry;
  const ABuildFacade: IRadIABuildFacade
);

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.Workspace;

type
  TRadIABuildToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FBuildFacade: IRadIABuildFacade;
    function BuildResultToToolResult(
      const AResult: TRadIABuildResult
    ): TRadIAToolResult;
    function StatusName(
      const AStatus: TRadIABuildStatus
    ): string;
  public
    constructor Create(const ABuildFacade: IRadIABuildFacade);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor;
      virtual; abstract;
  end;

  TRadIABuildProjectTool = class(TRadIABuildToolBase)
  private
    function ParseMode(const AMode: string): TRadIABuildMode;
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIACancelBuildTool = class(TRadIABuildToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAGetBuildStatusTool = class(TRadIABuildToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CBuildInputSchema =
    '{"type":"object","properties":{"mode":{"type":"string",' +
    '"enum":["make","build","check","clean"]},' +
    '"timeoutMs":{"type":"integer","minimum":1000,"maximum":600000},' +
    '"clearMessages":{"type":"boolean"}},"additionalProperties":false}';
  CBuildOutputSchema =
    '{"type":"object","required":["status","success"],' +
    '"properties":{"status":{"type":"string"},' +
    '"success":{"type":"boolean"},"messages":{"type":"array"}}}';
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';

{ TRadIABuildToolBase }

function TRadIABuildToolBase.BuildResultToToolResult(
  const AResult: TRadIABuildResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LMessage: TRadIACompilerMessage;
  LMessageJson: TJSONObject;
  LMessages: TJSONArray;
begin
  if (AResult.ErrorCode <> '') and
    (AResult.Status <> bsFailed) then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('success', TJSONBool.Create(AResult.Success));
    LJson.AddPair('status', StatusName(AResult.Status));
    LJson.AddPair('projectFile', AResult.ProjectFile);
    LJson.AddPair('configuration', AResult.Configuration);
    LJson.AddPair('platform', AResult.Platform);
    LJson.AddPair(
      'durationMs',
      TJSONNumber.Create(AResult.DurationMs)
    );
    LMessages := TJSONArray.Create;
    for LMessage in AResult.Messages do
    begin
      LMessageJson := TJSONObject.Create;
      LMessageJson.AddPair('text', LMessage.Text);
      LMessageJson.AddPair('fileName', LMessage.FileName);
      LMessageJson.AddPair(
        'line',
        TJSONNumber.Create(LMessage.Line)
      );
      LMessageJson.AddPair(
        'column',
        TJSONNumber.Create(LMessage.Column)
      );
      LMessages.AddElement(LMessageJson);
    end;
    LJson.AddPair('messages', LMessages);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

constructor TRadIABuildToolBase.Create(
  const ABuildFacade: IRadIABuildFacade
);
begin
  inherited Create;
  if not Assigned(ABuildFacade) then
    raise EArgumentNilException.Create('ABuildFacade');
  FBuildFacade := ABuildFacade;
end;

function TRadIABuildToolBase.StatusName(
  const AStatus: TRadIABuildStatus
): string;
begin
  case AStatus of
    bsIdle: Result := 'idle';
    bsRunning: Result := 'running';
    bsSucceeded: Result := 'succeeded';
    bsCancelled: Result := 'cancelled';
    bsTimedOut: Result := 'timedOut';
    bsUnsupported: Result := 'unsupported';
  else
    Result := 'failed';
  end;
end;

{ TRadIABuildProjectTool }

function TRadIABuildProjectTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LClearMessages: Boolean;
  LJson: TJSONObject;
  LMode: TRadIABuildMode;
  LTimeoutMs: Integer;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Build arguments must be a valid JSON object.'
    ));
  try
    LMode := ParseMode(
      LJson.GetValue<string>('mode', 'make')
    );
    LTimeoutMs := LJson.GetValue<Integer>('timeoutMs', 120000);
    if (LTimeoutMs < 1000) or (LTimeoutMs > 600000) then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'Build timeout must be between 1000 and 600000 ms.'
      ));
    LClearMessages := LJson.GetValue<Boolean>(
      'clearMessages',
      True
    );
    Result := BuildResultToToolResult(
      FBuildFacade.Execute(
        TRadIABuildRequest.Create(
          LMode,
          Cardinal(LTimeoutMs),
          LClearMessages
        )
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIABuildProjectTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'BuildProject',
    '1.0.0',
    'Builds the active project and returns diagnostics from this build only.',
    CBuildInputSchema,
    CBuildOutputSchema,
    trExecution
  ).WithExecutionOptions(600000, False);
end;

function TRadIABuildProjectTool.ParseMode(
  const AMode: string
): TRadIABuildMode;
begin
  if SameText(AMode, 'make') then
    Exit(bmMake);
  if SameText(AMode, 'build') then
    Exit(bmBuild);
  if SameText(AMode, 'check') then
    Exit(bmCheck);
  if SameText(AMode, 'clean') then
    Exit(bmClean);
  raise EArgumentException.CreateFmt(
    'Unsupported build mode "%s".',
    [AMode]
  );
end;

{ TRadIACancelBuildTool }

function TRadIACancelBuildTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  if FBuildFacade.Cancel then
    Result := TRadIAToolResult.Succeeded(
      '{"cancelRequested":true}'
    )
  else
    Result := TRadIAToolResult.Failed(
      'build_not_running',
      'No background build could be cancelled.'
    );
end;

function TRadIACancelBuildTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'CancelBuild',
    '1.0.0',
    'Requests cancellation of the active background build.',
    CEmptyInputSchema,
    '{"type":"object"}',
    trExecution
  ).WithExecutionOptions(30000, False);
end;

{ TRadIAGetBuildStatusTool }

function TRadIAGetBuildStatusTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair(
      'status',
      StatusName(FBuildFacade.GetStatus)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAGetBuildStatusTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetBuildStatus',
    '1.0.0',
    'Returns the current or most recent build status.',
    CEmptyInputSchema,
    '{"type":"object"}',
    trReadOnly
  );
end;

procedure RegisterRadIABuildTools(
  const ARegistry: IRadIAToolRegistry;
  const ABuildFacade: IRadIABuildFacade
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ABuildFacade) then
    raise EArgumentNilException.Create('ABuildFacade');

  ARegistry.RegisterTool(TRadIABuildProjectTool.Create(ABuildFacade));
  ARegistry.RegisterTool(TRadIACancelBuildTool.Create(ABuildFacade));
  ARegistry.RegisterTool(
    TRadIAGetBuildStatusTool.Create(ABuildFacade)
  );
end;

end.
