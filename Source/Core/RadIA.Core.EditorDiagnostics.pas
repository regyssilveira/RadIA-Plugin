unit RadIA.Core.EditorDiagnostics;

interface

type
  TRadIAEditorDiagnosticDecision = (
    eddUnchanged,
    eddWaiting,
    eddReady
  );

  TRadIAEditorDiagnosticObservation = record
  private
    FCancelActive: Boolean;
    FDecision: TRadIAEditorDiagnosticDecision;
  public
    constructor Create(
      const ADecision: TRadIAEditorDiagnosticDecision;
      const ACancelActive: Boolean
    );
    property CancelActive: Boolean read FCancelActive;
    property Decision: TRadIAEditorDiagnosticDecision read FDecision;
  end;

  TRadIAEditorDiagnosticDebouncer = class
  private
    FDelayMilliseconds: UInt64;
    FObservedAt: UInt64;
    FObservedKey: string;
    FSubmittedKey: string;
  public
    constructor Create(const ADelayMilliseconds: Cardinal);
    procedure Configure(const ADelayMilliseconds: Cardinal);
    procedure MarkSubmitted(const AKey: string);
    function Observe(
      const AKey: string;
      const ANowMilliseconds: UInt64
    ): TRadIAEditorDiagnosticObservation;
    procedure Reset;
  end;

implementation

uses
  System.SysUtils;

{ TRadIAEditorDiagnosticObservation }

constructor TRadIAEditorDiagnosticObservation.Create(
  const ADecision: TRadIAEditorDiagnosticDecision;
  const ACancelActive: Boolean
);
begin
  FDecision := ADecision;
  FCancelActive := ACancelActive;
end;

{ TRadIAEditorDiagnosticDebouncer }

procedure TRadIAEditorDiagnosticDebouncer.Configure(
  const ADelayMilliseconds: Cardinal
);
begin
  FDelayMilliseconds := ADelayMilliseconds;
end;

constructor TRadIAEditorDiagnosticDebouncer.Create(
  const ADelayMilliseconds: Cardinal
);
begin
  inherited Create;
  Configure(ADelayMilliseconds);
end;

procedure TRadIAEditorDiagnosticDebouncer.MarkSubmitted(
  const AKey: string
);
begin
  if SameText(AKey, FObservedKey) then
    FSubmittedKey := AKey;
end;

function TRadIAEditorDiagnosticDebouncer.Observe(
  const AKey: string;
  const ANowMilliseconds: UInt64
): TRadIAEditorDiagnosticObservation;
var
  LCancelActive: Boolean;
begin
  if AKey.Trim.IsEmpty then
  begin
    LCancelActive := not FObservedKey.IsEmpty or
      not FSubmittedKey.IsEmpty;
    Reset;
    Exit(TRadIAEditorDiagnosticObservation.Create(
      eddUnchanged,
      LCancelActive
    ));
  end;
  if not SameText(AKey, FObservedKey) then
  begin
    LCancelActive := not FSubmittedKey.IsEmpty;
    FObservedKey := AKey;
    FObservedAt := ANowMilliseconds;
    Exit(TRadIAEditorDiagnosticObservation.Create(
      eddWaiting,
      LCancelActive
    ));
  end;
  if SameText(AKey, FSubmittedKey) then
    Exit(TRadIAEditorDiagnosticObservation.Create(
      eddUnchanged,
      False
    ));
  if (ANowMilliseconds - FObservedAt) < FDelayMilliseconds then
    Exit(TRadIAEditorDiagnosticObservation.Create(
      eddWaiting,
      False
    ));
  Result := TRadIAEditorDiagnosticObservation.Create(
    eddReady,
    False
  );
end;

procedure TRadIAEditorDiagnosticDebouncer.Reset;
begin
  FObservedAt := 0;
  FObservedKey := '';
  FSubmittedKey := '';
end;

end.
