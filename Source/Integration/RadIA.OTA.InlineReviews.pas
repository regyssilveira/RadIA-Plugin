unit RadIA.OTA.InlineReviews;

interface

uses
  System.Classes,
  System.Types,
  ToolsAPI,
  Vcl.Graphics,
  RadIA.Core.InlineReviews;

type
  TRadIAEditPaintContext = record
    View: IOTAEditView;
    LineNumber: Integer;
    Canvas: TCanvas;
    TextRect: TRect;
    LineRect: TRect;
    CellSize: TSize;
  end;

  TRadIAOTAInlineReviewFacade = class(
    TInterfacedObject,
    IRadIAInlineReviewVisualFacade,
    INTAEditViewNotifier
  )
  private
    FCurrentRevision: string;
    FExpectedRevision: string;
    FFileName: string;
    FReviews: TArray<TRadIAInlineReview>;
    FView: IOTAEditView;
    FViewNotifierIndex: Integer;
    function ColorFor(
      const ASeverity: TRadIAInlineReviewSeverity
    ): TColor;
    function FindReview(
      const ALineNumber: Integer;
      out AReview: TRadIAInlineReview
    ): Boolean;
    procedure RegisterCurrentView;
    procedure RunOnMainThread(const AAction: TThreadProcedure);
    procedure UnregisterView;
  protected
    procedure PaintOverlay(
      const APaintContext: TRadIAEditPaintContext
    ); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowReviews(
      const AFileName: string;
      const ARevision: string;
      const AReviews: TArray<TRadIAInlineReview>
    );
    procedure ClearReviews;
    procedure AfterSave; virtual;
    procedure BeforeSave; virtual;
    procedure Destroyed; virtual;
    procedure Modified; virtual;
    procedure EditorIdle(const View: IOTAEditView); virtual;
    procedure BeginPaint(
      const View: IOTAEditView;
      var FullRepaint: Boolean
    ); virtual;
    procedure PaintLine(
      const View: IOTAEditView;
      LineNumber: Integer;
      const LineText: PAnsiChar;
      const TextWidth: Word;
      const LineAttributes: TOTAAttributeArray;
      const Canvas: TCanvas;
      const TextRect: TRect;
      const LineRect: TRect;
      const CellSize: TSize
    ); virtual;
    procedure EndPaint(const View: IOTAEditView); virtual;
  end;

implementation

uses
  System.Hash,
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.Logger,
  RadIA.Core.Types,
  RadIA.OTA.TextReader;

constructor TRadIAOTAInlineReviewFacade.Create;
begin
  inherited;
  FViewNotifierIndex := -1;
  SetLength(FReviews, 0);
end;

destructor TRadIAOTAInlineReviewFacade.Destroy;
begin
  UnregisterView;
  inherited;
end;

procedure TRadIAOTAInlineReviewFacade.Destroyed;
begin
  FViewNotifierIndex := -1;
  FView := nil;
end;

procedure TRadIAOTAInlineReviewFacade.AfterSave;
begin
  // No action is required for edit view save notifications.
end;

procedure TRadIAOTAInlineReviewFacade.BeforeSave;
begin
  // No action is required before saving an edit view.
end;

procedure TRadIAOTAInlineReviewFacade.BeginPaint(
  const View: IOTAEditView;
  var FullRepaint: Boolean
);
var
  LContent: string;
begin
  FCurrentRevision := '';
  if not Assigned(View) or not Assigned(View.Buffer) or
    not SameFileName(View.Buffer.FileName, FFileName) then
    Exit;
  LContent := ReadRadIAEditReaderText(
    View.Buffer.CreateReader
  );
  FCurrentRevision := THashSHA2.GetHashString(LContent);
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
  LMessage: string;
  LReview: TRadIAInlineReview;
begin
  if not Assigned(View) or not Assigned(View.Position) or
    not SameText(FCurrentRevision, FExpectedRevision) or
    not FindReview(View.Position.Row, LReview) then
    Exit;
  LMessage := LReview.Message.Replace(#13, ' ').Replace(#10, ' ');
  View.SetTempMsg(Copy(LMessage, 1, 240));
end;

procedure TRadIAOTAInlineReviewFacade.EndPaint(
  const View: IOTAEditView
);
begin
  // Paint state contains only scalar data and needs no cleanup.
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

procedure TRadIAOTAInlineReviewFacade.Modified;
begin
  FCurrentRevision := '';
end;

procedure TRadIAOTAInlineReviewFacade.PaintLine(
  const View: IOTAEditView;
  LineNumber: Integer;
  const LineText: PAnsiChar;
  const TextWidth: Word;
  const LineAttributes: TOTAAttributeArray;
  const Canvas: TCanvas;
  const TextRect: TRect;
  const LineRect: TRect;
  const CellSize: TSize
);
var
  LPaintContext: TRadIAEditPaintContext;
  LReview: TRadIAInlineReview;
  LRight: Integer;
  LUnderlineY: Integer;
begin
  if SameText(FCurrentRevision, FExpectedRevision) and
    FindReview(LineNumber, LReview) then
  begin
    Canvas.Pen.Color := ColorFor(LReview.Severity);
    Canvas.Pen.Width := 2;
    LUnderlineY := Min(TextRect.Bottom - 1, LineRect.Bottom - 1);
    LRight := TextRect.Left + (TextWidth * CellSize.cx);
    LRight := Min(Max(LRight, TextRect.Left + CellSize.cx), LineRect.Right);
    Canvas.MoveTo(TextRect.Left, LUnderlineY);
    Canvas.LineTo(LRight, LUnderlineY);
  end;
  LPaintContext.View := View;
  LPaintContext.LineNumber := LineNumber;
  LPaintContext.Canvas := Canvas;
  LPaintContext.TextRect := TextRect;
  LPaintContext.LineRect := LineRect;
  LPaintContext.CellSize := CellSize;
  PaintOverlay(LPaintContext);
end;

procedure TRadIAOTAInlineReviewFacade.PaintOverlay(
  const APaintContext: TRadIAEditPaintContext
);
begin
  // Descendants may add editor decorations through the compact paint context.
end;

procedure TRadIAOTAInlineReviewFacade.RegisterCurrentView;
var
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
  if Assigned(FView) and (FView = LView) then
    Exit;
  UnregisterView;
  FView := LView;
  FViewNotifierIndex := FView.AddNotifier(Self);
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
  LReviews: TArray<TRadIAInlineReview>;
begin
  LReviews := Copy(AReviews);
  RunOnMainThread(
    procedure
    begin
      FFileName := AFileName;
      FExpectedRevision := ARevision;
      FReviews := LReviews;
      RegisterCurrentView;
      if Assigned(FView) then
        FView.Paint;
    end
  );
end;

procedure TRadIAOTAInlineReviewFacade.UnregisterView;
begin
  if Assigned(FView) and (FViewNotifierIndex >= 0) and
    not GIsShuttingDown then
  begin
    try
      FView.RemoveNotifier(FViewNotifierIndex);
    except
      on E: Exception do
        TLogger.Log(
          'Inline review notifier removal failed: ' + E.Message,
          'Warning'
        );
    end;
  end;
  FViewNotifierIndex := -1;
  FView := nil;
end;

end.
