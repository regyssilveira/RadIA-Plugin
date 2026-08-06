unit RadIA.Core.MultiFilePatches;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Patches,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAMultiFilePatchState = (
    mpsPrepared,
    mpsApplied,
    mpsReverted
  );

  TRadIAMultiFilePatchSpec = record
  private
    FTargetFile: string;
    FBaseRevision: string;
    FProposedContent: string;
  public
    constructor Create(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AProposedContent: string
    );
    property TargetFile: string read FTargetFile;
    property BaseRevision: string read FBaseRevision;
    property ProposedContent: string read FProposedContent;
  end;

  TRadIAMultiFilePatchEntry = record
  private
    FSpec: TRadIAMultiFilePatchSpec;
    FOriginalContent: string;
    FProposedRevision: string;
  public
    constructor Create(
      const ASpec: TRadIAMultiFilePatchSpec;
      const AOriginalContent: string;
      const AProposedRevision: string
    );
    property Spec: TRadIAMultiFilePatchSpec read FSpec;
    property OriginalContent: string read FOriginalContent;
    property ProposedRevision: string read FProposedRevision;
  end;

  TRadIAMultiFilePatchPreview = class
  private
    FId: string;
    FEntries: TArray<TRadIAMultiFilePatchEntry>;
    FState: TRadIAMultiFilePatchState;
    FExpiresAtUtc: TDateTime;
  public
    constructor Create(
      const AId: string;
      const AEntries: TArray<TRadIAMultiFilePatchEntry>;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property Entries: TArray<TRadIAMultiFilePatchEntry> read FEntries;
    property State: TRadIAMultiFilePatchState read FState write FState;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAMultiFilePatchResult = record
  private
    FSuccess: Boolean;
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAMultiFilePatchPreview;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAMultiFilePatchResult; static;
    class function Succeeded(
      const APreview: TRadIAMultiFilePatchPreview
    ): TRadIAMultiFilePatchResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAMultiFilePatchPreview read FPreview;
  end;

  IRadIAMultiFilePatchService = interface
    ['{9FC10F7A-F00C-44C5-8ED6-058D6D986066}']
    function Prepare(
      const ASpecs: TArray<TRadIAMultiFilePatchSpec>
    ): TRadIAMultiFilePatchResult;
    function Apply(
      const APreviewId: string
    ): TRadIAMultiFilePatchResult;
    function Revert(
      const APreviewId: string
    ): TRadIAMultiFilePatchResult;
    procedure Clear;
  end;

  TRadIAMultiFilePatchService = class(
    TInterfacedObject,
    IRadIAMultiFilePatchService
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FMutation: IRadIAEditorMutationFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    FPreviews: TObjectDictionary<string, TRadIAMultiFilePatchPreview>;
    FExpirationMinutes: Integer;
    function ApplyEntries(
      const APreview: TRadIAMultiFilePatchPreview;
      const AForward: Boolean
    ): TRadIAMultiFilePatchResult;
    function BuildEntries(
      const ASpecs: TArray<TRadIAMultiFilePatchSpec>;
      out AEntries: TArray<TRadIAMultiFilePatchEntry>
    ): TRadIAMultiFilePatchResult;
    function Compensate(
      const AEntries: TArray<TRadIAMultiFilePatchEntry>;
      const ALastAppliedIndex: Integer;
      const AForward: Boolean
    ): Boolean;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAMultiFilePatchPreview
    ): TRadIAMultiFilePatchResult;
    function Preflight(
      const APreview: TRadIAMultiFilePatchPreview;
      const AForward: Boolean
    ): TRadIAMultiFilePatchResult;
    function ValidateSpec(
      const ASpec: TRadIAMultiFilePatchSpec;
      const ASeenFiles: TDictionary<string, Boolean>;
      out AEntry: TRadIAMultiFilePatchEntry
    ): TRadIAMultiFilePatchResult;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const ASpecs: TArray<TRadIAMultiFilePatchSpec>
    ): TRadIAMultiFilePatchResult;
    function Apply(
      const APreviewId: string
    ): TRadIAMultiFilePatchResult;
    function Revert(
      const APreviewId: string
    ): TRadIAMultiFilePatchResult;
    procedure Clear;
  end;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.SysUtils;

