unit RadIA.Core.InlineReviews;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Patches,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAInlineReviewSeverity = (
    irsInfo,
    irsWarning,
    irsError
  );

  TRadIAInlineReview = record
  private
    FBaseRevision: string;
    FEndLine: Integer;
    FFileName: string;
    FId: string;
    FMessage: string;
    FOriginalText: string;
    FReplacementText: string;
    FSeverity: TRadIAInlineReviewSeverity;
    FStartLine: Integer;
  public
    constructor Create(
      const AId: string;
      const AFileName: string;
      const ABaseRevision: string;
      const AStartLine: Integer;
      const AEndLine: Integer;
      const ASeverity: TRadIAInlineReviewSeverity
    );
    procedure SetContent(
      const AMessage: string;
      const AOriginalText: string;
      const AReplacementText: string
    );
    function HasSuggestion: Boolean;
    property Id: string read FId;
    property FileName: string read FFileName;
    property BaseRevision: string read FBaseRevision;
    property StartLine: Integer read FStartLine;
    property EndLine: Integer read FEndLine;
    property Severity: TRadIAInlineReviewSeverity read FSeverity;
    property Message: string read FMessage;
    property OriginalText: string read FOriginalText;
    property ReplacementText: string read FReplacementText;
  end;

  IRadIAInlineReviewVisualFacade = interface
    ['{1B4FC1A0-CF22-49AA-98CF-C319E02647BE}']
    procedure ShowReviews(
      const AFileName: string;
      const ARevision: string;
      const AReviews: TArray<TRadIAInlineReview>
    );
    procedure ClearReviews;
  end;

  TRadIAInlineReviewResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FReview: TRadIAInlineReview;
    FSuccess: Boolean;
  public
    class function Failed(
      const ACode: string;
      const AMessage: string
    ): TRadIAInlineReviewResult; static;
    class function Succeeded(
      const AReview: TRadIAInlineReview
    ): TRadIAInlineReviewResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Review: TRadIAInlineReview read FReview;
  end;

  IRadIAInlineReviewService = interface
    ['{959FB9B4-AD35-4E9B-863C-7D475DE1DB3D}']
    function Publish(
      const AReview: TRadIAInlineReview
    ): TRadIAInlineReviewResult;
    function ListCurrent: TArray<TRadIAInlineReview>;
    function PrepareFix(
      const AReviewId: string
    ): TRadIAPatchResult;
    function ApplyFix(
      const AReviewId: string
    ): TRadIAPatchResult;
    function Reject(
      const AReviewId: string
    ): Boolean;
    function Remove(
      const AReviewId: string
    ): Boolean;
    procedure Clear;
  end;

  TRadIAInlineReviewService = class(
    TInterfacedObject,
    IRadIAInlineReviewService
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FPatchService: IRadIAPatchService;
    FReviews: TDictionary<string, TRadIAInlineReview>;
    FVisual: IRadIAInlineReviewVisualFacade;
    FWorkspace: IRadIAWorkspaceFacade;
    function CurrentReviews(
      const ASnapshot: TRadIAEditorContent
    ): TArray<TRadIAInlineReview>;
    function IsValidLineRange(
      const AReview: TRadIAInlineReview;
      const AContent: string
    ): Boolean;
    procedure RefreshVisual;
    function Validate(
      const AReview: TRadIAInlineReview;
      const ASnapshot: TRadIAEditorContent
    ): TRadIAInlineReviewResult;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const APatchService: IRadIAPatchService;
      const AVisual: IRadIAInlineReviewVisualFacade
    );
    destructor Destroy; override;
    function Publish(
      const AReview: TRadIAInlineReview
    ): TRadIAInlineReviewResult;
    function ListCurrent: TArray<TRadIAInlineReview>;
    function PrepareFix(
      const AReviewId: string
    ): TRadIAPatchResult;
    function ApplyFix(
      const AReviewId: string
    ): TRadIAPatchResult;
    function Reject(
      const AReviewId: string
    ): Boolean;
    function Remove(
      const AReviewId: string
    ): Boolean;
    procedure Clear;
  end;

implementation

uses
  System.Classes,
  System.SysUtils;

const
  CMaxMessageLength = 2000;
  CMaxReviewBufferLength = 2 * 1024 * 1024;
  CMaxReviews = 128;
  CMaxSuggestionLength = 256 * 1024;

