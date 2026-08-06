unit RadIA.Core.ProjectTemplateTools;

interface

uses
  RadIA.Core.Build,
  RadIA.Core.ProjectTemplateService,
  RadIA.Core.Tools;

procedure RegisterRadIAProjectTemplateTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAProjectTemplateService;
  const ABuildFacade: IRadIABuildFacade
);

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.ProjectTemplates,
  RadIA.Core.Workspace;

type
  TRadIAProjectTemplateToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FService: IRadIAProjectTemplateService;
    function GetRequiredString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function ResultToToolResult(
      const AResult: TRadIAProjectTemplateOperationResult
    ): TRadIAToolResult;
  public
    constructor Create(const AService: IRadIAProjectTemplateService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor;
      virtual; abstract;
  end;

  TRadIAPreviewProjectTemplateTool = class(
    TRadIAProjectTemplateToolBase
  )
  private
    function ParseKind(
      const AValue: string
    ): TRadIAProjectTemplateKind;
    function ParsePlatforms(
      const AJson: TJSONObject
    ): TArray<string>;
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIACommitProjectTemplateTool = class(
    TRadIAProjectTemplateToolBase
  )
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIARollbackProjectTemplateTool = class(
    TRadIAProjectTemplateToolBase
  )
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAOpenProjectTemplateTool = class(
    TRadIAProjectTemplateToolBase
  )
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAValidateCreatedProjectTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FService: IRadIAProjectTemplateService;
    FBuildFacade: IRadIABuildFacade;
    function ExecuteValidation(
      const APreviewId: string;
      const ATimeoutMs: Integer
    ): TRadIABuildResult;
    function RollbackAfterFailure(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    function StatusName(const AStatus: TRadIABuildStatus): string;
  public
    constructor Create(
      const AService: IRadIAProjectTemplateService;
      const ABuildFacade: IRadIABuildFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CPreviewIdInputSchema =
    '{"type":"object","required":["previewId"],' +
    '"properties":{"previewId":{"type":"string"}},' +
    '"additionalProperties":false}';
  CPreviewInputSchema =
    '{"type":"object","required":["projectName","template",' +
    '"delphiVersion","platforms","destinationPath"],"properties":{' +
    '"projectName":{"type":"string"},"template":{"type":"string",' +
    '"enum":["console","vcl","fmx","library","package","dunitx",' +
    '"service"]},' +
    '"delphiVersion":{"type":"string","enum":["23.0","37.0"]},' +
    '"platforms":{"type":"array","items":{"type":"string",' +
    '"enum":["Win32","Win64"]},"minItems":1},' +
    '"destinationPath":{"type":"string"}},"additionalProperties":false}';
  CProjectTemplateOutputSchema =
    '{"type":"object","required":["previewId","destinationPath",' +
    '"preview","committed","rolledBack"],"properties":{' +
    '"previewId":{"type":"string"},"destinationPath":{"type":"string"},' +
    '"preview":{"type":"object"},"committed":{"type":"boolean"},' +
    '"rolledBack":{"type":"boolean"},"opened":{"type":"boolean"},' +
    '"projectFileName":{"type":"string"}}}';
  CValidateInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"},"timeoutMs":{"type":"integer",' +
    '"minimum":1000,"maximum":600000}},"additionalProperties":false}';
  CValidateOutputSchema =
    '{"type":"object","required":["buildSucceeded","status",' +
    '"rolledBack"],"properties":{"buildSucceeded":{"type":"boolean"},' +
    '"status":{"type":"string"},"rolledBack":{"type":"boolean"},' +
    '"messages":{"type":"array","items":{"type":"string"}},' +
    '"errorCode":{"type":"string"},"errorMessage":{"type":"string"}}}';

{ TRadIAProjectTemplateToolBase }

constructor TRadIAProjectTemplateToolBase.Create(
  const AService: IRadIAProjectTemplateService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAProjectTemplateToolBase.GetRequiredString(
  const AJson: TJSONObject;
  const AName: string
): string;
begin
  Result := AJson.GetValue<string>(AName, '');
  if Result = '' then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must not be empty.',
      [AName]
    );
end;

function TRadIAProjectTemplateToolBase.ResultToToolResult(
  const AResult: TRadIAProjectTemplateOperationResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPreview: TJSONValue;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.PreviewId);
    LJson.AddPair('destinationPath', AResult.DestinationPath);
    LPreview := TJSONObject.ParseJSONValue(AResult.PreviewJson);
    if not Assigned(LPreview) then
      LPreview := TJSONObject.Create;
    LJson.AddPair('preview', LPreview);
    LJson.AddPair('committed', TJSONBool.Create(AResult.Committed));
    LJson.AddPair('rolledBack', TJSONBool.Create(AResult.RolledBack));
    LJson.AddPair('opened', TJSONBool.Create(AResult.Opened));
    LJson.AddPair('projectFileName', AResult.ProjectFileName);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

{ TRadIAOpenProjectTemplateTool }

function TRadIAOpenProjectTemplateTool.Execute(
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
      'Project template arguments must be a valid JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Open(GetRequiredString(LJson, 'previewId'))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAOpenProjectTemplateTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'OpenCreatedProject',
    '1.0.0',
    'Opens a committed generated project in the Delphi IDE.',
    CPreviewIdInputSchema,
    CProjectTemplateOutputSchema,
    trExecution
  );
end;

{ TRadIAValidateCreatedProjectTool }

constructor TRadIAValidateCreatedProjectTool.Create(
  const AService: IRadIAProjectTemplateService;
  const ABuildFacade: IRadIABuildFacade
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  if not Assigned(ABuildFacade) then
    raise EArgumentNilException.Create('ABuildFacade');
  FService := AService;
  FBuildFacade := ABuildFacade;
end;

function TRadIAValidateCreatedProjectTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LBuildResult: TRadIABuildResult;
  LJson: TJSONObject;
  LMessage: TRadIACompilerMessage;
  LMessages: TJSONArray;
  LPreviewId: string;
  LRequestJson: TJSONObject;
  LRollbackResult: TRadIAProjectTemplateOperationResult;
  LTimeoutMs: Integer;
begin
  LRequestJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LRequestJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Project validation arguments must be a valid JSON object.'
    ));
  try
    LPreviewId := LRequestJson.GetValue<string>('previewId', '');
    if LPreviewId = '' then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'Argument "previewId" must not be empty.'
      ));
    LTimeoutMs := LRequestJson.GetValue<Integer>('timeoutMs', 120000);
    if (LTimeoutMs < 1000) or (LTimeoutMs > 600000) then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'Build timeout must be between 1000 and 600000 ms.'
      ));

    LBuildResult := ExecuteValidation(LPreviewId, LTimeoutMs);

    LRollbackResult := Default(TRadIAProjectTemplateOperationResult);
    if not LBuildResult.Success then
      LRollbackResult := RollbackAfterFailure(LPreviewId);

    LJson := TJSONObject.Create;
    try
      LJson.AddPair(
        'buildSucceeded',
        TJSONBool.Create(LBuildResult.Success)
      );
      LJson.AddPair('status', StatusName(LBuildResult.Status));
      LJson.AddPair(
        'rolledBack',
        TJSONBool.Create(
          not LBuildResult.Success and LRollbackResult.Success
        )
      );
      LJson.AddPair('errorCode', LBuildResult.ErrorCode);
      LJson.AddPair('errorMessage', LBuildResult.ErrorMessage);
      LMessages := TJSONArray.Create;
      for LMessage in LBuildResult.Messages do
        LMessages.Add(LMessage.Text);
      LJson.AddPair('messages', LMessages);
      if not LBuildResult.Success and
        not LRollbackResult.Success then
      begin
        LJson.AddPair(
          'rollbackErrorCode',
          LRollbackResult.ErrorCode
        );
        LJson.AddPair(
          'rollbackErrorMessage',
          LRollbackResult.ErrorMessage
        );
      end;
      Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LRequestJson.Free;
  end;
