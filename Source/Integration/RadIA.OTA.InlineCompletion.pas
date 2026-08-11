unit RadIA.OTA.InlineCompletion;

interface

uses
  ToolsAPI,
  RadIA.Core.InlineCompletion,
  RadIA.OTA.InlineReviews;

type
  TRadIAInlineCompletionIdleHandler = reference to procedure;

  IRadIAOTAInlineCompletionSession = interface(
    IRadIAInlineCompletionView
  )
    ['{A5BC63FC-32A1-4CB4-9090-97350A55B6C4}']
    function Capture(
      out AContext: TRadIAInlineCompletionContext
    ): Boolean;
    procedure ConfigureContinuous(
      const AEnabled: Boolean;
      const AIdleHandler: TRadIAInlineCompletionIdleHandler
    );
    function UndoCurrentBuffer: Boolean;
    procedure WatchCurrentView;
  end;

  TRadIAOTAInlineCompletionSession = class(
    TRadIAOTAInlineReviewFacade,
    IRadIAInlineCompletionView,
    IRadIAOTAInlineCompletionSession
  )
  private
    FAlternatives: TArray<string>;
    FContext: TRadIAInlineCompletionContext;
    FContinuousEnabled: Boolean;
    FGhostLines: TArray<TRadIAInlineGhostLine>;
    FIdleHandler: TRadIAInlineCompletionIdleHandler;
    FPaintEvidenceLogged: Boolean;
    FPanelPaintEvidenceLogged: Boolean;
    FSelectedAlternative: Integer;
    FSuggestion: string;
    function CurrentView: IOTAEditView;
    function GhostHorizontalPosition(
      const APaintContext: TRadIAEditPaintContext;
      const ALineOffset: Integer
    ): Integer;
    function LanguageForFile(const AFileName: string): string;
    function PaintGhostText(
      const APaintContext: TRadIAEditPaintContext;
      const AText: string;
      const AHorizontalPosition: Integer;
      const ATop: Integer;
      const AClipToLine: Boolean
    ): Boolean;
    procedure PaintAlternativePanel(
      const APaintContext: TRadIAEditPaintContext
    );
    procedure PaintOverflowLines(
      const APaintContext: TRadIAEditPaintContext
    );
  protected
    procedure PaintOverlay(
      const APaintContext: TRadIAEditPaintContext
    ); override;
  public
    function Apply(
      const AContext: TRadIAInlineCompletionContext;
      const AText: string;
      out AUpdatedContext: TRadIAInlineCompletionContext
    ): Boolean;
    function Capture(
      out AContext: TRadIAInlineCompletionContext
    ): Boolean;
    procedure ConfigureContinuous(
      const AEnabled: Boolean;
      const AIdleHandler: TRadIAInlineCompletionIdleHandler
    );
    procedure Clear;
    procedure Show(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string
    );
    procedure ShowAlternatives(
      const AContext: TRadIAInlineCompletionContext;
      const AAlternatives: TArray<string>;
      const ASelectedIndex: Integer
    );
    function UndoCurrentBuffer: Boolean;
    procedure Modified; override;
    procedure EditorIdle(const View: IOTAEditView); override;
    procedure WatchCurrentView;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  RadIA.Core.Container,
  RadIA.Core.EditorContext,
  RadIA.Core.Interfaces,
  RadIA.Core.JourneyContext,
  RadIA.Core.Logger,
  RadIA.OTA.TextReader;

function TRadIAOTAInlineCompletionSession.Apply(
  const AContext: TRadIAInlineCompletionContext;
  const AText: string;
  out AUpdatedContext: TRadIAInlineCompletionContext
): Boolean;
var
  LCurrentContext: TRadIAInlineCompletionContext;
  LView: IOTAEditView;
