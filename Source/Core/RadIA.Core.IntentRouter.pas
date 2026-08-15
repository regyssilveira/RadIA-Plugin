unit RadIA.Core.IntentRouter;

interface

type
  TRadIAIntentKind = (
    rikUnknown,
    rikCreateProject,
    rikFixBuild,
    rikRunTests,
    rikDiagnose
  );

  TRadIAIntentConfidence = (ricLow, ricMedium, ricHigh);

  TRadIAIntentRecommendation = record
  private
    FCommand: string;
    FConfidence: TRadIAIntentConfidence;
    FExplanation: string;
    FIntent: TRadIAIntentKind;
    FRoute: string;
  public
    constructor Create(
      const AIntent: TRadIAIntentKind;
      const AConfidence: TRadIAIntentConfidence;
      const ARoute: string;
      const ACommand: string;
      const AExplanation: string
    );
    function ConfidenceName: string;
    function IntentName: string;
    property Command: string read FCommand;
    property Confidence: TRadIAIntentConfidence read FConfidence;
    property Explanation: string read FExplanation;
    property Intent: TRadIAIntentKind read FIntent;
    property Route: string read FRoute;
  end;

  TRadIAIntentRouter = class
  private
    class function ContainsAny(
      const AText: string;
      const ATerms: array of string
    ): Boolean; static;
    class function TryClassifyJourney(
      const AInput: string;
      out ARecommendation: TRadIAIntentRecommendation
    ): Boolean; static;
  public
    class function TryRecommend(
      const AInput: string;
      out ARecommendation: TRadIAIntentRecommendation
    ): Boolean; static;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.Journeys;

constructor TRadIAIntentRecommendation.Create(
  const AIntent: TRadIAIntentKind;
  const AConfidence: TRadIAIntentConfidence;
  const ARoute: string;
  const ACommand: string;
  const AExplanation: string
);
begin
  FIntent := AIntent;
  FConfidence := AConfidence;
  FRoute := ARoute;
  FCommand := ACommand;
  FExplanation := AExplanation;
end;

function TRadIAIntentRecommendation.ConfidenceName: string;
begin
  case FConfidence of
    ricHigh: Result := 'high';
    ricMedium: Result := 'medium';
  else
    Result := 'low';
  end;
end;

function TRadIAIntentRecommendation.IntentName: string;
begin
  case FIntent of
    rikCreateProject: Result := 'Create project';
    rikFixBuild: Result := 'Fix build';
    rikRunTests: Result := 'Run tests';
    rikDiagnose: Result := 'Diagnose problem';
  else
    Result := 'General chat';
  end;
end;

class function TRadIAIntentRouter.ContainsAny(
  const AText: string;
  const ATerms: array of string
): Boolean;
var
  LTerm: string;
begin
  for LTerm in ATerms do
    if ContainsText(AText, LTerm) then
      Exit(True);
  Result := False;
end;

class function TRadIAIntentRouter.TryClassifyJourney(
  const AInput: string;
  out ARecommendation: TRadIAIntentRecommendation
): Boolean;
var
  LCommand: string;
  LText: string;
begin
  LText := ' ' + LowerCase(Trim(AInput)) + ' ';
  if TRadIAJourneyCatalog.TryInferCreateProject(AInput, LCommand) then
  begin
    ARecommendation := TRadIAIntentRecommendation.Create(
      rikCreateProject,
      ricHigh,
      'journey',
      LCommand,
      'The request asks for a complete Delphi project, so the guided creation journey can ' +
        'collect missing details, create it, open it, build it, and validate its main scenario.'
    );
    Exit(True);
  end;
  if ContainsAny(LText, [' build ', ' compile ', ' compilation ', ' compilar ', ' compilacao ',
    ' compilação ', ' e2003 ', ' e2029 ', ' compiler error ']) and
    ContainsAny(LText, [' fix ', ' repair ', ' correct ', ' corrig', ' resolv', ' falh', ' error ',
      ' erro ']) then
  begin
    ARecommendation := TRadIAIntentRecommendation.Create(
      rikFixBuild,
      ricHigh,
      'journey',
      '/journey fix-build ' + Trim(AInput),
      'The request combines a build or compilation failure with a repair objective. The build ' +
        'journey preserves constraints, reproduces the failure, applies a reviewable fix, and rebuilds.'
    );
    Exit(True);
  end;
  if ContainsAny(LText, [' test ', ' tests ', ' dunitx ', ' teste ', ' testes ']) and
    ContainsAny(LText, [' run ', ' execute ', ' check ', ' validate ', ' rod', ' execut', ' verific',
      ' valid']) then
  begin
    ARecommendation := TRadIAIntentRecommendation.Create(
      rikRunTests,
      ricHigh,
      'journey',
      '/journey tests ' + Trim(AInput),
      'The request asks to execute or validate tests. The test journey discovers the suite, runs it, ' +
        'explains failures, and records evidence without hiding skipped or failing tests.'
    );
    Exit(True);
  end;
  if ContainsAny(LText, [' access violation ', ' memory leak ', ' vazamento ', ' exception ',
    ' excecao ', ' exceção ', ' crash ', ' trava ', ' breakpoint ', ' debug ']) then
  begin
    ARecommendation := TRadIAIntentRecommendation.Create(
      rikDiagnose,
      ricMedium,
      'journey',
      '/journey debug ' + Trim(AInput),
      'The request describes a runtime symptom. The debug journey first confirms reproduction steps ' +
        'and expected behavior, then gathers debugger evidence before proposing a correction.'
    );
    Exit(True);
  end;
  Result := False;
end;

class function TRadIAIntentRouter.TryRecommend(
  const AInput: string;
  out ARecommendation: TRadIAIntentRecommendation
): Boolean;
begin
  Result := False;
  if Trim(AInput).IsEmpty or Trim(AInput).StartsWith('/') then
    Exit;
  Result := TryClassifyJourney(AInput, ARecommendation);
end;

end.
