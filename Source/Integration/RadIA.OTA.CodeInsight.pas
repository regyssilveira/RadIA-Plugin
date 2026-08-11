unit RadIA.OTA.CodeInsight;

interface

uses
  ToolsAPI,
  RadIA.Core.InlineCompletion,
  RadIA.OTA.InlineCompletion;

type
  TRadIACodeInsightRegistration = class
  private
    FEnabled: Boolean;
    FIndex: Integer;
    FManager: IOTACodeInsightManager;
    FProvider: IRadIAInlineCompletionProvider;
    FSession: IRadIAOTAInlineCompletionSession;
  public
    constructor Create(
      const AProvider: IRadIAInlineCompletionProvider;
      const ASession: IRadIAOTAInlineCompletionSession;
      const AEnabled: Boolean
    );
    destructor Destroy; override;
    function Install: Boolean;
    procedure Uninstall;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.SysUtils,
  System.SyncObjs,
  RadIA.Core.Logger;

type
  IRadIACodeInsightCancellation = interface(
    IRadIAInlineCompletionCancellationToken
  )
    ['{4C443668-14EC-4C56-A376-52147A0A57E0}']
    procedure Cancel;
  end;

  IRadIACodeInsightLifecycle = interface
    ['{178188EB-2FD0-48BC-9C98-840D740DA554}']
    procedure Stop;
  end;

  TRadIACodeInsightCancellation = class(
    TInterfacedObject,
    IRadIAInlineCompletionCancellationToken,
    IRadIACodeInsightCancellation
  )
  private
    FCanceled: Integer;
  public
    procedure Cancel;
    function IsCancellationRequested: Boolean;
  end;

  TRadIACodeInsightRequest = class
  private
    FCallback: TOTACodeCompleteCallBack;
    FCancellation: IRadIACodeInsightCancellation;
    FContext: TRadIAInlineCompletionContext;
    FError: string;
    FId: Integer;
    FKeepAlive: IRadIACodeInsightLifecycle;
    FSuggestion: string;
  public
    constructor Create(
      const AId: Integer;
      const AContext: TRadIAInlineCompletionContext;
      const ACancellation: IRadIACodeInsightCancellation;
      const ACallback: TOTACodeCompleteCallBack;
      const AKeepAlive: IRadIACodeInsightLifecycle
    );
    destructor Destroy; override;
    procedure SetResult(const ASuggestion, AError: string);
    property Callback: TOTACodeCompleteCallBack read FCallback;
    property Cancellation: IRadIACodeInsightCancellation read FCancellation;
    property Context: TRadIAInlineCompletionContext read FContext;
    property Error: string read FError;
    property Id: Integer read FId;
    property Suggestion: string read FSuggestion;
  end;

  TRadIACodeInsightSymbolList = class(
    TInterfacedObject,
    IOTACodeInsightSymbolList,
    IOTACodeInsightSymbolList80
  )
  private
    FFilter: string;
    FSortOrder: TOTASortOrder;
    FSuggestion: string;
  public
    procedure Clear;
    function FindIdent(const AnIdent: string): Integer;
    function FindSymIndex(const Ident: string; var Index: Integer): Boolean;
    function GetCount: Integer;
    function GetProcDispatchFlags(I: Integer): TOTAProcDispatchFlags;
    function GetSortOrder: TOTASortOrder;
    function GetSymbolClassText(I: Integer): string;
    function GetSymbolDocumentation(I: Integer): string;
    function GetSymbolIsAbstract(I: Integer): Boolean;
    function GetSymbolIsReadWrite(I: Integer): Boolean;
    function GetSymbolText(Index: Integer): string;
    function GetSymbolTypeText(Index: Integer): string;
    function GetViewerSymbolFlags(I: Integer): TOTAViewerSymbolFlags;
    function GetViewerVisibilityFlags(I: Integer): TOTAViewerVisibilityFlags;
    procedure SetFilter(const FilterText: string);
    procedure SetSortOrder(const Value: TOTASortOrder);
    procedure SetSuggestion(const AValue: string);
  end;

  TRadIACodeInsightManager = class(
    TInterfacedObject,
    IOTACodeInsightManager,
    IOTAAsyncCodeInsightManager,
    IRadIACodeInsightLifecycle
  )
  private
    FActiveCancellation: IRadIACodeInsightCancellation;
    FActiveId: Integer;
    FEnabled: Boolean;
    FLock: TObject;
    FNextId: Integer;
    FProvider: IRadIAInlineCompletionProvider;
    FSession: IRadIAOTAInlineCompletionSession;
    FStopping: Integer;
    FSymbols: TRadIACodeInsightSymbolList;
    FSymbolList: IOTACodeInsightSymbolList;
    procedure CompleteRequest(const ARequest: TRadIACodeInsightRequest);
    procedure ExecuteRequest(const ARequest: TRadIACodeInsightRequest);
    function IsStopping: Boolean;
    function NewRequestId: Integer;
    function NormalizeSuggestion(const AValue: string): string;
  public
    constructor Create(
      const AProvider: IRadIAInlineCompletionProvider;
      const ASession: IRadIAOTAInlineCompletionSession;
      const AEnabled: Boolean
    );
    destructor Destroy; override;
    procedure AllowCodeInsight(var Allow: Boolean; const Key: Char);
    procedure AsyncAllowCodeInsight(var AAllow: Boolean; const AKey: Char);
    function AsyncCanInvoke(AInsightType: TOTACodeInsightType): Boolean;
    function AsyncEnabled: Boolean;
    function AsyncGetHintText(
      HintLine, HintCol: Integer;
      ACallBack: TOTAHintTextCallBack
    ): Integer;
    function AsyncGotoDefinition(
      const AFileName: string;
      ALine, ACharIndex: Integer;
      ACallBack: TOTAGotoDefinitionCallBack
    ): Integer;
    function AsyncInvokeCodeCompletion(
      AHowInvoked: TOTAInvokeType;
      var AStr: string;
      ALine, ACharIndex: Integer;
      ACallback: TOTACodeCompleteCallBack
    ): Integer;
    function AsyncInvokeParameterCodeInsight(
      HowInvoked: TOTAInvokeType;
      const AFileName: string;
      ALine, ACharIndex: Integer;
      ACallback: TOTAParametersCallBack
    ): Integer;
    procedure AsyncOperationCanceled(AId: Integer);
    procedure AsyncParameterCodeInsightParamIndex(
      const AFileName: string;
      ALine, ACharIndex: Integer;
      ACallBack: TOTAParamIndexCallBack
    );
    procedure Done(Accepted: Boolean; out DisplayParams: Boolean);
    function EditorTokenValidChars(PreValidating: Boolean): TSysCharSet;
    function GetEnabled: Boolean;
    function GetIDString: string;
    function GetLongestItem: string;
    function GetMultiSelect: Boolean;
    function GetName: string;
    function GetOptionSetName: string;
    procedure GetCodeInsightType(
      AChar: Char;
      AElement: Integer;
      out CodeInsightType: TOTACodeInsightType;
      out InvokeType: TOTAInvokeType
    );
    function GetHintText(HintLine, HintCol: Integer): string;
    procedure GetParameterList(
      out ParameterList: IOTACodeInsightParameterList
    );
    procedure GetSymbolList(out SymbolList: IOTACodeInsightSymbolList);
    function GotoDefinition(
      out AFileName: string;
      out ALineNum: Integer;
      Index: Integer = -1
    ): Boolean;
    function HandlesFile(const AFileName: string): Boolean;
    function InvokeCodeCompletion(
      HowInvoked: TOTAInvokeType;
      var Str: string
    ): Boolean;
    function InvokeParameterCodeInsight(
      HowInvoked: TOTAInvokeType;
      var SelectedIndex: Integer
    ): Boolean;
    function IsViewerBrowsable(Index: Integer): Boolean;
    procedure OnEditorKey(
      Key: Char;
      var CloseViewer: Boolean;
      var Accept: Boolean
    );
    procedure ParameterCodeInsightAnchorPos(var EdPos: TOTAEditPos);
    function ParameterCodeInsightParamIndex(EdPos: TOTAEditPos): Integer;
    function PreValidateCodeInsight(const Str: string): Boolean;
    procedure SetEnabled(Value: Boolean);
    function ShowCalculating: Boolean;
    procedure Stop;
  end;

