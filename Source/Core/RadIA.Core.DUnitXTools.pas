unit RadIA.Core.DUnitXTools;

interface

uses
  RadIA.Core.DUnitX,
  RadIA.Core.Tools;

procedure RegisterRadIADUnitXTools(
  const ARegistry: IRadIAToolRegistry;
  const ARunner: IRadIADUnitXRunner
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIADUnitXToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FRunner: IRadIADUnitXRunner;
    function StatusName(
      const AStatus: TRadIADUnitXRunStatus
    ): string;
  public
    constructor Create(const ARunner: IRadIADUnitXRunner);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor;
      virtual; abstract;
  end;

  TRadIARunDUnitXTestsTool = class(TRadIADUnitXToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIACancelDUnitXTestsTool = class(TRadIADUnitXToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAGetDUnitXStatusTool = class(TRadIADUnitXToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CRunInputSchema =
    '{"type":"object","required":["executablePath"],"properties":{' +
    '"executablePath":{"type":"string","minLength":1},' +
    '"timeoutMs":{"type":"integer","minimum":1000,"maximum":600000},' +
    '"tests":{"type":"array","items":{"type":"string","minLength":1},' +
    '"maxItems":100}},"additionalProperties":false}';
  CRunOutputSchema =
    '{"type":"object","required":["status"],"properties":{' +
    '"status":{"type":"string"},"report":{"type":"object"},' +
    '"durationMs":{"type":"integer"},"exitCode":{"type":"integer"}}}';
  CEmptySchema = '{"type":"object","additionalProperties":false}';

function ParseTests(const AJson: TJSONObject): TArray<string>;
var
  LArray: TJSONArray;
  LIndex: Integer;
begin
  SetLength(Result, 0);
  if not AJson.TryGetValue<TJSONArray>('tests', LArray) then
    Exit;
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    Result[LIndex] := Trim(LArray[LIndex].Value);
    if Result[LIndex] = '' then
      raise EArgumentException.Create('Test names cannot be empty.');
  end;
end;

{ TRadIADUnitXToolBase }

constructor TRadIADUnitXToolBase.Create(
  const ARunner: IRadIADUnitXRunner
);
begin
  inherited Create;
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  FRunner := ARunner;
end;

function TRadIADUnitXToolBase.StatusName(
  const AStatus: TRadIADUnitXRunStatus
): string;
begin
  case AStatus of
    drsIdle: Result := 'idle';
    drsRunning: Result := 'running';
    drsSucceeded: Result := 'succeeded';
    drsCancelled: Result := 'cancelled';
    drsTimedOut: Result := 'timedOut';
  else
    Result := 'failed';
  end;
end;

{ TRadIARunDUnitXTestsTool }

function TRadIARunDUnitXTestsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LExecutablePath: string;
  LJson: TJSONObject;
  LOutputJson: TJSONObject;
  LReportJson: TJSONValue;
  LResult: TRadIADUnitXRunResult;
  LTests: TArray<string>;
  LTimeoutMs: Integer;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'DUnitX arguments must be a valid JSON object.'
    ));
  try
    if not LJson.TryGetValue<string>(
      'executablePath',
      LExecutablePath
    ) or (Trim(LExecutablePath) = '') then
      Exit(TRadIAToolResult.Failed(
        'invalid_executable',
        'Executable path is required.'
      ));
    LTimeoutMs := 120000;
    LJson.TryGetValue<Integer>('timeoutMs', LTimeoutMs);
    if (LTimeoutMs < 1000) or (LTimeoutMs > 600000) then
      Exit(TRadIAToolResult.Failed(
        'invalid_timeout',
        'Timeout must be between 1000 and 600000 milliseconds.'
      ));
    try
      LTests := ParseTests(LJson);
    except
      on E: EArgumentException do
        Exit(TRadIAToolResult.Failed('invalid_tests', E.Message));
    end;
    LResult := FRunner.Execute(
      TRadIADUnitXRunRequest.Create(
        LExecutablePath,
        LTimeoutMs,
        LTests
      )
    );
    if LResult.ErrorCode <> '' then
      Exit(TRadIAToolResult.Failed(
        LResult.ErrorCode,
        LResult.ErrorMessage
      ));
    LOutputJson := TJSONObject.Create;
    try
      LOutputJson.AddPair('status', StatusName(LResult.Status));
      LOutputJson.AddPair(
        'exitCode',
        TJSONNumber.Create(LResult.ExitCode)
      );
      LOutputJson.AddPair(
        'durationMs',
        TJSONNumber.Create(LResult.DurationMs)
      );
      LReportJson := TJSONObject.ParseJSONValue(
        LResult.Report.ToJson
      );
      LOutputJson.AddPair('report', LReportJson);
      LOutputJson.AddPair('output', LResult.Output);
      Result := TRadIAToolResult.Succeeded(LOutputJson.ToJSON);
    finally
      LOutputJson.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIARunDUnitXTestsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'RunDUnitXTests',
    '1.0.0',
    'Run a workspace-confined DUnitX executable and return its NUnit report.',
    CRunInputSchema,
    CRunOutputSchema,
    trExecution
  );
end;

{ TRadIACancelDUnitXTestsTool }

function TRadIACancelDUnitXTestsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('cancelled', TJSONBool.Create(FRunner.Cancel));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIACancelDUnitXTestsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'CancelDUnitXTests',
    '1.0.0',
    'Cancel the active DUnitX test process.',
    CEmptySchema,
    CEmptySchema,
    trExecution
  );
end;

{ TRadIAGetDUnitXStatusTool }

function TRadIAGetDUnitXStatusTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('status', StatusName(FRunner.GetStatus));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAGetDUnitXStatusTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetDUnitXStatus',
    '1.0.0',
    'Return the current DUnitX runner status.',
    CEmptySchema,
    CEmptySchema,
    trReadOnly
  );
end;

procedure RegisterRadIADUnitXTools(
  const ARegistry: IRadIAToolRegistry;
  const ARunner: IRadIADUnitXRunner
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  ARegistry.RegisterTool(TRadIARunDUnitXTestsTool.Create(ARunner));
  ARegistry.RegisterTool(TRadIACancelDUnitXTestsTool.Create(ARunner));
  ARegistry.RegisterTool(TRadIAGetDUnitXStatusTool.Create(ARunner));
end;

end.
