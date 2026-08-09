unit RadIA.Core.BlockReviews;

interface

type
  TRadIABlockReviewDecision = (
    brdPending,
    brdAccepted,
    brdRejected,
    brdEdited
  );

  TRadIABlockReviewLocation = record
  private
    FOriginalStartLine: Integer;
    FOriginalLineCount: Integer;
    FProposedStartLine: Integer;
    FProposedLineCount: Integer;
  public
    constructor Create(
      const AOriginalStartLine: Integer;
      const AOriginalLineCount: Integer;
      const AProposedStartLine: Integer;
      const AProposedLineCount: Integer
    );
    property OriginalStartLine: Integer read FOriginalStartLine;
    property OriginalLineCount: Integer read FOriginalLineCount;
    property ProposedStartLine: Integer read FProposedStartLine;
    property ProposedLineCount: Integer read FProposedLineCount;
  end;

  TRadIABlockReview = record
  private
    FId: string;
    FTargetFile: string;
    FBaseRevision: string;
    FOriginalStartLine: Integer;
    FOriginalLineCount: Integer;
    FProposedStartLine: Integer;
    FProposedLineCount: Integer;
    FOriginalText: string;
    FProposedText: string;
    FDecision: TRadIABlockReviewDecision;
    FEditedText: string;
  public
    constructor Create(
      const ATargetFile: string;
      const ABaseRevision: string;
      const ALocation: TRadIABlockReviewLocation;
      const AOriginalText: string;
      const AProposedText: string
    );
    function WithDecision(
      const ADecision: TRadIABlockReviewDecision;
      const AEditedText: string = ''
    ): TRadIABlockReview;
    property Id: string read FId;
    property TargetFile: string read FTargetFile;
    property BaseRevision: string read FBaseRevision;
    property OriginalStartLine: Integer read FOriginalStartLine;
    property OriginalLineCount: Integer read FOriginalLineCount;
    property ProposedStartLine: Integer read FProposedStartLine;
    property ProposedLineCount: Integer read FProposedLineCount;
    property OriginalText: string read FOriginalText;
    property ProposedText: string read FProposedText;
    property Decision: TRadIABlockReviewDecision read FDecision;
    property EditedText: string read FEditedText;
  end;

  TRadIABlockReviewEngine = class
  private
    class function BuildFallbackBlock(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AOriginalLines: TArray<string>;
      const AProposedLines: TArray<string>
    ): TArray<TRadIABlockReview>; static;
    class function JoinLines(
      const ALines: TArray<string>;
      const AStartIndex: Integer;
      const ACount: Integer;
      const ALineBreak: string
    ): string; static;
    class function SplitLines(const AText: string): TArray<string>; static;
  public
    class function Build(
      const ATargetFile: string;
      const ABaseRevision: string;
      const AOriginalContent: string;
      const AProposedContent: string
    ): TArray<TRadIABlockReview>; static;
    class function Compose(
      const AOriginalContent: string;
      const ABlocks: TArray<TRadIABlockReview>
    ): string; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.Math,
  System.SysUtils;

const
  CMaximumLcsCells = 1000000;

type
  TRadIALineOperationKind = (
    lokEqual,
    lokDelete,
    lokInsert
  );

  TRadIALineOperation = record
    Kind: TRadIALineOperationKind;
    Text: string;
  end;

function BuildLcsCells(
  const AOriginalLines: TArray<string>;
  const AProposedLines: TArray<string>;
  out AColumnCount: Integer
): TArray<Integer>;
var
  LNewIndex: Integer;
  LOldIndex: Integer;
begin
  AColumnCount := Length(AProposedLines) + 1;
  SetLength(Result, (Length(AOriginalLines) + 1) * AColumnCount);
  for LOldIndex := High(AOriginalLines) downto 0 do
    for LNewIndex := High(AProposedLines) downto 0 do
      if AOriginalLines[LOldIndex] = AProposedLines[LNewIndex] then
        Result[(LOldIndex * AColumnCount) + LNewIndex] :=
          Result[((LOldIndex + 1) * AColumnCount) + LNewIndex + 1] + 1
      else
        Result[(LOldIndex * AColumnCount) + LNewIndex] :=
          Max(
            Result[((LOldIndex + 1) * AColumnCount) + LNewIndex],
            Result[(LOldIndex * AColumnCount) + LNewIndex + 1]
          );