procedure TRadIACodeInsightCancellation.Cancel;
begin
  TInterlocked.Exchange(FCanceled, 1);
end;

function TRadIACodeInsightCancellation.IsCancellationRequested: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCanceled, 0, 0) <> 0;
end;

constructor TRadIACodeInsightRequest.Create(
  const AId: Integer;
  const AContext: TRadIAInlineCompletionContext;
  const ACancellation: IRadIACodeInsightCancellation;
  const ACallback: TOTACodeCompleteCallBack;
  const AKeepAlive: IRadIACodeInsightLifecycle
);
begin
  inherited Create;
  FId := AId;
  FContext := AContext;
  FCancellation := ACancellation;
  FCallback := ACallback;
  FKeepAlive := AKeepAlive;
end;

procedure TRadIACodeInsightRequest.SetResult(
  const ASuggestion, AError: string
);
begin
  FSuggestion := ASuggestion;
  FError := AError;
end;

destructor TRadIACodeInsightRequest.Destroy;
begin
  FKeepAlive := nil;
  FCancellation := nil;
  inherited Destroy;
end;

procedure TRadIACodeInsightSymbolList.Clear;
begin
  FFilter := '';
  FSuggestion := '';
end;

function TRadIACodeInsightSymbolList.FindIdent(const AnIdent: string): Integer;
begin
  if (FSuggestion <> '') and ContainsText(FSuggestion, AnIdent) then
    Result := 0
  else
    Result := -1;
