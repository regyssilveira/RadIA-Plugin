unit RadIA.Tests.SemanticQueries;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASemanticQueryTests = class
  public
    [Test]
    procedure BuildsBoundedResolvedContext;
    [Test]
    procedure ReportsEngineFailureForFallback;
    [Test]
    procedure RegistersAgentQueryTool;
    [Test]
    procedure AgentToolPointsToBoundedFallback;
    [Test]
    procedure EnrichesGhostTextContextWithResolvedMembers;
    [Test]
    procedure KeepsGhostTextFallbackWhenEngineFails;
    [Test]
    procedure ListsPublicApiWithVisibility;
    [Test]
    procedure FindsReferencesWithNavigationCoordinates;
    [Test]
    procedure RejectsAmbiguousReferenceQueryWithoutUnit;
    [Test]
    procedure ReturnsIndexedTypeHierarchy;
    [Test]
    procedure ReturnsTransitiveHierarchyDepthAndExternalTypes;
    [Test]
    procedure ResolvesRoutineFamilyWithDeclarationSections;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.InlineCompletion,
  RadIA.Core.SemanticQueries,
  RadIA.Core.SemanticHierarchyTools,
  RadIA.Core.SemanticQueryTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Semantic.Workspace;

type
  TRadIASemanticQueryClientMock = class(
    TInterfacedObject,
    IRadIASemanticRequestClient
  )
  private
    FFail: Boolean;
  public
    constructor Create(const AFail: Boolean);
    function GetRestartCount: Integer;
    function Request(
      const AMethod: string;
      const AParameters: string;
      out AResponse: string;
      out AError: string
    ): Boolean;
  end;

constructor TRadIASemanticQueryClientMock.Create(const AFail: Boolean);
begin
  inherited Create;
  FFail := AFail;
end;

function TRadIASemanticQueryClientMock.GetRestartCount: Integer;
begin
  Result := 0;
end;

function TRadIASemanticQueryClientMock.Request(
  const AMethod: string;
  const AParameters: string;
  out AResponse: string;
  out AError: string
): Boolean;
begin
  if FFail then
  begin
    AError := 'Semantic engine unavailable.';
    AResponse := '';
    Exit(False);
  end;
  AError := '';
  if SameText(AMethod, 'listPublicApiSymbols') then
    AResponse :=
      '{"result":{"symbols":[{"name":"Execute","kind":"method",' +
      '"container":"TWorker","fileName":"Worker.pas",' +
      '"visibility":"public","signature":"procedure Execute;",' +
      '"startOffset":84}]}}'
  else if SameText(AMethod, 'listTypeSymbols') then
    AResponse :=
      '{"result":{"symbols":[' +
      '{"symbolId":"type-base","unitKey":"Base","name":"TBase",' +
      '"kind":"class","container":"","fileName":"Base.pas",' +
      '"signature":"TBase = class(TObject)","startOffset":10,' +
      '"ancestors":["TObject"]},' +
      '{"symbolId":"type-worker","unitKey":"Worker",' +
      '"name":"TWorker","kind":"class","container":"",' +
      '"fileName":"Worker.pas","signature":"TWorker = class(TBase)",' +
      '"startOffset":20,"ancestors":["TBase"]},' +
      '{"symbolId":"type-special","unitKey":"Special",' +
      '"name":"TSpecialWorker","kind":"class","container":"",' +
      '"fileName":"Special.pas","signature":' +
      '"TSpecialWorker = class(TWorker)","startOffset":30,' +
      '"ancestors":["TWorker"]}]}}'
  else if SameText(AMethod, 'findSymbols') then
  begin
    if ContainsText(AParameters, 'TShared') then
      AResponse :=
        '{"result":{"symbols":[' +
        '{"symbolId":"sym-first","unitKey":"First","name":"TShared",' +
        '"kind":"class","container":"","fileName":"First.pas",' +
        '"signature":"TShared = class","startOffset":42},' +
        '{"symbolId":"sym-second","unitKey":"Second","name":"TShared",' +
        '"kind":"class","container":"","fileName":"Second.pas",' +
        '"signature":"TShared = class","startOffset":42}]}}'
    else
      AResponse :=
        '{"result":{"symbols":[{"symbolId":"sym-worker",' +
        '"unitKey":"Worker","name":"TWorker","kind":"class",' +
        '"container":"","fileName":"Worker.pas","signature":' +
        '"TWorker = class(TBaseWorker)","startOffset":42}]}}';
  end
  else if SameText(AMethod, 'findRoutineSymbols') then
    AResponse :=
      '{"result":{"symbols":[' +
      '{"symbolId":"routine-execute","unitKey":"Worker",' +
      '"name":"Execute","kind":"method","container":"TWorker",' +
      '"section":"interface","fileName":"Worker.pas",' +
      '"signature":"procedure Execute(const AValue: Integer);",' +
      '"startOffset":42},' +
      '{"symbolId":"routine-execute","unitKey":"Worker",' +
      '"name":"Execute","kind":"method","container":"TWorker",' +
      '"section":"implementation","fileName":"Worker.pas",' +
      '"signature":"procedure TWorker.Execute(const AValue: Integer);",' +
      '"startOffset":142}]}}'
  else if SameText(AMethod, 'findReferences') then
    AResponse :=
      '{"result":{"status":"resolved","references":[' +
      '{"symbolId":"sym-worker","unitKey":"Worker",' +
      '"fileName":"Worker.pas","startOffset":42,"length":7,' +
      '"line":3,"column":3,"kind":"declaration",' +
      '"reason":"declaration"},{"symbolId":"sym-worker",' +
      '"unitKey":"Consumer","fileName":"Consumer.pas",' +
      '"startOffset":91,"length":7,"line":8,"column":12,' +
      '"kind":"exact","reason":"unique-symbol"}]}}'
  else
    AResponse :=
      '{"result":{"symbols":[{"name":"Execute","kind":"method",' +
      '"container":"TBaseWorker","fileName":"BaseWorker.pas",' +
      '"signature":"procedure Execute;","startOffset":84}]}}';
  Result := AParameters <> '';
