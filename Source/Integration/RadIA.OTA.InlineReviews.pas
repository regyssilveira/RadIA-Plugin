unit RadIA.OTA.InlineReviews;

interface

uses
  System.Classes,
  System.Types,
  ToolsAPI,
  ToolsAPI.Editor,
  Vcl.Controls,
  Vcl.Graphics,
  RadIA.Core.InlineReviews;

type
  TRadIACodeEditorNotifier = class(TNTACodeEditorNotifier)
  protected
    function AllowedEvents: TCodeEditorEvents; override;
    function AllowedLineStages: TPaintLineStages; override;
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
    IRadIAInlineReviewVisualFacade
  )
  private
    FCodeEditorNotifier: INTACodeEditorEvents;
    FCodeEditorNotifierIndex: Integer;
    FCurrentRevision: string;
    FExpectedRevision: string;
    FFileName: string;
    FObservedRevision: string;
    FReviews: TArray<TRadIAInlineReview>;
    FSmokeInvalidated: Boolean;
    FSmokePainted: Boolean;
    FView: IOTAEditView;
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
    procedure HandleBeginPaint(
      const AEditor: TWinControl;
      const AForceFullRepaint: Boolean
    );
    procedure HandleEndPaint(const AEditor: TWinControl);
    procedure HandlePaintLine(
      const ARect: TRect;
      const AStage: TPaintLineStage;
      const ABeforeEvent: Boolean;
      var AAllowDefaultPainting: Boolean;
      const AContext: INTACodeEditorPaintContext
    );
    procedure RunOnMainThread(const AAction: TThreadProcedure);
    procedure WriteSmokeEvidence;
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
  Winapi.Windows,
  RadIA.Core.Logger,
  RadIA.Core.Types,
  RadIA.OTA.TextReader;

{ TRadIACodeEditorNotifier }

function TRadIACodeEditorNotifier.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevBeginEndPaintEvents, cevPaintLineEvents];
end;

function TRadIACodeEditorNotifier.AllowedLineStages: TPaintLineStages;
begin
  Result := [plsEndPaint];
end;

constructor TRadIAOTAInlineReviewFacade.Create;
begin
  inherited;
  FCodeEditorNotifierIndex := -1;
  FSmokeInvalidated := False;
  FSmokePainted := False;
  SetLength(FReviews, 0);
end;

destructor TRadIAOTAInlineReviewFacade.Destroy;
begin
  UnregisterView;
  inherited;
end;

procedure TRadIAOTAInlineReviewFacade.HandleBeginPaint(
  const AEditor: TWinControl;
  const AForceFullRepaint: Boolean
);
var
  LContent: string;
  LNewRevision: string;
begin
  if not Assigned(FView) or not Assigned(FView.Buffer) then
  begin
    FCurrentRevision := '';
    Exit;
  end;
  LContent := ReadRadIAEditReaderText(
    FView.Buffer.CreateReader
  );
  LNewRevision := THashSHA2.GetHashString(LContent);
  if (FObservedRevision <> '') and
    not SameText(FObservedRevision, LNewRevision) then
    Modified;
  FObservedRevision := LNewRevision;
  if SameFileName(FView.Buffer.FileName, FFileName) then
    FCurrentRevision := LNewRevision
  else
    FCurrentRevision := '';
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

function TRadIAOTAInlineReviewFacade.GetCellSize(
  const AContext: INTACodeEditorPaintContext
): TSize;
begin
  Result.cx := Max(1, AContext.Canvas.TextWidth('W'));
  Result.cy := Max(1, AContext.Canvas.TextHeight('W'));
end;

procedure TRadIAOTAInlineReviewFacade.Modified;
begin
  FCurrentRevision := '';
  FSmokeInvalidated := True;
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
  LCellSize: TSize;
  LPaintContext: TRadIAEditPaintContext;
  LReview: TRadIAInlineReview;
  LRight: Integer;
  LUnderlineY: Integer;
begin
  if ABeforeEvent or (AStage <> plsEndPaint) or
    not Assigned(AContext) or not Assigned(AContext.LineState) then
    Exit;
  LCellSize := GetCellSize(AContext);
  if SameText(FCurrentRevision, FExpectedRevision) and
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
end;

procedure TRadIAOTAInlineReviewFacade.PaintOverlay(
  const APaintContext: TRadIAEditPaintContext
);
begin
  // Descendants may add editor decorations through the compact paint context.
end;

procedure TRadIAOTAInlineReviewFacade.RegisterCurrentView;
var
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
