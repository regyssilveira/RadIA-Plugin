unit RadIA.OTA.InlineReviews;

interface

uses
  System.Classes,
  System.Types,
  ToolsAPI,
  ToolsAPI.Editor,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.Menus,
  Winapi.Windows,
  RadIA.Core.BlockReviews,
  RadIA.Core.BlockReviewSessions,
  RadIA.Core.InlineReviews;

type
  TRadIACodeEditorNotifier = class(TNTACodeEditorNotifier)
  protected
    function AllowedEvents: TCodeEditorEvents; override;
    function AllowedLineStages: TPaintLineStages; override;
  end;

  TRadIABlockCodeEditorNotifier = class(TNTACodeEditorNotifier)
  protected
    function AllowedEvents: TCodeEditorEvents; override;
    function AllowedGutterStages: TPaintGutterStages; override;
  end;

  TRadIAEditPaintContext = record
    View: IOTAEditView;
    LineNumber: Integer;
    Canvas: TCanvas;
    TextRect: TRect;
    LineRect: TRect;
    CellSize: TSize;
    CodeLeftEdge: Integer;
    LeftColumn: Integer;
  end;

  TRadIAOTAInlineReviewFacade = class(
    TInterfacedObject,
    IRadIAInlineReviewVisualFacade,
    IRadIABlockReviewVisualFacade
  )
  private type
    TRadIABlockReviewHitTarget = record
      Bounds: TRect;
      Block: TRadIABlockReview;
    end;
  private
    FBlockReviews: TArray<TRadIABlockReview>;
    FBlockCodeEditorNotifier: INTACodeEditorEvents;
    FBlockCodeEditorNotifierIndex: Integer;
    FBlockMenu: TPopupMenu;
    FCodeEditorNotifier: INTACodeEditorEvents;
    FCodeEditorNotifierIndex: Integer;
    FCurrentRevision: string;
    FExpectedRevision: string;
    FFileName: string;
    FObservedRevision: string;
    FReviews: TArray<TRadIAInlineReview>;
    FRepaintTimer: TTimer;
    FSmokeInvalidated: Boolean;
    FSmokePainted: Boolean;
    FSmokeBlockPainted: Boolean;
    FSmokeBlockX: Integer;
    FSmokeBlockY: Integer;
    FSmokeBlockScreenX: Integer;
    FSmokeBlockScreenY: Integer;
    FSmokeMouseHit: Boolean;
    FSmokeMouseReceived: Boolean;
    FSmokeMouseX: Integer;
    FSmokeMouseY: Integer;
    FEditorWindowHandle: HWND;
    FView: IOTAEditView;
    FHitTargets: TArray<TRadIABlockReviewHitTarget>;
    FSelectedBlock: TRadIABlockReview;
    function BlockColor(
      const ADecision: TRadIABlockReviewDecision
    ): TColor;
    function FindBlock(
      const ALineNumber: Integer;
      out ABlock: TRadIABlockReview
    ): Boolean;
    function FindHitTarget(
      const X: Integer;
      const Y: Integer;
      out ABlock: TRadIABlockReview
    ): Boolean;
    procedure StoreHitTarget(
      const AHitTarget: TRadIABlockReviewHitTarget
    );
    function ColorFor(
      const ASeverity: TRadIAInlineReviewSeverity
    ): TColor;
    function FindReview(
      const ALineNumber: Integer;
      out AReview: TRadIAInlineReview
    ): Boolean;
    function GetCellSize(
      const AContext: INTACodeEditorPaintContext
    ): TSize;
    function TryGetCurrentBuffer(
      out ABuffer: IOTAEditBuffer;
      out AFileName: string
    ): Boolean;
    procedure HandleBeginPaint(
      const AEditor: TWinControl;
      const AForceFullRepaint: Boolean
    );
    procedure HandleEndPaint(const AEditor: TWinControl);
    procedure HandleMouseUp(
      const AEditor: TWinControl;
      AButton: TMouseButton;
      AShift: TShiftState;
      X: Integer;
      Y: Integer
    );
    procedure HandlePaintGutter(
      const ARect: TRect;
      const AStage: TPaintGutterStage;
      const ABeforeEvent: Boolean;
      var AAllowDefaultPainting: Boolean;
      const AContext: INTACodeEditorPaintContext
    );
    procedure HandlePaintLine(
      const ARect: TRect;
      const AStage: TPaintLineStage;
      const ABeforeEvent: Boolean;
      var AAllowDefaultPainting: Boolean;
      const AContext: INTACodeEditorPaintContext
    );
    procedure RunOnMainThread(const AAction: TThreadProcedure);
    procedure ScheduleRepaint;
    procedure RepaintTimerTick(Sender: TObject);
    procedure WriteSmokeEvidence;
    procedure OnAcceptBlock(Sender: TObject);
    procedure OnApplyBlockSession(Sender: TObject);
    procedure OnClearBlockSession(Sender: TObject);
    procedure OnEditBlock(Sender: TObject);
    procedure OnExplainBlock(Sender: TObject);
    procedure OnRejectBlock(Sender: TObject);
    procedure OnRequestChangesBlock(Sender: TObject);
    procedure ShowBlockMenu(
      const AEditor: TWinControl;
      const X: Integer;
      const Y: Integer
    );
  protected
    procedure PaintOverlay(
      const APaintContext: TRadIAEditPaintContext
    ); virtual;
    procedure RegisterCurrentView;
    procedure UnregisterView;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowReviews(
      const AFileName: string;
      const ARevision: string;
      const AReviews: TArray<TRadIAInlineReview>
    );
    procedure ShowBlocks(
      const ABlocks: TArray<TRadIABlockReview>
    );
    procedure ClearBlocks;
    procedure ClearReviews;
    procedure Modified; virtual;
    procedure EditorIdle(const View: IOTAEditView); virtual;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.Math,
  System.SysUtils,
  Vcl.Dialogs,
  RadIA.Core.Container,
  RadIA.Core.Logger,
  RadIA.Core.Types,
  RadIA.OTA.TextReader
  {$IFNDEF TESTS},
  RadIA.UI.DiffForm
  {$ENDIF};

