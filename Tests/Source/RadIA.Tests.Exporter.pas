unit RadIA.Tests.Exporter;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces;

type
  [TestFixture]
  TTestRadIAExporter = class
  private
    FHistory: TArray<IRadIAChatMessage>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestExportMarkdown_ContainsAllMessages;
    [Test]
    procedure TestExportMarkdown_ContainsHeader;
    [Test]
    procedure TestExportMarkdown_EmptyHistory;
    [Test]
    procedure TestExportHTML_ContainsStylesAndContent;
    [Test]
    procedure TestExportMarkdown_RedactsSecretsWhenRedactorIsSupplied;
    [Test]
    procedure TestExportHTML_RedactsSecretsWhenRedactorIsSupplied;
    [Test]
    procedure TestExportMarkdown_KeepsContentWhenRedactorIsAbsent;
  end;

implementation

uses
  System.SysUtils, RadIA.Core.ChatMessage, RadIA.Core.Types, RadIA.Core.ConversationExporter,
  RadIA.Core.ToolSecurity;

{ TTestRadIAExporter }

procedure TTestRadIAExporter.Setup;
begin
  FHistory := TArray<IRadIAChatMessage>.Create(
    TRadIAChatMessage.CreateMessage(mrUser, 'Como criar uma classe em Delphi?'),
    TRadIAChatMessage.CreateMessage(mrAssistant, 'Use a sintaxe `type TMyClass = class`.')
  );
end;

procedure TTestRadIAExporter.TearDown;
begin
  FHistory := nil;
end;

procedure TTestRadIAExporter.TestExportMarkdown_ContainsAllMessages;
var
  LMarkdown: string;
begin
  LMarkdown := TConversationExporter.ExportToMarkdown(FHistory, 'OpenAI', 'gpt-4o');

  Assert.IsNotEmpty(LMarkdown);
  Assert.IsTrue(LMarkdown.Contains('Como criar uma classe em Delphi?'));
  Assert.IsTrue(LMarkdown.Contains('Use a sintaxe `type TMyClass = class`.'));
  Assert.IsTrue(LMarkdown.Contains('👤 User'));
  Assert.IsTrue(LMarkdown.Contains('🤖 Assistant (Rad IA)'));
end;

procedure TTestRadIAExporter.TestExportMarkdown_ContainsHeader;
var
  LMarkdown: string;
begin
  LMarkdown := TConversationExporter.ExportToMarkdown(FHistory, 'Google Gemini', 'gemini-1.5-flash');

  Assert.IsTrue(LMarkdown.Contains('# Conversation History - Rad IA'));
  Assert.IsTrue(LMarkdown.Contains('**Provider**: Google Gemini'));
  Assert.IsTrue(LMarkdown.Contains('**Model**: gemini-1.5-flash'));
end;

procedure TTestRadIAExporter.TestExportMarkdown_EmptyHistory;
var
  LMarkdown: string;
  LEmptyHistory: TArray<IRadIAChatMessage>;
begin
  LEmptyHistory := [];
  LMarkdown := TConversationExporter.ExportToMarkdown(LEmptyHistory, 'OpenAI', 'gpt-4o');

  Assert.IsTrue(LMarkdown.Contains('# Conversation History - Rad IA'));
  Assert.IsFalse(LMarkdown.Contains('👤 User'));
end;

procedure TTestRadIAExporter.TestExportHTML_ContainsStylesAndContent;
var
  LHtml: string;
begin
  LHtml := TConversationExporter.ExportToHTML(FHistory, 'Anthropic Claude', 'claude-3-5-sonnet');

  Assert.IsNotEmpty(LHtml);
  Assert.IsTrue(LHtml.Contains('<!DOCTYPE html>'));
  Assert.IsTrue(LHtml.Contains('<html>'));
  Assert.IsTrue(LHtml.Contains('<head>'));
  Assert.IsTrue(LHtml.Contains('background-color: #1e1e1e;'));
  Assert.IsTrue(LHtml.Contains('Como criar uma classe em Delphi?'));
  Assert.IsTrue(LHtml.Contains('Use a sintaxe `type TMyClass = class`.'));
  Assert.IsTrue(LHtml.Contains('class="message user"'));
  Assert.IsTrue(LHtml.Contains('class="message assistant"'));
end;

procedure TTestRadIAExporter.TestExportMarkdown_RedactsSecretsWhenRedactorIsSupplied;
var
  LHistory: TArray<IRadIAChatMessage>;
  LMarkdown: string;
begin
  LHistory := TArray<IRadIAChatMessage>.Create(
    TRadIAChatMessage.CreateMessage(
      mrUser,
      'Authorization: Bearer sk-secret-value-123 and AKIA1234567890ABCDEF'
    ),
    TRadIAChatMessage.CreateMessage(mrAssistant, '{"api_key": "sk-live-abc123"}')
  );

  LMarkdown := TConversationExporter.ExportToMarkdown(
    LHistory, 'OpenAI', 'gpt-4o', TRadIASecretRedactor.Create);

  Assert.IsFalse(LMarkdown.Contains('sk-secret-value-123'));
  Assert.IsFalse(LMarkdown.Contains('AKIA1234567890ABCDEF'));
  Assert.IsFalse(LMarkdown.Contains('sk-live-abc123'));
  Assert.IsTrue(LMarkdown.Contains('Bearer [REDACTED]'));
  Assert.IsTrue(LMarkdown.Contains('[REDACTED_AWS_ACCESS_KEY]'));
end;

procedure TTestRadIAExporter.TestExportHTML_RedactsSecretsWhenRedactorIsSupplied;
var
  LHistory: TArray<IRadIAChatMessage>;
  LHtml: string;
begin
  LHistory := TArray<IRadIAChatMessage>.Create(
    TRadIAChatMessage.CreateMessage(mrUser, 'Token: Bearer sk-secret-value-123')
  );

  LHtml := TConversationExporter.ExportToHTML(
    LHistory, 'OpenAI', 'gpt-4o', TRadIASecretRedactor.Create);

  Assert.IsFalse(LHtml.Contains('sk-secret-value-123'));
  Assert.IsTrue(LHtml.Contains('Bearer [REDACTED]'));
end;

procedure TTestRadIAExporter.TestExportMarkdown_KeepsContentWhenRedactorIsAbsent;
var
  LMarkdown: string;
begin
  LMarkdown := TConversationExporter.ExportToMarkdown(FHistory, 'OpenAI', 'gpt-4o');

  Assert.IsTrue(LMarkdown.Contains('Como criar uma classe em Delphi?'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAExporter);

end.