end;

function BuildLineOperations(
  const AOriginalLines: TArray<string>;
  const AProposedLines: TArray<string>;
  const ACells: TArray<Integer>;
  const AColumnCount: Integer
): TArray<TRadIALineOperation>;
var
  LNewIndex: Integer;
  LOldIndex: Integer;
  LOperation: TRadIALineOperation;
  LOperations: TList<TRadIALineOperation>;
begin
  LOperations := TList<TRadIALineOperation>.Create;
  try
    LOldIndex := 0;
    LNewIndex := 0;
    while (LOldIndex < Length(AOriginalLines)) or
      (LNewIndex < Length(AProposedLines)) do
    begin
      if (LOldIndex < Length(AOriginalLines)) and
        (LNewIndex < Length(AProposedLines)) and
        (AOriginalLines[LOldIndex] = AProposedLines[LNewIndex]) then
      begin
        LOperation.Kind := lokEqual;
        LOperation.Text := AOriginalLines[LOldIndex];
        Inc(LOldIndex);
        Inc(LNewIndex);
      end
      else if (LNewIndex < Length(AProposedLines)) and
        ((LOldIndex >= Length(AOriginalLines)) or
        (ACells[(LOldIndex * AColumnCount) + LNewIndex + 1] >=
        ACells[((LOldIndex + 1) * AColumnCount) + LNewIndex])) then
      begin
        LOperation.Kind := lokInsert;
        LOperation.Text := AProposedLines[LNewIndex];
        Inc(LNewIndex);
      end
      else
      begin
        LOperation.Kind := lokDelete;
        LOperation.Text := AOriginalLines[LOldIndex];
        Inc(LOldIndex);
      end;
      LOperations.Add(LOperation);
    end;
    Result := LOperations.ToArray;
  finally
    LOperations.Free;
  end;
end;

procedure AppendOperationText(
  const AOperation: TRadIALineOperation;
  const AOriginalText: TStringBuilder;
  const AProposedText: TStringBuilder;
  var AOriginalCount: Integer;
  var AProposedCount: Integer
);
var
  LTarget: TStringBuilder;
