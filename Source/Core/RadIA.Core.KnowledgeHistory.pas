unit RadIA.Core.KnowledgeHistory;

interface

uses
  RadIA.Core.AgentRuntime,
  RadIA.Core.Interfaces,
  RadIA.Core.Knowledge;

const
  RADIA_APPROVED_HISTORY_PREFIX = 'radia-approved-history://';

type
  TRadIAApprovedHistoryKnowledgeSource = class(
    TInterfacedObject,
    IRadIAKnowledgeSource
  )
  private
    FConfig: IRadIAConfig;
    FSource: IRadIAKnowledgeSource;
    FStore: TRadIAAgentFileCheckpointStore;
    function BuildDocument(
      const ASummary: TRadIAAgentCheckpointSummary
    ): TRadIAKnowledgeDocument;
    function FindSummary(
      const AFileName: string;
      out ASummary: TRadIAAgentCheckpointSummary
    ): Boolean;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const ASource: IRadIAKnowledgeSource;
      const ACheckpointDirectory: string
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
  System.Generics.Collections,
  System.SysUtils;

const
  MAX_APPROVED_HISTORY_DOCUMENTS = 50;

constructor TRadIAApprovedHistoryKnowledgeSource.Create(
  const AConfig: IRadIAConfig;
  const ASource: IRadIAKnowledgeSource;
  const ACheckpointDirectory: string
);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  if not Assigned(ASource) then
    raise EArgumentNilException.Create('ASource');
  FConfig := AConfig;
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
  LFileName := RADIA_APPROVED_HISTORY_PREFIX + ASummary.SessionId;
  LContent := 'Approved agent run' + sLineBreak +
    'Objective: ' + ASummary.Objective + sLineBreak +
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
  LSessionId: string;
  LSummary: TRadIAAgentCheckpointSummary;
begin
  Result := False;
  ASummary := Default(TRadIAAgentCheckpointSummary);
  if not IsHistoryDocument(AFileName) then
    Exit;
  LSessionId := Copy(
    AFileName,
    Length(RADIA_APPROVED_HISTORY_PREFIX) + 1,
    MaxInt
  );
  for LSummary in FStore.SearchApproved(
    GetProjectId,
    MAX_APPROVED_HISTORY_DOCUMENTS
  ) do
  begin
    if SameText(LSummary.SessionId, LSessionId) then
    begin
      ASummary := LSummary;
      Exit(True);
    end;
  end;
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
      LFiles.Add(
        RADIA_APPROVED_HISTORY_PREFIX + LSummary.SessionId
      );
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

end.