constructor TRadIAInlineReview.Create(
  const AId: string;
  const AFileName: string;
  const ABaseRevision: string;
  const AStartLine: Integer;
  const AEndLine: Integer;
  const ASeverity: TRadIAInlineReviewSeverity
);
begin
  FId := AId;
  FFileName := AFileName;
  FBaseRevision := ABaseRevision;
  FStartLine := AStartLine;
  FEndLine := AEndLine;
  FSeverity := ASeverity;
end;

function TRadIAInlineReview.HasSuggestion: Boolean;
begin
  Result := (FOriginalText <> '') and
    (FOriginalText <> FReplacementText);
end;

procedure TRadIAInlineReview.SetContent(
  const AMessage: string;
  const AOriginalText: string;
  const AReplacementText: string
);
begin
  FMessage := AMessage;
  FOriginalText := AOriginalText;
  FReplacementText := AReplacementText;
end;

class function TRadIAInlineReviewResult.Failed(
  const ACode: string;
  const AMessage: string
): TRadIAInlineReviewResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := ACode;
  Result.FErrorMessage := AMessage;
  Result.FReview := Default(TRadIAInlineReview);
end;

class function TRadIAInlineReviewResult.Succeeded(
  const AReview: TRadIAInlineReview
): TRadIAInlineReviewResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FReview := AReview;
end;

function TRadIAInlineReviewService.ApplyFix(
  const AReviewId: string
): TRadIAPatchResult;
var
  LPrepared: TRadIAPatchResult;
begin
  LPrepared := PrepareFix(AReviewId);
  if not LPrepared.Success then
    Exit(LPrepared);
  Result := FPatchService.Apply(LPrepared.Preview.Id);
  if Result.Success then
    Remove(AReviewId);
end;

procedure TRadIAInlineReviewService.Clear;
begin
  TMonitor.Enter(FReviews);
  try
    FReviews.Clear;
  finally
    TMonitor.Exit(FReviews);
  end;
  FVisual.ClearReviews;
end;

constructor TRadIAInlineReviewService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const APatchService: IRadIAPatchService;
  const AVisual: IRadIAInlineReviewVisualFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  if not Assigned(AVisual) then
    raise EArgumentNilException.Create('AVisual');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FPatchService := APatchService;
  FVisual := AVisual;
  FReviews := TDictionary<string, TRadIAInlineReview>.Create;
end;

function TRadIAInlineReviewService.CurrentReviews(
  const ASnapshot: TRadIAEditorContent
): TArray<TRadIAInlineReview>;
var
  LPair: TPair<string, TRadIAInlineReview>;
begin
  SetLength(Result, 0);
  TMonitor.Enter(FReviews);
  try
    for LPair in FReviews do
    begin
      if SameFileName(
        LPair.Value.FileName,
        ASnapshot.FileName
      ) and SameText(
        LPair.Value.BaseRevision,
        ASnapshot.Revision
      ) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := LPair.Value;
      end;
    end;
  finally
    TMonitor.Exit(FReviews);
  end;
end;

destructor TRadIAInlineReviewService.Destroy;
begin
  FVisual.ClearReviews;
  FReviews.Free;
  inherited;
end;

function TRadIAInlineReviewService.IsValidLineRange(
  const AReview: TRadIAInlineReview;
  const AContent: string
): Boolean;
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AContent;
    Result := (AReview.StartLine >= 1) and
      (AReview.EndLine >= AReview.StartLine) and
      (AReview.EndLine <= LLines.Count);
  finally
    LLines.Free;
  end;
end;

function TRadIAInlineReviewService.ListCurrent:
  TArray<TRadIAInlineReview>;
var
  LSnapshot: TRadIAEditorContent;
begin
  LSnapshot := FWorkspace.GetEditorContent(-1);
  Result := CurrentReviews(LSnapshot);
  FVisual.ShowReviews(
    LSnapshot.FileName,
    LSnapshot.Revision,
    Result
  );
end;

function TRadIAInlineReviewService.PrepareFix(
  const AReviewId: string
): TRadIAPatchResult;
var
  LReview: TRadIAInlineReview;
begin
  TMonitor.Enter(FReviews);
  try
    if not FReviews.TryGetValue(AReviewId, LReview) then
      Exit(TRadIAPatchResult.Failed(
        'review_not_found',
        'Inline review was not found.'
      ));
  finally
    TMonitor.Exit(FReviews);
  end;
  if not LReview.HasSuggestion then
    Exit(TRadIAPatchResult.Failed(
      'suggestion_unavailable',
      'Inline review does not contain a source suggestion.'
    ));
  Result := FPatchService.Prepare(
    TRadIAPatchSpec.Create(
      LReview.FileName,
      LReview.BaseRevision,
      LReview.OriginalText,
      LReview.ReplacementText
    )
  );
