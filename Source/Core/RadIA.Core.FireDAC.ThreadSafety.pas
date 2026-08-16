unit RadIA.Core.FireDAC.ThreadSafety;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Model;

const
  CRadIAFireDACMaximumThreadContexts = 256;
  CRadIAFireDACThreadContextLineLimit = 120;

type
  TRadIAFireDACThreadContext = record
  private
    FKind: string;
    FLine: Integer;
    FLocalComponentCount: Integer;
    FMarshalledUI: Boolean;
    FSharedComponentCount: Integer;
  public
    constructor Create(
      const AKind: string;
      const ALine: Integer;
      const ASharedComponentCount: Integer;
      const ALocalComponentCount: Integer;
      const AMarshalledUI: Boolean
    );
    property Kind: string read FKind;
    property Line: Integer read FLine;
    property LocalComponentCount: Integer read FLocalComponentCount;
    property MarshalledUI: Boolean read FMarshalledUI;
    property SharedComponentCount: Integer read FSharedComponentCount;
  end;

  TRadIAFireDACThreadSafetyAnalysis = class
  private
    FContexts: TList<TRadIAFireDACThreadContext>;
    FFindings: TList<TRadIAFireDACFinding>;
    FTruncated: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddContext(const AContext: TRadIAFireDACThreadContext);
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    function ContextCount: Integer;
    function Findings: TArray<TRadIAFireDACFinding>;
    function ToJson: string;
    property Truncated: Boolean read FTruncated write FTruncated;
  end;

  TRadIAFireDACThreadSafetyAnalyzer = class
  private
    procedure AnalyzeContext(
      const ALines: TArray<string>;
      const AStartIndex: Integer;
      const AFileName: string;
      const AComponents: TDictionary<string, string>;
      const AResult: TRadIAFireDACThreadSafetyAnalysis
    );
    function CollectSharedComponents(
      const AContent: string
    ): TDictionary<string, string>;
    function ContextText(
      const ALines: TArray<string>;
      const AStartIndex: Integer
    ): string;
    function IsBackgroundStart(const ALine: string; out AKind: string): Boolean;
  public
    function Analyze(
      const AContent: string;
      const AFileName: string
    ): TRadIAFireDACThreadSafetyAnalysis;
  end;

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.SysUtils,
  RadIA.Core.FireDAC.PascalMask;

const
  CFireDACThreadClassPattern =
    'TFD(?:Connection|Transaction|Query|Command|Table|StoredProc|MemTable|LocalSQL|Script)';

constructor TRadIAFireDACThreadContext.Create(
  const AKind: string;
  const ALine: Integer;
  const ASharedComponentCount: Integer;
  const ALocalComponentCount: Integer;
  const AMarshalledUI: Boolean
);
begin
  FKind := AKind;
  FLine := ALine;
  FSharedComponentCount := ASharedComponentCount;
  FLocalComponentCount := ALocalComponentCount;
  FMarshalledUI := AMarshalledUI;
end;

constructor TRadIAFireDACThreadSafetyAnalysis.Create;
begin
  inherited Create;
  FContexts := TList<TRadIAFireDACThreadContext>.Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
end;

destructor TRadIAFireDACThreadSafetyAnalysis.Destroy;
begin
  FFindings.Free;
  FContexts.Free;
  inherited;
end;

procedure TRadIAFireDACThreadSafetyAnalysis.AddContext(
  const AContext: TRadIAFireDACThreadContext
);
begin
  if FContexts.Count >= CRadIAFireDACMaximumThreadContexts then
  begin
    FTruncated := True;
    Exit;
  end;
  FContexts.Add(AContext);
end;

procedure TRadIAFireDACThreadSafetyAnalysis.AddFinding(
  const AFinding: TRadIAFireDACFinding
);
begin
  if FFindings.Count >= CRadIAFireDACMaximumFindings then
  begin
    FTruncated := True;
    Exit;
  end;
  FFindings.Add(AFinding);
end;

function TRadIAFireDACThreadSafetyAnalysis.ContextCount: Integer;
begin
  Result := FContexts.Count;
end;

function TRadIAFireDACThreadSafetyAnalysis.Findings: TArray<TRadIAFireDACFinding>;
begin
  Result := FFindings.ToArray;
end;

function TRadIAFireDACThreadSafetyAnalysis.ToJson: string;
var
  LArray: TJSONArray;
  LContext: TRadIAFireDACThreadContext;
  LFinding: TRadIAFireDACFinding;
  LObject: TJSONObject;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('truncated', TJSONBool.Create(FTruncated));
    LArray := TJSONArray.Create;
    for LContext in FContexts do
    begin
      LObject := TJSONObject.Create;
      LObject.AddPair('kind', LContext.Kind);
      LObject.AddPair('line', TJSONNumber.Create(LContext.Line));
      LObject.AddPair('sharedComponentCount', TJSONNumber.Create(LContext.SharedComponentCount));
      LObject.AddPair('localComponentCount', TJSONNumber.Create(LContext.LocalComponentCount));
      LObject.AddPair('marshalledUI', TJSONBool.Create(LContext.MarshalledUI));
      LArray.AddElement(LObject);
    end;
    LRoot.AddPair('contexts', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACThreadSafetyAnalyzer.CollectSharedComponents(
  const AContent: string
): TDictionary<string, string>;
var
  LMatch: TMatch;
begin
  Result := TDictionary<string, string>.Create;
  LMatch := TRegEx.Match(
    AContent,
    '(?i)\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(' + CFireDACThreadClassPattern + ')\b'
  );
  while LMatch.Success do
  begin
    if not Result.ContainsKey(LMatch.Groups[1].Value) then
      Result.Add(LMatch.Groups[1].Value, LMatch.Groups[2].Value);
    LMatch := LMatch.NextMatch;
  end;
end;

function TRadIAFireDACThreadSafetyAnalyzer.IsBackgroundStart(
  const ALine: string;
  out AKind: string
): Boolean;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)\b(TTask\.Run|TParallel\.(?:For|ForEach)|TThread\.CreateAnonymousThread)\s*\('
  );
  Result := LMatch.Success;
  if Result then
    AKind := LMatch.Groups[1].Value
  else
    AKind := '';
