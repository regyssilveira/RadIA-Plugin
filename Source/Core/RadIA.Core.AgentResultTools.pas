unit RadIA.Core.AgentResultTools;

interface

uses
  RadIA.Core.AgentResultStore,
  RadIA.Core.Tools;

procedure RegisterRadIAAgentResultTools(
  const ARegistry: IRadIAToolRegistry;
  const AStore: IRadIAAgentResultStore
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAAgentResultToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FStore: IRadIAAgentResultStore;
  public
    constructor Create(const AStore: IRadIAAgentResultStore);
    function GetDescriptor: TRadIAToolDescriptor; virtual; abstract;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
  end;

  TRadIAGetToolResultSummaryTool = class(TRadIAAgentResultToolBase)
  public
    function GetDescriptor: TRadIAToolDescriptor; override;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
  end;

  TRadIAGetToolResultRangeTool = class(TRadIAAgentResultToolBase)
  public
    function GetDescriptor: TRadIAToolDescriptor; override;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
  end;

const
  CArtifactInputSchema =
    '{"type":"object","required":["artifactId"],' +
    '"properties":{"artifactId":{"type":"string"}},' +
    '"additionalProperties":false}';
  CRangeInputSchema =
    '{"type":"object","required":["artifactId","startCharacter"],' +
    '"properties":{"artifactId":{"type":"string"},' +
    '"startCharacter":{"type":"integer","minimum":0},' +
    '"maxCharacters":{"type":"integer","minimum":1,"maximum":65536}},' +
    '"additionalProperties":false}';
  COutputSchema = '{"type":"object"}';

constructor TRadIAAgentResultToolBase.Create(
  const AStore: IRadIAAgentResultStore
);
begin
  inherited Create;
  if not Assigned(AStore) then
    raise EArgumentNilException.Create('AStore');
  FStore := AStore;
end;

function TRadIAGetToolResultSummaryTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArtifact: TRadIAAgentResultArtifact;
  LArtifactId: string;
  LInput: TJSONObject;
  LResult: TJSONObject;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Invalid JSON object.'));
  try
    LArtifactId := LInput.GetValue<string>('artifactId', '');
    if not FStore.TryGetSummary(ARequest.SessionId, LArtifactId, LArtifact) then
      Exit(TRadIAToolResult.Failed(
        'result_artifact_not_found',
        'The requested tool result artifact was not found.'
      ));
    LResult := TJSONObject.Create;
    try
      LResult.AddPair('artifactId', LArtifact.ArtifactId);
      LResult.AddPair('hash', LArtifact.Hash);
      LResult.AddPair(
        'characterCount',
        TJSONNumber.Create(LArtifact.CharacterCount)
      );
      LResult.AddPair('stepIndex', TJSONNumber.Create(LArtifact.StepIndex));
      Result := TRadIAToolResult.Succeeded(LResult.ToJSON);
    finally
      LResult.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIAGetToolResultSummaryTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetToolResultSummary',
    '1.0.0',
    'Return metadata for a complete agent tool result artifact.',
    CArtifactInputSchema,
    COutputSchema,
    trReadOnly
  );
end;

function TRadIAGetToolResultRangeTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArtifactId: string;
  LContent: string;
  LInput: TJSONObject;
  LMaxCharacters: Integer;
  LResult: TJSONObject;
  LStartCharacter: Integer;
  LTotalCharacters: Integer;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Invalid JSON object.'));
  try
    LArtifactId := LInput.GetValue<string>('artifactId', '');
    LStartCharacter := LInput.GetValue<Integer>('startCharacter', 0);
    LMaxCharacters := LInput.GetValue<Integer>('maxCharacters', 8192);
    try
      if not FStore.TryReadRange(
        ARequest.SessionId,
        LArtifactId,
        LStartCharacter,
        LMaxCharacters,
        LContent,
        LTotalCharacters
      ) then
        Exit(TRadIAToolResult.Failed(
          'result_artifact_not_found',
          'The requested tool result artifact was not found.'
        ));
    except
      on E: EArgumentException do
        Exit(TRadIAToolResult.Failed('invalid_arguments', E.Message));
    end;
    LResult := TJSONObject.Create;
    try
      LResult.AddPair('artifactId', LArtifactId);
      LResult.AddPair(
        'startCharacter',
        TJSONNumber.Create(LStartCharacter)
      );
      LResult.AddPair(
        'returnedCharacters',
        TJSONNumber.Create(Length(LContent))
      );
      LResult.AddPair(
        'totalCharacters',
        TJSONNumber.Create(LTotalCharacters)
      );
      LResult.AddPair(
        'hasMore',
        TJSONBool.Create(
          LStartCharacter + Length(LContent) < LTotalCharacters
        )
      );
      LResult.AddPair('content', LContent);
      Result := TRadIAToolResult.Succeeded(LResult.ToJSON);
    finally
      LResult.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIAGetToolResultRangeTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetToolResultRange',
    '1.0.0',
    'Return a bounded range from a complete agent tool result artifact.',
    CRangeInputSchema,
    COutputSchema,
    trReadOnly
  );
end;

procedure RegisterRadIAAgentResultTools(
  const ARegistry: IRadIAToolRegistry;
  const AStore: IRadIAAgentResultStore
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AStore) then
    raise EArgumentNilException.Create('AStore');
  ARegistry.RegisterTool(TRadIAGetToolResultSummaryTool.Create(AStore));
  ARegistry.RegisterTool(TRadIAGetToolResultRangeTool.Create(AStore));
end;

end.