end;

function TRadIACodeInsightSymbolList.FindSymIndex(
  const Ident: string;
  var Index: Integer
): Boolean;
begin
  Result := SameText(FSuggestion, Ident);
  if Result then
    Index := 0;
end;

function TRadIACodeInsightSymbolList.GetCount: Integer;
begin
  if (FSuggestion <> '') and
    ((FFilter = '') or ContainsText(FSuggestion, FFilter)) then
    Result := 1
  else
    Result := 0;
end;

function TRadIACodeInsightSymbolList.GetProcDispatchFlags(
  I: Integer
): TOTAProcDispatchFlags;
begin
  Result := pdfNone;
end;

function TRadIACodeInsightSymbolList.GetSortOrder: TOTASortOrder;
begin
  Result := FSortOrder;
end;

function TRadIACodeInsightSymbolList.GetSymbolClassText(I: Integer): string;
begin
  Result := 'RadIA';
end;

function TRadIACodeInsightSymbolList.GetSymbolDocumentation(
  I: Integer
): string;
begin
  Result := 'RadIA asynchronous CodeInsight public API probe.';
end;

function TRadIACodeInsightSymbolList.GetSymbolIsAbstract(I: Integer): Boolean;
begin
  Result := False;
end;

function TRadIACodeInsightSymbolList.GetSymbolIsReadWrite(I: Integer): Boolean;
begin
  Result := False;
end;

function TRadIACodeInsightSymbolList.GetSymbolText(Index: Integer): string;
begin
  Result := FSuggestion;
end;

function TRadIACodeInsightSymbolList.GetSymbolTypeText(Index: Integer): string;
begin
  Result := 'AI completion';
end;

function TRadIACodeInsightSymbolList.GetViewerSymbolFlags(
  I: Integer
): TOTAViewerSymbolFlags;
begin
  Result := vsfUnknown;
end;

function TRadIACodeInsightSymbolList.GetViewerVisibilityFlags(
  I: Integer
): TOTAViewerVisibilityFlags;
begin
  Result := 0;
end;

procedure TRadIACodeInsightSymbolList.SetFilter(const FilterText: string);
begin
  FFilter := FilterText;
end;

procedure TRadIACodeInsightSymbolList.SetSortOrder(const Value: TOTASortOrder);
begin
  FSortOrder := Value;
end;

procedure TRadIACodeInsightSymbolList.SetSuggestion(const AValue: string);
begin
  FFilter := '';
  FSuggestion := AValue;
end;