const
  CApplyFailed = 'apply_failed';
  CCompensationFailed = 'compensation_failed';
  CInvalidPatch = 'invalid_patch';
  CPreconditionFailed = 'precondition_failed';
  CPreviewExpired = 'preview_expired';
  CPreviewNotFound = 'preview_not_found';
  CResourceLimit = 'resource_limit';
  CMaxFiles = 32;
  CMaxFileCharacters = 2 * 1024 * 1024;
  CMaxPreviews = 16;

{ TRadIAMultiFilePatchSpec }

constructor TRadIAMultiFilePatchSpec.Create(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AProposedContent: string
);
begin
  FTargetFile := ATargetFile;
  FBaseRevision := ABaseRevision;
  FProposedContent := AProposedContent;
end;

{ TRadIAMultiFilePatchEntry }

constructor TRadIAMultiFilePatchEntry.Create(
  const ASpec: TRadIAMultiFilePatchSpec;
  const AOriginalContent: string;
  const AProposedRevision: string
);
begin
  FSpec := ASpec;
  FOriginalContent := AOriginalContent;
  FProposedRevision := AProposedRevision;
end;

{ TRadIAMultiFilePatchPreview }

constructor TRadIAMultiFilePatchPreview.Create(
  const AId: string;
  const AEntries: TArray<TRadIAMultiFilePatchEntry>;
  const AExpiresAtUtc: TDateTime
);
begin
  inherited Create;
  FId := AId;
  FEntries := Copy(AEntries);
  FState := mpsPrepared;
  FExpiresAtUtc := AExpiresAtUtc;
end;

{ TRadIAMultiFilePatchResult }

class function TRadIAMultiFilePatchResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAMultiFilePatchResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIAMultiFilePatchResult.Succeeded(
  const APreview: TRadIAMultiFilePatchPreview
): TRadIAMultiFilePatchResult;
begin
  Result.FSuccess := True;
  Result.FPreview := APreview;
end;

{ TRadIAMultiFilePatchService }

function TRadIAMultiFilePatchService.Apply(
  const APreviewId: string
): TRadIAMultiFilePatchResult;
var
  LPreview: TRadIAMultiFilePatchPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.State <> mpsPrepared then
      Exit(TRadIAMultiFilePatchResult.Failed(
        CPreconditionFailed,
        'Multi-file patch must be prepared before apply.'
      ));
    Result := ApplyEntries(LPreview, True);
    if Result.Success then
      LPreview.State := mpsApplied;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIAMultiFilePatchService.ApplyEntries(
  const APreview: TRadIAMultiFilePatchPreview;
  const AForward: Boolean
): TRadIAMultiFilePatchResult;
var
  LAppliedRevision: string;
  LEntry: TRadIAMultiFilePatchEntry;
  LExpectedRevision: string;
  LIndex: Integer;
  LNewContent: string;
begin
  Result := Preflight(APreview, AForward);
  if not Result.Success then
    Exit;
  for LIndex := Low(APreview.Entries) to High(APreview.Entries) do
  begin
    LEntry := APreview.Entries[LIndex];
    if AForward then
    begin
      LExpectedRevision := LEntry.Spec.BaseRevision;
      LNewContent := LEntry.Spec.ProposedContent;
    end
    else
    begin
      LExpectedRevision := LEntry.ProposedRevision;
      LNewContent := LEntry.OriginalContent;
    end;
    if not FMutation.ApplyContent(
      LEntry.Spec.TargetFile,
      LExpectedRevision,
      LNewContent,
      LAppliedRevision
    ) then
    begin
      if not Compensate(
        APreview.Entries,
        LIndex - 1,
        AForward
      ) then
        Exit(TRadIAMultiFilePatchResult.Failed(
          CCompensationFailed,
          'Multi-file patch failed and compensation was incomplete.'
        ));
      Exit(TRadIAMultiFilePatchResult.Failed(
        CApplyFailed,
        'Multi-file patch was rejected and fully compensated.'
      ));
    end;
  end;
  Result := TRadIAMultiFilePatchResult.Succeeded(APreview);
