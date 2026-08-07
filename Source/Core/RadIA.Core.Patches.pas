unit RadIA.Core.Patches;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAPatchSpec = record
  private
    FTargetFile: string;
    FBaseRevision: string;
    FOriginalText: string;
    FReplacementText: string;
  public
    constructor Create(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AOriginalText: string;
      const AReplacementText: string
    );
    property TargetFile: string read FTargetFile;
    property BaseRevision: string read FBaseRevision;
    property OriginalText: string read FOriginalText;
    property ReplacementText: string read FReplacementText;
  end;

  TRadIAPatchPreview = record
  private
    FId: string;
    FSpec: TRadIAPatchSpec;
    FOriginalContent: string;
    FProposedContent: string;
    FProposedRevision: string;
    FExpiresAtUtc: TDateTime;
  public
    constructor Create(
      const AId: string;
      const ASpec: TRadIAPatchSpec;
      const AOriginalContent: string;
      const AProposedContent: string;
      const AProposedRevision: string;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property Spec: TRadIAPatchSpec read FSpec;
    property OriginalContent: string read FOriginalContent;
    property ProposedContent: string read FProposedContent;
    property ProposedRevision: string read FProposedRevision;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAPatchResult = record
  private
    FSuccess: Boolean;
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAPatchPreview;
  public
    class function Succeeded(
      const APreview: TRadIAPatchPreview
    ): TRadIAPatchResult; static;
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAPatchResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAPatchPreview read FPreview;
  end;

  IRadIAEditorMutationFacade = interface
    ['{542F56BD-100D-4D20-9D3A-538BAE14BB56}']
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
  end;

  IRadIAEditorPersistenceFacade = interface
    ['{8F34CC93-37C1-4A48-820F-9072C350E2D4}']
    function ReloadFile(const AFileName: string): Boolean;
  end;

  IRadIAPatchService = interface
    ['{133C31E5-AF60-497D-838D-F35852ED8CBA}']
    function Prepare(
      const ASpec: TRadIAPatchSpec
    ): TRadIAPatchResult;
    function Apply(const APreviewId: string): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
  end;

  TRadIAPatchService = class(
    TInterfacedObject,
    IRadIAPatchService
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FMutation: IRadIAEditorMutationFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    FPreviews: TDictionary<string, TRadIAPatchPreview>;
    FExpirationMinutes: Integer;
    function BuildProposedContent(
      const AContent: string;
      const ASpec: TRadIAPatchSpec;
      out AProposedContent: string
    ): TRadIAPatchResult;
    function CheckBoundary(
      const AFileName: string
    ): TRadIAPatchResult;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAPatchPreview
    ): TRadIAPatchResult;
    procedure RemoveExpiredPreviews;
    function ValidateSnapshot(
      const ASpec: TRadIAPatchSpec;
      const ASnapshot: TRadIAEditorContent
    ): TRadIAPatchResult;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const ASpec: TRadIAPatchSpec
    ): TRadIAPatchResult;
    function Apply(const APreviewId: string): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
  end;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.SysUtils;

const
  CInvalidPatch = 'invalid_patch';
  CAmbiguousOriginal = 'ambiguous_original';
  COriginalNotFound = 'original_not_found';
  CPreconditionFailed = 'precondition_failed';
  CPreviewExpired = 'preview_expired';
  CPreviewNotFound = 'preview_not_found';
  CApplyFailed = 'apply_failed';
  CResourceLimit = 'resource_limit';
  CMaxPatchCharacters = 2 * 1024 * 1024;
  CMaxPatchPreviews = 64;

{ TRadIAPatchSpec }

constructor TRadIAPatchSpec.Create(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AOriginalText: string;
  const AReplacementText: string
);
begin
  FTargetFile := ATargetFile;
  FBaseRevision := ABaseRevision;
  FOriginalText := AOriginalText;
  FReplacementText := AReplacementText;
end;

{ TRadIAPatchPreview }

constructor TRadIAPatchPreview.Create(
  const AId: string;
  const ASpec: TRadIAPatchSpec;
  const AOriginalContent: string;
  const AProposedContent: string;
  const AProposedRevision: string;
  const AExpiresAtUtc: TDateTime
);
begin
  FId := AId;
  FSpec := ASpec;
  FOriginalContent := AOriginalContent;
  FProposedContent := AProposedContent;
  FProposedRevision := AProposedRevision;
  FExpiresAtUtc := AExpiresAtUtc;
end;

{ TRadIAPatchResult }

class function TRadIAPatchResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAPatchResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
  Result.FPreview := Default(TRadIAPatchPreview);
end;

class function TRadIAPatchResult.Succeeded(
  const APreview: TRadIAPatchPreview
): TRadIAPatchResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FPreview := APreview;
end;

