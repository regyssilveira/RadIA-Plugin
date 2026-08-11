unit RadIA.OTA.CodeInsight;

interface

uses
  ToolsAPI;

type
  TRadIACodeInsightRegistration = class
  private
    FIndex: Integer;
    FManager: IOTACodeInsightManager;
  public
    constructor Create;
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
    IOTAAsyncCodeInsightManager
  )
  private
    FCanceledId: Integer;
    FEnabled: Boolean;
    FNextId: Integer;
    FSymbols: TRadIACodeInsightSymbolList;
    FSymbolList: IOTACodeInsightSymbolList;
    function NewRequestId: Integer;
  public
    constructor Create;
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

constructor TRadIACodeInsightManager.Create;
begin
  inherited Create;
  FEnabled := SameText(
    GetEnvironmentVariable('RADIA_CODEINSIGHT_SPIKE'),
    '1'
  );
  FSymbols := TRadIACodeInsightSymbolList.Create;
  FSymbolList := FSymbols;
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
  LId: Integer;
begin
  LId := NewRequestId;
  Result := LId;
  TThread.Queue(
    nil,
    procedure
    begin
      if TInterlocked.CompareExchange(FCanceledId, 0, 0) = LId then
        Exit;
      FSymbols.SetSuggestion('RadIACompletionProbe');
      ACallback(Self, LId, False, '');
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
  TInterlocked.Exchange(FCanceledId, AId);
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
  FEnabled := Value and SameText(
    GetEnvironmentVariable('RADIA_CODEINSIGHT_SPIKE'),
    '1'
  );
end;

function TRadIACodeInsightManager.ShowCalculating: Boolean;
begin
  Result := True;
end;

constructor TRadIACodeInsightRegistration.Create;
begin
  inherited Create;
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
  FManager := TRadIACodeInsightManager.Create;
  FIndex := LServices.AddCodeInsightManager(FManager);
  Result := FIndex >= 0;
  if Result then
    TLogger.Log('Public CodeInsight manager registered', 'CodeInsight');
end;

procedure TRadIACodeInsightRegistration.Uninstall;
var
  LServices: IOTACodeInsightServices;
begin
  if (FIndex >= 0) and
    Supports(BorlandIDEServices, IOTACodeInsightServices, LServices) then
    LServices.RemoveCodeInsightManager(FIndex);
  FIndex := -1;
  FManager := nil;
end;

end.