{ TRadIACodeEditorNotifier }

function TRadIACodeEditorNotifier.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevBeginEndPaintEvents, cevPaintLineEvents];
end;

function TRadIABlockCodeEditorNotifier.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevMouseEvents, cevPaintGutterEvents];
end;

function TRadIABlockCodeEditorNotifier.AllowedGutterStages:
  TPaintGutterStages;
begin
  Result := [pgsEndPaint];
end;

function TRadIACodeEditorNotifier.AllowedLineStages: TPaintLineStages;
begin
  Result := [plsEndPaint];
end;

constructor TRadIAOTAInlineReviewFacade.Create;
begin
  inherited;
  FBlockMenu := TPopupMenu.Create(nil);
  FRepaintTimer := TTimer.Create(nil);
  FRepaintTimer.Enabled := False;
  FRepaintTimer.Interval := 100;
  FRepaintTimer.OnTimer := RepaintTimerTick;
  FCodeEditorNotifierIndex := -1;
  FBlockCodeEditorNotifierIndex := -1;
  FSmokeInvalidated := False;
  FSmokePainted := False;
  SetLength(FBlockReviews, 0);
  SetLength(FHitTargets, 0);
  SetLength(FReviews, 0);
end;

destructor TRadIAOTAInlineReviewFacade.Destroy;
begin
  UnregisterView;
  FRepaintTimer.Free;
  FBlockMenu.Free;
  inherited;
end;

procedure TRadIAOTAInlineReviewFacade.HandleBeginPaint(
  const AEditor: TWinControl;
  const AForceFullRepaint: Boolean
);
var
  LBuffer: IOTAEditBuffer;
  LContent: string;
  LNewRevision: string;
begin
  if GIsShuttingDown then
    Exit;
  try
    if Assigned(AEditor) then
      FEditorWindowHandle := AEditor.Handle;
    if not Assigned(FView) then
    begin
      FCurrentRevision := '';
      Exit;
    end;
    LBuffer := FView.Buffer;
    if not Assigned(LBuffer) then
    begin
      FCurrentRevision := '';
      Exit;
    end;
    LContent := ReadRadIAEditReaderText(
      LBuffer.CreateReader
    );
    LNewRevision := THashSHA2.GetHashString(LContent);
    if (FObservedRevision <> '') and
      not SameText(FObservedRevision, LNewRevision) then
      Modified;
    FObservedRevision := LNewRevision;
    FCurrentRevision := LNewRevision;
  except
    on E: Exception do
    begin
      FCurrentRevision := '';
      TLogger.Log(
        'Inline review paint ignored a closing editor buffer: ' + E.Message,
        'InlineReviews'
      );
    end;
  end;
end;

