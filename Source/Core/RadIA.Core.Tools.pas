unit RadIA.Core.Tools;

interface

type
  IRadIAToolCancellationToken = interface
    ['{28C282D6-ECC9-4CD1-BE2E-9AB26FBFDD99}']
    function GetCancellationRequested: Boolean;
    property CancellationRequested: Boolean
      read GetCancellationRequested;
  end;

  TRadIAToolRisk = (
    trReadOnly,
    trReversibleWrite,
    trStructuralWrite,
    trExecution,
    trDestructive,
    trSensitive
  );

  TRadIAToolDescriptor = record
  private
    FName: string;
    FVersion: string;
    FDescription: string;
    FInputSchema: string;
    FOutputSchema: string;
    FRisk: TRadIAToolRisk;
    FTimeoutMs: Cardinal;
    FIdempotent: Boolean;
  public
    constructor Create(
      const AName: string;
      const AVersion: string;
      const ADescription: string;
      const AInputSchema: string;
      const AOutputSchema: string;
      const ARisk: TRadIAToolRisk
    );
    function WithExecutionOptions(
      const ATimeoutMs: Cardinal;
      const AIdempotent: Boolean
    ): TRadIAToolDescriptor;
    property Name: string read FName;
    property Version: string read FVersion;
    property Description: string read FDescription;
    property InputSchema: string read FInputSchema;
    property OutputSchema: string read FOutputSchema;
    property Risk: TRadIAToolRisk read FRisk;
    property TimeoutMs: Cardinal read FTimeoutMs;
    property Idempotent: Boolean read FIdempotent;
  end;

  TRadIAToolRequest = record
  private
    FToolName: string;
    FArgumentsJson: string;
    FCorrelationId: string;
    FOrigin: string;
    FSessionId: string;
    FProjectId: string;
    FScope: string;
    FCancellationToken: IRadIAToolCancellationToken;
  public
    constructor Create(
      const AToolName: string;
      const AArgumentsJson: string;
      const ACorrelationId: string
    ); overload;
    constructor Create(
      const AToolName: string;
      const AArgumentsJson: string;
      const ACorrelationId: string;
      const AOrigin: string;
      const ASessionId: string;
      const AProjectId: string;
      const AScope: string
    ); overload;
    function WithCancellation(
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIAToolRequest;
    property ToolName: string read FToolName;
    property ArgumentsJson: string read FArgumentsJson;
    property CorrelationId: string read FCorrelationId;
    property Origin: string read FOrigin;
    property SessionId: string read FSessionId;
    property ProjectId: string read FProjectId;
    property Scope: string read FScope;
    property CancellationToken: IRadIAToolCancellationToken
      read FCancellationToken;
  end;

  TRadIAToolResult = record
  private
    FSuccess: Boolean;
    FContentJson: string;
    FErrorCode: string;
    FErrorMessage: string;
    FTruncated: Boolean;
  public
    class function Succeeded(
      const AContentJson: string;
      const ATruncated: Boolean = False
    ): TRadIAToolResult; static;
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAToolResult; static;
    property Success: Boolean read FSuccess;
    property ContentJson: string read FContentJson;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Truncated: Boolean read FTruncated;
  end;

  IRadIATool = interface
    ['{D214957B-5FC5-4A34-8270-FAC59ED12DBA}']
    function GetDescriptor: TRadIAToolDescriptor;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    property Descriptor: TRadIAToolDescriptor read GetDescriptor;
  end;

  IRadIAToolRegistry = interface
    ['{BE2FC771-FA34-4F79-9AD1-E8467DDBBF00}']
    procedure RegisterTool(const ATool: IRadIATool);
    procedure RegisterTools(const ATools: TArray<IRadIATool>);
    procedure UnregisterTools(const ANames: TArray<string>);
    function Resolve(const AName: string): IRadIATool;
    function TryResolve(
      const AName: string;
      out ATool: IRadIATool
    ): Boolean;
    function GetDescriptors: TArray<TRadIAToolDescriptor>;
    function GetCount: Integer;
    procedure Clear;
    property Count: Integer read GetCount;
  end;

  IRadIAToolExecutor = interface
    ['{420F5D33-6C41-4CE9-868D-B6650ED3E096}']
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

  IRadIAToolDescriptorProvider = interface
    ['{38BDBF91-EC26-4F07-9938-F217784BBC81}']
    function TryGetToolDescriptor(
      const AName: string;
      out ADescriptor: TRadIAToolDescriptor
    ): Boolean;
  end;

function RadIAToolRiskName(const ARisk: TRadIAToolRisk): string;

implementation

function RadIAToolRiskName(const ARisk: TRadIAToolRisk): string;
begin
  case ARisk of
    trReadOnly:
      Result := 'readOnly';
    trReversibleWrite:
      Result := 'reversibleWrite';
    trStructuralWrite:
      Result := 'structuralWrite';
    trExecution:
      Result := 'execution';
    trDestructive:
      Result := 'destructive';
    trSensitive:
      Result := 'sensitive';
  else
    Result := 'unknown';
  end;
end;

{ TRadIAToolDescriptor }

constructor TRadIAToolDescriptor.Create(
  const AName: string;
  const AVersion: string;
  const ADescription: string;
  const AInputSchema: string;
  const AOutputSchema: string;
  const ARisk: TRadIAToolRisk
);
begin
  FName := AName;
  FVersion := AVersion;
  FDescription := ADescription;
  FInputSchema := AInputSchema;
  FOutputSchema := AOutputSchema;
  FRisk := ARisk;
  FTimeoutMs := 10000;
  FIdempotent := ARisk = trReadOnly;
end;

function TRadIAToolDescriptor.WithExecutionOptions(
  const ATimeoutMs: Cardinal;
  const AIdempotent: Boolean
): TRadIAToolDescriptor;
begin
  Result := Self;
  Result.FTimeoutMs := ATimeoutMs;
  Result.FIdempotent := AIdempotent;
end;

{ TRadIAToolRequest }

constructor TRadIAToolRequest.Create(
  const AToolName: string;
  const AArgumentsJson: string;
  const ACorrelationId: string
);
begin
  Self := TRadIAToolRequest.Create(
    AToolName,
    AArgumentsJson,
    ACorrelationId,
    'internal',
    '',
    '',
    ''
  );
end;

constructor TRadIAToolRequest.Create(
  const AToolName: string;
  const AArgumentsJson: string;
  const ACorrelationId: string;
  const AOrigin: string;
  const ASessionId: string;
  const AProjectId: string;
  const AScope: string
);
begin
  FToolName := AToolName;
  FArgumentsJson := AArgumentsJson;
  FCorrelationId := ACorrelationId;
  FOrigin := AOrigin;
  FSessionId := ASessionId;
  FProjectId := AProjectId;
  FScope := AScope;
  FCancellationToken := nil;
end;

function TRadIAToolRequest.WithCancellation(
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIAToolRequest;
begin
  Result := Self;
  Result.FCancellationToken := ACancellationToken;
end;

{ TRadIAToolResult }

class function TRadIAToolResult.Succeeded(
  const AContentJson: string;
  const ATruncated: Boolean
): TRadIAToolResult;
begin
  Result.FSuccess := True;
  Result.FContentJson := AContentJson;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FTruncated := ATruncated;
end;

class function TRadIAToolResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAToolResult;
begin
  Result.FSuccess := False;
  Result.FContentJson := '';
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
  Result.FTruncated := False;
end;

end.
