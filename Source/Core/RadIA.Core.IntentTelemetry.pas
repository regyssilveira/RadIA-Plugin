unit RadIA.Core.IntentTelemetry;

interface

type
  TRadIAIntentTelemetryEvent = (
    riteRecommended,
    riteAccepted,
    riteReviewed,
    riteChatFallback,
    riteSuperseded
  );

  TRadIAIntentTelemetry = class
  private const
    CMaximumFileSize = 1024 * 1024;
  private
    class var FLock: TObject;
    class constructor Create;
    class destructor Destroy;
    class function DefaultFileName: string; static;
    class function EventName(
      const AEvent: TRadIAIntentTelemetryEvent
    ): string; static;
    class function NormalizeConfidence(const AConfidence: string): string; static;
    class function NormalizeIntent(const AIntent: string): string; static;
    class procedure EnsureStorageReady(const AFileName: string); static;
  public
    class function SummaryJson: string; static;
    class function SummaryJsonFrom(const AFileName: string): string; static;
    class procedure TryRecord(
      const AEvent: TRadIAIntentTelemetryEvent;
      const AIntent: string;
      const AConfidence: string
    ); static;
    class procedure TryRecordTo(
      const AFileName: string;
      const AEvent: TRadIAIntentTelemetryEvent;
      const AIntent: string;
      const AConfidence: string
    ); static;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Logger;

type
  TRadIAIntentTelemetryCounters = record
  private
    FAccepted: Integer;
    FChatFallback: Integer;
    FRecommended: Integer;
    FReviewed: Integer;
    FSuperseded: Integer;
  public
    procedure Add(const AEvent: string);
    function Total: Integer;
    property Accepted: Integer read FAccepted;
    property ChatFallback: Integer read FChatFallback;
    property Recommended: Integer read FRecommended;
    property Reviewed: Integer read FReviewed;
    property Superseded: Integer read FSuperseded;
  end;

procedure TRadIAIntentTelemetryCounters.Add(const AEvent: string);
begin
  if SameText(AEvent, 'recommended') then
    Inc(FRecommended)
  else if SameText(AEvent, 'accepted') then
    Inc(FAccepted)
  else if SameText(AEvent, 'reviewed') then
    Inc(FReviewed)
  else if SameText(AEvent, 'chat-fallback') then
    Inc(FChatFallback)
  else if SameText(AEvent, 'superseded') then
    Inc(FSuperseded);
end;

function TRadIAIntentTelemetryCounters.Total: Integer;
begin
  Result := FRecommended + FAccepted + FReviewed + FChatFallback + FSuperseded;
end;

class constructor TRadIAIntentTelemetry.Create;
begin
  FLock := TObject.Create;
end;

class destructor TRadIAIntentTelemetry.Destroy;
begin
  FLock.Free;
end;

class function TRadIAIntentTelemetry.DefaultFileName: string;
var
  LRoot: string;
begin
  LRoot := GetEnvironmentVariable('LOCALAPPDATA');
  if LRoot.IsEmpty then
    LRoot := TPath.GetHomePath;
  Result := TPath.Combine(
    TPath.Combine(TPath.Combine(LRoot, 'RadIA'), 'Telemetry'),
    'intent-routing.jsonl'
  );
end;

class procedure TRadIAIntentTelemetry.EnsureStorageReady(
  const AFileName: string
);
var
  LDirectory: string;
begin
  LDirectory := TPath.GetDirectoryName(AFileName);
  if not LDirectory.IsEmpty then
    TDirectory.CreateDirectory(LDirectory);
  if TFile.Exists(AFileName) and
    (TFile.GetSize(AFileName) >= CMaximumFileSize) then
    TFile.Delete(AFileName);
end;

class function TRadIAIntentTelemetry.EventName(
  const AEvent: TRadIAIntentTelemetryEvent
): string;
begin
  case AEvent of
    riteRecommended: Result := 'recommended';
    riteAccepted: Result := 'accepted';
    riteReviewed: Result := 'reviewed';
    riteChatFallback: Result := 'chat-fallback';
    riteSuperseded: Result := 'superseded';
  else
    Result := 'unknown';
  end;
end;