procedure TRadIAOTAInlineReviewFacade.ClearReviews;
begin
  RunOnMainThread(
    procedure
    begin
      SetLength(FReviews, 0);
      FExpectedRevision := '';
      FFileName := '';
      if Assigned(FView) then
        FView.Paint;
      if Length(FBlockReviews) = 0 then
        UnregisterView;
    end
  );
end;

function TRadIAOTAInlineReviewFacade.BlockColor(
  const ADecision: TRadIABlockReviewDecision
): TColor;
begin
  case ADecision of
    brdAccepted:
      Result := TColor($0050B050);
    brdRejected:
      Result := clGray;
    brdEdited:
      Result := TColor($00C060A0);
    brdChangesRequested:
      Result := TColor($004040D0);
  else
    Result := TColor($0000A5FF);
  end;
end;

procedure TRadIAOTAInlineReviewFacade.ClearBlocks;
begin
  RunOnMainThread(
    procedure
    begin
      SetLength(FBlockReviews, 0);
      SetLength(FHitTargets, 0);
      FSmokeBlockX := 0;
      FSmokeBlockY := 0;
      if Assigned(FView) then
        FView.Paint;
      if Length(FReviews) = 0 then
        UnregisterView;
    end
  );
end;

function TRadIAOTAInlineReviewFacade.ColorFor(
  const ASeverity: TRadIAInlineReviewSeverity
): TColor;
begin
  case ASeverity of
    irsInfo:
      Result := clHighlight;
    irsWarning:
      Result := TColor($0000A5FF);
    irsError:
      Result := clRed;
  else
    Result := clGray;
  end;
end;

procedure TRadIAOTAInlineReviewFacade.EditorIdle(
  const View: IOTAEditView
);
var
  LBlock: TRadIABlockReview;
  LMessage: string;
  LReview: TRadIAInlineReview;
