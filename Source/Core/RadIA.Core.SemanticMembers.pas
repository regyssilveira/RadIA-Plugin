unit RadIA.Core.SemanticMembers;

interface

uses
  RadIA.Core.DelphiEnvironment,
  RadIA.Core.Patches,
  RadIA.Semantic.Workspace;

type
  TRadIASemanticMemberPreviewResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FChanged: Boolean;
    FMissingCount: Integer;
    FPatchResult: TRadIAPatchResult;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIASemanticMemberPreviewResult; static;
    class function Succeeded(
      const AMissingCount: Integer;
      const APatchResult: TRadIAPatchResult
    ): TRadIASemanticMemberPreviewResult; static;
    class function Unchanged: TRadIASemanticMemberPreviewResult; static;
    property Changed: Boolean read FChanged;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property MissingCount: Integer read FMissingCount;
    property PatchResult: TRadIAPatchResult read FPatchResult;
    property Success: Boolean read FSuccess;
  end;

  IRadIASemanticMemberService = interface
    ['{42FF83E8-5193-463A-8E79-EAE5AFC93249}']
    function PrepareMissingMembers(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AContainerName: string
    ): TRadIASemanticMemberPreviewResult;
  end;

  TRadIASemanticMemberService = class(
    TInterfacedObject,
    IRadIASemanticMemberService
  )
  private
    FClient: IRadIASemanticRequestClient;
    FEnvironment: IRadIADelphiEnvironmentService;
    FPatchService: IRadIAPatchService;
    FMutation: IRadIAEditorMutationFacade;
    function BuildParameters(
      const ASource: string;
      const AContainerName: string;
      const ADefines: TArray<string>
    ): string;
  public
    constructor Create(
      const AClient: IRadIASemanticRequestClient;
      const AEnvironment: IRadIADelphiEnvironmentService;
      const AMutation: IRadIAEditorMutationFacade;
      const APatchService: IRadIAPatchService
    );
    function PrepareMissingMembers(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AContainerName: string
    ): TRadIASemanticMemberPreviewResult;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.Workspace;

const
  CMaximumSemanticSourceCharacters = 2 * 1024 * 1024;

{ TRadIASemanticMemberPreviewResult }

class function TRadIASemanticMemberPreviewResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIASemanticMemberPreviewResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIASemanticMemberPreviewResult.Succeeded(
  const AMissingCount: Integer;
  const APatchResult: TRadIAPatchResult
): TRadIASemanticMemberPreviewResult;
begin
  Result.FSuccess := True;
  Result.FChanged := True;
  Result.FMissingCount := AMissingCount;
  Result.FPatchResult := APatchResult;
end;

class function TRadIASemanticMemberPreviewResult.Unchanged:
  TRadIASemanticMemberPreviewResult;
begin
  Result.FSuccess := True;
  Result.FChanged := False;
  Result.FMissingCount := 0;
end;

{ TRadIASemanticMemberService }

constructor TRadIASemanticMemberService.Create(
  const AClient: IRadIASemanticRequestClient;
  const AEnvironment: IRadIADelphiEnvironmentService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatchService: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient');
  if not Assigned(AEnvironment) then
    raise EArgumentNilException.Create('AEnvironment');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  FClient := AClient;
  FEnvironment := AEnvironment;
  FMutation := AMutation;
  FPatchService := APatchService;
end;

function TRadIASemanticMemberService.BuildParameters(
  const ASource: string;
  const AContainerName: string;
  const ADefines: TArray<string>
): string;
var
  LDefine: string;
  LDefines: TJSONArray;
  LParameters: TJSONObject;
begin
  LParameters := TJSONObject.Create;
  try
    LParameters.AddPair('source', ASource);
    LParameters.AddPair('container', AContainerName);
    LDefines := TJSONArray.Create;
    for LDefine in ADefines do
      LDefines.Add(LDefine);
    LParameters.AddPair('defines', LDefines);
    Result := LParameters.ToJSON;
  finally
    LParameters.Free;
  end;
end;

function TRadIASemanticMemberService.PrepareMissingMembers(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AContainerName: string
): TRadIASemanticMemberPreviewResult;
var
  LDocument: TJSONObject;
  LError: string;
  LMissingCount: Integer;
  LPatchResult: TRadIAPatchResult;
  LProfile: TRadIADelphiEnvironmentProfile;
  LProposedSource: string;
  LResponse: string;
  LResult: TJSONObject;
  LSnapshot: TRadIAEditorContent;
begin
  LSnapshot := FMutation.ReadContent(
    ATargetFile,
    CMaximumSemanticSourceCharacters
  );
  if LSnapshot.Truncated then
    Exit(TRadIASemanticMemberPreviewResult.Failed(
      'resource_limit',
      'The target source exceeds the semantic mutation limit.'
    ));
  if not SameText(LSnapshot.Revision, ABaseRevision) then
    Exit(TRadIASemanticMemberPreviewResult.Failed(
      'precondition_failed',
      'The editor buffer revision does not match the request.'
    ));
  LProfile := FEnvironment.BuildProfile;
  if not FClient.Request(
    'prepareMissingMembers',
    BuildParameters(LSnapshot.Content, AContainerName, LProfile.Defines),
    LResponse,
    LError
  ) then
    Exit(TRadIASemanticMemberPreviewResult.Failed(
      'semantic_engine_unavailable',
      LError
    ));
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    if not Assigned(LDocument) then
      Exit(TRadIASemanticMemberPreviewResult.Failed(
        'invalid_semantic_response',
        'The semantic engine returned invalid JSON.'
      ));
    LResult := LDocument.GetValue<TJSONObject>('result');
    if not Assigned(LResult) then
      Exit(TRadIASemanticMemberPreviewResult.Failed(
        'semantic_engine_error',
        'The semantic engine did not return a preview.'
      ));
    LError := LResult.GetValue<string>('errorMessage', '');
    if LError <> '' then
      Exit(TRadIASemanticMemberPreviewResult.Failed(
        'semantic_preview_failed',
        LError
      ));
    LMissingCount := LResult.GetValue<Integer>('missingCount', 0);
    if not LResult.GetValue<Boolean>('changed', False) then
      Exit(TRadIASemanticMemberPreviewResult.Unchanged);
    LProposedSource := LResult.GetValue<string>('proposedSource', '');
    LPatchResult := FPatchService.Prepare(
      TRadIAPatchSpec.Create(
        ATargetFile,
        ABaseRevision,
        LSnapshot.Content,
        LProposedSource
      )
    );
    if not LPatchResult.Success then
      Exit(TRadIASemanticMemberPreviewResult.Failed(
        LPatchResult.ErrorCode,
        LPatchResult.ErrorMessage
      ));
    Result := TRadIASemanticMemberPreviewResult.Succeeded(
      LMissingCount,
      LPatchResult
    );
  finally
    LDocument.Free;
  end;
end;

end.
