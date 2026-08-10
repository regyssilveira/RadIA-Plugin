unit RadIA.Core.ConsentGate;

interface

uses
  System.SyncObjs;

type
  IRadIAConsentGate = interface
    ['{C59539B4-E7BA-4D90-8A61-C5EC0E5FEF08}']
    function Acquire(
      const ATimeoutMs: Cardinal;
      const AWait: Boolean
    ): Boolean;
    procedure Release;
  end;

  TRadIAConsentGate = class(TInterfacedObject, IRadIAConsentGate)
  private
    FSemaphore: TSemaphore;
  public
    constructor Create;
    destructor Destroy; override;
    function Acquire(
      const ATimeoutMs: Cardinal;
      const AWait: Boolean
    ): Boolean;
    procedure Release;
  end;

implementation

constructor TRadIAConsentGate.Create;
begin
  inherited Create;
  FSemaphore := TSemaphore.Create(nil, 1, 1, '');
end;

destructor TRadIAConsentGate.Destroy;
begin
  FSemaphore.Free;
  inherited Destroy;
end;

function TRadIAConsentGate.Acquire(
  const ATimeoutMs: Cardinal;
  const AWait: Boolean
): Boolean;
var
  LTimeoutMs: Cardinal;
begin
  if AWait then
    LTimeoutMs := ATimeoutMs
  else
    LTimeoutMs := 0;
  Result := FSemaphore.WaitFor(LTimeoutMs) = wrSignaled;
end;

procedure TRadIAConsentGate.Release;
begin
  FSemaphore.Release;
end;

end.
