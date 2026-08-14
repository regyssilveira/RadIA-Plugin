unit RadIA.Core.ThreadingAssistant;

interface

uses
  RadIA.Core.Patches,
  RadIA.Core.Workspace;

type
  TRadIAThreadRisk = record
  private
    FCode: string;
    FLine: Integer;
    FMessage: string;
  public
    constructor Create(const ACode, AMessage: string; const ALine: Integer);
    property Code: string read FCode;
    property Line: Integer read FLine;
    property Message: string read FMessage;
  end;

  TRadIAThreadAnalysis = record
  private
    FBackgroundWork: Boolean;
    FRisks: TArray<TRadIAThreadRisk>;
  public
    constructor Create(const ABackgroundWork: Boolean; const ARisks: TArray<TRadIAThreadRisk>);
    property BackgroundWork: Boolean read FBackgroundWork;
    property Risks: TArray<TRadIAThreadRisk> read FRisks;
  end;

  TRadIAThreadPreparation = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPatch: TRadIAPatchResult;
    FSuccess: Boolean;
  public
    class function Failed(const ACode, AMessage: string): TRadIAThreadPreparation; static;
    class function Succeeded(const APatch: TRadIAPatchResult): TRadIAThreadPreparation; static;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Patch: TRadIAPatchResult read FPatch;
    property Success: Boolean read FSuccess;
  end;

  IRadIAThreadingAssistantService = interface
    ['{FE0B53A1-FF18-4BA1-92A8-34BB93E961A6}']
    function Analyze: TRadIAThreadAnalysis;
    function PrepareReplacement(
      const AOriginalText: string;
      const AReplacementText: string
    ): TRadIAThreadPreparation;
  end;

  TRadIAThreadingAssistantService = class(TInterfacedObject, IRadIAThreadingAssistantService)
  private
    FPatchService: IRadIAPatchService;
    FWorkspace: IRadIAWorkspaceFacade;
    function AnalyzeText(const AText: string): TRadIAThreadAnalysis;
    function ContainsCancellation(const AText: string): Boolean;
    function ContainsExceptionHandling(const AText: string): Boolean;
    function ContainsUIAccess(const AText: string): Boolean;
    function ContainsUIMarshalling(const AText: string): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const APatchService: IRadIAPatchService
    );
    function Analyze: TRadIAThreadAnalysis;
    function PrepareReplacement(
      const AOriginalText: string;
      const AReplacementText: string
    ): TRadIAThreadPreparation;
  end;

implementation

uses
  System.Generics.Collections,
  System.RegularExpressions,
  System.SysUtils;

constructor TRadIAThreadRisk.Create(const ACode, AMessage: string; const ALine: Integer);
begin
  FCode := ACode;
  FMessage := AMessage;
  FLine := ALine;
end;

constructor TRadIAThreadAnalysis.Create(
  const ABackgroundWork: Boolean;
  const ARisks: TArray<TRadIAThreadRisk>
);
begin
  FBackgroundWork := ABackgroundWork;
  FRisks := Copy(ARisks);
end;

class function TRadIAThreadPreparation.Failed(
  const ACode, AMessage: string
): TRadIAThreadPreparation;
begin
  Result.FSuccess := False;
  Result.FErrorCode := ACode;
  Result.FErrorMessage := AMessage;
end;

class function TRadIAThreadPreparation.Succeeded(
  const APatch: TRadIAPatchResult
): TRadIAThreadPreparation;
begin
  Result.FSuccess := True;
  Result.FPatch := APatch;
end;

constructor TRadIAThreadingAssistantService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const APatchService: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  FWorkspace := AWorkspace;
  FPatchService := APatchService;
end;

function TRadIAThreadingAssistantService.ContainsCancellation(const AText: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AText,
    '\b(Cancelled|CancellationToken|TEvent|Terminated|CheckCancellation)\b',
    [roIgnoreCase]
  );
end;

function TRadIAThreadingAssistantService.ContainsExceptionHandling(const AText: string): Boolean;
begin
  Result := TRegEx.IsMatch(AText, '\btry\b[\s\S]*\bexcept\b', [roIgnoreCase]);
