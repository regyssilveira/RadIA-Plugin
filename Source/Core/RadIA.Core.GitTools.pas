unit RadIA.Core.GitTools;

interface

uses
  RadIA.Core.Git,
  RadIA.Core.Tools;

procedure RegisterRadIAGitTools(
  const ARegistry: IRadIAToolRegistry;
  const AGit: IRadIAGitFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAGitToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FGit: IRadIAGitFacade;
    function ToToolResult(
      const AResult: TRadIAGitResult
    ): TRadIAToolResult;
  public
    constructor Create(const AGit: IRadIAGitFacade);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor;
      virtual; abstract;
  end;

  TRadIAGetGitStatusTool = class(TRadIAGitToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAGetGitDiffTool = class(TRadIAGitToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAPreviewGitCommitTool = class(TRadIAGitToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIACommitChangesTool = class(TRadIAGitToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CEmptySchema = '{"type":"object","additionalProperties":false}';
  CPathsSchema =
    '{"type":"object","properties":{"paths":{"type":"array",' +
    '"items":{"type":"string","minLength":1},"maxItems":100}},' +
    '"additionalProperties":false}';
  CPreviewSchema =
    '{"type":"object","required":["paths","message"],"properties":{' +
    '"paths":{"type":"array","items":{"type":"string","minLength":1},' +
    '"minItems":1,"maxItems":100},"message":{"type":"string",' +
    '"minLength":1,"maxLength":500}},"additionalProperties":false}';
  CCommitSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":1}},' +
    '"additionalProperties":false}';
  CResultSchema = '{"type":"object"}';

function ReadPaths(const AJson: TJSONObject): TArray<string>;
var
  LArray: TJSONArray;
  LIndex: Integer;
begin
  SetLength(Result, 0);
  if not AJson.TryGetValue<TJSONArray>('paths', LArray) then
    Exit;
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
    Result[LIndex] := LArray[LIndex].Value;
end;

constructor TRadIAGitToolBase.Create(const AGit: IRadIAGitFacade);
begin
  inherited Create;
  if not Assigned(AGit) then
    raise EArgumentNilException.Create('AGit');
  FGit := AGit;
end;

function TRadIAGitToolBase.ToToolResult(
  const AResult: TRadIAGitResult
): TRadIAToolResult;
begin
  if AResult.Success then
    Result := TRadIAToolResult.Succeeded(AResult.ContentJson)
  else
    Result := TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    );
end;

function TRadIAGetGitStatusTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := ToToolResult(FGit.GetStatus);
end;

function TRadIAGetGitStatusTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetGitStatus',
    '1.0.0',
    'Return Git status scoped to the active Delphi project workspace.',
    CEmptySchema,
    CResultSchema,
    trReadOnly
  );
end;

function TRadIAGetGitDiffTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Git diff arguments must be a JSON object.'
    ));
  try
    Result := ToToolResult(FGit.GetDiff(ReadPaths(LJson)));
  finally
    LJson.Free;
  end;
end;

function TRadIAGetGitDiffTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetGitDiff',
    '1.0.0',
    'Return an unstaged Git diff for workspace-confined paths.',
    CPathsSchema,
    CResultSchema,
    trReadOnly
  );
end;

function TRadIAPreviewGitCommitTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LMessage: string;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Git preview arguments must be a JSON object.'
    ));
  try
    LMessage := LJson.GetValue<string>('message', '');
    Result := ToToolResult(
      FGit.PreviewCommit(ReadPaths(LJson), LMessage)
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAPreviewGitCommitTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PreviewGitCommit',
    '1.0.0',
    'Preview selected paths and freeze their fingerprint without staging.',
    CPreviewSchema,
    CResultSchema,
    trReadOnly
  );
end;

function TRadIACommitChangesTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Git commit arguments must be a JSON object.'
    ));
  try
    Result := ToToolResult(
      FGit.Commit(LJson.GetValue<string>('previewId', ''))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIACommitChangesTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'CommitChanges',
    '1.0.0',
    'Create the reviewed local Git commit without pushing.',
    CCommitSchema,
    CResultSchema,
    trStructuralWrite
  );
end;

procedure RegisterRadIAGitTools(
  const ARegistry: IRadIAToolRegistry;
  const AGit: IRadIAGitFacade
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AGit) then
    raise EArgumentNilException.Create('AGit');
  ARegistry.RegisterTool(TRadIAGetGitStatusTool.Create(AGit));
  ARegistry.RegisterTool(TRadIAGetGitDiffTool.Create(AGit));
  ARegistry.RegisterTool(TRadIAPreviewGitCommitTool.Create(AGit));
  ARegistry.RegisterTool(TRadIACommitChangesTool.Create(AGit));
end;

end.