begin
  AUpdatedContext := Default(TRadIAInlineCompletionContext);
  Result := Capture(LCurrentContext) and
    SameFileName(LCurrentContext.FileName, AContext.FileName) and
    SameText(LCurrentContext.Revision, AContext.Revision) and
    (LCurrentContext.CursorLine = AContext.CursorLine) and
    (LCurrentContext.CursorColumn = AContext.CursorColumn);
  if not Result then
    Exit;

  LView := CurrentView;
  Result := Assigned(LView) and Assigned(LView.Position);
  if not Result then
    Exit;
  LView.Position.InsertText(AText);
  Result := Capture(AUpdatedContext);
end;

function TRadIAOTAInlineCompletionSession.Capture(
  out AContext: TRadIAInlineCompletionContext
): Boolean;
var
  LBufferBytes: TBytes;
  LCharPosition: TOTACharPos;
  LContent: string;
  LCursorOffset: Integer;
  LEditPosition: TOTAEditPos;
  LFileName: string;
  LPrefix: string;
  LProjectContext: string;
  LProjectName: string;
  LProjectFolder: string;
  LSemanticContext: TRadIAEditorSemanticContext;
  LSymbolName: string;
  LSuffix: string;
  LView: IOTAEditView;
  LEditorAdapter: IRadIAEditorAdapter;
  LJourneyContext: IRadIAJourneyContextCoordinator;
begin
  AContext := Default(TRadIAInlineCompletionContext);
  LView := CurrentView;
  Result := Assigned(LView) and Assigned(LView.Buffer) and
    Assigned(LView.Position);
  if not Result then
    Exit;

  LFileName := LView.Buffer.FileName;
  LContent := ReadRadIAEditReaderText(LView.Buffer.CreateReader);
  LBufferBytes := TEncoding.UTF8.GetBytes(LContent);
  LEditPosition := LView.CursorPos;
  LCharPosition := Default(TOTACharPos);
  LView.ConvertPos(True, LEditPosition, LCharPosition);
  LCursorOffset := EnsureRange(
    LView.CharPosToPos(LCharPosition),
    0,
    Length(LBufferBytes)
  );
  LPrefix := TEncoding.UTF8.GetString(
    LBufferBytes,
    0,
    LCursorOffset
  );
  LSuffix := TEncoding.UTF8.GetString(
    LBufferBytes,
    LCursorOffset,
    Length(LBufferBytes) - LCursorOffset
  );

  LProjectName := '';
  LProjectFolder := '';
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditorAdapter) then
  begin
    LProjectName := LEditorAdapter.GetActiveProjectName;
    LProjectFolder := LEditorAdapter.GetActiveProjectFolder;
  end;
  LProjectContext := 'Project: ' + LProjectName + sLineBreak +
    'Root: ' + LProjectFolder;
  if TRadIAContainer.TryResolve<IRadIAJourneyContextCoordinator>(
    LJourneyContext
  ) then
    LProjectContext := TRadIAJourneyContextEnricher.EnrichProjectContext(
      LProjectContext,
      LProjectFolder,
      LJourneyContext
    );
  LSemanticContext := TRadIAEditorContextAnalyzer.Analyze(
    LContent,
    LView.Position.Row
  );
  LSymbolName := LSemanticContext.CurrentSymbol;
  if LSemanticContext.ToPromptContext <> '' then
    LProjectContext := LProjectContext + sLineBreak +
      LSemanticContext.ToPromptContext;
  AContext := TRadIAInlineCompletionContext.Create(
    LFileName,
    LanguageForFile(LFileName),
    LPrefix,
    LSuffix,
    LSymbolName,
    LProjectContext,
    THashSHA2.GetHashString(LContent)
  ).WithCursor(LView.Position.Row, LView.Position.Column);
  Result := AContext.IsValid;
end;

procedure TRadIAOTAInlineCompletionSession.Clear;
var
  LView: IOTAEditView;
begin
  FAlternatives := nil;
  FSelectedAlternative := -1;
  FPanelPaintEvidenceLogged := False;
  FSuggestion := '';
  FGhostLines := nil;
  FPaintEvidenceLogged := False;
  FContext := Default(TRadIAInlineCompletionContext);
  LView := CurrentView;
  if Assigned(LView) then
    LView.Paint;
  if not FContinuousEnabled then
    UnregisterView;