begin
  if AOperation.Kind = lokDelete then
  begin
    LTarget := AOriginalText;
    Inc(AOriginalCount);
  end
  else
  begin
    LTarget := AProposedText;
    Inc(AProposedCount);
  end;
  if LTarget.Length > 0 then
    LTarget.Append(#10);
  LTarget.Append(AOperation.Text);
end;

function BuildBlocksFromOperations(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AOperations: TArray<TRadIALineOperation>
): TArray<TRadIABlockReview>;
var
  LBlocks: TList<TRadIABlockReview>;
  LIndex: Integer;
  LNewIndex: Integer;
  LOldIndex: Integer;
  LOriginalCount: Integer;
  LOriginalStart: Integer;
  LOriginalText: TStringBuilder;
  LProposedCount: Integer;
  LProposedStart: Integer;
  LProposedText: TStringBuilder;
begin
  LBlocks := TList<TRadIABlockReview>.Create;
  LOriginalText := TStringBuilder.Create;
  LProposedText := TStringBuilder.Create;
  try
    LOldIndex := 0;
    LNewIndex := 0;
    LIndex := 0;
    while LIndex < Length(AOperations) do
    begin
      if AOperations[LIndex].Kind = lokEqual then
      begin
        Inc(LOldIndex);
        Inc(LNewIndex);
        Inc(LIndex);
        Continue;
      end;
      LOriginalStart := LOldIndex;
      LProposedStart := LNewIndex;
      LOriginalCount := 0;
      LProposedCount := 0;
      LOriginalText.Clear;
      LProposedText.Clear;
      while (LIndex < Length(AOperations)) and
        (AOperations[LIndex].Kind <> lokEqual) do
      begin
        AppendOperationText(
          AOperations[LIndex],
          LOriginalText,
          LProposedText,
          LOriginalCount,
          LProposedCount
        );
        if AOperations[LIndex].Kind = lokDelete then
          Inc(LOldIndex)
        else
          Inc(LNewIndex);
        Inc(LIndex);
      end;
      LBlocks.Add(TRadIABlockReview.Create(
        ATargetFile,
        ABaseRevision,
        TRadIABlockReviewLocation.Create(
          LOriginalStart + 1,
          LOriginalCount,
          LProposedStart + 1,
          LProposedCount
        ),
        LOriginalText.ToString,
        LProposedText.ToString
      ));
    end;
    Result := LBlocks.ToArray;
  finally
    LProposedText.Free;
    LOriginalText.Free;
    LBlocks.Free;
  end;
end;

function DetectLineBreak(const AText: string): string;
begin
  if AText.Contains(#13#10) then
    Result := #13#10
  else
    Result := #10;
end;

{ TRadIABlockReviewLocation }

constructor TRadIABlockReviewLocation.Create(
  const AOriginalStartLine: Integer;
  const AOriginalLineCount: Integer;
  const AProposedStartLine: Integer;
  const AProposedLineCount: Integer
);
begin
  FOriginalStartLine := AOriginalStartLine;
  FOriginalLineCount := AOriginalLineCount;
  FProposedStartLine := AProposedStartLine;
  FProposedLineCount := AProposedLineCount;
end;

{ TRadIABlockReview }

constructor TRadIABlockReview.Create(
  const ATargetFile: string;
  const ABaseRevision: string;
  const ALocation: TRadIABlockReviewLocation;
  const AOriginalText: string;
  const AProposedText: string
);
var
  LIdentity: string;
begin
  FTargetFile := ATargetFile;
  FBaseRevision := ABaseRevision;
  FOriginalStartLine := ALocation.OriginalStartLine;
  FOriginalLineCount := ALocation.OriginalLineCount;
  FProposedStartLine := ALocation.ProposedStartLine;
  FProposedLineCount := ALocation.ProposedLineCount;
  FOriginalText := AOriginalText;
  FProposedText := AProposedText;
  FDecision := brdPending;
  FEditedText := '';
  LIdentity := ATargetFile + #0 + ABaseRevision + #0 +
    FOriginalStartLine.ToString + #0 + FOriginalLineCount.ToString + #0 +
    FProposedStartLine.ToString + #0 + FProposedLineCount.ToString + #0 +
    AOriginalText + #0 + AProposedText;
  FId := THashSHA2.GetHashString(LIdentity);
end;

function TRadIABlockReview.WithDecision(
  const ADecision: TRadIABlockReviewDecision;
  const AEditedText: string
): TRadIABlockReview;
begin
  Result := Self;
  Result.FDecision := ADecision;
  if ADecision = brdEdited then
    Result.FEditedText := AEditedText
  else
    Result.FEditedText := '';
end;

{ TRadIABlockReviewEngine }

class function TRadIABlockReviewEngine.Build(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AOriginalContent: string;
  const AProposedContent: string
): TArray<TRadIABlockReview>;
var
  LCells: TArray<Integer>;
  LColumnCount: Integer;
  LOriginalLines: TArray<string>;
  LProposedLines: TArray<string>;
  LOperations: TArray<TRadIALineOperation>;
begin
  LOriginalLines := SplitLines(AOriginalContent);
  LProposedLines := SplitLines(AProposedContent);
  if AOriginalContent = AProposedContent then
    Exit(nil);
  if (Int64(Length(LOriginalLines) + 1) *
    Int64(Length(LProposedLines) + 1)) > CMaximumLcsCells then
    Exit(BuildFallbackBlock(
      ATargetFile,
      ABaseRevision,
      LOriginalLines,
      LProposedLines
    ));

  LCells := BuildLcsCells(LOriginalLines, LProposedLines, LColumnCount);
  LOperations := BuildLineOperations(
    LOriginalLines,
    LProposedLines,
    LCells,
    LColumnCount
  );
  Result := BuildBlocksFromOperations(
    ATargetFile,
    ABaseRevision,
    LOperations
  );
end;

class function TRadIABlockReviewEngine.BuildFallbackBlock(
  const ATargetFile: string;
  const ABaseRevision: string;
  const AOriginalLines: TArray<string>;
  const AProposedLines: TArray<string>
): TArray<TRadIABlockReview>;
var
  LPrefix: Integer;
  LSuffix: Integer;
begin
  LPrefix := 0;
  while (LPrefix < Length(AOriginalLines)) and
    (LPrefix < Length(AProposedLines)) and
    (AOriginalLines[LPrefix] = AProposedLines[LPrefix]) do
    Inc(LPrefix);
  LSuffix := 0;
  while (LSuffix < Length(AOriginalLines) - LPrefix) and
    (LSuffix < Length(AProposedLines) - LPrefix) and
    (AOriginalLines[High(AOriginalLines) - LSuffix] =
    AProposedLines[High(AProposedLines) - LSuffix]) do
    Inc(LSuffix);
  SetLength(Result, 1);
  Result[0] := TRadIABlockReview.Create(
    ATargetFile,
    ABaseRevision,
    TRadIABlockReviewLocation.Create(
      LPrefix + 1,
      Length(AOriginalLines) - LPrefix - LSuffix,
      LPrefix + 1,
      Length(AProposedLines) - LPrefix - LSuffix
    ),
    JoinLines(
      AOriginalLines,
      LPrefix,
      Length(AOriginalLines) - LPrefix - LSuffix,
      #10
    ),
    JoinLines(
      AProposedLines,
      LPrefix,
      Length(AProposedLines) - LPrefix - LSuffix,
      #10
    )
  );
end;

class function TRadIABlockReviewEngine.Compose(
  const AOriginalContent: string;
  const ABlocks: TArray<TRadIABlockReview>
): string;
var
  LBlock: TRadIABlockReview;
  LCursor: Integer;
  LLineBreak: string;
  LOriginalLines: TArray<string>;
  LOutput: TStringBuilder;
  LReplacement: string;

  procedure AppendText(const AText: string);
  var
    LNormalized: string;
  begin
    if AText = '' then
      Exit;
    if LOutput.Length > 0 then
      LOutput.Append(LLineBreak);
    LNormalized := AText.Replace(#13#10, #10).Replace(#13, #10);
    LOutput.Append(LNormalized.Replace(#10, LLineBreak));
  end;

begin
  LOriginalLines := SplitLines(AOriginalContent);
  LLineBreak := DetectLineBreak(AOriginalContent);
  LOutput := TStringBuilder.Create;
  try
    LCursor := 0;
    for LBlock in ABlocks do
    begin
      if (LBlock.OriginalStartLine - 1) < LCursor then
        raise EArgumentException.Create('Review blocks overlap or are not ordered.');
      AppendText(JoinLines(
        LOriginalLines,
        LCursor,
        (LBlock.OriginalStartLine - 1) - LCursor,
        LLineBreak
      ));
      case LBlock.Decision of
        brdAccepted: LReplacement := LBlock.ProposedText;
        brdEdited: LReplacement := LBlock.EditedText;
      else
        LReplacement := LBlock.OriginalText;
      end;
      AppendText(LReplacement);
      LCursor := (LBlock.OriginalStartLine - 1) +
        LBlock.OriginalLineCount;
    end;
    AppendText(JoinLines(
      LOriginalLines,
      LCursor,
      Length(LOriginalLines) - LCursor,
      LLineBreak
    ));
    Result := LOutput.ToString;
  finally
    LOutput.Free;
  end;
end;

class function TRadIABlockReviewEngine.JoinLines(
  const ALines: TArray<string>;
  const AStartIndex: Integer;
  const ACount: Integer;
  const ALineBreak: string
): string;
var
  LBuilder: TStringBuilder;
  LIndex: Integer;
begin
  if ACount <= 0 then
    Exit('');
  LBuilder := TStringBuilder.Create;
  try
    for LIndex := AStartIndex to AStartIndex + ACount - 1 do
    begin
      if LBuilder.Length > 0 then
        LBuilder.Append(ALineBreak);
      LBuilder.Append(ALines[LIndex]);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TRadIABlockReviewEngine.SplitLines(
  const AText: string
): TArray<string>;
begin
  if AText = '' then
    Exit(nil);
  Result := AText.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
end;

end.
