unit RadIA.Core.Journeys;

interface

type
  TRadIAJourneyPhase = record
  private
    FName: string;
    FRequirement: string;
    FEvidence: string;
  public
    constructor Create(
      const AName: string;
      const ARequirement: string;
      const AEvidence: string
    );
    property Name: string read FName;
    property Requirement: string read FRequirement;
    property Evidence: string read FEvidence;
  end;

  TRadIAJourneyDefinition = record
  private
    FCommand: string;
    FName: string;
    FDescription: string;
    FObjective: string;
    FPhases: TArray<TRadIAJourneyPhase>;
    FSuccessCriteria: TArray<string>;
  public
    constructor Create(
      const ACommand: string;
      const AName: string;
      const ADescription: string;
      const AObjective: string;
      const APhases: TArray<TRadIAJourneyPhase>;
      const ASuccessCriteria: TArray<string>
    );
    function BuildAgentObjective(const AContext: string): string;
    property Command: string read FCommand;
    property Name: string read FName;
    property Description: string read FDescription;
    property Objective: string read FObjective;
    property Phases: TArray<TRadIAJourneyPhase> read FPhases;
    property SuccessCriteria: TArray<string> read FSuccessCriteria;
  end;

  TRadIAJourneyCatalog = class
  public
    class function All: TArray<TRadIAJourneyDefinition>; static;
    class function Find(
      const ACommand: string;
      out ADefinition: TRadIAJourneyDefinition
    ): Boolean; static;
    class function Resolve(
      const AInput: string;
      out ADefinition: TRadIAJourneyDefinition;
      out AContext: string
    ): Boolean; static;
    class function HelpText: string; static;
  end;

implementation

uses
  System.SysUtils;

constructor TRadIAJourneyPhase.Create(
  const AName: string;
  const ARequirement: string;
  const AEvidence: string
);
begin
  FName := AName;
  FRequirement := ARequirement;
  FEvidence := AEvidence;
end;

constructor TRadIAJourneyDefinition.Create(
  const ACommand: string;
  const AName: string;
  const ADescription: string;
  const AObjective: string;
  const APhases: TArray<TRadIAJourneyPhase>;
  const ASuccessCriteria: TArray<string>
);
begin
  FCommand := ACommand;
  FName := AName;
  FDescription := ADescription;
  FObjective := AObjective;
  FPhases := APhases;
  FSuccessCriteria := ASuccessCriteria;
end;

function TRadIAJourneyDefinition.BuildAgentObjective(
  const AContext: string
): string;
var
  LCriterion: string;
  LIndex: Integer;
  LPhase: TRadIAJourneyPhase;
begin
  Result := FObjective + sLineBreak + sLineBreak + 'Required journey phases:';
  LIndex := 0;
  for LPhase in FPhases do
  begin
    Inc(LIndex);
    Result := Result + sLineBreak + Format(
      '%d. %s: %s Evidence: %s',
      [LIndex, LPhase.Name, LPhase.Requirement, LPhase.Evidence]
    );
  end;
  Result := Result + sLineBreak + sLineBreak + 'Completion criteria:';
  for LCriterion in FSuccessCriteria do
    Result := Result + sLineBreak + '- ' + LCriterion;
  if not AContext.Trim.IsEmpty then
    Result := Result + sLineBreak + sLineBreak +
      'User-provided context: ' + AContext.Trim;
end;

class function TRadIAJourneyCatalog.All:
  TArray<TRadIAJourneyDefinition>;
