unit RadIA.Core.Journeys;

interface

type
  TRadIAJourneyDefinition = record
  private
    FCommand: string;
    FName: string;
    FDescription: string;
    FObjective: string;
  public
    constructor Create(
      const ACommand: string;
      const AName: string;
      const ADescription: string;
      const AObjective: string
    );
    property Command: string read FCommand;
    property Name: string read FName;
    property Description: string read FDescription;
    property Objective: string read FObjective;
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

constructor TRadIAJourneyDefinition.Create(
  const ACommand: string;
  const AName: string;
  const ADescription: string;
  const AObjective: string
);
begin
  FCommand := ACommand;
  FName := AName;
  FDescription := ADescription;
  FObjective := AObjective;
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
      'then build it and summarize the generated architecture and any remaining risks.'
    ),
    TRadIAJourneyDefinition.Create(
      '/journey fix-build',
      'Fix Build',
      'Diagnoses compiler errors and validates a minimal repair.',
      'Diagnose the current Delphi build failure from compiler evidence. Present a minimal repair ' +
      'plan, apply only reviewable patches, rebuild, and repeat until the build succeeds or a ' +
      'specific external blocker is proven. Preserve unrelated user changes.'
    ),
    TRadIAJourneyDefinition.Create(
      '/journey tests',
      'Expand Tests',
      'Adds focused DUnitX coverage and validates the suite.',
      'Inspect the active Delphi project and identify the highest-value missing DUnitX coverage. ' +
      'Present a test plan, add focused deterministic tests with reviewable changes, run the ' +
      'relevant suite, and summarize coverage, failures, and production-code risks.'
    ),
    TRadIAJourneyDefinition.Create(
      '/journey debug',
      'Debug Failure',
      'Guides a debugger session from reproduction to verified correction.',
      'Reproduce and diagnose the reported Delphi failure using debugger state, breakpoints, call ' +
      'stack, watches, evaluations, and timeline evidence. Present the diagnosis before editing, ' +
      'apply a reviewable fix, then rebuild and rerun the relevant verification.'
    ),
    TRadIAJourneyDefinition.Create(
      '/journey release',
      'Prepare Delivery',
      'Runs project health, validation, and a reviewable Git delivery flow.',
      'Prepare the current Delphi project for delivery. Inspect project health and Git status, ' +
      'build, run relevant tests, review diffs, identify release risks, and prepare a scoped commit ' +
      'preview. Never push or publish without an explicit user instruction.'
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
      LDefinition.Description;
end;

end.