end;

procedure TRadIASemanticQueryTests.ResolvesRoutineFamilyWithDeclarationSections;
var
  LError: string;
  LRoutines: TArray<TRadIASemanticLocation>;
  LService: IRadIASemanticRoutineService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  Assert.IsTrue(LService.FindRoutineSymbols(
    'Execute',
    'Worker',
    'TWorker',
    'procedure Execute(const AValue: Integer);',
    LRoutines,
    LError
  ), LError);
  Assert.AreEqual(NativeInt(2), Length(LRoutines));
  Assert.AreEqual('interface', LRoutines[0].DeclarationSection);
  Assert.AreEqual('implementation', LRoutines[1].DeclarationSection);
  Assert.AreEqual(LRoutines[0].SymbolId, LRoutines[1].SymbolId);
end;

procedure TRadIASemanticQueryTests.
  FindsReferencesWithNavigationCoordinates;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticQueryTools(LRegistry, LService);
  LResult := LRegistry.Resolve('FindSymbolReferences').Execute(
    TRadIAToolRequest.Create(
      'FindSymbolReferences',
      '{"symbol":"TWorker"}',
      'semantic-reference-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"referenceCount":2');
  Assert.Contains(LResult.ContentJson, '"line":8');
  Assert.Contains(LResult.ContentJson, 'NavigateToFile');
end;

procedure TRadIASemanticQueryTests.
  RejectsAmbiguousReferenceQueryWithoutUnit;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticQueryTools(LRegistry, LService);
  LResult := LRegistry.Resolve('FindSymbolReferences').Execute(
    TRadIAToolRequest.Create(
      'FindSymbolReferences',
      '{"symbol":"TShared"}',
      'semantic-ambiguity-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('ambiguous_symbol', LResult.ErrorCode);
  Assert.Contains(LResult.ErrorMessage, 'First');
  Assert.Contains(LResult.ErrorMessage, 'Second');
end;

procedure TRadIASemanticQueryTests.ListsPublicApiWithVisibility;
var
  LError: string;
  LService: IRadIASemanticQueryService;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  Assert.IsTrue(LService.ListPublicApiSymbols(LSymbols, LError), LError);
  Assert.AreEqual(NativeInt(1), Length(LSymbols));
  Assert.AreEqual('Execute', LSymbols[0].Name);
  Assert.AreEqual('public', LSymbols[0].Visibility);
end;

procedure TRadIASemanticQueryTests.ReturnsIndexedTypeHierarchy;
var
  LHierarchy: IRadIASemanticHierarchyService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: TRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  LHierarchy := LService as IRadIASemanticHierarchyService;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticHierarchyTools(LRegistry, LHierarchy);
  LResult := LRegistry.Resolve('GetTypeHierarchy').Execute(
    TRadIAToolRequest.Create(
      'GetTypeHierarchy',
      '{"type":"TWorker"}',
      'semantic-hierarchy-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"name":"TBase"');
  Assert.Contains(LResult.ContentJson, '"relation":"ancestor"');
  Assert.Contains(LResult.ContentJson, '"name":"TSpecialWorker"');
  Assert.Contains(LResult.ContentJson, '"relation":"descendant"');
end;

procedure TRadIASemanticQueryTests.ReturnsTransitiveHierarchyDepthAndExternalTypes;
var
  LHierarchy: IRadIASemanticHierarchyService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: TRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  LHierarchy := LService as IRadIASemanticHierarchyService;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticHierarchyTools(LRegistry, LHierarchy);
  LResult := LRegistry.Resolve('GetTypeHierarchy').Execute(
    TRadIAToolRequest.Create(
      'GetTypeHierarchy',
      '{"type":"TBase"}',
      'semantic-transitive-hierarchy-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(
    LResult.ContentJson,
    '"name":"TSpecialWorker","kind":"class","relation":' +
    '"descendant","depth":2'
  );
  Assert.Contains(
    LResult.ContentJson,
    '"name":"TObject","kind":"external","relation":"ancestor",' +
    '"depth":1,"indexed":false'
  );
end;

procedure TRadIASemanticQueryTests.BuildsBoundedResolvedContext;
var
  LContext: string;
  LError: string;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  Assert.IsTrue(LService.BuildContext('TWorker', 4096, LContext, LError));
  Assert.Contains(LContext, 'class TWorker in Worker.pas');
  Assert.Contains(LContext, 'Member: TBaseWorker.Execute');
  Assert.IsTrue(LService.HasResolvedMember('TWorker', 'Execute'));
end;

procedure TRadIASemanticQueryTests.ReportsEngineFailureForFallback;
var
  LContext: string;
  LError: string;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(True)
  );
  Assert.IsFalse(LService.BuildContext('TWorker', 4096, LContext, LError));
  Assert.AreEqual('Semantic engine unavailable.', LError);
end;

procedure TRadIASemanticQueryTests.RegistersAgentQueryTool;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: IRadIASemanticQueryService;
  LTool: IRadIATool;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticQueryTools(LRegistry, LService);
  LTool := LRegistry.Resolve('GetSemanticContext');
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  Assert.IsTrue(LTool.Descriptor.Idempotent);
  LResult := LTool.Execute(TRadIAToolRequest.Create(
    'GetSemanticContext',
    '{"symbol":"TWorker","maxCharacters":4096}',
    'semantic-query-test'
  ));
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'TBaseWorker.Execute');
end;

procedure TRadIASemanticQueryTests.AgentToolPointsToBoundedFallback;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(True)
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticQueryTools(LRegistry, LService);
  LResult := LRegistry.Resolve('GetSemanticContext').Execute(
    TRadIAToolRequest.Create(
      'GetSemanticContext',
      '{"symbol":"TWorker"}',
      'semantic-fallback-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.Contains(LResult.ErrorMessage, 'GetEditorSemanticContext');
end;

procedure TRadIASemanticQueryTests.EnrichesGhostTextContextWithResolvedMembers;
var
  LContext: TRadIAInlineCompletionContext;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(False)
  );
  LContext := TRadIAInlineCompletionContext.Create(
    'Worker.pas',
    'delphi',
    'procedure TWorker.Run; begin ',
    ' end;',
    'TWorker',
    'Project: Sample',
    'revision-1'
  );
  LContext := TRadIAInlineSemanticContextEnricher.Enrich(
    LContext,
    LService,
    4096
  );
  Assert.Contains(LContext.ProjectContext, 'Indexed semantic context:');
  Assert.Contains(LContext.ProjectContext, 'TBaseWorker.Execute');
end;

procedure TRadIASemanticQueryTests.KeepsGhostTextFallbackWhenEngineFails;
var
  LContext: TRadIAInlineCompletionContext;
  LService: IRadIASemanticQueryService;
begin
  LService := TRadIASemanticQueryService.Create(
    TRadIASemanticQueryClientMock.Create(True)
  );
  LContext := TRadIAInlineCompletionContext.Create(
    'Worker.pas',
    'delphi',
    'begin ',
    ' end;',
    'TWorker',
    'Bounded context',
    'revision-1'
  );
  LContext := TRadIAInlineSemanticContextEnricher.Enrich(
    LContext,
    LService,
    4096
  );
  Assert.AreEqual('Bounded context', LContext.ProjectContext);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticQueryTests);

end.