begin
  if GIsShuttingDown or not Assigned(View) then
    Exit;
  try
    if not Assigned(View.Position) or not Assigned(View.Buffer) then
      Exit;
    if SameFileName(View.Buffer.FileName, FFileName) and
      SameText(FCurrentRevision, FExpectedRevision) and
      FindReview(View.Position.Row, LReview) then
    begin
      LMessage := LReview.Message.Replace(#13, ' ').Replace(#10, ' ');
      View.SetTempMsg(Copy(LMessage, 1, 240));
      Exit;
    end;
    if FindBlock(View.Position.Row, LBlock) then
      View.SetTempMsg(
        'RadIA block review: click the gutter marker or use the review shortcuts.'
      );
  except
    on E: Exception do
      TLogger.Log(
        'Inline review idle ignored a closing editor view: ' + E.Message,
        'InlineReviews'
      );
  end;
end;

procedure TRadIAOTAInlineReviewFacade.HandleEndPaint(
  const AEditor: TWinControl
);
begin
  EditorIdle(FView);
end;

function TRadIAOTAInlineReviewFacade.FindReview(
  const ALineNumber: Integer;
  out AReview: TRadIAInlineReview
): Boolean;
var
  LReview: TRadIAInlineReview;
begin
  AReview := Default(TRadIAInlineReview);
  for LReview in FReviews do
  begin
    if (ALineNumber >= LReview.StartLine) and
      (ALineNumber <= LReview.EndLine) then
    begin
      AReview := LReview;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TRadIAOTAInlineReviewFacade.FindBlock(
  const ALineNumber: Integer;
  out ABlock: TRadIABlockReview
): Boolean;
var
  LBlock: TRadIABlockReview;
  LBuffer: IOTAEditBuffer;
  LFileName: string;
begin
  ABlock := Default(TRadIABlockReview);
  if not TryGetCurrentBuffer(LBuffer, LFileName) then
    Exit(False);
  for LBlock in FBlockReviews do
    if SameFileName(LBlock.TargetFile, LFileName) and
      SameText(LBlock.BaseRevision, FCurrentRevision) and
      (LBlock.OriginalStartLine = ALineNumber) then
    begin
      ABlock := LBlock;
      Exit(True);
    end;
  Result := False;
end;

function TRadIAOTAInlineReviewFacade.FindHitTarget(
  const X: Integer;
  const Y: Integer;
  out ABlock: TRadIABlockReview
): Boolean;
var
  LHit: TRadIABlockReviewHitTarget;
begin
  ABlock := Default(TRadIABlockReview);
  for LHit in FHitTargets do
    if PtInRect(LHit.Bounds, Point(X, Y)) then
    begin
      ABlock := LHit.Block;
      Exit(True);
    end;
  Result := False;
end;

function TRadIAOTAInlineReviewFacade.GetCellSize(
  const AContext: INTACodeEditorPaintContext
): TSize;
begin
  Result.cx := Max(1, AContext.Canvas.TextWidth('W'));
  Result.cy := Max(1, AContext.Canvas.TextHeight('W'));
end;

function TRadIAOTAInlineReviewFacade.TryGetCurrentBuffer(
  out ABuffer: IOTAEditBuffer;
  out AFileName: string
): Boolean;
begin
  ABuffer := nil;
  AFileName := '';
  Result := False;
  if GIsShuttingDown or not Assigned(FView) then
    Exit;
  try
    ABuffer := FView.Buffer;
    if not Assigned(ABuffer) then
      Exit;
    AFileName := ABuffer.FileName;
    Result := True;
  except
    on E: Exception do
      TLogger.Log(
        'Inline review ignored a closing editor buffer: ' + E.Message,
        'InlineReviews'
      );
  end;
end;

procedure TRadIAOTAInlineReviewFacade.Modified;
var
  LBlock: TRadIABlockReview;
  LBuffer: IOTAEditBuffer;
  LContent: string;
  LFileName: string;
  LRevision: string;
begin
  LRevision := '';
  if TryGetCurrentBuffer(LBuffer, LFileName) then
  begin
    LContent := ReadRadIAEditReaderText(LBuffer.CreateReader);
    LRevision := THashSHA2.GetHashString(LContent);
  end;
  FCurrentRevision := LRevision;
  FObservedRevision := LRevision;
  FSmokeInvalidated :=
    (FExpectedRevision <> '') and
    not SameText(FExpectedRevision, LRevision);
  for LBlock in FBlockReviews do
    if (LFileName <> '') and
      SameFileName(LBlock.TargetFile, LFileName) and
      not SameText(LBlock.BaseRevision, LRevision) then
    begin
      FSmokeInvalidated := True;
      Break;
    end;
  WriteSmokeEvidence;
end;

procedure TRadIAOTAInlineReviewFacade.HandlePaintLine(
  const ARect: TRect;
  const AStage: TPaintLineStage;
  const ABeforeEvent: Boolean;
  var AAllowDefaultPainting: Boolean;
  const AContext: INTACodeEditorPaintContext
);
var
  LBuffer: IOTAEditBuffer;
  LCellSize: TSize;
  LFileName: string;
  LPaintContext: TRadIAEditPaintContext;
  LReview: TRadIAInlineReview;
  LRight: Integer;
  LUnderlineY: Integer;
begin
  if GIsShuttingDown then
    Exit;
  try
  if ABeforeEvent or (AStage <> plsEndPaint) or
    not Assigned(AContext) or not Assigned(AContext.LineState) then
    Exit;
  LCellSize := GetCellSize(AContext);
  if TryGetCurrentBuffer(LBuffer, LFileName) and
    SameFileName(LFileName, FFileName) and
    SameText(FCurrentRevision, FExpectedRevision) and
    FindReview(AContext.LogicalLineNum, LReview) then
  begin
    AContext.Canvas.Pen.Color := ColorFor(LReview.Severity);
    AContext.Canvas.Pen.Width := 2;
    LUnderlineY := Min(
      AContext.LineState.VisibleTextRect.Bottom - 1,
      AContext.LineState.WholeRect.Bottom - 1
    );
    LRight := Min(
      Max(
        AContext.LineState.VisibleTextRect.Right,
        AContext.LineState.VisibleTextRect.Left + LCellSize.cx
      ),
      AContext.LineState.WholeRect.Right
    );
    AContext.Canvas.MoveTo(
      AContext.LineState.VisibleTextRect.Left,
      LUnderlineY
    );
    AContext.Canvas.LineTo(LRight, LUnderlineY);
    if not FSmokePainted then
    begin
      FSmokePainted := True;
      WriteSmokeEvidence;
    end;
  end;
  LPaintContext.View := AContext.EditView;
  LPaintContext.LineNumber := AContext.LogicalLineNum;
  LPaintContext.Canvas := AContext.Canvas;
  LPaintContext.TextRect := AContext.LineState.VisibleTextRect;
  LPaintContext.LineRect := AContext.LineState.WholeRect;
  LPaintContext.CellSize := LCellSize;
  LPaintContext.CodeLeftEdge := AContext.EditorState.CodeLeftEdge;
  LPaintContext.LeftColumn := AContext.EditorState.LeftColumn;
  PaintOverlay(LPaintContext);
  except
    on E: Exception do
      TLogger.Log(
        'Inline review line paint ignored a closing editor: ' + E.Message,
        'InlineReviews'
      );
  end;
end;

procedure TRadIAOTAInlineReviewFacade.HandlePaintGutter(
  const ARect: TRect;
  const AStage: TPaintGutterStage;
  const ABeforeEvent: Boolean;
  var AAllowDefaultPainting: Boolean;
  const AContext: INTACodeEditorPaintContext
);
var
  LBlock: TRadIABlockReview;
  LHit: TRadIABlockReviewHitTarget;
  LMarkerSize: Integer;
  LScreenPoint: TPoint;
begin
  if GIsShuttingDown then
    Exit;
  try
  if ABeforeEvent or (AStage <> pgsEndPaint) or
    not Assigned(AContext) or
    not FindBlock(AContext.LogicalLineNum, LBlock) then
    Exit;
  LMarkerSize := Max(6, Min(12, ARect.Height - 4));
  LHit.Bounds := Rect(
    ARect.Right - LMarkerSize - 3,
    ARect.Top + Max(2, (ARect.Height - LMarkerSize) div 2),
    ARect.Right - 3,
    ARect.Top + Max(2, (ARect.Height - LMarkerSize) div 2) + LMarkerSize
  );
  LHit.Block := LBlock;
  StoreHitTarget(LHit);
  FSmokeBlockX := (LHit.Bounds.Left + LHit.Bounds.Right) div 2;
  FSmokeBlockY := (LHit.Bounds.Top + LHit.Bounds.Bottom) div 2;
  LScreenPoint := Point(FSmokeBlockX, FSmokeBlockY);
  if (FEditorWindowHandle <> 0) and
    Winapi.Windows.ClientToScreen(FEditorWindowHandle, LScreenPoint) then
  begin
    FSmokeBlockScreenX := LScreenPoint.X;
    FSmokeBlockScreenY := LScreenPoint.Y;
  end;
  AContext.Canvas.Brush.Color := BlockColor(LBlock.Decision);
  AContext.Canvas.Pen.Color := clWindowText;
  AContext.Canvas.Rectangle(LHit.Bounds);
  if not FSmokeBlockPainted then
  begin
    FSmokeBlockPainted := True;
    WriteSmokeEvidence;
  end;
  except
    on E: Exception do
      TLogger.Log(
        'Inline review gutter paint ignored a closing editor: ' + E.Message,
        'InlineReviews'
      );
  end;
end;

procedure TRadIAOTAInlineReviewFacade.StoreHitTarget(
  const AHitTarget: TRadIABlockReviewHitTarget
);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FHitTargets) do
    if SameText(FHitTargets[LIndex].Block.Id, AHitTarget.Block.Id) then
    begin
      FHitTargets[LIndex] := AHitTarget;
      Exit;
    end;
  SetLength(FHitTargets, Length(FHitTargets) + 1);
  FHitTargets[High(FHitTargets)] := AHitTarget;
