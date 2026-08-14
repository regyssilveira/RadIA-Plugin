unit RadIA.Core.SemanticCompletion;

interface

uses
  System.SysUtils,
  RadIA.Semantic.Workspace;

type
  TRadIASemanticCompletionResult = record
  private
    FAlternativeCount: Integer;
    FCandidateCount: Integer;
    FErrorMessage: string;
    FLatencyMs: Int64;
    FOriginUnit: string;
    FResolutionReason: string;
    FStatus: string;
    FSuggestion: string;
  public
    constructor Create(
      const AStatus: string;
      const ASuggestion: string;
      const ACandidateCount: Integer;
      const ALatencyMs: Int64;
      const AErrorMessage: string
    );
    function WithResolution(
      const AReason: string;
      const AOriginUnit: string;
      const AAlternativeCount: Integer
    ): TRadIASemanticCompletionResult;
    property AlternativeCount: Integer read FAlternativeCount;
    property CandidateCount: Integer read FCandidateCount;
    property ErrorMessage: string read FErrorMessage;
    property LatencyMs: Int64 read FLatencyMs;
    property OriginUnit: string read FOriginUnit;
    property ResolutionReason: string read FResolutionReason;
    property Status: string read FStatus;
    property Suggestion: string read FSuggestion;
  end;

  IRadIASemanticCompletionService = interface
    ['{AF9B9099-B71E-4D9D-B876-B1C4EFA6217A}']
    function Complete(
      const AContainerName: string;
      const APrefix: string;
      const AIsCancelled: TFunc<Boolean>
    ): TRadIASemanticCompletionResult;
    function GetLastResult: TRadIASemanticCompletionResult;
  end;

  TRadIASemanticCompletionService = class(
    TInterfacedObject,
    IRadIASemanticCompletionService
  )
  private
    FClient: IRadIASemanticRequestClient;
    FLastResult: TRadIASemanticCompletionResult;
    FLock: TObject;
    function ExecuteRequest(
      const AParameters: string;
      const AIsCancelled: TFunc<Boolean>;
      out AResponse: string;
      out AError: string
    ): Boolean;
    procedure Store(const AResult: TRadIASemanticCompletionResult);
  public
    constructor Create(const AClient: IRadIASemanticRequestClient);
    destructor Destroy; override;
    function Complete(
      const AContainerName: string;
      const APrefix: string;
      const AIsCancelled: TFunc<Boolean>
    ): TRadIASemanticCompletionResult;
    function GetLastResult: TRadIASemanticCompletionResult;
  end;

implementation

uses
  System.Diagnostics,
  System.JSON;

const
  CMaximumCompletionCandidates = 20;

function CommonPrefix(const AValues: TArray<string>): string;
var
  LIndex: Integer;
  LLength: Integer;
begin
  if Length(AValues) = 0 then
    Exit('');
  Result := AValues[0];
  for LIndex := 1 to High(AValues) do
  begin
    LLength := 0;
    while (LLength < Length(Result)) and
      (LLength < Length(AValues[LIndex])) and
      SameText(Result[LLength + 1], AValues[LIndex][LLength + 1]) do
      Inc(LLength);
    SetLength(Result, LLength);
    if Result = '' then
      Exit;
  end;
end;

constructor TRadIASemanticCompletionResult.Create(
  const AStatus: string;
  const ASuggestion: string;
  const ACandidateCount: Integer;
  const ALatencyMs: Int64;
  const AErrorMessage: string
);
begin
  FStatus := AStatus;
  FSuggestion := ASuggestion;
  FCandidateCount := ACandidateCount;
  FLatencyMs := ALatencyMs;
  FErrorMessage := AErrorMessage;
end;

procedure ReadResolution(
  const AResult: TJSONObject;
  out AStatus: string;
  out AReason: string;
  out AOriginUnit: string;
  out AAlternatives: TJSONArray
);
var
  LResolution: TJSONObject;
begin
  AStatus := '';
  AReason := '';
  AOriginUnit := '';
  AAlternatives := nil;
  LResolution := AResult.GetValue('resolution') as TJSONObject;
  if not Assigned(LResolution) then
    Exit;
  AStatus := LResolution.GetValue<string>('status', '');
  AReason := LResolution.GetValue<string>('reason', '');
  AOriginUnit := LResolution.GetValue<string>('originUnit', '');
  AAlternatives := LResolution.GetValue<TJSONArray>('alternatives');
end;

function TRadIASemanticCompletionResult.WithResolution(
  const AReason: string;
  const AOriginUnit: string;
  const AAlternativeCount: Integer
): TRadIASemanticCompletionResult;
begin
  Result := Self;
  Result.FResolutionReason := AReason;
  Result.FOriginUnit := AOriginUnit;
  Result.FAlternativeCount := AAlternativeCount;
end;

constructor TRadIASemanticCompletionService.Create(
  const AClient: IRadIASemanticRequestClient
);
begin
  inherited Create;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient');
  FClient := AClient;
  FLock := TObject.Create;
end;

