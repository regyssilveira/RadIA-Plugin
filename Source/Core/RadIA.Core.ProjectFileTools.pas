unit RadIA.Core.ProjectFileTools;

interface

uses
  RadIA.Core.ProjectFiles,
  RadIA.Core.Tools;

procedure RegisterRadIAProjectFileTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAProjectFileService
);

implementation

uses
  System.DateUtils,
  System.Hash,
  System.JSON,
  System.SysUtils;

type
  TRadIAProjectFileToolKind = (
    pftPrepareAdd,
    pftPrepareRemove,
    pftApply,
    pftRevert
  );

  TRadIAProjectFileTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIAProjectFileToolKind;
    FService: IRadIAProjectFileService;
    function GetRequiredString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function ParseFileKind(
      const AValue: string
    ): TRadIAProjectFileKind;
    function ResultToToolResult(
      const AResult: TRadIAProjectFileResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIAProjectFileToolKind;
      const AService: IRadIAProjectFileService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CAddInputSchema =
    '{"type":"object","required":["unitName","kind"],"properties":{' +
    '"unitName":{"type":"string"},"relativeDirectory":{"type":"string"},' +
    '"kind":{"type":"string","enum":["unit","vclForm","fmxForm"]}},' +
    '"additionalProperties":false}';
  CRemoveInputSchema =
    '{"type":"object","required":["fileName"],"properties":{' +
    '"fileName":{"type":"string"}},"additionalProperties":false}';
  CPreviewInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","operation","applied"],' +
    '"properties":{"previewId":{"type":"string"},' +
    '"operation":{"type":"string"},"applied":{"type":"boolean"},' +
    '"mainFileName":{"type":"string"},"files":{"type":"array"}}}';

constructor TRadIAProjectFileTool.Create(
  const AKind: TRadIAProjectFileToolKind;
  const AService: IRadIAProjectFileService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIAProjectFileTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LResult: TRadIAProjectFileResult;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Project file arguments must be a valid JSON object.'
    ));
  try
    case FKind of
      pftPrepareAdd:
        LResult := FService.PrepareAdd(
          GetRequiredString(LJson, 'unitName'),
          LJson.GetValue<string>('relativeDirectory', '.'),
          ParseFileKind(GetRequiredString(LJson, 'kind'))
        );
      pftPrepareRemove:
        LResult := FService.PrepareRemove(
          GetRequiredString(LJson, 'fileName')
        );
      pftApply:
        LResult := FService.Apply(
          GetRequiredString(LJson, 'previewId')
        );
    else
      LResult := FService.Revert(
        GetRequiredString(LJson, 'previewId')
      );
    end;
    Result := ResultToToolResult(LResult);
  finally
    LJson.Free;
  end;
end;

function TRadIAProjectFileTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    pftPrepareAdd:
      Result := TRadIAToolDescriptor.Create(
        'PrepareAddProjectFile',
        '1.0.0',
        'Previews deterministic unit or form files without writing.',
        CAddInputSchema,
        COutputSchema,
        trReadOnly
      );
    pftPrepareRemove:
      Result := TRadIAToolDescriptor.Create(
        'PrepareRemoveProjectFile',
        '1.0.0',
        'Previews unregistering a file without deleting it from disk.',
        CRemoveInputSchema,
        COutputSchema,
        trReadOnly
      );
    pftApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyProjectFileChange',
        '1.0.0',
        'Creates files before registration or unregisters without deletion.',
        CPreviewInputSchema,
        COutputSchema,
        trStructuralWrite
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'RevertProjectFileChange',
      '1.0.0',
      'Reverts the reviewed project file structure change.',
      CPreviewInputSchema,
      COutputSchema,
      trReversibleWrite
    );
  end;
end;

function TRadIAProjectFileTool.GetRequiredString(
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

function TRadIAProjectFileTool.ParseFileKind(
  const AValue: string
): TRadIAProjectFileKind;
begin
  if SameText(AValue, 'unit') then
    Exit(pfkUnit);
  if SameText(AValue, 'vclForm') then
    Exit(pfkVclForm);
  if SameText(AValue, 'fmxForm') then
    Exit(pfkFmxForm);
  raise EArgumentException.Create(
    'Argument "kind" contains an unsupported project file kind.'
  );
end;

function TRadIAProjectFileTool.ResultToToolResult(
  const AResult: TRadIAProjectFileResult
): TRadIAToolResult;
var
  LFile: TRadIAProjectFileContent;
  LFileJson: TJSONObject;
  LFiles: TJSONArray;
  LJson: TJSONObject;
  LOperation: string;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));
  if AResult.Preview.Operation = pfoAdd then
    LOperation := 'add'
  else
    LOperation := 'remove';
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('operation', LOperation);
    LJson.AddPair(
      'applied',
      TJSONBool.Create(AResult.Preview.Applied)
    );
    LJson.AddPair('mainFileName', AResult.Preview.MainFileName);
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    LFiles := TJSONArray.Create;
    LJson.AddPair('files', LFiles);
    for LFile in AResult.Preview.Files do
    begin
      LFileJson := TJSONObject.Create;
      LFileJson.AddPair('fileName', LFile.FileName);
      LFileJson.AddPair('content', LFile.Content);
      LFileJson.AddPair(
        'sha256',
        LowerCase(THashSHA2.GetHashString(LFile.Content))
      );
      LFiles.AddElement(LFileJson);
    end;
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure RegisterRadIAProjectFileTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAProjectFileService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  ARegistry.RegisterTool(
    TRadIAProjectFileTool.Create(pftPrepareAdd, AService)
  );
  ARegistry.RegisterTool(
    TRadIAProjectFileTool.Create(pftPrepareRemove, AService)
  );
  ARegistry.RegisterTool(
    TRadIAProjectFileTool.Create(pftApply, AService)
  );
  ARegistry.RegisterTool(
    TRadIAProjectFileTool.Create(pftRevert, AService)
  );
end;

end.
