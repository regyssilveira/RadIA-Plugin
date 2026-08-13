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
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.InlineCompletion,
  RadIA.Core.SemanticQueries,
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
  if SameText(AMethod, 'findSymbols') then
    AResponse :=
      '{"result":{"symbols":[{"name":"TWorker","kind":"class",' +
      '"container":"","fileName":"Worker.pas","signature":' +
      '"TWorker = class(TBaseWorker)","startOffset":42}]}}'
  else
    AResponse :=
      '{"result":{"symbols":[{"name":"Execute","kind":"method",' +
      '"container":"TBaseWorker","fileName":"BaseWorker.pas",' +
      '"signature":"procedure Execute;","startOffset":84}]}}';
  Result := AParameters <> '';
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