end;

function TRadIAValidateCreatedProjectTool.ExecuteValidation(
  const APreviewId: string;
  const ATimeoutMs: Integer
): TRadIABuildResult;
var
  LOpenResult: TRadIAProjectTemplateOperationResult;
begin
  try
    LOpenResult := FService.Open(APreviewId);
  except
    on E: Exception do
      Exit(TRadIABuildResult.Failed(
        bsFailed,
        'project_open_exception',
        E.ClassName + ': ' + E.Message
      ));
  end;
  if not LOpenResult.Success then
    Exit(TRadIABuildResult.Failed(
      bsFailed,
      LOpenResult.ErrorCode,
      LOpenResult.ErrorMessage
    ));
  try
    Result := FBuildFacade.Execute(
      TRadIABuildRequest.Create(
        bmBuild,
        Cardinal(ATimeoutMs),
        True
      )
    );
  except
    on E: Exception do
      Result := TRadIABuildResult.Failed(
        bsFailed,
        'project_build_exception',
        E.ClassName + ': ' + E.Message
      );
  end;
end;

function TRadIAValidateCreatedProjectTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ValidateCreatedProject',
    '1.0.0',
    'Opens and builds a generated project, rolling it back on failure.',
    CValidateInputSchema,
    CValidateOutputSchema,
    trExecution
  ).WithExecutionOptions(600000, False);
end;

function TRadIAValidateCreatedProjectTool.RollbackAfterFailure(
  const APreviewId: string
): TRadIAProjectTemplateOperationResult;
begin
  try
    Result := FService.Rollback(APreviewId);
  except
    on E: Exception do
      Result := TRadIAProjectTemplateOperationResult.Failed(
        'project_rollback_exception',
        E.ClassName + ': ' + E.Message
      );
  end;
