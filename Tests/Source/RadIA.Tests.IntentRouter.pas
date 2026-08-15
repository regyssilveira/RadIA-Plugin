unit RadIA.Tests.IntentRouter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAIntentRouter = class
  public
    [Test]
    procedure RecommendsProjectCreationWithoutExecutingIt;
    [Test]
    procedure RecommendsBuildRepair;
    [Test]
    procedure RecommendsTestJourney;
    [Test]
    procedure RecommendsDebugJourneyWithMediumConfidence;
    [Test]
    procedure LeavesOrdinaryChatAndExplicitCommandsUntouched;
  end;

implementation

uses
  RadIA.Core.IntentRouter;

procedure TTestRadIAIntentRouter.RecommendsProjectCreationWithoutExecutingIt;
var
  LRecommendation: TRadIAIntentRecommendation;
begin
  Assert.IsTrue(TRadIAIntentRouter.TryRecommend(
    'Crie uma calculadora VCL em D:\Calculator',
    LRecommendation
  ));
  Assert.AreEqual('Create project', LRecommendation.IntentName);
  Assert.AreEqual('high', LRecommendation.ConfidenceName);
  Assert.AreEqual('journey', LRecommendation.Route);
  Assert.StartsWith('/journey create ', LRecommendation.Command);
end;

procedure TTestRadIAIntentRouter.RecommendsBuildRepair;
var
  LRecommendation: TRadIAIntentRecommendation;
begin
  Assert.IsTrue(TRadIAIntentRouter.TryRecommend(
    'Corrija o erro de compilação E2003 deste projeto',
    LRecommendation
  ));
  Assert.AreEqual(rikFixBuild, LRecommendation.Intent);
  Assert.StartsWith('/journey fix-build ', LRecommendation.Command);
end;

procedure TTestRadIAIntentRouter.RecommendsTestJourney;
var
  LRecommendation: TRadIAIntentRecommendation;
begin
  Assert.IsTrue(TRadIAIntentRouter.TryRecommend(
    'Execute os testes DUnitX e verifique as falhas',
    LRecommendation
  ));
  Assert.AreEqual(rikRunTests, LRecommendation.Intent);
  Assert.StartsWith('/journey tests ', LRecommendation.Command);
end;

procedure TTestRadIAIntentRouter.RecommendsDebugJourneyWithMediumConfidence;
var
  LRecommendation: TRadIAIntentRecommendation;
begin
  Assert.IsTrue(TRadIAIntentRouter.TryRecommend(
    'A aplicação causa access violation ao fechar o formulário',
    LRecommendation
  ));
  Assert.AreEqual(rikDiagnose, LRecommendation.Intent);
  Assert.AreEqual(ricMedium, LRecommendation.Confidence);
  Assert.StartsWith('/journey debug ', LRecommendation.Command);
end;

procedure TTestRadIAIntentRouter.LeavesOrdinaryChatAndExplicitCommandsUntouched;
var
  LRecommendation: TRadIAIntentRecommendation;
begin
  Assert.IsFalse(TRadIAIntentRouter.TryRecommend('Quem é você?', LRecommendation));
  Assert.IsFalse(TRadIAIntentRouter.TryRecommend('/journey tests', LRecommendation));
  Assert.IsFalse(TRadIAIntentRouter.TryRecommend(
    'Explique como testes unitários funcionam',
    LRecommendation
  ));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAIntentRouter);

end.