end;

function TRadIAInlineReviewService.Publish(
  const AReview: TRadIAInlineReview
): TRadIAInlineReviewResult;
var
  LReview: TRadIAInlineReview;
  LSnapshot: TRadIAEditorContent;
begin
  LSnapshot := FWorkspace.GetEditorContent(-1);
  Result := Validate(AReview, LSnapshot);
  if not Result.Success then
    Exit;
  LReview := AReview;
  TMonitor.Enter(FReviews);
  try
    if FReviews.Count >= CMaxReviews then
      Exit(TRadIAInlineReviewResult.Failed(
        'resource_limit',
        'The inline review limit was reached.'
      ));
    if LReview.Id = '' then
    begin
      LReview := TRadIAInlineReview.Create(
        TGUID.NewGuid.ToString,
        AReview.FileName,
        AReview.BaseRevision,
        AReview.StartLine,
        AReview.EndLine,
        AReview.Severity
      );
      LReview.SetContent(
        AReview.Message,
        AReview.OriginalText,
        AReview.ReplacementText
      );
    end;
    if FReviews.ContainsKey(LReview.Id) then
      Exit(TRadIAInlineReviewResult.Failed(
        'duplicate_review',
        'Inline review identifier already exists.'
      ));
    FReviews.Add(LReview.Id, LReview);
  finally
    TMonitor.Exit(FReviews);
  end;
  RefreshVisual;
  Result := TRadIAInlineReviewResult.Succeeded(LReview);
end;

procedure TRadIAInlineReviewService.RefreshVisual;
var
  LReviews: TArray<TRadIAInlineReview>;
  LSnapshot: TRadIAEditorContent;
begin
  LSnapshot := FWorkspace.GetEditorContent(-1);
  LReviews := CurrentReviews(LSnapshot);
  FVisual.ShowReviews(
    LSnapshot.FileName,
    LSnapshot.Revision,
    LReviews
  );
end;

function TRadIAInlineReviewService.Reject(
  const AReviewId: string
): Boolean;
begin
  Result := Remove(AReviewId);
end;

function TRadIAInlineReviewService.Remove(
  const AReviewId: string
): Boolean;
begin
  TMonitor.Enter(FReviews);
  try
    Result := FReviews.ContainsKey(AReviewId);
    if Result then
      FReviews.Remove(AReviewId);
  finally
    TMonitor.Exit(FReviews);
  end;
  if Result then
    RefreshVisual;
end;

function TRadIAInlineReviewService.Validate(
  const AReview: TRadIAInlineReview;
  const ASnapshot: TRadIAEditorContent
): TRadIAInlineReviewResult;
var
  LPath: TRadIAPathValidation;
  LProject: TRadIAProjectSnapshot;
begin
  if ASnapshot.OriginalLength > CMaxReviewBufferLength then
    Exit(TRadIAInlineReviewResult.Failed(
      'resource_limit',
      'Active editor content exceeds the inline review limit.'
    ));
  if (Trim(AReview.Message) = '') or
    (Length(AReview.Message) > CMaxMessageLength) then
    Exit(TRadIAInlineReviewResult.Failed(
      'invalid_review',
      'Review message must contain between 1 and 2000 characters.'
    ));
  if (Length(AReview.OriginalText) > CMaxSuggestionLength) or
    (Length(AReview.ReplacementText) > CMaxSuggestionLength) then
    Exit(TRadIAInlineReviewResult.Failed(
      'resource_limit',
      'Inline review suggestion exceeds 256 KiB.'
    ));
  if not SameFileName(AReview.FileName, ASnapshot.FileName) or
    not SameText(AReview.BaseRevision, ASnapshot.Revision) then
    Exit(TRadIAInlineReviewResult.Failed(
      'precondition_failed',
      'The active editor file or revision does not match the review.'
    ));
  if not IsValidLineRange(AReview, ASnapshot.Content) then
    Exit(TRadIAInlineReviewResult.Failed(
      'invalid_review',
      'Inline review line range is outside the active editor buffer.'
    ));
  LProject := FWorkspace.GetActiveProject;
  LPath := FBoundary.ValidatePath(
    LProject.RootPath,
    AReview.FileName
  );
  if not LPath.Allowed then
    Exit(TRadIAInlineReviewResult.Failed(
      LPath.ErrorCode,
      LPath.ErrorMessage
    ));
  Result := TRadIAInlineReviewResult.Succeeded(AReview);
end;

end.