end;

procedure TRadIAOTAInlineCompletionSession.ConfigureContinuous(
  const AEnabled: Boolean;
  const AIdleHandler: TRadIAInlineCompletionIdleHandler
);
begin
  FContinuousEnabled := AEnabled;
  if AEnabled then
  begin
    FIdleHandler := AIdleHandler;
    WatchCurrentView;
  end
  else
  begin
    FIdleHandler := nil;
    if FSuggestion = '' then
      UnregisterView;
  end;
end;

function TRadIAOTAInlineCompletionSession.CurrentView: IOTAEditView;
var
  LEditorServices: IOTAEditorServices;
begin
  Result := nil;
  if Supports(
    BorlandIDEServices,
    IOTAEditorServices,
    LEditorServices
  ) then
    Result := LEditorServices.TopView;
end;

procedure TRadIAOTAInlineCompletionSession.EditorIdle(
  const View: IOTAEditView
);
begin
  if not Assigned(View) then
    Exit;
  if FSuggestion <> '' then
    View.SetTempMsg(
      Format(
        'RadIA Ghost Text: %d line(s). Accept, reject, or request ' +
        'an alternative from the RadIA editor menu.',
        [Length(FGhostLines)]
      )
    )
  else if FContinuousEnabled and Assigned(FIdleHandler) then
    FIdleHandler();
end;

function TRadIAOTAInlineCompletionSession.GhostHorizontalPosition(
  const APaintContext: TRadIAEditPaintContext;
  const ALineOffset: Integer
): Integer;
begin
  if ALineOffset = 0 then
    Exit(
      APaintContext.CodeLeftEdge +
      Max(
        0,
        FContext.CursorColumn - Max(1, APaintContext.LeftColumn)
      ) *
      APaintContext.CellSize.cx
    );
  Result := Max(
    APaintContext.TextRect.Left,
    APaintContext.TextRect.Right + APaintContext.CellSize.cx
  );
end;

function TRadIAOTAInlineCompletionSession.LanguageForFile(
  const AFileName: string
): string;
begin
  if SameText(TPath.GetExtension(AFileName), '.pas') or
    SameText(TPath.GetExtension(AFileName), '.dpr') or
    SameText(TPath.GetExtension(AFileName), '.dpk') then
    Exit('delphi');
  Result := TPath.GetExtension(AFileName).TrimLeft(['.']).ToLower;
end;

procedure TRadIAOTAInlineCompletionSession.Modified;
begin
  inherited;
  FAlternatives := nil;
  FSelectedAlternative := -1;
  FPanelPaintEvidenceLogged := False;
  FSuggestion := '';
  FGhostLines := nil;
  FPaintEvidenceLogged := False;
  FContext := Default(TRadIAInlineCompletionContext);
end;

function TRadIAOTAInlineCompletionSession.PaintGhostText(
  const APaintContext: TRadIAEditPaintContext;
  const AText: string;
  const AHorizontalPosition: Integer;
  const ATop: Integer;
  const AClipToLine: Boolean
): Boolean;
var
  LBrushStyle: TBrushStyle;
  LColor: TColor;
begin
  Result := False;
  if AText.IsEmpty or
    (AHorizontalPosition >= APaintContext.LineRect.Right) then
    Exit;
  LColor := APaintContext.Canvas.Font.Color;
  LBrushStyle := APaintContext.Canvas.Brush.Style;
  try
    APaintContext.Canvas.Font.Color := clGrayText;
    APaintContext.Canvas.Brush.Style := bsClear;
    if AClipToLine then
      APaintContext.Canvas.TextRect(
        APaintContext.LineRect,
        AHorizontalPosition,
        ATop,
        AText
      )
    else
      APaintContext.Canvas.TextOut(
        AHorizontalPosition,
        ATop,
        AText
      );
    Result := True;
  finally
    APaintContext.Canvas.Brush.Style := LBrushStyle;
    APaintContext.Canvas.Font.Color := LColor;
  end;
