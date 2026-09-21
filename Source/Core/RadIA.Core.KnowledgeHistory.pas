unit RadIA.Core.KnowledgeHistory;

interface

uses
  RadIA.Core.AgentRuntime,
  RadIA.Core.Interfaces,
  RadIA.Core.Knowledge,
  RadIA.Core.ToolSecurity;

const
  RADIA_APPROVED_HISTORY_PREFIX = 'radia-approved-history://';

type
  TRadIAApprovedHistoryKnowledgeSource = class(
    TInterfacedObject,
    IRadIAKnowledgeSource
  )
  private
    FConfig: IRadIAConfig;
    FRedactor: IRadIASecretRedactor;
    FSource: IRadIAKnowledgeSource;
    FStore: TRadIAAgentFileCheckpointStore;
    function BuildDocument(
      const ASummary: TRadIAAgentCheckpointSummary
    ): TRadIAKnowledgeDocument;
    function FindSummary(
      const AFileName: string;
      out ASummary: TRadIAAgentCheckpointSummary
    ): Boolean;
    class function HistoryDocumentName(
      const ASessionId: string
    ): string; static;
    class function IsWithinRetention(
      const ASummary: TRadIAAgentCheckpointSummary
    ): Boolean; static;
    function SanitizeObjective(const AObjective: string): string;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const ASource: IRadIAKnowledgeSource;
      const ACheckpointDirectory: string;
      const ARedactor: IRadIASecretRedactor
    );
    destructor Destroy; override;
    function GetProjectId: string;
    function ListSourceFiles: TArray<string>;
    function ReadSourceFile(
      const AFileName: string;
      out ADocument: TRadIAKnowledgeDocument
    ): Boolean;
    class function IsHistoryDocument(
      const AFileName: string
    ): Boolean; static;
  end;

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.Hash,
  System.SysUtils;

const
  MAX_APPROVED_HISTORY_DOCUMENTS = 50;
  MAX_APPROVED_HISTORY_AGE_DAYS = 30;
  MAX_APPROVED_HISTORY_OBJECTIVE_CHARACTERS = 500;

constructor TRadIAApprovedHistoryKnowledgeSource.Create(
  const AConfig: IRadIAConfig;
  const ASource: IRadIAKnowledgeSource;
  const ACheckpointDirectory: string;
  const ARedactor: IRadIASecretRedactor
);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  if not Assigned(ASource) then
    raise EArgumentNilException.Create('ASource');
  if not Assigned(ARedactor) then
    raise EArgumentNilException.Create('ARedactor');
  FConfig := AConfig;
  FRedactor := ARedactor;
  FSource := ASource;
  FStore := TRadIAAgentFileCheckpointStore.Create(
    ACheckpointDirectory
  );
end;

destructor TRadIAApprovedHistoryKnowledgeSource.Destroy;
begin
  FStore.Free;
  inherited;
end;

function TRadIAApprovedHistoryKnowledgeSource.BuildDocument(
  const ASummary: TRadIAAgentCheckpointSummary
): TRadIAKnowledgeDocument;
var
  LContent: string;
  LFileName: string;
begin
  LFileName := HistoryDocumentName(ASummary.SessionId);
  LContent := 'Approved agent run' + sLineBreak +
    'Objective: ' + SanitizeObjective(ASummary.Objective) + sLineBreak +
    'Status: ' + ASummary.Status + sLineBreak +
    'Steps: ' + ASummary.StepCount.ToString + sLineBreak +
    'Updated: ' + ASummary.UpdatedAtUtc;
  Result := TRadIAKnowledgeDocument.Create(
    LFileName,
    ASummary.UpdatedAtUtc,
    LContent
  );
end;

function TRadIAApprovedHistoryKnowledgeSource.FindSummary(
  const AFileName: string;
  out ASummary: TRadIAAgentCheckpointSummary
): Boolean;
var
  LSummary: TRadIAAgentCheckpointSummary;
