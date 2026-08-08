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
      'inspect authorized reference implementations and their licenses when requested, present a ' +
      'reviewable plan, preview every structural change, create and open the project, organize ' +
      'reusable code, update project references, document applicable provenance, then build it ' +
      'and iterate from compiler evidence until completion or a proven external blocker.',
      [
        TRadIAJourneyPhase.Create(
          'Discover',
          'Inspect the workspace and clarify project type, targets, constraints, references, and licenses.',
          'Record workspace state, agreed requirements, and authorized reference provenance.'
        ),
        TRadIAJourneyPhase.Create(
          'Design',
          'Prefer suitable Delphi RTL capabilities and propose structure, dependencies, forms, and units.',
          'Present an approved plan, dependency rationale, and reviewable file list.'
        ),
        TRadIAJourneyPhase.Create(
          'Create',
          'Generate, organize, document, and open the project through reviewed structural operations.',
          'Report created or moved files, updated project references, documentation, and project identity.'
        ),
        TRadIAJourneyPhase.Create(
          'Verify',
          'Build the target, inspect diagnostics, repair reviewed defects, and repeat until resolved.',
          'Provide build iterations, compiler messages, project health, and remaining risks.'
        )
      ],
      [
        'The requested project is open in the IDE.',
        'The selected target builds or a specific external blocker is proven.',
        'Architecture, usage, dependencies, and third-party provenance are documented when applicable.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey dext-minimal',
      'Create DEXT Minimal API',
      'Creates and verifies a compiled DEXT server with direct endpoint mappings.',
      'Create a new DEXT Minimal API project from the endpoints requested by the user. Convert the ' +
      'request into a versioned API specification, review every route and generated file, use the ' +
      'dext-minimal-api deterministic template, open and build the project, then start the server ' +
      'and verify its health endpoint. Do not claim success from generated text alone.',
      [
        TRadIAJourneyPhase.Create(
          'Specify',
          'Collect project settings and explicit HTTP method, path, group, status, and purpose for every endpoint.',
          'Present the versioned API specification and report all validation results.'
        ),
        TRadIAJourneyPhase.Create(
          'Design',
          'Review direct route mappings, contracts, configuration, dependency availability, and generated files.',
          'Present the immutable project preview before any file is written.'
        ),
        TRadIAJourneyPhase.Create(
          'Create',
          'Create the approved project atomically and open it in the Delphi IDE.',
          'Report the preview identifier, destination, project file, and committed files.'
        ),
        TRadIAJourneyPhase.Create(
          'Verify',
          'Build the selected target, start the server, and call its local health endpoint.',
          'Provide compiler diagnostics, process outcome, HTTP status, and remaining external blockers.'
        )
      ],
      [
        'Every requested endpoint is represented by a reviewed direct DEXT route mapping.',
        'The generated project is open and builds successfully.',
        'The server starts and its health endpoint responds, or a specific external blocker is proven.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey dext-controllers',
      'Create DEXT Controllers API',
      'Creates and verifies a compiled DEXT server organized with controllers.',
      'Create a new DEXT Controllers API project from the endpoints requested by the user. Convert ' +
      'the request into a versioned API specification, review controller grouping and generated ' +
      'files, use the dext-controller-api deterministic template, open and build the project, then ' +
      'start the server and verify health and Swagger when enabled.',
      [
        TRadIAJourneyPhase.Create(
          'Specify',
          'Collect project settings and explicit HTTP method, path, controller group, status, and purpose.',
          'Present the versioned API specification and report all validation results.'
        ),
        TRadIAJourneyPhase.Create(
          'Design',
          'Review controller groups, contracts, Swagger, dependency availability, and generated files.',
          'Present the immutable project preview before any file is written.'
        ),
        TRadIAJourneyPhase.Create(
          'Create',
          'Create the approved controller project atomically and open it in the Delphi IDE.',
          'Report the preview identifier, destination, project file, controllers, and committed files.'
        ),
        TRadIAJourneyPhase.Create(
          'Verify',
          'Build the selected target, start the server, and verify health and Swagger when enabled.',
          'Provide compiler diagnostics, process outcome, HTTP status, and remaining external blockers.'
        )
      ],
      [
        'Every requested endpoint is represented by a reviewed DEXT controller action.',
        'The generated project is open and builds successfully.',
        'Health and enabled Swagger endpoints respond, or a specific external blocker is proven.'
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
      'Build and start the Delphi application under the debugger, prepare and run a bounded runtime ' +
      'scenario, then wait for and capture the failure with stack and expression evidence. Present ' +
      'the diagnosis before editing, apply a reviewable fix, rebuild, rerun the same scenario, and ' +
      'compare failure and verification evidence.',
      [
        TRadIAJourneyPhase.Create(
          'Reproduce',
          'Build, start debugging, preview the runtime scenario, obtain consent, and run it.',
          'Record the authorized process, build, scenario, actions, and reproduction conditions.'
        ),
        TRadIAJourneyPhase.Create(
          'Inspect',
          'Wait for the debugger event and capture failure evidence with stack and safe expressions.',
          'Preserve the sanitized failure evidence identifier and decisive observations.'
        ),
        TRadIAJourneyPhase.Create(
          'Correct',
          'Present the diagnosis, then preview and apply a focused correction.',
          'Record the approved diagnosis and reviewed patch.'
        ),
        TRadIAJourneyPhase.Create(
          'Confirm',
          'Rebuild, start a new session, rerun the same scenario, and compare both evidence records.',
          'Provide a comparable fixed outcome, then add a focused DUnitX test or save the visual ' +
          'scenario as a versioned runtime regression.'
        )
      ],
      [
        'The root cause is supported by debugger evidence.',
        'The correction is reviewed before application.',
        'Failure and verification use different builds and debug sessions.',
        'An isolated cause has a focused DUnitX test or the visual scenario is saved as a regression.',
        'The original failure no longer reproduces or a blocker is proven.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey modernize',
      'Modernize Delphi Project',
      'Modernizes units, forms, packages, and dependencies with compile gates.',
      'Modernize the active Delphi project without changing its intended behavior. Inspect units, ' +
      'forms, packages, project dependencies, and supported targets before proposing changes. Use ' +
      'reviewable transactions, preserve public contracts unless approved, and validate each ' +
      'coherent batch with build and focused tests.',
      [
        TRadIAJourneyPhase.Create(
          'Inventory',
          'Inspect project health, units, symbols, forms, packages, dependencies, and target platforms.',
          'Record GetProjectHealth, ListProjectUnits, GetUnitSymbols, GetActiveForm, and dependency evidence.'
        ),
        TRadIAJourneyPhase.Create(
          'Prioritize',
          'Rank modernization candidates by user value, compatibility risk, and migration cost.',
          'Present independent batches with affected files, contracts, and rollback boundaries.'
        ),
        TRadIAJourneyPhase.Create(
          'Modernize',
          'Preview one coherent multi-file or designer transaction at a time before applying it.',
          'Record approved previews, applied transaction IDs, and untouched public contracts.'
        ),
        TRadIAJourneyPhase.Create(
          'Prove',
          'Build every requested target and run focused tests after each accepted batch.',
          'Provide build, compiler, DUnitX, project-health, and rollback evidence.'
        )
      ],
      [
        'Every applied batch has preview, consent, validation, and rollback evidence.',
        'Requested Delphi targets build or a target-specific external blocker is proven.',
        'Behavioral and public-contract changes are explicitly approved and documented.'
      ]
    ),
    TRadIAJourneyDefinition.Create(
      '/journey migrate',
      'Migrate Legacy Delphi Code',
      'Migrates a bounded legacy pattern through reversible multi-file transactions.',
      'Migrate the user-selected legacy Delphi pattern while preserving observable behavior. ' +
      'Establish a baseline first, map all affected Pascal, DFM or FMX, project, package, and ' +
      'dependency files, then execute reversible batches through the central transaction flow. ' +
      'Never perform a broad rewrite without an approved boundary and validation evidence.',
      [
        TRadIAJourneyPhase.Create(
          'Baseline',
          'Build, run focused tests, and capture project health before editing.',
          'Record baseline build, compiler messages, DUnitX result, and health score.'
        ),
        TRadIAJourneyPhase.Create(
          'Map',
          'Trace the selected legacy pattern across code, forms, projects, packages, and dependencies.',
          'List affected files, symbols, runtime contracts, data boundaries, and migration exclusions.'
        ),
        TRadIAJourneyPhase.Create(
          'Migrate',
          'Preview and apply the smallest reversible development transaction for one migration batch.',
          'Record transaction preview, consent, fingerprint, affected files, and revert capability.'
        ),
        TRadIAJourneyPhase.Create(
          'Compare',
          'Rebuild, rerun focused tests, compare health, and revert the batch on regression.',
          'Provide before-and-after build, tests, health, diff, and rollback decision evidence.'
        )
      ],
      [
        'The selected legacy pattern is removed only inside the approved boundary.',
        'Baseline behavior remains verified by build and focused tests.',
        'Every batch can be reverted independently and leaves unrelated files untouched.'
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
