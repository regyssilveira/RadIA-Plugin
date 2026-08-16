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
    StartsText('\\.\pipe\RadIA.Runtime.', FEndpoint) and
    (Length(FToken) >= 32) and
    (FProtocolVersion = 1);
end;

end.