end;

procedure TRadIAOTAInlineReviewFacade.HandleMouseUp(
  const AEditor: TWinControl;
  AButton: TMouseButton;
  AShift: TShiftState;
  X: Integer;
  Y: Integer
);
begin
  FSmokeMouseReceived := True;
  FSmokeMouseX := X;
  FSmokeMouseY := Y;
  if (AButton <> mbLeft) or not FindHitTarget(X, Y, FSelectedBlock) then
  begin
    WriteSmokeEvidence;
    Exit;
  end;
  FSmokeMouseHit := True;
  WriteSmokeEvidence;
  ShowBlockMenu(AEditor, X, Y);
end;

procedure TRadIAOTAInlineReviewFacade.PaintOverlay(
  const APaintContext: TRadIAEditPaintContext
);
begin
  // Descendants may add editor decorations through the compact paint context.
end;

procedure TRadIAOTAInlineReviewFacade.OnAcceptBlock(Sender: TObject);
var
  LResult: TRadIABlockReviewSessionResult;
  LSession: IRadIABlockReviewSession;
begin
  if not TRadIAContainer.TryResolve<IRadIABlockReviewSession>(LSession) then
    Exit;
  LResult := LSession.Decide(
    FSelectedBlock.Id,
    brdAccepted
  );
  if not LResult.Success then
    ShowMessage('The review block could not be accepted: ' +
      LResult.ErrorMessage);
end;

procedure TRadIAOTAInlineReviewFacade.OnApplyBlockSession(Sender: TObject);
var
  LResult: TRadIABlockReviewSessionResult;
  LSession: IRadIABlockReviewSession;
