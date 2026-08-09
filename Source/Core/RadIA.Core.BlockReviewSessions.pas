unit RadIA.Core.BlockReviewSessions;

interface

uses
  System.Generics.Collections,
  RadIA.Core.BlockReviews,
  RadIA.Core.MultiFilePatches;

type
  TRadIABlockReviewSessionStatus = record
  private
    FBlockCount: Integer;
    FFileCount: Integer;
    FPendingCount: Integer;
  public
    constructor Create(
      const AFileCount: Integer;
      const ABlockCount: Integer;
      const APendingCount: Integer
    );
    property FileCount: Integer read FFileCount;
    property BlockCount: Integer read FBlockCount;
    property PendingCount: Integer read FPendingCount;
  end;

  TRadIABlockReviewSessionResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FSuccess: Boolean;
    FTransactionId: string;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIABlockReviewSessionResult; static;
    class function Succeeded(
      const ATransactionId: string
    ): TRadIABlockReviewSessionResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property TransactionId: string read FTransactionId;
  end;

  IRadIABlockReviewSession = interface
    ['{3FDC986C-7034-4388-80B4-A9A90FE0FADE}']
    function PublishFile(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AOriginalContent: string;
      const AProposedContent: string
    ): TRadIABlockReviewSessionResult;
    function ListBlocks: TArray<TRadIABlockReview>;
    function Decide(
      const ABlockId: string;
      const ADecision: TRadIABlockReviewDecision;
      const AEditedText: string = ''
    ): TRadIABlockReviewSessionResult;
    function Apply: TRadIABlockReviewSessionResult;
    function GetStatus: TRadIABlockReviewSessionStatus;
    procedure Clear;
  end;

  TRadIABlockReviewSession = class(
    TInterfacedObject,
    IRadIABlockReviewSession
  )
  private type
    TRadIAFileReview = class
    private
      FBaseRevision: string;
      FBlocks: TArray<TRadIABlockReview>;
      FOriginalContent: string;
      FTargetFile: string;
    public
      constructor Create(
        const ATargetFile: string;
        const ABaseRevision: string;
        const AOriginalContent: string;
        const ABlocks: TArray<TRadIABlockReview>
      );
      property BaseRevision: string read FBaseRevision;
      property Blocks: TArray<TRadIABlockReview> read FBlocks write FBlocks;
      property OriginalContent: string read FOriginalContent;
      property TargetFile: string read FTargetFile;
    end;
  private
    FFiles: TObjectDictionary<string, TRadIAFileReview>;
    FPatchService: IRadIAMultiFilePatchService;
    function BuildSpecs(
      out ASpecs: TArray<TRadIAMultiFilePatchSpec>
    ): TRadIABlockReviewSessionResult;
    function FindBlock(
      const ABlockId: string;
      out AFileReview: TRadIAFileReview;
      out ABlockIndex: Integer
    ): Boolean;
  public
    constructor Create(
      const APatchService: IRadIAMultiFilePatchService
    );
    destructor Destroy; override;
    function PublishFile(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AOriginalContent: string;
      const AProposedContent: string
    ): TRadIABlockReviewSessionResult;
    function ListBlocks: TArray<TRadIABlockReview>;
    function Decide(
      const ABlockId: string;
      const ADecision: TRadIABlockReviewDecision;
      const AEditedText: string = ''
    ): TRadIABlockReviewSessionResult;
    function Apply: TRadIABlockReviewSessionResult;
    function GetStatus: TRadIABlockReviewSessionStatus;
    procedure Clear;
  end;

implementation

uses
  System.Generics.Defaults,
  System.SysUtils;

const
  CMaximumFiles = 32;
  CMaximumEditedCharacters = 2 * 1024 * 1024;

{ TRadIABlockReviewSessionStatus }

constructor TRadIABlockReviewSessionStatus.Create(
  const AFileCount: Integer;
  const ABlockCount: Integer;
  const APendingCount: Integer
);
begin
  FFileCount := AFileCount;
  FBlockCount := ABlockCount;
  FPendingCount := APendingCount;
end;

{ TRadIABlockReviewSessionResult }

class function TRadIABlockReviewSessionResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIABlockReviewSessionResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
  Result.FTransactionId := '';
end;

class function TRadIABlockReviewSessionResult.Succeeded(
  const ATransactionId: string
): TRadIABlockReviewSessionResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FTransactionId := ATransactionId;
end;

{ TRadIABlockReviewSession.TRadIAFileReview }