constructor TRadIACodeInsightManager.Create(
  const AProvider: IRadIAInlineCompletionProvider;
  const ASession: IRadIAOTAInlineCompletionSession;
  const AEnabled: Boolean
);
begin
  inherited Create;
  FProvider := AProvider;
  FSession := ASession;
  FEnabled := AEnabled;
  FLock := TObject.Create;
  FSymbols := TRadIACodeInsightSymbolList.Create;
  FSymbolList := FSymbols;
end;

destructor TRadIACodeInsightManager.Destroy;
begin
  Stop;
  FSymbolList := nil;
  FSymbols := nil;
  FSession := nil;
  FProvider := nil;
  FLock.Free;
  inherited Destroy;
end;

procedure TRadIACodeInsightManager.AllowCodeInsight(
  var Allow: Boolean;
  const Key: Char
);
begin
  Allow := FEnabled and (Key = #0);
end;

procedure TRadIACodeInsightManager.AsyncAllowCodeInsight(
  var AAllow: Boolean;
  const AKey: Char
);
begin
  AllowCodeInsight(AAllow, AKey);
end;

function TRadIACodeInsightManager.AsyncCanInvoke(
  AInsightType: TOTACodeInsightType
): Boolean;
begin
  Result := FEnabled and (AInsightType = citCodeInsight);
end;

function TRadIACodeInsightManager.AsyncEnabled: Boolean;
begin
  Result := FEnabled;
end;

function TRadIACodeInsightManager.AsyncGetHintText(
  HintLine, HintCol: Integer;
  ACallBack: TOTAHintTextCallBack
): Integer;
begin
  Result := NewRequestId;
  ACallBack(Self, Result, '', True, 'Hint insight is not part of the probe.');
end;

function TRadIACodeInsightManager.AsyncGotoDefinition(
  const AFileName: string;
  ALine, ACharIndex: Integer;
  ACallBack: TOTAGotoDefinitionCallBack
): Integer;
begin
  Result := NewRequestId;
  ACallBack(Self, Result, '', 0, True, 'Definition lookup is not part of the probe.');
end;

function TRadIACodeInsightManager.AsyncInvokeCodeCompletion(
  AHowInvoked: TOTAInvokeType;
  var AStr: string;
  ALine, ACharIndex: Integer;
  ACallback: TOTACodeCompleteCallBack
): Integer;
var
  LCancellation: IRadIACodeInsightCancellation;
  LContext: TRadIAInlineCompletionContext;
  LId: Integer;
  LKeepAlive: IRadIACodeInsightLifecycle;
  LRequest: TRadIACodeInsightRequest;
begin
  LId := NewRequestId;
  Result := LId;
  if IsStopping or not Assigned(FProvider) or not Assigned(FSession) or
    not FSession.Capture(LContext) then
  begin
    ACallback(Self, LId, True, 'No active Delphi editor context is available.');
    Exit;
  end;
  LCancellation := TRadIACodeInsightCancellation.Create;
  TMonitor.Enter(FLock);
  try
    if Assigned(FActiveCancellation) then
      FActiveCancellation.Cancel;
    FActiveCancellation := LCancellation;
    FActiveId := LId;
  finally
    TMonitor.Exit(FLock);
  end;
  LKeepAlive := Self;
  LRequest := TRadIACodeInsightRequest.Create(
    LId,
    LContext,
    LCancellation,
    ACallback,
    LKeepAlive
  );
  TThread.CreateAnonymousThread(
    procedure
    begin
      ExecuteRequest(LRequest);
    end
  ).Start;
end;

procedure TRadIACodeInsightManager.CompleteRequest(
  const ARequest: TRadIACodeInsightRequest
);
var
  LError: string;
  LSuggestion: string;
begin
  try
    if IsStopping or ARequest.Cancellation.IsCancellationRequested then
      Exit;
    LError := ARequest.Error;
    LSuggestion := NormalizeSuggestion(ARequest.Suggestion);
    if (LError = '') and (LSuggestion = '') then
      LError := 'The completion provider returned no suggestion.';
    if LError = '' then
      FSymbols.SetSuggestion(LSuggestion);
    ARequest.Callback(Self, ARequest.Id, LError <> '', LError);
  finally
    ARequest.Free;
  end;
end;

procedure TRadIACodeInsightManager.ExecuteRequest(
  const ARequest: TRadIACodeInsightRequest
);
var
  LError: string;
  LSuggestion: string;
begin
  LError := '';
  try
    LSuggestion := FProvider.Complete(
      ARequest.Context,
      ARequest.Cancellation
    );
  except
    on E: Exception do
      LError := E.Message;
  end;
  ARequest.SetResult(LSuggestion, LError);
  TThread.Queue(
    nil,
    procedure
    begin
      CompleteRequest(ARequest);
    end
  );
end;

function TRadIACodeInsightManager.AsyncInvokeParameterCodeInsight(
  HowInvoked: TOTAInvokeType;
  const AFileName: string;
  ALine, ACharIndex: Integer;
  ACallback: TOTAParametersCallBack
): Integer;
begin
  Result := NewRequestId;
  ACallback(Self, Result, -1, True, 'Parameter insight is not part of the probe.');
end;

procedure TRadIACodeInsightManager.AsyncOperationCanceled(AId: Integer);
begin
  TMonitor.Enter(FLock);
  try
    if (FActiveId = AId) and Assigned(FActiveCancellation) then
      FActiveCancellation.Cancel;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIACodeInsightManager.AsyncParameterCodeInsightParamIndex(
  const AFileName: string;
  ALine, ACharIndex: Integer;
  ACallBack: TOTAParamIndexCallBack
);
begin
  ACallBack(Self, -1);
end;

procedure TRadIACodeInsightManager.Done(
  Accepted: Boolean;
  out DisplayParams: Boolean
);
var
  LServices: IOTACodeInsightServices;
  LViewer: IOTACodeInsightViewer;
begin
  DisplayParams := False;
  if not Accepted then
    Exit;
  if Supports(BorlandIDEServices, IOTACodeInsightServices, LServices) then
  begin
    LServices.GetViewer(LViewer);
    if Assigned(LViewer) and (LViewer.SelectedString <> '') then
      LServices.InsertText(LViewer.SelectedString, True);
  end;
end;

function TRadIACodeInsightManager.EditorTokenValidChars(
  PreValidating: Boolean
): TSysCharSet;
begin
  Result := ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

function TRadIACodeInsightManager.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

function TRadIACodeInsightManager.GetIDString: string;
begin
  Result := 'RadIA.CodeInsight';
end;

function TRadIACodeInsightManager.GetLongestItem: string;
begin
  Result := 'RadIACompletionProbe';
end;

function TRadIACodeInsightManager.GetMultiSelect: Boolean;
begin
  Result := False;
end;

function TRadIACodeInsightManager.GetName: string;
begin
  Result := 'RadIA CodeInsight';
end;

function TRadIACodeInsightManager.GetOptionSetName: string;
begin
  Result := '';
end;

procedure TRadIACodeInsightManager.GetCodeInsightType(
  AChar: Char;
  AElement: Integer;
  out CodeInsightType: TOTACodeInsightType;
  out InvokeType: TOTAInvokeType
);
begin
  CodeInsightType := citNone;
  InvokeType := itManual;
  if FEnabled and (AChar = #0) then
    CodeInsightType := citCodeInsight;
end;

function TRadIACodeInsightManager.GetHintText(
  HintLine, HintCol: Integer
): string;
begin
  Result := '';
end;

procedure TRadIACodeInsightManager.GetParameterList(
  out ParameterList: IOTACodeInsightParameterList
);
begin
  ParameterList := nil;
end;

procedure TRadIACodeInsightManager.GetSymbolList(
  out SymbolList: IOTACodeInsightSymbolList
);
begin
  SymbolList := FSymbolList;
end;

function TRadIACodeInsightManager.GotoDefinition(
  out AFileName: string;
  out ALineNum: Integer;
  Index: Integer
): Boolean;
begin
  AFileName := '';
  ALineNum := 0;
  Result := False;
end;

function TRadIACodeInsightManager.HandlesFile(
  const AFileName: string
): Boolean;
begin
  Result := FEnabled and SameText(ExtractFileExt(AFileName), '.pas');
end;

function TRadIACodeInsightManager.InvokeCodeCompletion(
  HowInvoked: TOTAInvokeType;
  var Str: string
): Boolean;
begin
  Result := False;
end;

function TRadIACodeInsightManager.InvokeParameterCodeInsight(
  HowInvoked: TOTAInvokeType;
  var SelectedIndex: Integer
): Boolean;
begin
  SelectedIndex := -1;
  Result := False;
end;

function TRadIACodeInsightManager.IsViewerBrowsable(Index: Integer): Boolean;
begin
  Result := False;
end;

function TRadIACodeInsightManager.NewRequestId: Integer;
begin
  Result := TInterlocked.Increment(FNextId);
end;

function TRadIACodeInsightManager.IsStopping: Boolean;
begin
  Result := TInterlocked.CompareExchange(FStopping, 0, 0) <> 0;
end;

function TRadIACodeInsightManager.NormalizeSuggestion(
  const AValue: string
): string;
var
  LBreakAt: Integer;
begin
  Result := AValue.Trim;
  LBreakAt := Pos(#13, Result);
  if LBreakAt = 0 then
    LBreakAt := Pos(#10, Result);
  if LBreakAt > 0 then
    Result := Result.Substring(0, LBreakAt - 1).Trim;
  if Result.Length > 512 then
    SetLength(Result, 512);
end;

procedure TRadIACodeInsightManager.OnEditorKey(
  Key: Char;
  var CloseViewer: Boolean;
  var Accept: Boolean
);
begin
  CloseViewer := CharInSet(Key, [#9, #13, #27]);
  Accept := CharInSet(Key, [#9, #13]);
end;

procedure TRadIACodeInsightManager.ParameterCodeInsightAnchorPos(
  var EdPos: TOTAEditPos
);
begin
  // The probe does not move the IDE-provided anchor.
end;

function TRadIACodeInsightManager.ParameterCodeInsightParamIndex(
  EdPos: TOTAEditPos
): Integer;
begin
  Result := -1;
end;

function TRadIACodeInsightManager.PreValidateCodeInsight(
  const Str: string
): Boolean;
begin
  Result := FEnabled;
end;

procedure TRadIACodeInsightManager.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
end;

function TRadIACodeInsightManager.ShowCalculating: Boolean;
begin
  Result := True;
end;

procedure TRadIACodeInsightManager.Stop;
begin
  TInterlocked.Exchange(FStopping, 1);
  TMonitor.Enter(FLock);
  try
    if Assigned(FActiveCancellation) then
      FActiveCancellation.Cancel;
    FActiveCancellation := nil;
    FActiveId := 0;
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TRadIACodeInsightRegistration.Create(
  const AProvider: IRadIAInlineCompletionProvider;
  const ASession: IRadIAOTAInlineCompletionSession;
  const AEnabled: Boolean
);
begin
  inherited Create;
  FProvider := AProvider;
  FSession := ASession;
  FEnabled := AEnabled;
  FIndex := -1;
end;

destructor TRadIACodeInsightRegistration.Destroy;
begin
  Uninstall;
  inherited Destroy;
end;

function TRadIACodeInsightRegistration.Install: Boolean;
var
  LServices: IOTACodeInsightServices;
begin
  Result := FIndex >= 0;
  if Result then
    Exit;
  if not Supports(BorlandIDEServices, IOTACodeInsightServices, LServices) then
    Exit(False);
  FManager := TRadIACodeInsightManager.Create(
    FProvider,
    FSession,
    FEnabled
  );
  FIndex := LServices.AddCodeInsightManager(FManager);
  Result := FIndex >= 0;
  if Result then
    TLogger.Log('Public CodeInsight manager registered', 'CodeInsight');
end;

procedure TRadIACodeInsightRegistration.Uninstall;
var
  LLifecycle: IRadIACodeInsightLifecycle;
  LServices: IOTACodeInsightServices;
begin
  if Supports(FManager, IRadIACodeInsightLifecycle, LLifecycle) then
    LLifecycle.Stop;
  if (FIndex >= 0) and
    Supports(BorlandIDEServices, IOTACodeInsightServices, LServices) then
    LServices.RemoveCodeInsightManager(FIndex);
  FIndex := -1;
  FManager := nil;
end;

end.
