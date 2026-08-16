unit RadIA.Core.RuntimeVclAdapter;

interface

uses
  RadIA.Core.RuntimeAutomation;

type
  TRadIARuntimeVclAdapterLimits = record
  private
    FMaxDepth: Integer;
    FMaxPayloadBytes: Integer;
    FMaxTargets: Integer;
    FTimeoutMs: Cardinal;
  public
    constructor Create(
      const AMaxDepth: Integer;
      const AMaxTargets: Integer;
      const AMaxPayloadBytes: Integer;
      const ATimeoutMs: Cardinal
    );
    class function Defaults: TRadIARuntimeVclAdapterLimits; static;
    function IsValid: Boolean;
    property MaxDepth: Integer read FMaxDepth;
    property MaxTargets: Integer read FMaxTargets;
    property MaxPayloadBytes: Integer read FMaxPayloadBytes;
    property TimeoutMs: Cardinal read FTimeoutMs;
  end;

  TRadIARuntimeVclAdapterIdentity = record
  private
    FEndpoint: string;
    FProcessId: LongWord;
    FProtocolVersion: Integer;
    FSessionId: string;
    FToken: string;
  public
    constructor Create(
      const AProcessId: LongWord;
      const ASessionId: string;
      const AEndpoint: string;
      const AToken: string;
      const AProtocolVersion: Integer
    );
    function IsUsableFor(
      const ASession: TRadIARuntimeSessionIdentity
    ): Boolean;
    property ProcessId: LongWord read FProcessId;
    property SessionId: string read FSessionId;
    property Endpoint: string read FEndpoint;
    property Token: string read FToken;
    property ProtocolVersion: Integer read FProtocolVersion;
  end;

  TRadIARuntimeVclTransportResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPayload: string;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIARuntimeVclTransportResult; static;
    class function Succeeded(
      const APayload: string
    ): TRadIARuntimeVclTransportResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Payload: string read FPayload;
  end;

  IRadIARuntimeVclEndpointLocator = interface
    ['{573941F9-08DF-4218-8D25-2E24338E0A14}']
    function Locate(
      const ASession: TRadIARuntimeSessionIdentity;
      out AIdentity: TRadIARuntimeVclAdapterIdentity
    ): Boolean;
  end;

  IRadIARuntimeVclTransport = interface
    ['{1D094851-452A-4BF5-B13A-1FDDAA6095C0}']
    function Send(
      const AIdentity: TRadIARuntimeVclAdapterIdentity;
      const AMethod: string;
      const AParametersJson: string;
      const ALimits: TRadIARuntimeVclAdapterLimits
    ): TRadIARuntimeVclTransportResult;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils;

constructor TRadIARuntimeVclAdapterLimits.Create(
  const AMaxDepth: Integer;
  const AMaxTargets: Integer;
  const AMaxPayloadBytes: Integer;
  const ATimeoutMs: Cardinal
);
begin
  FMaxDepth := AMaxDepth;
  FMaxTargets := AMaxTargets;
  FMaxPayloadBytes := AMaxPayloadBytes;
  FTimeoutMs := ATimeoutMs;
end;

class function TRadIARuntimeVclAdapterLimits.Defaults:
  TRadIARuntimeVclAdapterLimits;
begin
  Result := TRadIARuntimeVclAdapterLimits.Create(32, 2000, 1024 * 1024, 5000);
end;

function TRadIARuntimeVclAdapterLimits.IsValid: Boolean;
begin
  Result :=
    (FMaxDepth >= 1) and
    (FMaxDepth <= 64) and
    (FMaxTargets >= 1) and
    (FMaxTargets <= 10000) and
    (FMaxPayloadBytes >= 1024) and
    (FMaxPayloadBytes <= 4 * 1024 * 1024) and
    (FTimeoutMs >= 100) and
    (FTimeoutMs <= 30000);
end;

constructor TRadIARuntimeVclAdapterIdentity.Create(
  const AProcessId: LongWord;
  const ASessionId: string;
  const AEndpoint: string;
  const AToken: string;
  const AProtocolVersion: Integer
);
begin
  FProcessId := AProcessId;
  FSessionId := Trim(ASessionId);
  FEndpoint := Trim(AEndpoint);
  FToken := Trim(AToken);
  FProtocolVersion := AProtocolVersion;
end;

function TRadIARuntimeVclAdapterIdentity.IsUsableFor(
  const ASession: TRadIARuntimeSessionIdentity
): Boolean;
begin
  Result :=
    ASession.IsComplete and
    (FProcessId = ASession.ProcessId) and
    SameText(FSessionId, ASession.SessionId) and
    StartsText(
      '\\.\pipe\RadIA.Runtime.' + FProcessId.ToString + '.',
      FEndpoint
    ) and
    (Length(FToken) >= 32) and
    (FProtocolVersion = 1);
end;

class function TRadIARuntimeVclTransportResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIARuntimeVclTransportResult;
begin
  Result := Default(TRadIARuntimeVclTransportResult);
  Result.FErrorCode := Trim(AErrorCode);
  Result.FErrorMessage := Trim(AErrorMessage);
end;

class function TRadIARuntimeVclTransportResult.Succeeded(
  const APayload: string
): TRadIARuntimeVclTransportResult;
begin
  Result := Default(TRadIARuntimeVclTransportResult);
  Result.FSuccess := True;
  Result.FPayload := APayload;
end;

end.