end;

function TRadIAMultiFilePatchService.BuildEntries(
  const ASpecs: TArray<TRadIAMultiFilePatchSpec>;
  out AEntries: TArray<TRadIAMultiFilePatchEntry>
): TRadIAMultiFilePatchResult;
var
  LEntry: TRadIAMultiFilePatchEntry;
  LIndex: Integer;
  LSeenFiles: TDictionary<string, Boolean>;
begin
  SetLength(AEntries, 0);
  if (Length(ASpecs) = 0) or (Length(ASpecs) > CMaxFiles) then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CResourceLimit,
      'Multi-file patch must contain between 1 and 32 files.'
    ));
  LSeenFiles := TDictionary<string, Boolean>.Create;
  try
    SetLength(AEntries, Length(ASpecs));
    for LIndex := Low(ASpecs) to High(ASpecs) do
    begin
      Result := ValidateSpec(
        ASpecs[LIndex],
        LSeenFiles,
        LEntry
      );
      if not Result.Success then
        Exit;
      AEntries[LIndex] := LEntry;
    end;
  finally
    LSeenFiles.Free;
  end;
  Result := TRadIAMultiFilePatchResult.Succeeded(nil);
end;

procedure TRadIAMultiFilePatchService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIAMultiFilePatchService.Compensate(
  const AEntries: TArray<TRadIAMultiFilePatchEntry>;
  const ALastAppliedIndex: Integer;
  const AForward: Boolean
): Boolean;
var
  LAppliedRevision: string;
  LEntry: TRadIAMultiFilePatchEntry;
  LExpectedRevision: string;
  LIndex: Integer;
  LNewContent: string;
begin
  Result := True;
  for LIndex := ALastAppliedIndex downto Low(AEntries) do
  begin
    LEntry := AEntries[LIndex];
    if AForward then
    begin
      LExpectedRevision := LEntry.ProposedRevision;
      LNewContent := LEntry.OriginalContent;
    end
    else
    begin
      LExpectedRevision := LEntry.Spec.BaseRevision;
      LNewContent := LEntry.Spec.ProposedContent;
    end;
    Result := FMutation.ApplyContent(
      LEntry.Spec.TargetFile,
      LExpectedRevision,
      LNewContent,
      LAppliedRevision
    ) and Result;
  end;
end;

constructor TRadIAMultiFilePatchService.Create(
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
  FPreviews := TObjectDictionary<
    string,
    TRadIAMultiFilePatchPreview
  >.Create([doOwnsValues]);
end;

destructor TRadIAMultiFilePatchService.Destroy;
begin
  FPreviews.Free;
  inherited Destroy;
end;

function TRadIAMultiFilePatchService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAMultiFilePatchPreview
): TRadIAMultiFilePatchResult;
begin
  APreview := nil;
  if not FPreviews.TryGetValue(APreviewId, APreview) then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CPreviewNotFound,
      'Multi-file patch preview was not found.'
    ));
  if TTimeZone.Local.ToUniversalTime(Now) >
    APreview.ExpiresAtUtc then
  begin
    FPreviews.Remove(APreviewId);
    APreview := nil;
    Exit(TRadIAMultiFilePatchResult.Failed(
      CPreviewExpired,
      'Multi-file patch preview expired.'
    ));
  end;
  Result := TRadIAMultiFilePatchResult.Succeeded(APreview);
end;

function TRadIAMultiFilePatchService.Preflight(
  const APreview: TRadIAMultiFilePatchPreview;
  const AForward: Boolean
): TRadIAMultiFilePatchResult;
var
  LEntry: TRadIAMultiFilePatchEntry;
  LExpectedRevision: string;
  LSnapshot: TRadIAEditorContent;
begin
  for LEntry in APreview.Entries do
  begin
    LSnapshot := FMutation.ReadContent(
      LEntry.Spec.TargetFile,
      -1
    );
    if LSnapshot.FileName = '' then
      Exit(TRadIAMultiFilePatchResult.Failed(
        CPreconditionFailed,
        'A multi-file patch target is no longer open.'
      ));
    if AForward then
      LExpectedRevision := LEntry.Spec.BaseRevision
    else
      LExpectedRevision := LEntry.ProposedRevision;
    if not SameText(LSnapshot.Revision, LExpectedRevision) then
      Exit(TRadIAMultiFilePatchResult.Failed(
        CPreconditionFailed,
        'A multi-file patch target changed after preview.'
      ));
  end;
  Result := TRadIAMultiFilePatchResult.Succeeded(APreview);