destructor TRadIASemanticCompletionService.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TRadIASemanticCompletionService.ExecuteRequest(
  const AParameters: string;
  const AIsCancelled: TFunc<Boolean>;
  out AResponse: string;
  out AError: string
): Boolean;
var
  LCancelable: IRadIASemanticCancelableRequestClient;
begin
  if Supports(FClient, IRadIASemanticCancelableRequestClient, LCancelable) then
    Exit(LCancelable.RequestCancelable(
      'completeResolvedMembers',
      AParameters,
      AIsCancelled,
      AResponse,
      AError
    ));
  if Assigned(AIsCancelled) and AIsCancelled() then
  begin
    AResponse := '';
    AError := 'The semantic completion request was cancelled.';
    Exit(False);
  end;
  Result := FClient.Request(
    'completeResolvedMembers',
    AParameters,
    AResponse,
    AError
  );
end;

function TRadIASemanticCompletionService.Complete(
  const AContainerName: string;
  const APrefix: string;
  const AIsCancelled: TFunc<Boolean>
): TRadIASemanticCompletionResult;
var
  LCandidates: TArray<string>;
  LDocument: TJSONObject;
  LError: string;
  LIndex: Integer;
  LParameters: TJSONObject;
  LResolutionReason: string;
  LResolutionStatus: string;
  LResponse: string;
  LResult: TJSONObject;
  LStopwatch: TStopwatch;
  LSymbols: TJSONArray;
  LSuggestion: string;
  LAlternatives: TJSONArray;
  LOriginUnit: string;
begin
  LStopwatch := TStopwatch.StartNew;
  LParameters := TJSONObject.Create;
  try
    LParameters.AddPair('container', AContainerName);
    LParameters.AddPair('prefix', APrefix);
    LParameters.AddPair(
      'maxItems',
      TJSONNumber.Create(CMaximumCompletionCandidates)
    );
    if not ExecuteRequest(
      LParameters.ToJSON,
      AIsCancelled,
      LResponse,
      LError
    ) then
    begin
      LStopwatch.Stop;
      if LError.Contains('cancel') then
        Result := TRadIASemanticCompletionResult.Create(
          'cancelled', '', 0, LStopwatch.ElapsedMilliseconds, LError
        )
      else
        Result := TRadIASemanticCompletionResult.Create(
          'unavailable', '', 0, LStopwatch.ElapsedMilliseconds, LError
        );
      Store(Result);
      Exit;
    end;
  finally
    LParameters.Free;
  end;
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    LResult := nil;
    LSymbols := nil;
    if Assigned(LDocument) then
      LResult := LDocument.GetValue<TJSONObject>('result');
    if Assigned(LResult) then
      LSymbols := LResult.GetValue<TJSONArray>('symbols');
    if not Assigned(LSymbols) then
    begin
      LStopwatch.Stop;
      Result := TRadIASemanticCompletionResult.Create(
        'invalid-response',
        '',
        0,
        LStopwatch.ElapsedMilliseconds,
        'The semantic completion response has no symbols.'
      );
      Store(Result);
      Exit;
    end;
    ReadResolution(
      LResult,
      LResolutionStatus,
      LResolutionReason,
      LOriginUnit,
      LAlternatives
    );
    SetLength(LCandidates, LSymbols.Count);
    for LIndex := 0 to LSymbols.Count - 1 do
      LCandidates[LIndex] :=
        (LSymbols[LIndex] as TJSONObject).GetValue<string>('name', '');
    LSuggestion := CommonPrefix(LCandidates);
    if SameText(LSuggestion, APrefix) then
      LSuggestion := ''
    else if LSuggestion.StartsWith(APrefix, True) then
      Delete(LSuggestion, 1, Length(APrefix));
    LStopwatch.Stop;
    if SameText(LResolutionStatus, 'ambiguous') then
    begin
      Result := TRadIASemanticCompletionResult.Create(
        'ambiguous', '', Length(LCandidates),
        LStopwatch.ElapsedMilliseconds, LResolutionReason
      );
      if Assigned(LAlternatives) then
        Result := Result.WithResolution(
          LResolutionReason,
          LOriginUnit,
          LAlternatives.Count
        );
      Store(Result);
      Exit;
    end;
    Result := TRadIASemanticCompletionResult.Create(
      LResolutionStatus,
      LSuggestion,
      Length(LCandidates),
      LStopwatch.ElapsedMilliseconds,
      ''
    );
    if Result.FStatus = '' then
      Result.FStatus := 'ready';
    if Assigned(LAlternatives) then
      Result := Result.WithResolution(
        LResolutionReason,
        LOriginUnit,
        LAlternatives.Count
      );
    Store(Result);
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticCompletionService.GetLastResult:
  TRadIASemanticCompletionResult;
begin
  TMonitor.Enter(FLock);
  try
    Result := FLastResult;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIASemanticCompletionService.Store(
  const AResult: TRadIASemanticCompletionResult
);
begin
  TMonitor.Enter(FLock);
  try
    FLastResult := AResult;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