constructor TRadIABlockReviewSession.TRadIAFileReview.Create(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AOriginalContent: string;
  const ABlocks: TArray<TRadIABlockReview>
);
begin
  inherited Create;
  FTargetFile := ATargetFile;
  FBaseRevision := ABaseRevision;
  FOriginalContent := AOriginalContent;
  FBlocks := Copy(ABlocks);
end;

{ TRadIABlockReviewSession }

function TRadIABlockReviewSession.Apply:
  TRadIABlockReviewSessionResult;
var
  LApply: TRadIAMultiFilePatchResult;
  LPrepare: TRadIAMultiFilePatchResult;
  LSpecs: TArray<TRadIAMultiFilePatchSpec>;
begin
  TMonitor.Enter(FFiles);
  try
    Result := BuildSpecs(LSpecs);
    if not Result.Success then
      Exit;
    if Length(LSpecs) = 0 then
    begin
      FFiles.Clear;
      Exit(TRadIABlockReviewSessionResult.Succeeded(''));
    end;
    LPrepare := FPatchService.Prepare(LSpecs);
    if not LPrepare.Success then
      Exit(TRadIABlockReviewSessionResult.Failed(
        LPrepare.ErrorCode,
        LPrepare.ErrorMessage
      ));
    LApply := FPatchService.Apply(LPrepare.Preview.Id);
    if not LApply.Success then
      Exit(TRadIABlockReviewSessionResult.Failed(
        LApply.ErrorCode,
        LApply.ErrorMessage
      ));
    Result := TRadIABlockReviewSessionResult.Succeeded(
      LApply.Preview.Id
    );
    FFiles.Clear;
  finally
    TMonitor.Exit(FFiles);
  end;
end;

function TRadIABlockReviewSession.BuildSpecs(
  out ASpecs: TArray<TRadIAMultiFilePatchSpec>
): TRadIABlockReviewSessionResult;
var
  LBlock: TRadIABlockReview;
  LFile: TRadIAFileReview;
  LProposedContent: string;
  LSpecs: TList<TRadIAMultiFilePatchSpec>;
begin
  LSpecs := TList<TRadIAMultiFilePatchSpec>.Create;
  try
    for LFile in FFiles.Values do
    begin
      for LBlock in LFile.Blocks do
        if LBlock.Decision = brdPending then
          Exit(TRadIABlockReviewSessionResult.Failed(
            'pending_decisions',
            'Every review block must be accepted, rejected, or edited before apply.'
          ));
      LProposedContent := TRadIABlockReviewEngine.Compose(
        LFile.OriginalContent,
        LFile.Blocks
      );
      if LProposedContent <> LFile.OriginalContent then
        LSpecs.Add(TRadIAMultiFilePatchSpec.Create(
          LFile.TargetFile,
          LFile.BaseRevision,
          LProposedContent
        ));
    end;
    ASpecs := LSpecs.ToArray;
    Result := TRadIABlockReviewSessionResult.Succeeded('');
  finally
    LSpecs.Free;
  end;
end;

procedure TRadIABlockReviewSession.Clear;
begin
  TMonitor.Enter(FFiles);
  try
    FFiles.Clear;
  finally
    TMonitor.Exit(FFiles);
  end;
end;