begin
  if not TRadIAContainer.TryResolve<IRadIABlockReviewSession>(LSession) then
    Exit;
  LResult := LSession.Apply;
  if not LResult.Success then
    ShowMessage('The review session could not be applied: ' +
      LResult.ErrorMessage);
end;

procedure TRadIAOTAInlineReviewFacade.OnClearBlockSession(Sender: TObject);
var
  LSession: IRadIABlockReviewSession;
begin
  if TRadIAContainer.TryResolve<IRadIABlockReviewSession>(LSession) and
    (MessageDlg(
      'Discard every pending block review without changing files?',
      mtConfirmation,
      [mbYes, mbNo],
      0
    ) = mrYes) then
    LSession.Clear;
end;

procedure TRadIAOTAInlineReviewFacade.OnEditBlock(Sender: TObject);
{$IFNDEF TESTS}
var
  LForm: TRadIAFormAIDiff;
  LResult: TRadIABlockReviewSessionResult;
  LSession: IRadIABlockReviewSession;
{$ENDIF}
begin
  {$IFNDEF TESTS}
  if not TRadIAContainer.TryResolve<IRadIABlockReviewSession>(LSession) then
    Exit;
  LForm := TRadIAFormAIDiff.Create(nil);
  try
    LForm.InitializePreparedDiff(
      FSelectedBlock.TargetFile,
      FSelectedBlock.OriginalText,
      FSelectedBlock.ProposedText
    );
    if LForm.ShowModal <> mrOk then
      Exit;
    LResult := LSession.Decide(
      FSelectedBlock.Id,
      brdEdited,
      LForm.SuggestedCode
    );
    if not LResult.Success then
      ShowMessage('The edited block could not be saved: ' +
        LResult.ErrorMessage);
  finally
    LForm.Free;
  end;
  {$ENDIF}
end;

procedure TRadIAOTAInlineReviewFacade.OnExplainBlock(Sender: TObject);
begin
  ShowMessage(
    'Review block at line ' +
    FSelectedBlock.OriginalStartLine.ToString + sLineBreak +
    'Original lines: ' + FSelectedBlock.OriginalLineCount.ToString +
    sLineBreak + 'Proposed lines: ' +
    FSelectedBlock.ProposedLineCount.ToString + sLineBreak +
    'The block remains revision-bound until the session is applied.'
  );
end;

procedure TRadIAOTAInlineReviewFacade.OnRejectBlock(Sender: TObject);
var
  LResult: TRadIABlockReviewSessionResult;
  LSession: IRadIABlockReviewSession;
begin
  if not TRadIAContainer.TryResolve<IRadIABlockReviewSession>(LSession) then
    Exit;
  LResult := LSession.Decide(
    FSelectedBlock.Id,
    brdRejected
  );
  if not LResult.Success then
    ShowMessage('The review block could not be rejected: ' +
      LResult.ErrorMessage);
end;

procedure TRadIAOTAInlineReviewFacade.OnRequestChangesBlock(Sender: TObject);
var
  LComment: string;
  LResult: TRadIABlockReviewSessionResult;
  LSession: IRadIABlockReviewSession;
begin
  LComment := FSelectedBlock.Comment;
  if not InputQuery(
    'Request changes',
    'Explain what must change before this block can be accepted:',
    LComment
  ) then
    Exit;
  if not TRadIAContainer.TryResolve<IRadIABlockReviewSession>(LSession) then
    Exit;
  LResult := LSession.Decide(
    FSelectedBlock.Id,
    brdChangesRequested,
    '',
    LComment
  );
  if not LResult.Success then
    ShowMessage(
      'The change request could not be saved: ' + LResult.ErrorMessage
    );
end;

procedure TRadIAOTAInlineReviewFacade.ShowBlockMenu(
  const AEditor: TWinControl;
  const X: Integer;
  const Y: Integer
);
var
  LItem: TMenuItem;
  LScreenPoint: TPoint;

  procedure AddItem(
    const ACaption: string;
    const AHandler: TNotifyEvent
  );
  begin
    LItem := TMenuItem.Create(FBlockMenu);
    LItem.Caption := ACaption;
    LItem.OnClick := AHandler;
    FBlockMenu.Items.Add(LItem);
  end;