begin
  Result := False;
  ASummary := Default(TRadIAAgentCheckpointSummary);
  if not IsHistoryDocument(AFileName) then
    Exit;
  for LSummary in FStore.SearchApproved(
    GetProjectId,
    MAX_APPROVED_HISTORY_DOCUMENTS
  ) do
  begin
    if IsWithinRetention(LSummary) and
      SameText(HistoryDocumentName(LSummary.SessionId), AFileName) then
    begin
      ASummary := LSummary;
      Exit(True);
    end;
  end;
end;

class function TRadIAApprovedHistoryKnowledgeSource.HistoryDocumentName(
  const ASessionId: string
): string;
begin
  Result := RADIA_APPROVED_HISTORY_PREFIX +
    Copy(THashSHA2.GetHashString(ASessionId), 1, 16);
end;

class function TRadIAApprovedHistoryKnowledgeSource.IsWithinRetention(
  const ASummary: TRadIAAgentCheckpointSummary
): Boolean;
var
  LUpdatedAtUtc: TDateTime;
begin
  Result := False;
  if not TryISO8601ToDate(
    ASummary.UpdatedAtUtc,
    LUpdatedAtUtc,
    True
  ) then
    Exit;
  Result := LUpdatedAtUtc >= IncDay(
    TTimeZone.Local.ToUniversalTime(Now),
    -MAX_APPROVED_HISTORY_AGE_DAYS
  );
end;

function TRadIAApprovedHistoryKnowledgeSource.GetProjectId: string;
begin
  Result := FSource.GetProjectId;
end;

class function TRadIAApprovedHistoryKnowledgeSource.IsHistoryDocument(
  const AFileName: string
): Boolean;
begin
  Result := AFileName.StartsWith(
    RADIA_APPROVED_HISTORY_PREFIX,
    True
  );
end;

function TRadIAApprovedHistoryKnowledgeSource.ListSourceFiles:
  TArray<string>;
var
  LFileName: string;
  LFiles: TList<string>;
  LSummary: TRadIAAgentCheckpointSummary;
begin
  if not FConfig.KnowledgeApprovedHistoryEnabled then
    Exit(FSource.ListSourceFiles);
  LFiles := TList<string>.Create;
  try
    for LFileName in FSource.ListSourceFiles do
      LFiles.Add(LFileName);
    for LSummary in FStore.SearchApproved(
      GetProjectId,
      MAX_APPROVED_HISTORY_DOCUMENTS
    ) do
      if IsWithinRetention(LSummary) then
        LFiles.Add(HistoryDocumentName(LSummary.SessionId));
    Result := LFiles.ToArray;
  finally
    LFiles.Free;
  end;
end;

function TRadIAApprovedHistoryKnowledgeSource.ReadSourceFile(
  const AFileName: string;
  out ADocument: TRadIAKnowledgeDocument
): Boolean;
var
  LSummary: TRadIAAgentCheckpointSummary;
begin
  ADocument := Default(TRadIAKnowledgeDocument);
  if not IsHistoryDocument(AFileName) then
    Exit(FSource.ReadSourceFile(AFileName, ADocument));
  if not FConfig.KnowledgeApprovedHistoryEnabled then
    Exit(False);
  Result := FindSummary(AFileName, LSummary);
  if Result then
    ADocument := BuildDocument(LSummary);
end;

function TRadIAApprovedHistoryKnowledgeSource.SanitizeObjective(
  const AObjective: string
): string;
begin
  Result := FRedactor.Redact(AObjective)
    .Replace(#13, ' ')
    .Replace(#10, ' ')
    .Replace(#9, ' ')
    .Trim;
  while Result.Contains('  ') do
    Result := Result.Replace('  ', ' ');
  if Length(Result) > MAX_APPROVED_HISTORY_OBJECTIVE_CHARACTERS then
    SetLength(Result, MAX_APPROVED_HISTORY_OBJECTIVE_CHARACTERS);
  if Result.IsEmpty then
    Result := '[REDACTED OBJECTIVE]';
end;

end.