end;

procedure TRadIAOTAInlineCompletionSession.PaintAlternativePanel(
  const APaintContext: TRadIAEditPaintContext
);
const
  CMaximumVisibleAlternatives = 3;
  CMaximumSummaryCharacters = 72;
var
  LBrushColor: TColor;
  LBrushStyle: TBrushStyle;
  LFontColor: TColor;
  LIndex: Integer;
  LRowRect: TRect;
  LSummary: string;
  LVisibleCount: Integer;
begin
  if Length(FAlternatives) < 2 then
    Exit;
  LVisibleCount := Min(
    Length(FAlternatives),
    CMaximumVisibleAlternatives
  );
  LBrushColor := APaintContext.Canvas.Brush.Color;
  LBrushStyle := APaintContext.Canvas.Brush.Style;
  LFontColor := APaintContext.Canvas.Font.Color;
  try
    for LIndex := 0 to LVisibleCount - 1 do
    begin
      LRowRect := Rect(
        APaintContext.TextRect.Left,
        APaintContext.TextRect.Bottom + 2 +
          LIndex * APaintContext.CellSize.cy,
        APaintContext.TextRect.Right,
        APaintContext.TextRect.Bottom + 2 +
          (LIndex + 1) * APaintContext.CellSize.cy
      );
      if LIndex = FSelectedAlternative then
      begin
        APaintContext.Canvas.Brush.Color := clHighlight;
        APaintContext.Canvas.Font.Color := clHighlightText;
      end
      else
      begin
        APaintContext.Canvas.Brush.Color := clInfoBk;
        APaintContext.Canvas.Font.Color := clInfoText;
      end;
      APaintContext.Canvas.Brush.Style := bsSolid;
      APaintContext.Canvas.FillRect(LRowRect);
      LSummary := FAlternatives[LIndex]
        .Replace(#13, ' ')
        .Replace(#10, ' ');
      if Length(LSummary) > CMaximumSummaryCharacters then
        LSummary := Copy(
          LSummary,
          1,
          CMaximumSummaryCharacters - 1
        ) + #$2026;
      APaintContext.Canvas.TextRect(
        LRowRect,
        LRowRect.Left + 4,
        LRowRect.Top,
        Format('%d/%d  %s', [
          LIndex + 1,
          Length(FAlternatives),
          LSummary
        ])
      );
    end;
    if not FPanelPaintEvidenceLogged then
    begin
      FPanelPaintEvidenceLogged := True;
      TLogger.Log(
        Format(
          'Inline alternatives painted: count=%d, selected=%d',
          [Length(FAlternatives), FSelectedAlternative + 1]
        ),
        'InlineCompletion'
      );
    end;
  finally
    APaintContext.Canvas.Brush.Color := LBrushColor;
    APaintContext.Canvas.Brush.Style := LBrushStyle;
    APaintContext.Canvas.Font.Color := LFontColor;
  end;
end;

procedure TRadIAOTAInlineCompletionSession.PaintOverlay(
  const APaintContext: TRadIAEditPaintContext
);
var
  LDrawn: Boolean;
  LHorizontalPosition: Integer;
  LLine: TRadIAInlineGhostLine;
  LLineOffset: Integer;
begin
  if FSuggestion.IsEmpty then
    Exit;
  LLineOffset := APaintContext.LineNumber - FContext.CursorLine;
  if not TRadIAInlineGhostLayout.TryGetLine(
    FGhostLines,
    LLineOffset,
    LLine
  ) then
    Exit;
  LHorizontalPosition := GhostHorizontalPosition(
    APaintContext,
    LLineOffset
  );
  LDrawn := PaintGhostText(
    APaintContext,
    LLine.Text,
    LHorizontalPosition,
    APaintContext.TextRect.Top,
    True
  );
  if LDrawn and not FPaintEvidenceLogged then
  begin
    FPaintEvidenceLogged := True;
    TLogger.Log(
      Format(
        'Ghost text painted: lines=%d, file=%s',
        [Length(FGhostLines), TPath.GetFileName(FContext.FileName)]
      ),
      'InlineCompletion'
    );
  end;
  if LLineOffset = 0 then
  begin
    PaintOverflowLines(APaintContext);
    PaintAlternativePanel(APaintContext);
  end;
end;

procedure TRadIAOTAInlineCompletionSession.PaintOverflowLines(
  const APaintContext: TRadIAEditPaintContext
);
var
  LHorizontalPosition: Integer;
  LIndex: Integer;
  LLastEditorLine: Integer;
begin
  if not Assigned(APaintContext.View.Position) then
    Exit;
  LLastEditorLine := APaintContext.View.Position.LastRow;
  for LIndex := 1 to Length(FGhostLines) - 1 do
  begin
    if FContext.CursorLine + LIndex <= LLastEditorLine then
      Continue;
    LHorizontalPosition := APaintContext.TextRect.Left;
    PaintGhostText(
      APaintContext,
      FGhostLines[LIndex].Text,
      LHorizontalPosition,
      APaintContext.TextRect.Top +
        LIndex * APaintContext.CellSize.cy,
      False
    );
  end;
end;

procedure TRadIAOTAInlineCompletionSession.Show(
  const AContext: TRadIAInlineCompletionContext;
  const ASuggestion: string
);
var
  LView: IOTAEditView;
begin
  LView := CurrentView;
  if not Assigned(LView) or not Assigned(LView.Buffer) or
    not SameFileName(LView.Buffer.FileName, AContext.FileName) then
    Exit;
  FContext := AContext;
  FSuggestion := ASuggestion;
  FGhostLines := TRadIAInlineGhostLayout.Build(ASuggestion);
  FPaintEvidenceLogged := False;
  TLogger.Log(
    Format(
      'Ghost text prepared: lines=%d, file=%s',
      [Length(FGhostLines), TPath.GetFileName(FContext.FileName)]
    ),
    'InlineCompletion'
  );
  RegisterCurrentView;
  if Assigned(LView.Position) then
    LView.Position.Move(
      LView.Position.Row,
      LView.Position.Column
    );
  LView.Paint;
end;

procedure TRadIAOTAInlineCompletionSession.ShowAlternatives(
  const AContext: TRadIAInlineCompletionContext;
  const AAlternatives: TArray<string>;
  const ASelectedIndex: Integer
);
var
  LSelectedIndex: Integer;
  LView: IOTAEditView;
begin
  if Length(AAlternatives) = 0 then
  begin
    Clear;
    Exit;
  end;
  LSelectedIndex := EnsureRange(
    ASelectedIndex,
    0,
    Length(AAlternatives) - 1
  );
  FAlternatives := Copy(AAlternatives);
  FSelectedAlternative := LSelectedIndex;
  FPanelPaintEvidenceLogged := False;
  Show(AContext, AAlternatives[LSelectedIndex]);
  LView := CurrentView;
  if Assigned(LView) then
    LView.SetTempMsg(
      Format(
        'RadIA suggestion %d of %d. Use the editor menu to navigate, ' +
        'accept, reject, or generate another.',
        [LSelectedIndex + 1, Length(AAlternatives)]
      )
    );
end;

function TRadIAOTAInlineCompletionSession.UndoCurrentBuffer: Boolean;
var
  LView: IOTAEditView;
begin
  LView := CurrentView;
  Result := Assigned(LView) and Assigned(LView.Buffer) and
    LView.Buffer.Undo;
end;

procedure TRadIAOTAInlineCompletionSession.WatchCurrentView;
var
  LView: IOTAEditView;
begin
  if not FContinuousEnabled then
    Exit;
  LView := CurrentView;
  if Assigned(LView) then
    RegisterCurrentView;
end;

end.
