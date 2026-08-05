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
    procedure WatchCurrentView;
  end;

  TRadIAOTAInlineCompletionSession = class(
    TRadIAOTAInlineReviewFacade,
    IRadIAInlineCompletionView,
    IRadIAOTAInlineCompletionSession
  )
  private
    FContext: TRadIAInlineCompletionContext;
    FContinuousEnabled: Boolean;
    FIdleHandler: TRadIAInlineCompletionIdleHandler;
    FSuggestion: string;
    function CurrentView: IOTAEditView;
    function FirstSuggestionLine: string;
    function LanguageForFile(const AFileName: string): string;
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
  Vcl.Graphics,
  RadIA.Core.Container,
  RadIA.Core.IDENavigation,
  RadIA.Core.Interfaces,
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
  LSymbol: TRadIAUnitSymbol;
  LSymbolName: string;
  LSuffix: string;
  LView: IOTAEditView;
  LEditorAdapter: IRadIAEditorAdapter;
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
  LSymbolName := '';
  if TRadIAUnitSymbolScanner.TryFindAtLine(
    LContent,
    LView.Position.Row,
    LSymbol
  ) then
  begin
    LSymbolName := LSymbol.Name;
    LProjectContext := LProjectContext + sLineBreak +
      'Current symbol: ' + LSymbol.Kind + ' ' + LSymbol.Name +
      ' at line ' + LSymbol.Line.ToString;
  end;
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
  FSuggestion := '';
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
      'RadIA Ghost Text: accept, reject, or request an alternative ' +
      'from the RadIA editor menu.'
    )
  else if FContinuousEnabled and Assigned(FIdleHandler) then
    FIdleHandler();
end;

function TRadIAOTAInlineCompletionSession.FirstSuggestionLine: string;
var
  LBreakIndex: Integer;
begin
  Result := FSuggestion;
  LBreakIndex := Result.IndexOfAny([#13, #10]);
  if LBreakIndex >= 0 then
    Result := Result.Substring(0, LBreakIndex);
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
  FSuggestion := '';
  FContext := Default(TRadIAInlineCompletionContext);
end;

procedure TRadIAOTAInlineCompletionSession.PaintOverlay(
  const APaintContext: TRadIAEditPaintContext
);
var
  LBrushStyle: TBrushStyle;
  LColor: TColor;
  LHorizontalPosition: Integer;
  LSuggestionLine: string;
begin
  if (FSuggestion = '') or
    (APaintContext.LineNumber <> FContext.CursorLine) then
    Exit;
  LSuggestionLine := FirstSuggestionLine;
  if LSuggestionLine = '' then
    Exit;
  LHorizontalPosition := APaintContext.TextRect.Left +
    (Max(1, FContext.CursorColumn) - 1) *
    APaintContext.CellSize.cx;
  if LHorizontalPosition >= APaintContext.LineRect.Right then
    Exit;

  LColor := APaintContext.Canvas.Font.Color;
  LBrushStyle := APaintContext.Canvas.Brush.Style;
  try
    APaintContext.Canvas.Font.Color := clGrayText;
    APaintContext.Canvas.Brush.Style := bsClear;
    APaintContext.Canvas.TextRect(
      APaintContext.LineRect,
      LHorizontalPosition,
      APaintContext.TextRect.Top,
      LSuggestionLine
    );
  finally
    APaintContext.Canvas.Brush.Style := LBrushStyle;
    APaintContext.Canvas.Font.Color := LColor;
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
  RegisterCurrentView;
  LView.Paint;
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