{ TRadIAPatchService }

function TRadIAPatchService.Apply(
  const APreviewId: string
): TRadIAPatchResult;
var
  LAppliedRevision: string;
  LPreview: TRadIAPatchPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;
  Result := CheckBoundary(LPreview.Spec.TargetFile);
  if not Result.Success then
    Exit;

  if not FMutation.ApplyContent(
    LPreview.Spec.TargetFile,
    LPreview.Spec.BaseRevision,
    LPreview.ProposedContent,
    LAppliedRevision
  ) then
  begin
    if SameText(
      LAppliedRevision,
      LPreview.Spec.BaseRevision
    ) then
      Exit(TRadIAPatchResult.Failed(
        CApplyFailed,
        'The editor rejected the proposed content.'
      ));
    Exit(TRadIAPatchResult.Failed(
      CPreconditionFailed,
      'The editor buffer changed after the patch preview.'
    ));
  end;

  if not SameText(LAppliedRevision, LPreview.ProposedRevision) then
    Exit(TRadIAPatchResult.Failed(
      CApplyFailed,
      'The applied editor revision does not match the preview.'
    ));
  Result := TRadIAPatchResult.Succeeded(LPreview);
end;

function TRadIAPatchService.BuildProposedContent(
  const AContent: string;
  const ASpec: TRadIAPatchSpec;
  out AProposedContent: string
): TRadIAPatchResult;
var
  LFirstPosition: Integer;
  LNextPosition: Integer;
begin
  AProposedContent := '';
  if ASpec.OriginalText = '' then
    Exit(TRadIAPatchResult.Failed(
      CInvalidPatch,
      'Original text must not be empty.'
    ));

  LFirstPosition := Pos(ASpec.OriginalText, AContent);
  if LFirstPosition = 0 then
    Exit(TRadIAPatchResult.Failed(
      COriginalNotFound,
      'Original text was not found in the editor buffer.'
    ));

  LNextPosition := Pos(
    ASpec.OriginalText,
    AContent,
    LFirstPosition + Length(ASpec.OriginalText)
  );
  if LNextPosition > 0 then
    Exit(TRadIAPatchResult.Failed(
      CAmbiguousOriginal,
      'Original text occurs more than once in the editor buffer.'
    ));

  AProposedContent :=
    Copy(AContent, Low(AContent), LFirstPosition - 1) +
    ASpec.ReplacementText +
    Copy(
      AContent,
      LFirstPosition + Length(ASpec.OriginalText),
      MaxInt
    );
  Result := TRadIAPatchResult.Succeeded(
    Default(TRadIAPatchPreview)
  );
end;

function TRadIAPatchService.CheckBoundary(
  const AFileName: string
): TRadIAPatchResult;
var
  LPathValidation: TRadIAPathValidation;
  LProject: TRadIAProjectSnapshot;
begin
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath = '' then
    Exit(TRadIAPatchResult.Failed(
      CPreconditionFailed,
      'No active project is available.'
    ));

  LPathValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    AFileName
  );
  if not LPathValidation.Allowed then
    Exit(TRadIAPatchResult.Failed(
      LPathValidation.ErrorCode,
      LPathValidation.ErrorMessage
    ));
  Result := TRadIAPatchResult.Succeeded(
    Default(TRadIAPatchPreview)
  );
end;

procedure TRadIAPatchService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAPatchService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AExpirationMinutes: Integer
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if AExpirationMinutes <= 0 then
    raise EArgumentOutOfRangeException.Create('AExpirationMinutes');

  FWorkspace := AWorkspace;
  FMutation := AMutation;
  FBoundary := ABoundary;
  FExpirationMinutes := AExpirationMinutes;
  FPreviews := TDictionary<string, TRadIAPatchPreview>.Create;
end;

destructor TRadIAPatchService.Destroy;
begin
  FPreviews.Free;
  inherited;
end;

function TRadIAPatchService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAPatchPreview
): TRadIAPatchResult;
begin
  APreview := Default(TRadIAPatchPreview);
  TMonitor.Enter(FPreviews);
  try
    if not FPreviews.TryGetValue(APreviewId, APreview) then
      Exit(TRadIAPatchResult.Failed(
        CPreviewNotFound,
        'Patch preview was not found.'
      ));
    if TTimeZone.Local.ToUniversalTime(Now) >
      APreview.ExpiresAtUtc then
    begin
      FPreviews.Remove(APreviewId);
      Exit(TRadIAPatchResult.Failed(
        CPreviewExpired,
        'Patch preview expired.'
      ));
    end;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAPatchResult.Succeeded(APreview);
end;

function TRadIAPatchService.Prepare(
  const ASpec: TRadIAPatchSpec
): TRadIAPatchResult;
var
  LPreview: TRadIAPatchPreview;
  LProposedContent: string;
  LSnapshot: TRadIAEditorContent;