end;

function TRadIAFireDACThreadSafetyAnalyzer.ContextText(
  const ALines: TArray<string>;
  const AStartIndex: Integer
): string;
var
  C: Char;
  I: Integer;
  LLastIndex: Integer;
  LParenthesisDepth: Integer;
begin
  Result := '';
  LParenthesisDepth := 0;
  LLastIndex := AStartIndex + CRadIAFireDACThreadContextLineLimit - 1;
  if LLastIndex > High(ALines) then
    LLastIndex := High(ALines);
  for I := AStartIndex to LLastIndex do
  begin
    Result := Result + ALines[I] + sLineBreak;
    for C in ALines[I] do
      if C = '(' then
        Inc(LParenthesisDepth)
      else if C = ')' then
        Dec(LParenthesisDepth);
    if LParenthesisDepth <= 0 then
      Break;
  end;
end;

function IsLocalComponent(const AContext, AName, AClassName: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AContext,
    '(?i)\b' + TRegEx.Escape(AName) + '\s*:=\s*' + TRegEx.Escape(AClassName) + '\.Create\b'
  );
end;

function UsesComponent(const AContext, AName: string): Boolean;
begin
  Result := TRegEx.IsMatch(AContext, '(?i)\b' + TRegEx.Escape(AName) + '\s*\.');
end;

function UsesUI(const AContext: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AContext,
    '(?i)\.(Caption|Text|Enabled|Visible|Parent|Items|Navigate)\s*(:=|\.|\()'
  );
end;

function MarshalsUI(const AContext: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AContext,
    '(?i)\bTThread\.(?:ForceQueue|Queue|Synchronize)\s*\('
  );
end;

procedure TRadIAFireDACThreadSafetyAnalyzer.AnalyzeContext(
  const ALines: TArray<string>;
  const AStartIndex: Integer;
  const AFileName: string;
  const AComponents: TDictionary<string, string>;
  const AResult: TRadIAFireDACThreadSafetyAnalysis
);
var
  LClassName: string;
  LContext: string;
  LKind: string;
  LLocalCount: Integer;
  LMarshalledUI: Boolean;
  LName: string;
  LSharedCount: Integer;
begin
  if not IsBackgroundStart(ALines[AStartIndex], LKind) then
    Exit;
  LContext := ContextText(ALines, AStartIndex);
  LLocalCount := 0;
  LSharedCount := 0;
  for LName in AComponents.Keys do
  begin
    LClassName := AComponents[LName];
    if not UsesComponent(LContext, LName) then
      Continue;
    if IsLocalComponent(LContext, LName, LClassName) then
    begin
      Inc(LLocalCount);
      Continue;
    end;
    Inc(LSharedCount);
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.thread.shared-component',
      ffsHigh,
      ffcStrong,
      'FireDAC component is shared with background work',
      'A component declared outside the worker is referenced from a background context.',
      TRadIAFireDACFindingDetails.Create(
        TRadIAFireDACLocation.Create(AFileName, AStartIndex + 1),
        LName,
        LClassName + ' is referenced inside ' + LKind + '.',
        'Create and release a worker-local connection and datasets for each background operation.',
        False
      )
    ));
  end;
  LMarshalledUI := MarshalsUI(LContext);
  if UsesUI(LContext) and not LMarshalledUI then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.thread.ui-without-marshalling',
      ffsHigh,
      ffcStrong,
      'Background work accesses UI without marshalling',
      'A FireDAC-related background context accesses UI without Queue or Synchronize.',
      TRadIAFireDACFindingDetails.Create(
        TRadIAFireDACLocation.Create(AFileName, AStartIndex + 1),
        LKind,
        'A VCL property access exists without a visible TThread marshalling call.',
        'Marshal UI changes with TThread.Queue or TThread.Synchronize.',
        False
      )
    ));
  AResult.AddContext(TRadIAFireDACThreadContext.Create(
    LKind,
    AStartIndex + 1,
    LSharedCount,
    LLocalCount,
    LMarshalledUI
  ));
end;

function TRadIAFireDACThreadSafetyAnalyzer.Analyze(
  const AContent: string;
  const AFileName: string
): TRadIAFireDACThreadSafetyAnalysis;
var
  LComponents: TDictionary<string, string>;
  I: Integer;
  LKind: string;
  LLines: TArray<string>;
  LSanitized: string;
begin
  LSanitized := RadIAMaskPascalNonCode(AContent);
  LComponents := CollectSharedComponents(LSanitized);
  try
    Result := TRadIAFireDACThreadSafetyAnalysis.Create;
    try
      LLines := LSanitized.Split([sLineBreak]);
      for I := Low(LLines) to High(LLines) do
      begin
        if Result.ContextCount >= CRadIAFireDACMaximumThreadContexts then
        begin
          Result.Truncated := True;
          Break;
        end;
        if IsBackgroundStart(LLines[I], LKind) then
          AnalyzeContext(LLines, I, AFileName, LComponents, Result);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LComponents.Free;
  end;
end;

end.