class function TRadIAIntentTelemetry.NormalizeConfidence(
  const AConfidence: string
): string;
begin
  if SameText(AConfidence, 'high') then
    Exit('high');
  if SameText(AConfidence, 'medium') then
    Exit('medium');
  if SameText(AConfidence, 'low') then
    Exit('low');
  Result := 'unknown';
end;

class function TRadIAIntentTelemetry.NormalizeIntent(
  const AIntent: string
): string;
begin
  if SameText(AIntent, 'Create project') then
    Exit('Create project');
  if SameText(AIntent, 'Fix build') then
    Exit('Fix build');
  if SameText(AIntent, 'Run tests') then
    Exit('Run tests');
  if SameText(AIntent, 'Diagnose problem') then
    Exit('Diagnose problem');
  if SameText(AIntent, 'General chat') then
    Exit('General chat');
  Result := 'Unknown';
end;

class function TRadIAIntentTelemetry.SummaryJson: string;
begin
  Result := SummaryJsonFrom(DefaultFileName);
end;

class function TRadIAIntentTelemetry.SummaryJsonFrom(
  const AFileName: string
): string;
var
  LCounters: TRadIAIntentTelemetryCounters;
  LEvent: string;
  LItem: TJSONValue;
  LLine: string;
  LLines: TArray<string>;
  LRoot: TJSONObject;
begin
  LCounters := Default(TRadIAIntentTelemetryCounters);
  TMonitor.Enter(FLock);
  try
    try
      if TFile.Exists(AFileName) then
        LLines := TFile.ReadAllLines(AFileName, TEncoding.UTF8)
      else
        LLines := [];
      for LLine in LLines do
      begin
        LItem := TJSONObject.ParseJSONValue(LLine);
        try
          if not (LItem is TJSONObject) then
            Continue;
          LEvent := TJSONObject(LItem).GetValue<string>('event', '');
          LCounters.Add(LEvent);
        finally
          LItem.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        LCounters := Default(TRadIAIntentTelemetryCounters);
        TLogger.Log(
          'Intent telemetry summary is unavailable: ' + E.ClassName,
          'Telemetry'
        );
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('scope', 'local-only');
    LRoot.AddPair('sanitized', TJSONBool.Create(True));
    LRoot.AddPair('promptContentStored', TJSONBool.Create(False));
    LRoot.AddPair('eventCount', TJSONNumber.Create(LCounters.Total));
    LRoot.AddPair('recommended', TJSONNumber.Create(LCounters.Recommended));
    LRoot.AddPair('accepted', TJSONNumber.Create(LCounters.Accepted));
    LRoot.AddPair('reviewed', TJSONNumber.Create(LCounters.Reviewed));
    LRoot.AddPair('chatFallback', TJSONNumber.Create(LCounters.ChatFallback));
    LRoot.AddPair('superseded', TJSONNumber.Create(LCounters.Superseded));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

class procedure TRadIAIntentTelemetry.TryRecord(
  const AEvent: TRadIAIntentTelemetryEvent;
  const AIntent: string;
  const AConfidence: string
);
begin
  {$IFDEF TESTS}
  Exit;
  {$ENDIF}
  TryRecordTo(DefaultFileName, AEvent, AIntent, AConfidence);
end;

class procedure TRadIAIntentTelemetry.TryRecordTo(
  const AFileName: string;
  const AEvent: TRadIAIntentTelemetryEvent;
  const AIntent: string;
  const AConfidence: string
);
var
  LItem: TJSONObject;
  LLine: string;
begin
  if AFileName.IsEmpty then
    Exit;
  LItem := TJSONObject.Create;
  try
    LItem.AddPair('schemaVersion', TJSONNumber.Create(1));
    LItem.AddPair('timestampUtc', DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True));
    LItem.AddPair('event', EventName(AEvent));
    LItem.AddPair('intent', NormalizeIntent(AIntent));
    LItem.AddPair('confidence', NormalizeConfidence(AConfidence));
    LLine := LItem.ToJSON + sLineBreak;
  finally
    LItem.Free;
  end;
  TMonitor.Enter(FLock);
  try
    try
      EnsureStorageReady(AFileName);
      TFile.AppendAllText(AFileName, LLine, TEncoding.UTF8);
    except
      on E: Exception do
        TLogger.Log(
          'Intent telemetry storage is unavailable: ' + E.ClassName,
          'Telemetry'
        );
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
