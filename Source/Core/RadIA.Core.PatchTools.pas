unit RadIA.Core.PatchTools;

interface

uses
  RadIA.Core.Patches,
  RadIA.Core.Tools;

procedure RegisterRadIAPatchTools(
  const ARegistry: IRadIAToolRegistry;
  const APatchService: IRadIAPatchService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIAPatchToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FPatchService: IRadIAPatchService;
    function GetRequiredString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function PatchResultToToolResult(
      const AResult: TRadIAPatchResult
    ): TRadIAToolResult;
  public
    constructor Create(const APatchService: IRadIAPatchService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor;
      virtual; abstract;
  end;

  TRadIAPreparePatchTool = class(TRadIAPatchToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAApplyPatchTool = class(TRadIAPatchToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIARevertPatchTool = class(TRadIAPatchToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CPatchOutputSchema =
    '{"type":"object","required":["previewId","targetFile"],' +
    '"properties":{"previewId":{"type":"string"},' +
    '"targetFile":{"type":"string"}}}';
  CPreviewIdInputSchema =
    '{"type":"object","required":["previewId"],' +
    '"properties":{"previewId":{"type":"string"}},' +
    '"additionalProperties":false}';
  CPrepareInputSchema =
    '{"type":"object","required":["targetFile","baseRevision",' +
    '"originalText","replacementText"],"properties":{' +
    '"targetFile":{"type":"string"},"baseRevision":{"type":"string"},' +
    '"originalText":{"type":"string"},' +
    '"replacementText":{"type":"string"}},' +
    '"additionalProperties":false}';

{ TRadIAPatchToolBase }

constructor TRadIAPatchToolBase.Create(
  const APatchService: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  FPatchService := APatchService;
end;

function TRadIAPatchToolBase.GetRequiredString(
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

function TRadIAPatchToolBase.PatchResultToToolResult(
  const AResult: TRadIAPatchResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('targetFile', AResult.Preview.Spec.TargetFile);
    LJson.AddPair('baseRevision', AResult.Preview.Spec.BaseRevision);
    LJson.AddPair(
      'proposedRevision',
      AResult.Preview.ProposedRevision
    );
    LJson.AddPair(
      'originalContent',
      AResult.Preview.OriginalContent
    );
    LJson.AddPair(
      'proposedContent',
      AResult.Preview.ProposedContent
    );
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

{ TRadIAPreparePatchTool }

function TRadIAPreparePatchTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LSpec: TRadIAPatchSpec;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Patch arguments must be a valid JSON object.'
    ));
  try
    LSpec := TRadIAPatchSpec.Create(
      GetRequiredString(LJson, 'targetFile'),
      GetRequiredString(LJson, 'baseRevision'),
      GetRequiredString(LJson, 'originalText'),
      LJson.GetValue<string>('replacementText', '')
    );
    Result := PatchResultToToolResult(
      FPatchService.Prepare(LSpec)
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAPreparePatchTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PreparePatch',
    '1.0.0',
    'Prepares an immutable editor patch preview without changing the buffer.',
    CPrepareInputSchema,
    CPatchOutputSchema,
    trReadOnly
  );
end;

{ TRadIAApplyPatchTool }

function TRadIAApplyPatchTool.Execute(
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
      'Patch arguments must be a valid JSON object.'
    ));
  try
    Result := PatchResultToToolResult(
      FPatchService.Apply(
        GetRequiredString(LJson, 'previewId')
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAApplyPatchTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ApplyPatch',
    '1.0.0',
    'Applies a reviewed patch when the active buffer revision still matches.',
    CPreviewIdInputSchema,
    CPatchOutputSchema,
    trReversibleWrite
  );
end;

{ TRadIARevertPatchTool }

function TRadIARevertPatchTool.Execute(
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
      'Patch arguments must be a valid JSON object.'
    ));
  try
    Result := PatchResultToToolResult(
      FPatchService.Revert(
        GetRequiredString(LJson, 'previewId')
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIARevertPatchTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'RevertPatch',
    '1.0.0',
    'Reverts an applied patch when the buffer still matches its proposed revision.',
    CPreviewIdInputSchema,
    CPatchOutputSchema,
    trReversibleWrite
  );
end;

procedure RegisterRadIAPatchTools(
  const ARegistry: IRadIAToolRegistry;
  const APatchService: IRadIAPatchService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');

  ARegistry.RegisterTool(
    TRadIAPreparePatchTool.Create(APatchService)
  );
  ARegistry.RegisterTool(
    TRadIAApplyPatchTool.Create(APatchService)
  );
  ARegistry.RegisterTool(
    TRadIARevertPatchTool.Create(APatchService)
  );
end;

end.