end;

function TRadIAValidateCreatedProjectTool.StatusName(
  const AStatus: TRadIABuildStatus
): string;
begin
  case AStatus of
    bsIdle: Result := 'idle';
    bsRunning: Result := 'running';
    bsSucceeded: Result := 'succeeded';
    bsCancelled: Result := 'cancelled';
    bsTimedOut: Result := 'timedOut';
    bsUnsupported: Result := 'unsupported';
  else
    Result := 'failed';
  end;
end;

{ TRadIAPreviewProjectTemplateTool }

function TRadIAPreviewProjectTemplateTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LRequest: TRadIAProjectTemplateRequest;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Project template arguments must be a valid JSON object.'
    ));
  try
    LRequest := TRadIAProjectTemplateRequest.Create(
      GetRequiredString(LJson, 'projectName'),
      ParseKind(GetRequiredString(LJson, 'template')),
      GetRequiredString(LJson, 'delphiVersion'),
      ParsePlatforms(LJson)
    );
    Result := ResultToToolResult(
      FService.Preview(
        LRequest,
        GetRequiredString(LJson, 'destinationPath')
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAPreviewProjectTemplateTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PreviewProjectTemplate',
    '1.0.0',
    'Previews deterministic project files without changing the workspace.',
    CPreviewInputSchema,
    CProjectTemplateOutputSchema,
    trReadOnly
  );
end;

function TRadIAPreviewProjectTemplateTool.ParseKind(
  const AValue: string
): TRadIAProjectTemplateKind;
begin
  if SameText(AValue, 'console') then
    Exit(ptkConsole);
  if SameText(AValue, 'vcl') then
    Exit(ptkVcl);
  if SameText(AValue, 'fmx') then
    Exit(ptkFmx);
  if SameText(AValue, 'library') then
    Exit(ptkLibrary);
  if SameText(AValue, 'package') then
    Exit(ptkPackage);
  if SameText(AValue, 'dunitx') then
    Exit(ptkDUnitX);
  if SameText(AValue, 'service') then
    Exit(ptkService);
  raise EArgumentException.Create(
    'Argument "template" contains an unsupported template kind.'
  );
end;

function TRadIAPreviewProjectTemplateTool.ParsePlatforms(
  const AJson: TJSONObject
): TArray<string>;
var
  LArray: TJSONArray;
  LIndex: Integer;
begin
  LArray := AJson.GetValue<TJSONArray>('platforms');
  if not Assigned(LArray) or (LArray.Count = 0) then
    raise EArgumentException.Create(
      'Argument "platforms" must contain at least one platform.'
    );
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if not (LArray[LIndex] is TJSONString) then
      raise EArgumentException.Create(
        'Argument "platforms" must contain only strings.'
      );
    Result[LIndex] := LArray[LIndex].Value;
  end;
end;

{ TRadIACommitProjectTemplateTool }

function TRadIACommitProjectTemplateTool.Execute(
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
      'Project template arguments must be a valid JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Commit(GetRequiredString(LJson, 'previewId'))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIACommitProjectTemplateTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'CreateProjectFromTemplate',
    '1.0.0',
    'Creates the reviewed project atomically from an immutable preview.',
    CPreviewIdInputSchema,
    CProjectTemplateOutputSchema,
    trStructuralWrite
  );
end;

{ TRadIARollbackProjectTemplateTool }

function TRadIARollbackProjectTemplateTool.Execute(
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
      'Project template arguments must be a valid JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Rollback(GetRequiredString(LJson, 'previewId'))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIARollbackProjectTemplateTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'RevertCreatedProject',
    '1.0.0',
    'Removes a project previously created from the same reviewed preview.',
    CPreviewIdInputSchema,
    CProjectTemplateOutputSchema,
    trReversibleWrite
  );
end;

procedure RegisterRadIAProjectTemplateTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAProjectTemplateService;
  const ABuildFacade: IRadIABuildFacade
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  if not Assigned(ABuildFacade) then
    raise EArgumentNilException.Create('ABuildFacade');
  ARegistry.RegisterTool(
    TRadIAPreviewProjectTemplateTool.Create(AService)
  );
  ARegistry.RegisterTool(
    TRadIACommitProjectTemplateTool.Create(AService)
  );
  ARegistry.RegisterTool(
    TRadIARollbackProjectTemplateTool.Create(AService)
  );
  ARegistry.RegisterTool(
    TRadIAOpenProjectTemplateTool.Create(AService)
  );
  ARegistry.RegisterTool(
    TRadIAValidateCreatedProjectTool.Create(
      AService,
      ABuildFacade
    )
  );
end;

end.