begin
  FBlockMenu.Items.Clear;
  AddItem('&Accept block', OnAcceptBlock);
  AddItem('&Reject block', OnRejectBlock);
  AddItem('Request &changes...', OnRequestChangesBlock);
  AddItem('&Edit block...', OnEditBlock);
  AddItem('E&xplain block', OnExplainBlock);
  AddItem('-', nil);
  AddItem('A&pply resolved review', OnApplyBlockSession);
  AddItem('&Discard review session', OnClearBlockSession);
  LScreenPoint := AEditor.ClientToScreen(Point(X, Y));
  FBlockMenu.Popup(LScreenPoint.X, LScreenPoint.Y);
end;

procedure TRadIAOTAInlineReviewFacade.RegisterCurrentView;
var
  LBlockNotifier: TRadIABlockCodeEditorNotifier;
  LCodeEditorServices: INTACodeEditorServices;
  LNotifier: TRadIACodeEditorNotifier;
  LEditorServices: IOTAEditorServices;
  LView: IOTAEditView;
begin
  if not Supports(
    BorlandIDEServices,
    IOTAEditorServices,
    LEditorServices
  ) then
    Exit;
  LView := LEditorServices.TopView;
  if not Assigned(LView) then
    Exit;
  if not Assigned(FView) or not FView.SameView(LView) then
    FObservedRevision := '';
  FView := LView;
  if Assigned(FCodeEditorNotifier) then
    Exit;
  if not Supports(
    BorlandIDEServices,
    INTACodeEditorServices,
    LCodeEditorServices
  ) then
    Exit;
  LNotifier := TRadIACodeEditorNotifier.Create;
  LNotifier.OnEditorBeginPaint := HandleBeginPaint;
  LNotifier.OnEditorEndPaint := HandleEndPaint;
  LNotifier.OnEditorPaintLine := HandlePaintLine;
  FCodeEditorNotifier := LNotifier;
  FCodeEditorNotifierIndex := LCodeEditorServices.AddEditorEventsNotifier(
    FCodeEditorNotifier
  );
  LBlockNotifier := TRadIABlockCodeEditorNotifier.Create;
  LBlockNotifier.OnEditorMouseUp := HandleMouseUp;
  LBlockNotifier.OnEditorPaintGutter := HandlePaintGutter;
  FBlockCodeEditorNotifier := LBlockNotifier;
  FBlockCodeEditorNotifierIndex :=
    LCodeEditorServices.AddEditorEventsNotifier(FBlockCodeEditorNotifier);
end;

procedure TRadIAOTAInlineReviewFacade.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    Exit;
  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

procedure TRadIAOTAInlineReviewFacade.ShowReviews(
  const AFileName: string;
  const ARevision: string;
  const AReviews: TArray<TRadIAInlineReview>
);
var
  LContent: string;
  LCurrentRevision: string;
  LReviews: TArray<TRadIAInlineReview>;
begin
  LReviews := Copy(AReviews);
  LCurrentRevision := '';
  RunOnMainThread(
    procedure
    begin
      FFileName := AFileName;
      FExpectedRevision := ARevision;
      FReviews := LReviews;
      FSmokeInvalidated := False;
      FSmokePainted := False;
      RegisterCurrentView;
      ScheduleRepaint;
      if Assigned(FView) and Assigned(FView.Buffer) and
        SameFileName(FView.Buffer.FileName, FFileName) then
      begin
        LContent := ReadRadIAEditReaderText(
          FView.Buffer.CreateReader
        );
        LCurrentRevision := THashSHA2.GetHashString(LContent);
      end;
      FCurrentRevision := LCurrentRevision;
      FObservedRevision := LCurrentRevision;
      WriteSmokeEvidence;
      if Assigned(FView) then
      begin
        if Assigned(FView.Position) then
          FView.Position.Move(
            FView.Position.Row,
            FView.Position.Column
          );
        FView.Paint;
      end;
    end
  );
end;

procedure TRadIAOTAInlineReviewFacade.ScheduleRepaint;
begin
  if not GIsShuttingDown and Assigned(FRepaintTimer) then
  begin
    FRepaintTimer.Enabled := False;
    FRepaintTimer.Enabled := True;
  end;
end;

procedure TRadIAOTAInlineReviewFacade.RepaintTimerTick(Sender: TObject);
begin
  FRepaintTimer.Enabled := False;
  if not GIsShuttingDown and Assigned(FView) then
    FView.Paint;
end;

procedure TRadIAOTAInlineReviewFacade.ShowBlocks(
  const ABlocks: TArray<TRadIABlockReview>
);
var
  LBlocks: TArray<TRadIABlockReview>;
