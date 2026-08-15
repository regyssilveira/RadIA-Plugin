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
    [Test]
    procedure RoutesBeginnerPromptMatrix;
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
  Assert.IsFalse(TRadIAIntentRouter.TryRecommend(
    'O que é uma access violation?',
    LRecommendation
  ));
end;

procedure TTestRadIAIntentRouter.RoutesBeginnerPromptMatrix;
const
  CCreatePrompts: array[0..3] of string = (
    'Quero criar um programa simples de cadastro em VCL',
    'Monte uma calculadora com as quatro operações',
    'Create a small Delphi console application',
    'Gere um projeto FMX para controlar tarefas'
  );
  CBuildPrompts: array[0..3] of string = (
    'Meu projeto não compila, corrija o erro E2003',
    'Resolva a falha de build deste projeto',
    'Fix the compiler error in the current application',
    'A compilação falhou, pode corrigir o projeto?'
  );
  CTestPrompts: array[0..3] of string = (
    'Rode os testes e veja por que estão falhando',
    'Execute os testes DUnitX deste projeto',
    'Run the tests and check the failures',
    'Valide os testes unitários da aplicação'
  );
  CDiagnosePrompts: array[0..3] of string = (
    'Ao fechar o formulário acontece uma access violation',
    'O aplicativo trava quando cancelo a tela de cadastro',
    'Diagnose the memory leak in this application',
    'Investigue a exceção que ocorre ao clicar no botão Salvar'
  );
var
  LPrompt: string;
  LRecommendation: TRadIAIntentRecommendation;
begin
  for LPrompt in CCreatePrompts do
  begin
    Assert.IsTrue(TRadIAIntentRouter.TryRecommend(LPrompt, LRecommendation), LPrompt);
    Assert.AreEqual(rikCreateProject, LRecommendation.Intent, LPrompt);
  end;
  for LPrompt in CBuildPrompts do
  begin
    Assert.IsTrue(TRadIAIntentRouter.TryRecommend(LPrompt, LRecommendation), LPrompt);
    Assert.AreEqual(rikFixBuild, LRecommendation.Intent, LPrompt);
  end;
  for LPrompt in CTestPrompts do
  begin
    Assert.IsTrue(TRadIAIntentRouter.TryRecommend(LPrompt, LRecommendation), LPrompt);
    Assert.AreEqual(rikRunTests, LRecommendation.Intent, LPrompt);
  end;
  for LPrompt in CDiagnosePrompts do
  begin
    Assert.IsTrue(TRadIAIntentRouter.TryRecommend(LPrompt, LRecommendation), LPrompt);
    Assert.AreEqual(rikDiagnose, LRecommendation.Intent, LPrompt);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAIntentRouter);

end.
