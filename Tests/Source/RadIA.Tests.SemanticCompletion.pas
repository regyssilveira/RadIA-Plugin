unit RadIA.Tests.SemanticCompletion;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASemanticCompletionTests = class
  public
    [Test]
    procedure ReturnsUniqueResolvedSuffixAndMetrics;
    [Test]
    procedure ReturnsCommonPrefixForMultipleCandidates;
    [Test]
    procedure RefusesAmbiguousStructuralResolution;
    [Test]
    procedure HonorsPreCancelledRequest;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.SemanticCompletion,
  RadIA.Semantic.Workspace;

type
  TRadIASemanticCompletionClientMock = class(
    TInterfacedObject,
    IRadIASemanticRequestClient,
    IRadIASemanticCancelableRequestClient
  )
  private
    FNames: TArray<string>;
    FResolutionJson: string;
  public
    constructor Create(
      const ANames: TArray<string>;
      const AResolutionJson: string = ''
    );
    function GetRestartCount: Integer;
    function Request(
      const AMethod: string;
      const AParameters: string;
      out AResponse: string;
      out AError: string
    ): Boolean;
    function RequestCancelable(
      const AMethod: string;
      const AParameters: string;
      const AIsCancelled: TFunc<Boolean>;
      out AResponse: string;
      out AError: string
    ): Boolean;
  end;

constructor TRadIASemanticCompletionClientMock.Create(
  const ANames: TArray<string>;
  const AResolutionJson: string
);
begin
  inherited Create;
  FNames := Copy(ANames);
  FResolutionJson := AResolutionJson;
end;

function TRadIASemanticCompletionClientMock.GetRestartCount: Integer;
begin
  Result := 0;
end;

function TRadIASemanticCompletionClientMock.Request(
  const AMethod: string;
  const AParameters: string;
  out AResponse: string;
  out AError: string
): Boolean;
begin
  Result := RequestCancelable(
    AMethod,
    AParameters,
    nil,
    AResponse,
    AError
  );
end;

function TRadIASemanticCompletionClientMock.RequestCancelable(
  const AMethod: string;
  const AParameters: string;
  const AIsCancelled: TFunc<Boolean>;
  out AResponse: string;
  out AError: string
): Boolean;
var
  LIndex: Integer;
begin
  if Assigned(AIsCancelled) and AIsCancelled() then
  begin
    AResponse := '';
    AError := 'The semantic engine request was cancelled.';
    Exit(False);
  end;
  AError := '';
  AResponse := '{"result":{"symbols":[';
  for LIndex := Low(FNames) to High(FNames) do
  begin
    if LIndex > Low(FNames) then
      AResponse := AResponse + ',';
    AResponse := AResponse + '{"name":"' + FNames[LIndex] + '"}';
  end;
  AResponse := AResponse + ']';
  if FResolutionJson <> '' then
    AResponse := AResponse + ',"resolution":' + FResolutionJson;
  AResponse := AResponse + '}}';
  Result := SameText(AMethod, 'completeResolvedMembers') and
    (AParameters <> '');
end;

procedure TRadIASemanticCompletionTests.RefusesAmbiguousStructuralResolution;
var
  LClient: IRadIASemanticRequestClient;
  LResult: TRadIASemanticCompletionResult;
  LService: IRadIASemanticCompletionService;
begin
  LClient := TRadIASemanticCompletionClientMock.Create(
    ['Save'],
    '{"status":"ambiguous","reason":"short-name-ambiguous",' +
    '"alternatives":[{"unitKey":"Vcl.Sample"},' +
    '{"unitKey":"Fmx.Sample"}]}'
  );
  LService := TRadIASemanticCompletionService.Create(LClient);
  LResult := LService.Complete('TSample', 'Sa', nil);
  Assert.AreEqual('ambiguous', LResult.Status);
  Assert.AreEqual('', LResult.Suggestion);
  Assert.AreEqual('short-name-ambiguous', LResult.ResolutionReason);
  Assert.AreEqual(2, LResult.AlternativeCount);
end;

procedure TRadIASemanticCompletionTests.
  ReturnsUniqueResolvedSuffixAndMetrics;
var
  LClient: IRadIASemanticRequestClient;
  LResult: TRadIASemanticCompletionResult;
  LService: IRadIASemanticCompletionService;
begin
  LClient := TRadIASemanticCompletionClientMock.Create(['Save']);
  LService := TRadIASemanticCompletionService.Create(LClient);
  LResult := LService.Complete('TForm', 'Sa', nil);
  Assert.AreEqual('ready', LResult.Status);
  Assert.AreEqual('ve', LResult.Suggestion);
  Assert.AreEqual(1, LResult.CandidateCount);
  Assert.IsTrue(LResult.LatencyMs >= 0);
end;

procedure TRadIASemanticCompletionTests.
  ReturnsCommonPrefixForMultipleCandidates;
var
  LClient: IRadIASemanticRequestClient;
  LResult: TRadIASemanticCompletionResult;
  LService: IRadIASemanticCompletionService;
begin
  LClient := TRadIASemanticCompletionClientMock.Create(['Save', 'SaveAs']);
  LService := TRadIASemanticCompletionService.Create(LClient);
  LResult := LService.Complete('TForm', 'Sa', nil);
  Assert.AreEqual('ve', LResult.Suggestion);
  Assert.AreEqual(2, LResult.CandidateCount);
end;

procedure TRadIASemanticCompletionTests.HonorsPreCancelledRequest;
var
  LClient: IRadIASemanticRequestClient;
  LResult: TRadIASemanticCompletionResult;
  LService: IRadIASemanticCompletionService;
begin
  LClient := TRadIASemanticCompletionClientMock.Create(['Save']);
  LService := TRadIASemanticCompletionService.Create(LClient);
  LResult := LService.Complete(
    'TForm',
    'Sa',
    function: Boolean
    begin
      Result := True;
    end
  );
  Assert.AreEqual('cancelled', LResult.Status);
  Assert.AreEqual('', LResult.Suggestion);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticCompletionTests);

end.