end;

function TRadIAMultiFilePatchService.Prepare(
  const ASpecs: TArray<TRadIAMultiFilePatchSpec>
): TRadIAMultiFilePatchResult;
var
  LEntries: TArray<TRadIAMultiFilePatchEntry>;
  LPreview: TRadIAMultiFilePatchPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
      Exit(TRadIAMultiFilePatchResult.Failed(
        CResourceLimit,
        'Too many multi-file patch previews are active.'
      ));
    Result := BuildEntries(ASpecs, LEntries);
    if not Result.Success then
      Exit;
    LPreview := TRadIAMultiFilePatchPreview.Create(
      TGUID.NewGuid.ToString,
      LEntries,
      IncMinute(
        TTimeZone.Local.ToUniversalTime(Now),
        FExpirationMinutes
      )
    );
    FPreviews.Add(LPreview.Id, LPreview);
    Result := TRadIAMultiFilePatchResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIAMultiFilePatchService.Revert(
  const APreviewId: string
): TRadIAMultiFilePatchResult;
var
  LPreview: TRadIAMultiFilePatchPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.State <> mpsApplied then
      Exit(TRadIAMultiFilePatchResult.Failed(
        CPreconditionFailed,
        'Multi-file patch must be applied before revert.'
      ));
    Result := ApplyEntries(LPreview, False);
    if Result.Success then
      LPreview.State := mpsReverted;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIAMultiFilePatchService.ValidateSpec(
  const ASpec: TRadIAMultiFilePatchSpec;
  const ASeenFiles: TDictionary<string, Boolean>;
  out AEntry: TRadIAMultiFilePatchEntry
): TRadIAMultiFilePatchResult;
var
  LPathValidation: TRadIAPathValidation;
  LProject: TRadIAProjectSnapshot;
  LSnapshot: TRadIAEditorContent;
begin
  AEntry := Default(TRadIAMultiFilePatchEntry);
  if (ASpec.TargetFile = '') or (ASpec.BaseRevision = '') then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CInvalidPatch,
      'Target file and base revision are required.'
    ));
  if Length(ASpec.ProposedContent) > CMaxFileCharacters then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CResourceLimit,
      'Proposed file content exceeds the 2 MB limit.'
    ));
  LProject := FWorkspace.GetActiveProject;
  LPathValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    ASpec.TargetFile
  );
  if not LPathValidation.Allowed then
    Exit(TRadIAMultiFilePatchResult.Failed(
      LPathValidation.ErrorCode,
      LPathValidation.ErrorMessage
    ));
  if ASeenFiles.ContainsKey(LPathValidation.ResolvedPath.ToLower) then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CInvalidPatch,
      'Multi-file patch contains a duplicate target.'
    ));
  ASeenFiles.Add(LPathValidation.ResolvedPath.ToLower, True);
  LSnapshot := FMutation.ReadContent(
    LPathValidation.ResolvedPath,
    -1
  );
  if (LSnapshot.FileName = '') or LSnapshot.Truncated then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CPreconditionFailed,
      'Multi-file patch target must be open and fully readable.'
    ));
  if not SameText(LSnapshot.Revision, ASpec.BaseRevision) then
    Exit(TRadIAMultiFilePatchResult.Failed(
      CPreconditionFailed,
      'Multi-file patch base revision does not match the buffer.'
    ));
  AEntry := TRadIAMultiFilePatchEntry.Create(
    TRadIAMultiFilePatchSpec.Create(
      LPathValidation.ResolvedPath,
      ASpec.BaseRevision,
      ASpec.ProposedContent
    ),
    LSnapshot.Content,
    THashSHA2.GetHashString(ASpec.ProposedContent)
  );
  Result := TRadIAMultiFilePatchResult.Succeeded(nil);
end;

end.