begin
  LBlocks := Copy(ABlocks);
  RunOnMainThread(
    procedure
    begin
      FBlockReviews := LBlocks;
      FSmokeBlockPainted := False;
      FSmokeBlockX := 0;
      FSmokeBlockY := 0;
      FSmokeBlockScreenX := 0;
      FSmokeBlockScreenY := 0;
      FSmokeMouseHit := False;
      FSmokeMouseReceived := False;
      FSmokeMouseX := 0;
      FSmokeMouseY := 0;
      RegisterCurrentView;
      ScheduleRepaint;
      WriteSmokeEvidence;
      if Assigned(FView) then
        FView.Paint;
    end
  );
end;

procedure TRadIAOTAInlineReviewFacade.UnregisterView;
var
  LCodeEditorServices: INTACodeEditorServices;
begin
  if (FCodeEditorNotifierIndex >= 0) and not GIsShuttingDown and
    Supports(
      BorlandIDEServices,
      INTACodeEditorServices,
      LCodeEditorServices
    ) then
  begin
    try
      LCodeEditorServices.RemoveEditorEventsNotifier(
        FCodeEditorNotifierIndex
      );
      if FBlockCodeEditorNotifierIndex >= 0 then
        LCodeEditorServices.RemoveEditorEventsNotifier(
          FBlockCodeEditorNotifierIndex
        );
    except
      on E: Exception do
        TLogger.Log(
          'Inline review notifier removal failed: ' + E.Message,
          'Warning'
        );
    end;
  end;
  FCodeEditorNotifier := nil;
  FCodeEditorNotifierIndex := -1;
  FBlockCodeEditorNotifier := nil;
  FBlockCodeEditorNotifierIndex := -1;
  FView := nil;
end;

procedure TRadIAOTAInlineReviewFacade.WriteSmokeEvidence;
var
  LEvidencePath: string;
  LJson: TJSONObject;
begin
  LEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_INLINE_REVIEW')
  );
  if (LEvidencePath = '') or SameText(LEvidencePath, '1') then
    Exit;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('published', TJSONBool.Create(Length(FReviews) > 0));
    LJson.AddPair('painted', TJSONBool.Create(FSmokePainted));
    LJson.AddPair('invalidated', TJSONBool.Create(FSmokeInvalidated));
    LJson.AddPair('reviewCount', TJSONNumber.Create(Length(FReviews)));
    LJson.AddPair(
      'lineNotifierIndex',
      TJSONNumber.Create(FCodeEditorNotifierIndex)
    );
    LJson.AddPair(
      'blockNotifierIndex',
      TJSONNumber.Create(FBlockCodeEditorNotifierIndex)
    );
    LJson.AddPair(
      'blockPublished',
      TJSONBool.Create(Length(FBlockReviews) > 0)
    );
    LJson.AddPair('blockPainted', TJSONBool.Create(FSmokeBlockPainted));
    LJson.AddPair('blockMarkerX', TJSONNumber.Create(FSmokeBlockX));
    LJson.AddPair('blockMarkerY', TJSONNumber.Create(FSmokeBlockY));
    LJson.AddPair(
      'blockMarkerScreenX',
      TJSONNumber.Create(FSmokeBlockScreenX)
    );
    LJson.AddPair(
      'blockMarkerScreenY',
      TJSONNumber.Create(FSmokeBlockScreenY)
    );
    LJson.AddPair('blockMouseReceived', TJSONBool.Create(FSmokeMouseReceived));
    LJson.AddPair('blockMouseHit', TJSONBool.Create(FSmokeMouseHit));
    LJson.AddPair('blockMouseX', TJSONNumber.Create(FSmokeMouseX));
    LJson.AddPair('blockMouseY', TJSONNumber.Create(FSmokeMouseY));
    LJson.AddPair(
      'blockCount',
      TJSONNumber.Create(Length(FBlockReviews))
    );
    LJson.AddPair('expectedRevision', FExpectedRevision);
    LJson.AddPair('currentRevision', FCurrentRevision);
    if Assigned(FView) and Assigned(FView.Buffer) then
      LJson.AddPair('viewFileName', FView.Buffer.FileName)
    else
      LJson.AddPair('viewFileName', '');
    LJson.AddPair(
      'revisionMatched',
      TJSONBool.Create(
        (FCurrentRevision <> '') and
        SameText(FCurrentRevision, FExpectedRevision)
      )
    );
    TDirectory.CreateDirectory(
      ExtractFilePath(LEvidencePath)
    );
    TFile.WriteAllText(
      LEvidencePath,
      LJson.ToJSON,
      TEncoding.UTF8
    );
  finally
    LJson.Free;
  end;
end;

end.