begin
  RemoveExpiredPreviews;
  if Length(ASpec.OriginalText) > CMaxPatchCharacters then
    Exit(TRadIAPatchResult.Failed(
      CResourceLimit,
      'Original text exceeds the patch size limit.'
    ));
  if Length(ASpec.ReplacementText) > CMaxPatchCharacters then
    Exit(TRadIAPatchResult.Failed(
      CResourceLimit,
      'Replacement text exceeds the patch size limit.'
    ));
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPatchPreviews then
      Exit(TRadIAPatchResult.Failed(
        CResourceLimit,
        'Too many patch previews are active.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;

  Result := CheckBoundary(ASpec.TargetFile);
  if not Result.Success then
    Exit;

  LSnapshot := FMutation.ReadContent(ASpec.TargetFile, -1);
  if LSnapshot.OriginalLength > CMaxPatchCharacters then
    Exit(TRadIAPatchResult.Failed(
      CResourceLimit,
      'Editor content exceeds the patch size limit.'
    ));
  Result := ValidateSnapshot(ASpec, LSnapshot);
  if not Result.Success then
    Exit;

  Result := BuildProposedContent(
    LSnapshot.Content,
    ASpec,
    LProposedContent
  );
  if not Result.Success then
    Exit;

  LPreview := TRadIAPatchPreview.Create(
    TGUID.NewGuid.ToString,
    ASpec,
    LSnapshot.Content,
    LProposedContent,
    THashSHA2.GetHashString(LProposedContent),
    IncMinute(
      TTimeZone.Local.ToUniversalTime(Now),
      FExpirationMinutes
    )
  );
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Add(LPreview.Id, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAPatchResult.Succeeded(LPreview);
end;

procedure TRadIAPatchService.RemoveExpiredPreviews;
var
  LExpiredIds: TList<string>;
  LId: string;
  LPair: TPair<string, TRadIAPatchPreview>;
  LUtcNow: TDateTime;
begin
  LExpiredIds := TList<string>.Create;
  try
    LUtcNow := TTimeZone.Local.ToUniversalTime(Now);
    TMonitor.Enter(FPreviews);
    try
      for LPair in FPreviews do
      begin
        if LUtcNow > LPair.Value.ExpiresAtUtc then
          LExpiredIds.Add(LPair.Key);
      end;
      for LId in LExpiredIds do
        FPreviews.Remove(LId);
    finally
      TMonitor.Exit(FPreviews);
    end;
  finally
    LExpiredIds.Free;
  end;
end;

function TRadIAPatchService.Revert(
  const APreviewId: string
): TRadIAPatchResult;
var
  LAppliedRevision: string;
  LPreview: TRadIAPatchPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;
  Result := CheckBoundary(LPreview.Spec.TargetFile);
  if not Result.Success then
    Exit;

  if not FMutation.ApplyContent(
    LPreview.Spec.TargetFile,
    LPreview.ProposedRevision,
    LPreview.OriginalContent,
    LAppliedRevision
  ) then
  begin
    if SameText(
      LAppliedRevision,
      LPreview.ProposedRevision
    ) then
      Exit(TRadIAPatchResult.Failed(
        CApplyFailed,
        'The editor rejected the original content.'
      ));
    Exit(TRadIAPatchResult.Failed(
      CPreconditionFailed,
      'The editor buffer changed after the patch was applied.'
    ));
  end;

  if not SameText(
    LAppliedRevision,
    LPreview.Spec.BaseRevision
  ) then
    Exit(TRadIAPatchResult.Failed(
      CApplyFailed,
      'The reverted editor revision does not match the original.'
    ));
  Result := TRadIAPatchResult.Succeeded(LPreview);
end;

function TRadIAPatchService.ValidateSnapshot(
  const ASpec: TRadIAPatchSpec;
  const ASnapshot: TRadIAEditorContent
): TRadIAPatchResult;
begin
  if not SameFileName(ASnapshot.FileName, ASpec.TargetFile) then
    Exit(TRadIAPatchResult.Failed(
      CPreconditionFailed,
      'The target file is not the active editor buffer.'
    ));
  if ASnapshot.Truncated then
    Exit(TRadIAPatchResult.Failed(
      CPreconditionFailed,
      'A patch cannot be prepared from truncated content.'
    ));
  if not SameText(ASnapshot.Revision, ASpec.BaseRevision) then
    Exit(TRadIAPatchResult.Failed(
      CPreconditionFailed,
      'The editor revision differs from the requested base revision.'
    ));
  Result := TRadIAPatchResult.Succeeded(
    Default(TRadIAPatchPreview)
  );
end;

end.