constructor TRadIABlockReviewSession.Create(
  const APatchService: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  FPatchService := APatchService;
  FFiles := TObjectDictionary<string, TRadIAFileReview>.Create(
    [doOwnsValues]
  );
end;

function TRadIABlockReviewSession.Decide(
  const ABlockId: string;
  const ADecision: TRadIABlockReviewDecision;
  const AEditedText: string
): TRadIABlockReviewSessionResult;
var
  LBlockIndex: Integer;
  LBlocks: TArray<TRadIABlockReview>;
  LFile: TRadIAFileReview;
begin
  if ABlockId = '' then
    Exit(TRadIABlockReviewSessionResult.Failed(
      'invalid_block',
      'Review block id must not be empty.'
    ));
  if (ADecision = brdEdited) and
    (Length(AEditedText) > CMaximumEditedCharacters) then
    Exit(TRadIABlockReviewSessionResult.Failed(
      'resource_limit',
      'Edited block content exceeds the configured safety limit.'
    ));
  TMonitor.Enter(FFiles);
  try
    if not FindBlock(ABlockId, LFile, LBlockIndex) then
      Exit(TRadIABlockReviewSessionResult.Failed(
        'block_not_found',
        'Review block was not found in the active session.'
      ));
    LBlocks := LFile.Blocks;
    LBlocks[LBlockIndex] := LBlocks[LBlockIndex].WithDecision(
      ADecision,
      AEditedText
    );
    LFile.Blocks := LBlocks;
    Result := TRadIABlockReviewSessionResult.Succeeded('');
  finally
    TMonitor.Exit(FFiles);
  end;
end;

destructor TRadIABlockReviewSession.Destroy;
begin
  FFiles.Free;
  inherited;
end;

function TRadIABlockReviewSession.FindBlock(
  const ABlockId: string;
  out AFileReview: TRadIAFileReview;
  out ABlockIndex: Integer
): Boolean;
var
  LFile: TRadIAFileReview;
  LIndex: Integer;
begin
  AFileReview := nil;
  ABlockIndex := -1;
  for LFile in FFiles.Values do
    for LIndex := Low(LFile.Blocks) to High(LFile.Blocks) do
      if SameText(LFile.Blocks[LIndex].Id, ABlockId) then
      begin
        AFileReview := LFile;
        ABlockIndex := LIndex;
        Exit(True);
      end;
  Result := False;
end;

function TRadIABlockReviewSession.GetStatus:
  TRadIABlockReviewSessionStatus;
var
  LBlock: TRadIABlockReview;
  LBlockCount: Integer;
  LFile: TRadIAFileReview;
  LPendingCount: Integer;
begin
  LBlockCount := 0;
  LPendingCount := 0;
  TMonitor.Enter(FFiles);
  try
    for LFile in FFiles.Values do
      for LBlock in LFile.Blocks do
      begin
        Inc(LBlockCount);
        if LBlock.Decision = brdPending then
          Inc(LPendingCount);
      end;
    Result := TRadIABlockReviewSessionStatus.Create(
      FFiles.Count,
      LBlockCount,
      LPendingCount
    );
  finally
    TMonitor.Exit(FFiles);
  end;
end;

function TRadIABlockReviewSession.ListBlocks:
  TArray<TRadIABlockReview>;
var
  LBlock: TRadIABlockReview;
  LBlocks: TList<TRadIABlockReview>;
  LFile: TRadIAFileReview;
begin
  LBlocks := TList<TRadIABlockReview>.Create;
  try
    TMonitor.Enter(FFiles);
    try
      for LFile in FFiles.Values do
        for LBlock in LFile.Blocks do
          LBlocks.Add(LBlock);
      LBlocks.Sort(
        TComparer<TRadIABlockReview>.Construct(
          function(
            const ALeft: TRadIABlockReview;
            const ARight: TRadIABlockReview
          ): Integer
          begin
            Result := CompareText(ALeft.TargetFile, ARight.TargetFile);
            if Result = 0 then
              Result := ALeft.OriginalStartLine - ARight.OriginalStartLine;
          end
        )
      );
      Result := LBlocks.ToArray;
    finally
      TMonitor.Exit(FFiles);
    end;
  finally
    LBlocks.Free;
  end;
end;

function TRadIABlockReviewSession.PublishFile(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AOriginalContent: string;
  const AProposedContent: string
): TRadIABlockReviewSessionResult;
var
  LBlocks: TArray<TRadIABlockReview>;
  LFile: TRadIAFileReview;
begin
  if (ATargetFile = '') or (ABaseRevision = '') then
    Exit(TRadIABlockReviewSessionResult.Failed(
      'invalid_review',
      'Target file and base revision are required for block review.'
    ));
  LBlocks := TRadIABlockReviewEngine.Build(
    ATargetFile,
    ABaseRevision,
    AOriginalContent,
    AProposedContent
  );
  if Length(LBlocks) = 0 then
    Exit(TRadIABlockReviewSessionResult.Failed(
      'no_changes',
      'The proposed content does not contain reviewable changes.'
    ));
  LFile := TRadIAFileReview.Create(
    ATargetFile,
    ABaseRevision,
    AOriginalContent,
    LBlocks
  );
  TMonitor.Enter(FFiles);
  try
    if not FFiles.ContainsKey(ATargetFile) and
      (FFiles.Count >= CMaximumFiles) then
      Exit(TRadIABlockReviewSessionResult.Failed(
        'resource_limit',
        'Block review session reached the maximum file count.'
      ));
    FFiles.AddOrSetValue(ATargetFile, LFile);
    LFile := nil;
    Result := TRadIABlockReviewSessionResult.Succeeded('');
  finally
    TMonitor.Exit(FFiles);
    LFile.Free;
  end;
end;

end.