end;

function TRadIAThreadingAssistantService.ContainsUIAccess(const AText: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AText,
    '\.(Caption|Text|Enabled|Visible|Parent|Items|Navigate)\s*(:=|\.|\()',
    [roIgnoreCase]
  );
end;

function TRadIAThreadingAssistantService.ContainsUIMarshalling(const AText: string): Boolean;
begin
  Result := TRegEx.IsMatch(AText, 'TThread\.(ForceQueue|Queue|Synchronize)\s*\(', [roIgnoreCase]);
end;

function TRadIAThreadingAssistantService.AnalyzeText(const AText: string): TRadIAThreadAnalysis;
var
  LBackground: TMatch;
  LLine: Integer;
  LRisks: TList<TRadIAThreadRisk>;
begin
  LBackground := TRegEx.Match(
    AText,
    '(TTask\.Run|TParallel\.For|TThread\.CreateAnonymousThread)\s*\(',
    [roIgnoreCase]
  );
  if not LBackground.Success then
    Exit(TRadIAThreadAnalysis.Create(False, []));
  LLine := 1 + TRegEx.Matches(AText.Substring(0, LBackground.Index), '\r?\n').Count;
  LRisks := TList<TRadIAThreadRisk>.Create;
  try
    if ContainsUIAccess(AText) and not ContainsUIMarshalling(AText) then
      LRisks.Add(TRadIAThreadRisk.Create(
        'unsafe_vcl_access',
        'Background work accesses VCL state without Queue or Synchronize.',
        LLine
      ));
    if not ContainsCancellation(AText) then
      LRisks.Add(TRadIAThreadRisk.Create(
        'missing_cancellation',
        'Background work has no visible cancellation check.',
        LLine
      ));
    if not ContainsExceptionHandling(AText) then
      LRisks.Add(TRadIAThreadRisk.Create(
        'missing_exception_handling',
        'Background work has no visible try/except boundary.',
        LLine
      ));
    Result := TRadIAThreadAnalysis.Create(True, LRisks.ToArray);
  finally
    LRisks.Free;
  end;
end;

function TRadIAThreadingAssistantService.Analyze: TRadIAThreadAnalysis;
begin
  Result := AnalyzeText(FWorkspace.GetEditorContent(2 * 1024 * 1024).Content);
end;

function TRadIAThreadingAssistantService.PrepareReplacement(
  const AOriginalText: string;
  const AReplacementText: string
): TRadIAThreadPreparation;
var
  LAnalysis: TRadIAThreadAnalysis;
  LPatch: TRadIAPatchResult;
  LSnapshot: TRadIAEditorContent;
begin
  if AOriginalText.IsEmpty or AReplacementText.IsEmpty then
    Exit(TRadIAThreadPreparation.Failed('invalid_replacement', 'Original and replacement text are required.'));
  LSnapshot := FWorkspace.GetEditorContent(2 * 1024 * 1024);
  if not LSnapshot.FileName.EndsWith('.pas', True) then
    Exit(TRadIAThreadPreparation.Failed('unsupported_file', 'The active editor is not a Pascal unit.'));
  if not LSnapshot.Content.Contains(AOriginalText) then
    Exit(TRadIAThreadPreparation.Failed('original_not_found', 'Original text was not found in the active editor.'));
  LAnalysis := AnalyzeText(AReplacementText);
  if LAnalysis.BackgroundWork and (Length(LAnalysis.Risks) > 0) then
    Exit(TRadIAThreadPreparation.Failed(
      'unsafe_replacement',
      'Replacement must include VCL marshalling when needed, cancellation, and exception handling.'
    ));
  LPatch := FPatchService.Prepare(TRadIAPatchSpec.Create(
    LSnapshot.FileName,
    LSnapshot.Revision,
    AOriginalText,
    AReplacementText
  ));
  if not LPatch.Success then
    Exit(TRadIAThreadPreparation.Failed(LPatch.ErrorCode, LPatch.ErrorMessage));
  Result := TRadIAThreadPreparation.Succeeded(LPatch);
end;

end.