begin
  Result := [
    TRadIAJourneyDefinition.Create(
      '/journey create',
      'Create Delphi Project',
      'Creates, validates, opens, and explains a new Delphi project.',
      'Create a Delphi project from the user requirements. Inspect the current workspace first, ' +
      'present a reviewable plan, preview every structural change, create and open the project, ' +
      'then build it and summarize the generated architecture and any remaining risks.',
      [
        TRadIAJourneyPhase.Create(
          'Discover',
          'Inspect the workspace and clarify project type, targets, and constraints.',
          'Record the active workspace state and the agreed requirements.'
        ),
        TRadIAJourneyPhase.Create(
          'Design',
          'Propose project structure, dependencies, forms, and units before mutation.',
          'Present an approved plan and reviewable file list.'
        ),
        TRadIAJourneyPhase.Create(
          'Create',
          'Generate and open the project through reviewed structural operations.',
          'Report created files and the active project identity.'
        ),
        TRadIAJourneyPhase.Create(
          'Verify',
          'Build the requested target and inspect project health.',
          'Provide build status, compiler messages, and remaining risks.'
        )
      ],
      [
        'The requested project is open in the IDE.',
        'The selected target builds or a specific external blocker is proven.',
        'Created architecture and remaining risks are summarized.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey fix-build',
      'Fix Build',
      'Diagnoses compiler errors and validates a minimal repair.',
      'Diagnose the current Delphi build failure from compiler evidence. Present a minimal repair ' +
      'plan, apply only reviewable patches, rebuild, and repeat until the build succeeds or a ' +
      'specific external blocker is proven. Preserve unrelated user changes.',
      [
        TRadIAJourneyPhase.Create(
          'Reproduce',
          'Run or inspect the failing build without changing source files.',
          'Capture build status and compiler diagnostics.'
        ),
        TRadIAJourneyPhase.Create(
          'Diagnose',
          'Trace the first actionable compiler error to its source and dependencies.',
          'Explain the root cause and affected files.'
        ),
        TRadIAJourneyPhase.Create(
          'Repair',
          'Preview and apply the smallest reviewed correction.',
          'Record reviewed patches and preserve unrelated changes.'
        ),
        TRadIAJourneyPhase.Create(
          'Rebuild',
          'Rebuild and repeat diagnosis only when evidence requires it.',
          'Provide final build status and compiler message count.'
        )
      ],
      [
        'The build succeeds or a specific external blocker is documented.',
        'Every mutation has review evidence.',
        'Unrelated user changes remain untouched.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey tests',
      'Expand Tests',
      'Adds focused DUnitX coverage and validates the suite.',
      'Inspect the active Delphi project and identify the highest-value missing DUnitX coverage. ' +
      'Present a test plan, add focused deterministic tests with reviewable changes, run the ' +
      'relevant suite, and summarize coverage, failures, and production-code risks.',
      [
        TRadIAJourneyPhase.Create(
          'Assess',
          'Inspect production behavior, current tests, and the highest-risk uncovered path.',
          'List the selected behaviors and why they matter.'
        ),
        TRadIAJourneyPhase.Create(
          'Plan',
          'Define deterministic test cases and required seams before editing.',
          'Present expected cases, fixtures, and file changes.'
        ),
        TRadIAJourneyPhase.Create(
          'Implement',
          'Preview and add focused DUnitX tests with minimal production changes.',
          'Record reviewed patches and test names.'
        ),
        TRadIAJourneyPhase.Create(
          'Run',
          'Execute the relevant suite and inspect failures, errors, and leaks.',
          'Provide total, passed, failed, errored, ignored, and leak evidence.'
        )
      ],
      [
        'Selected tests pass without leaks.',
        'The covered behaviors and remaining risks are explicit.',
        'Production changes are justified by testability needs.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey debug',
      'Debug Failure',
      'Guides a debugger session from reproduction to verified correction.',
      'Reproduce and diagnose the reported Delphi failure using debugger state, breakpoints, call ' +
      'stack, watches, evaluations, and timeline evidence. Present the diagnosis before editing, ' +
      'apply a reviewable fix, then rebuild and rerun the relevant verification.',
      [
        TRadIAJourneyPhase.Create(
          'Reproduce',
          'Start or attach the debugger and reproduce the reported behavior.',
          'Record process state, location, and reproduction conditions.'
        ),
        TRadIAJourneyPhase.Create(
          'Inspect',
          'Use breakpoints, call stack, watches, and evaluations to isolate the cause.',
          'Capture the decisive debugger observations.'
        ),
        TRadIAJourneyPhase.Create(
          'Correct',
          'Present the diagnosis, then preview and apply a focused correction.',
          'Record the approved diagnosis and reviewed patch.'
        ),
        TRadIAJourneyPhase.Create(
          'Confirm',
          'Rebuild and rerun the reproduction or focused test.',
          'Provide build and runtime verification evidence.'
        )
      ],
      [
        'The root cause is supported by debugger evidence.',
        'The correction is reviewed before application.',
        'The original failure no longer reproduces or a blocker is proven.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey release',
      'Prepare Delivery',
      'Runs project health, validation, and a reviewable Git delivery flow.',
      'Prepare the current Delphi project for delivery. Inspect project health and Git status, ' +
      'build, run relevant tests, review diffs, identify release risks, and prepare a scoped commit ' +
      'preview. Never push or publish without an explicit user instruction.',
      [
        TRadIAJourneyPhase.Create(
          'Inspect',
          'Read project health, Git status, and the complete scoped diff.',
          'List changed files, health risks, and unrelated work.'
        ),
        TRadIAJourneyPhase.Create(
          'Validate',
          'Build required targets and run relevant tests and quality gates.',
          'Record build, test, leak, and quality-gate results.'
        ),
        TRadIAJourneyPhase.Create(
          'Review',
          'Review the final diff, release notes, version, and package scope.',
          'Present remaining risks and a commit preview.'
        ),
        TRadIAJourneyPhase.Create(
          'Deliver',
          'Commit, push, or publish only when the user explicitly authorizes each action.',
          'Record resulting references without exposing credentials.'
        )
      ],
      [
        'Required validation gates pass.',
        'The final diff and delivery scope are reviewed.',
        'No remote mutation occurs without explicit user authorization.'
      ]
    )
  ];
end;

class function TRadIAJourneyCatalog.Find(
  const ACommand: string;
  out ADefinition: TRadIAJourneyDefinition
): Boolean;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  ADefinition := Default(TRadIAJourneyDefinition);
  for LDefinition in All do
  begin
    if SameText(LDefinition.Command, Trim(ACommand)) then
    begin
      ADefinition := LDefinition;
      Exit(True);
    end;
  end;
  Result := False;
end;

class function TRadIAJourneyCatalog.Resolve(
  const AInput: string;
  out ADefinition: TRadIAJourneyDefinition;
  out AContext: string
): Boolean;
const
  MAX_CONTEXT_LENGTH = 4000;
var
  LDefinition: TRadIAJourneyDefinition;
  LInput: string;
begin
  ADefinition := Default(TRadIAJourneyDefinition);
  AContext := '';
  LInput := Trim(AInput);
  for LDefinition in All do
  begin
    if SameText(LInput, LDefinition.Command) then
    begin
      ADefinition := LDefinition;
      Exit(True);
    end;
    if LInput.StartsWith(LDefinition.Command + ' ', True) then
    begin
      AContext := Trim(
        Copy(LInput, Length(LDefinition.Command) + 1, MaxInt)
      );
      if Length(AContext) > MAX_CONTEXT_LENGTH then
        raise EArgumentException.Create(
          'Journey context must not exceed 4000 characters.'
        );
      ADefinition := LDefinition;
      Exit(True);
    end;
  end;
  Result := False;
end;

class function TRadIAJourneyCatalog.HelpText: string;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  Result := 'Available Delphi journeys:';
  for LDefinition in All do
    Result := Result + sLineBreak + LDefinition.Command + ' - ' +
      LDefinition.Description + Format(
        ' (%d phases, %d completion criteria)',
        [Length(LDefinition.Phases), Length(LDefinition.SuccessCriteria)]
      );
end;

end.
