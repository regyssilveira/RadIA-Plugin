unit RadIA.Core.KnowledgeTools;

interface

uses
  RadIA.Core.Knowledge,
  RadIA.Core.Tools;

procedure RegisterRadIAKnowledgeTools(
  const ARegistry: IRadIAToolRegistry;
  const AKnowledge: IRadIAKnowledgeService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAKnowledgeToolKind = (
    ktkIndexProject,
    ktkSearchProject,
    ktkGetStatus,
    ktkGetDocument,
    ktkClearProject
  );

  TRadIAKnowledgeTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIAKnowledgeToolKind;
    FKnowledge: IRadIAKnowledgeService;
    function ExecuteIndex: TRadIAToolResult;
    function ExecuteSearch(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteStatus: TRadIAToolResult;
    function ExecuteDocument(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteClear: TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetIntegerArgument(
      const AJson: TJSONObject;
      const AName: string;
      const ADefault: Integer;
      const AMinimum: Integer;
      const AMaximum: Integer
    ): Integer;
  public
    constructor Create(
      const AKind: TRadIAKnowledgeToolKind;
      const AKnowledge: IRadIAKnowledgeService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';
  CSearchInputSchema =
    '{"type":"object","required":["query"],"properties":{' +
    '"query":{"type":"string","minLength":2,"maxLength":512},' +
    '"maxResults":{"type":"integer","minimum":1,"maximum":50}},' +
    '"additionalProperties":false}';
  CDocumentInputSchema =
    '{"type":"object","required":["fileName"],"properties":{' +
    '"fileName":{"type":"string","minLength":1,"maxLength":4096},' +
    '"maxCharacters":{"type":"integer","minimum":1,"maximum":65536}},' +
    '"additionalProperties":false}';
  CMaxResultContentCharacters = 4000;
  CDefaultDocumentCharacters = 16000;
  CMaxDocumentCharacters = 65536;

procedure RegisterRadIAKnowledgeTools(
  const ARegistry: IRadIAToolRegistry;
  const AKnowledge: IRadIAKnowledgeService
);
var
  LKind: TRadIAKnowledgeToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AKnowledge) then
    raise EArgumentNilException.Create('AKnowledge');

  for LKind := Low(TRadIAKnowledgeToolKind) to
    High(TRadIAKnowledgeToolKind) do
    ARegistry.RegisterTool(
      TRadIAKnowledgeTool.Create(LKind, AKnowledge)
    );
end;

{ TRadIAKnowledgeTool }

constructor TRadIAKnowledgeTool.Create(
  const AKind: TRadIAKnowledgeToolKind;
  const AKnowledge: IRadIAKnowledgeService
);
begin
  inherited Create;
  if not Assigned(AKnowledge) then
    raise EArgumentNilException.Create('AKnowledge');
  FKind := AKind;
  FKnowledge := AKnowledge;
end;

function TRadIAKnowledgeTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    ktkIndexProject:
      Result := ExecuteIndex;
    ktkSearchProject:
      Result := ExecuteSearch(ARequest);
    ktkGetStatus:
      Result := ExecuteStatus;
    ktkGetDocument:
      Result := ExecuteDocument(ARequest);
    ktkClearProject:
      Result := ExecuteClear;
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Knowledge tool kind is not supported.'
    );
  end;
end;

function TRadIAKnowledgeTool.ExecuteDocument(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LChunk: TRadIAKnowledgeChunk;
  LContent: string;
  LDocument: TRadIAIndexedKnowledgeDocument;
  LFileName: string;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LMaxCharacters: Integer;
  LProjectId: string;
  LRemaining: Integer;
  LRoot: TJSONObject;
  LTruncated: Boolean;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Knowledge document arguments must be a JSON object.'
    ));
  try
    LFileName := Trim(LJson.GetValue<string>('fileName', ''));
    if (LFileName = '') or (Length(LFileName) > 4096) then
      Exit(TRadIAToolResult.Failed(
        'invalid_file',
        'Knowledge document file name is invalid.'
      ));
    LMaxCharacters := GetIntegerArgument(
      LJson,
      'maxCharacters',
      CDefaultDocumentCharacters,
      1,
      CMaxDocumentCharacters
    );
  finally
    LJson.Free;
  end;

  LProjectId := FKnowledge.GetCurrentProjectId;
  if not FKnowledge.GetDocument(
    LProjectId,
    LFileName,
    LDocument
  ) then
    Exit(TRadIAToolResult.Failed(
      'knowledge_document_not_found',
      'The requested file is not present in the active project index.'
    ));

  LRemaining := LMaxCharacters;
  LTruncated := False;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('projectId', LProjectId);
    LRoot.AddPair('fileName', LDocument.FileName);
    LRoot.AddPair('revision', LDocument.Revision);
    LArray := TJSONArray.Create;
    LRoot.AddPair('chunks', LArray);
    for LChunk in LDocument.Chunks do
    begin
      if LRemaining = 0 then
      begin
        LTruncated := True;
        Break;
      end;
      LContent := LChunk.Content;
      if Length(LContent) > LRemaining then
      begin
        LContent := Copy(LContent, Low(LContent), LRemaining);
        LTruncated := True;
      end;
      Dec(LRemaining, Length(LContent));
      LItem := TJSONObject.Create;
      LItem.AddPair('id', LChunk.Id);
      LItem.AddPair('symbol', LChunk.Symbol);
      LItem.AddPair(
        'startLine',
        TJSONNumber.Create(LChunk.StartLine)
      );
      LItem.AddPair(
        'endLine',
        TJSONNumber.Create(LChunk.EndLine)
      );
      LItem.AddPair('content', LContent);
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair('truncated', TJSONBool.Create(LTruncated));
    Result := TRadIAToolResult.Succeeded(
      LRoot.ToJSON,
      LTruncated
    );
  finally
    LRoot.Free;
  end;
end;

function TRadIAKnowledgeTool.ExecuteClear: TRadIAToolResult;
var
  LJson: TJSONObject;
  LProjectId: string;
begin
  LProjectId := FKnowledge.GetCurrentProjectId;
  if Trim(LProjectId) = '' then
    Exit(TRadIAToolResult.Failed(
      'invalid_project',
      'No active project knowledge index is available.'
    ));
  FKnowledge.ClearProject(LProjectId);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('projectId', LProjectId);
    LJson.AddPair('cleared', TJSONBool.Create(True));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAKnowledgeTool.ExecuteIndex: TRadIAToolResult;
var
  LJson: TJSONObject;
  LRefresh: TRadIAKnowledgeRefreshResult;
begin
  LRefresh := FKnowledge.RefreshProject;
  if not LRefresh.Success then
    Exit(TRadIAToolResult.Failed(
      LRefresh.ErrorCode,
      LRefresh.ErrorMessage
    ));

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('projectId', LRefresh.ProjectId);
    LJson.AddPair(
      'indexedFiles',
      TJSONNumber.Create(LRefresh.IndexedFiles)
    );
    LJson.AddPair(
      'updatedFiles',
      TJSONNumber.Create(LRefresh.UpdatedFiles)
    );
    LJson.AddPair(
      'skippedFiles',
      TJSONNumber.Create(LRefresh.SkippedFiles)
    );
    LJson.AddPair(
      'removedFiles',
      TJSONNumber.Create(LRefresh.RemovedFiles)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAKnowledgeTool.ExecuteSearch(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LContent: string;
  LHit: TRadIAKnowledgeSearchHit;
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LMaxResults: Integer;
  LProjectId: string;
  LQuery: string;
  LRoot: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Knowledge search arguments must be a JSON object.'
    ));
  try
    LQuery := Trim(LJson.GetValue<string>('query', ''));
    if (Length(LQuery) < 2) or (Length(LQuery) > 512) then
      Exit(TRadIAToolResult.Failed(
        'invalid_query',
        'Search query must contain between 2 and 512 characters.'
      ));
    LMaxResults := GetIntegerArgument(
      LJson,
      'maxResults',
      10,
      1,
      50
    );
  finally
    LJson.Free;
  end;

  LProjectId := FKnowledge.GetCurrentProjectId;
  LHits := FKnowledge.Search(
    LProjectId,
    LQuery,
    LMaxResults
  );
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('projectId', LProjectId);
    LRoot.AddPair('query', LQuery);
    LArray := TJSONArray.Create;
    LRoot.AddPair('results', LArray);
    for LHit in LHits do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('fileName', LHit.Chunk.FileName);
      LItem.AddPair('revision', LHit.Chunk.Revision);
      LItem.AddPair('symbol', LHit.Chunk.Symbol);
      LItem.AddPair(
        'startLine',
        TJSONNumber.Create(LHit.Chunk.StartLine)
      );
      LItem.AddPair(
        'endLine',
        TJSONNumber.Create(LHit.Chunk.EndLine)
      );
      LItem.AddPair('score', TJSONNumber.Create(LHit.Score));
      LContent := LHit.Chunk.Content;
      if Length(LContent) > CMaxResultContentCharacters then
        LContent := Copy(
          LContent,
          Low(LContent),
          CMaxResultContentCharacters
        );
      LItem.AddPair('content', LContent);
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair('count', TJSONNumber.Create(Length(LHits)));
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAKnowledgeTool.ExecuteStatus: TRadIAToolResult;
var
  LJson: TJSONObject;
  LProjectId: string;
  LStatus: TRadIAKnowledgeStatus;
begin
  LProjectId := FKnowledge.GetCurrentProjectId;
  if Trim(LProjectId) = '' then
    Exit(TRadIAToolResult.Failed(
      'invalid_project',
      'No active project knowledge index is available.'
    ));
  LStatus := FKnowledge.GetStatus(LProjectId);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('projectId', LStatus.ProjectId);
    LJson.AddPair('loaded', TJSONBool.Create(LStatus.Loaded));
    LJson.AddPair(
      'fileCount',
      TJSONNumber.Create(LStatus.FileCount)
    );
    LJson.AddPair(
      'chunkCount',
      TJSONNumber.Create(LStatus.ChunkCount)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAKnowledgeTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    ktkIndexProject:
      Result := TRadIAToolDescriptor.Create(
        'IndexProjectKnowledge',
        '1.0',
        'Incrementally indexes local Delphi source files for offline search.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      ).WithExecutionOptions(120000, True);
    ktkSearchProject:
      Result := TRadIAToolDescriptor.Create(
        'SearchProjectKnowledge',
        '1.0',
        'Searches the active project index and returns traceable source chunks.',
        CSearchInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    ktkGetStatus:
      Result := TRadIAToolDescriptor.Create(
        'GetKnowledgeStatus',
        '1.0',
        'Returns local index status and aggregate counts for the active project.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    ktkGetDocument:
      Result := TRadIAToolDescriptor.Create(
        'GetKnowledgeDocument',
        '1.0',
        'Returns bounded traceable chunks for one indexed project file.',
        CDocumentInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    ktkClearProject:
      Result := TRadIAToolDescriptor.Create(
        'ClearProjectKnowledge',
        '1.0',
        'Removes the derived local index for the active project.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReversibleWrite
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIAKnowledgeTool.GetIntegerArgument(
  const AJson: TJSONObject;
  const AName: string;
  const ADefault: Integer;
  const AMinimum: Integer;
  const AMaximum: Integer
): Integer;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  LValue := AJson.GetValue(AName);
  if not Assigned(LValue) then
    Exit;
  if not (LValue is TJSONNumber) then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must be an integer.',
      [AName]
    );
  Result := TJSONNumber(LValue).AsInt;
  if (Result < AMinimum) or (Result > AMaximum) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Argument "%s" must be between %d and %d.',
      [AName, AMinimum, AMaximum]
    );
end;

end.
