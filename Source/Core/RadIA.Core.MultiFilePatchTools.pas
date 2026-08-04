unit RadIA.Core.MultiFilePatchTools;

interface

uses
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Tools;

procedure RegisterRadIAMultiFilePatchTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAMultiFilePatchService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIAMultiFilePatchToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FService: IRadIAMultiFilePatchService;
    function GetPreviewId(const AJson: TJSONObject): string;
    function ResultToToolResult(
      const AResult: TRadIAMultiFilePatchResult
    ): TRadIAToolResult;
  public
    constructor Create(const AService: IRadIAMultiFilePatchService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor;
      virtual; abstract;
  end;

  TRadIAPrepareMultiFilePatchTool = class(
    TRadIAMultiFilePatchToolBase
  )
  private
    function ParseSpecs(
      const AJson: TJSONObject
    ): TArray<TRadIAMultiFilePatchSpec>;
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAApplyMultiFilePatchTool = class(
    TRadIAMultiFilePatchToolBase
  )
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIARevertMultiFilePatchTool = class(
    TRadIAMultiFilePatchToolBase
  )
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CPreviewIdInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"}},"additionalProperties":false}';
  CPrepareInputSchema =
    '{"type":"object","required":["files"],"properties":{"files":{' +
    '"type":"array","minItems":1,"maxItems":32,"items":{' +
    '"type":"object","required":["targetFile","baseRevision",' +
    '"proposedContent"],"properties":{"targetFile":{"type":"string"},' +
    '"baseRevision":{"type":"string"},"proposedContent":{' +
    '"type":"string"}},"additionalProperties":false}}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","files"],' +
    '"properties":{"previewId":{"type":"string"},' +
    '"state":{"type":"string"},"files":{"type":"array"}}}';

{ TRadIAMultiFilePatchToolBase }

constructor TRadIAMultiFilePatchToolBase.Create(
  const AService: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAMultiFilePatchToolBase.GetPreviewId(
  const AJson: TJSONObject
): string;
begin
  Result := AJson.GetValue<string>('previewId', '');
  if Result = '' then
    raise EArgumentException.Create(
      'Argument "previewId" must not be empty.'
    );
end;

function TRadIAMultiFilePatchToolBase.ResultToToolResult(
  const AResult: TRadIAMultiFilePatchResult
): TRadIAToolResult;
var
  LEntry: TRadIAMultiFilePatchEntry;
  LEntryJson: TJSONObject;
  LFiles: TJSONArray;
  LJson: TJSONObject;
  LState: string;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));
  case AResult.Preview.State of
    mpsPrepared: LState := 'prepared';
    mpsApplied: LState := 'applied';
  else
    LState := 'reverted';
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('state', LState);
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    LFiles := TJSONArray.Create;
    LJson.AddPair('files', LFiles);
    for LEntry in AResult.Preview.Entries do
    begin
      LEntryJson := TJSONObject.Create;
      LEntryJson.AddPair('targetFile', LEntry.Spec.TargetFile);
      LEntryJson.AddPair(
        'baseRevision',
        LEntry.Spec.BaseRevision
      );
      LEntryJson.AddPair(
        'proposedRevision',
        LEntry.ProposedRevision
      );
      LEntryJson.AddPair(
        'originalContent',
        LEntry.OriginalContent
      );
      LEntryJson.AddPair(
        'proposedContent',
        LEntry.Spec.ProposedContent
      );
      LFiles.AddElement(LEntryJson);
    end;
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

{ TRadIAPrepareMultiFilePatchTool }

function TRadIAPrepareMultiFilePatchTool.Execute(
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
      'Multi-file patch arguments must be a valid JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Prepare(ParseSpecs(LJson))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAPrepareMultiFilePatchTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareMultiFilePatch',
    '1.0.0',
    'Prepares one immutable preview for a multi-buffer edit transaction.',
    CPrepareInputSchema,
    COutputSchema,
    trReadOnly
  );
end;

function TRadIAPrepareMultiFilePatchTool.ParseSpecs(
  const AJson: TJSONObject
): TArray<TRadIAMultiFilePatchSpec>;
var
  LArray: TJSONArray;
  LEntryJson: TJSONObject;
  LIndex: Integer;
begin
  LArray := AJson.GetValue<TJSONArray>('files');
  if not Assigned(LArray) then
    raise EArgumentException.Create(
      'Argument "files" must be an array.'
    );
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if not (LArray.Items[LIndex] is TJSONObject) then
      raise EArgumentException.Create(
        'Each multi-file patch entry must be an object.'
      );
    LEntryJson := TJSONObject(LArray.Items[LIndex]);
    Result[LIndex] := TRadIAMultiFilePatchSpec.Create(
      LEntryJson.GetValue<string>('targetFile', ''),
      LEntryJson.GetValue<string>('baseRevision', ''),
      LEntryJson.GetValue<string>('proposedContent', '')
    );
  end;
end;

{ TRadIAApplyMultiFilePatchTool }

function TRadIAApplyMultiFilePatchTool.Execute(
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
      'Multi-file patch arguments must be a valid JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Apply(GetPreviewId(LJson))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAApplyMultiFilePatchTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ApplyMultiFilePatch',
    '1.0.0',
    'Applies all reviewed buffer edits or compensates every partial write.',
    CPreviewIdInputSchema,
    COutputSchema,
    trReversibleWrite
  );
end;

{ TRadIARevertMultiFilePatchTool }

function TRadIARevertMultiFilePatchTool.Execute(
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
      'Multi-file patch arguments must be a valid JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Revert(GetPreviewId(LJson))
    );
  finally
    LJson.Free;
  end;
end;

function TRadIARevertMultiFilePatchTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'RevertMultiFilePatch',
    '1.0.0',
    'Reverts all applied buffer edits or restores the proposed transaction.',
    CPreviewIdInputSchema,
    COutputSchema,
    trReversibleWrite
  );
end;

procedure RegisterRadIAMultiFilePatchTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAMultiFilePatchService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  ARegistry.RegisterTool(
    TRadIAPrepareMultiFilePatchTool.Create(AService)
  );
  ARegistry.RegisterTool(
    TRadIAApplyMultiFilePatchTool.Create(AService)
  );
  ARegistry.RegisterTool(
    TRadIARevertMultiFilePatchTool.Create(AService)
  );
end;

end.
