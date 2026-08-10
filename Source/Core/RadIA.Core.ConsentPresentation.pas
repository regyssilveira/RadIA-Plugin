unit RadIA.Core.ConsentPresentation;

interface

uses
  RadIA.Core.Tools,
  RadIA.Core.ToolSecurity;

type
  TRadIAConsentPresentation = record
  private
    FArguments: string;
    FDescription: string;
    FProjectId: string;
    FRisk: string;
    FScope: string;
    FSource: string;
    FTitle: string;
  public
    class function Build(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor;
      const ARedactor: IRadIASecretRedactor;
      const AShowArguments: Boolean
    ): TRadIAConsentPresentation; static;
    property Arguments: string read FArguments;
    property Description: string read FDescription;
    property ProjectId: string read FProjectId;
    property Risk: string read FRisk;
    property Scope: string read FScope;
    property Source: string read FSource;
    property Title: string read FTitle;
  end;

implementation

uses
  System.SysUtils;

function ConsentRiskName(const ARisk: TRadIAToolRisk): string;
begin
  case ARisk of
    trReadOnly: Result := 'Read only';
    trReversibleWrite: Result := 'Reversible write';
    trStructuralWrite: Result := 'Structural write';
    trExecution: Result := 'Execution';
    trDestructive: Result := 'Destructive';
  else
    Result := 'Sensitive';
  end;
end;

function ConsentSourceName(const AOrigin: string): string;
begin
  if SameText(AOrigin, 'chat') then
    Result := 'Chat command'
  else if SameText(AOrigin, 'chat-agent') then
    Result := 'Native agent'
  else if SameText(AOrigin, 'mcp') then
    Result := 'MCP client'
  else if SameText(AOrigin, 'terminal') then
    Result := 'Terminal'
  else if SameText(AOrigin, 'workflow') then
    Result := 'Declarative workflow'
  else if SameText(AOrigin, 'internal') then
    Result := 'Internal operation'
  else if Trim(AOrigin) = '' then
    Result := 'Unknown source'
  else
    Result := Copy(Trim(AOrigin), 1, 100);
end;

class function TRadIAConsentPresentation.Build(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor;
  const ARedactor: IRadIASecretRedactor;
  const AShowArguments: Boolean
): TRadIAConsentPresentation;
begin
  Result.FTitle := 'RadIA requests permission to run ' + ADescriptor.Name;
  Result.FDescription := ADescriptor.Description;
  Result.FSource := ConsentSourceName(ARequest.Origin);
  Result.FRisk := ConsentRiskName(ADescriptor.Risk);
  Result.FProjectId := ARequest.ProjectId;
  Result.FScope := ARequest.Scope;
  if not AShowArguments then
    Result.FArguments :=
      'Arguments are hidden by your Security & Consent settings.'
  else if Assigned(ARedactor) then
    Result.FArguments := ARedactor.Redact(ARequest.ArgumentsJson)
  else
    Result.FArguments := 'Arguments are unavailable because redaction is not configured.';
end;

end.
