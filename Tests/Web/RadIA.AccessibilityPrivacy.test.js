const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const webRoot = path.join(repositoryRoot, 'Source', 'UI', 'Web');
const chatHtml = fs.readFileSync(path.join(webRoot, 'chat.html'), 'utf8');
const chatJs = fs.readFileSync(path.join(webRoot, 'chat.js'), 'utf8');
const chatCss = fs.readFileSync(path.join(webRoot, 'chat.css'), 'utf8');
const diffHtml = fs.readFileSync(path.join(webRoot, 'diff.html'), 'utf8');
const configFrame = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ConfigFrame.pas'),
  'utf8'
);
const externalMcpFrame = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ExternalMcpFrame.pas'),
  'utf8'
);
const externalMcpFrameDfm = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ExternalMcpFrame.dfm'),
  'utf8'
);
const chatFrame = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ChatFrame.pas'),
  'utf8'
);
const dockableForm = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.DockableForm.pas'),
  'utf8'
);
const configForm = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ConfigForm.pas'),
  'utf8'
);
const projectWizard = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ProjectWizard.pas'),
  'utf8'
);
const versionUnit = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Core', 'RadIA.Core.Version.pas'),
  'utf8'
);
const packageInstaller = fs.readFileSync(
  path.join(repositoryRoot, 'scripts', 'Install-RadIA.Package.ps1'),
  'utf8'
);
const visualInstaller = fs.readFileSync(
  path.join(repositoryRoot, 'installer', 'RadIA.iss'),
  'utf8'
);

test('web surfaces do not contact external origins during startup', () => {
  assert.doesNotMatch(chatHtml, /(?:src|href)="https?:\/\//i);
  assert.doesNotMatch(diffHtml, /(?:src|href)="https?:\/\//i);
});

test('external chat links open in the Windows default browser', () => {
  assert.match(chatFrame, /OnNavigationStarting := EdgeBrowserNavigationStarting/u);
  assert.match(chatFrame, /Args\.ArgsInterface\.Set_Cancel\(1\)/u);
  assert.match(chatFrame, /ShellExecute\(0, 'open', PChar\(LUrl\)/u);
});

test('local chat links cannot replace the main chat surface', () => {
  assert.match(chatFrame, /LUrl\.StartsWith\(LAllowedChatUrl, True\)/u);
  assert.match(chatFrame, /if LUrl\.StartsWith\('file:\/\/\/', True\) then/u);
  assert.match(chatFrame, /TryOpenLocalLinkInIDE\(LLocalPath\)/u);
  assert.match(chatFrame, /IOTAActionServices[\s\S]*OpenFile\(AFileName\)/u);
  assert.match(chatFrame, /Blocked unsupported chat navigation/u);
});

test('chat exposes its primary controls and live regions to assistive technology', () => {
  assert.match(chatHtml, /id="chat-container"[^>]*role="log"/);
  assert.match(chatHtml, /<output id="status-bar"/);
  assert.match(chatHtml, /id="prompt-textarea"[^>]*aria-label="Message Rad IA"/);
  assert.match(chatHtml, /id="btn-send-prompt"[^>]*aria-label="Send message"/);
  assert.match(chatHtml, /id="btn-agent-mode"[\s\S]*?aria-pressed="true"/);
  assert.match(chatHtml, /<button[^>]*id="provider-dropdown-trigger"/);
  assert.match(chatHtml, /<button[^>]*id="model-dropdown-trigger"/);
});

test('custom selectors support keyboard activation and synchronized ARIA state', () => {
  assert.match(chatJs, /modelDropdownTrigger\.addEventListener\('keydown'/);
  assert.match(chatJs, /providerDropdownTrigger\.addEventListener\('keydown'/);
  assert.match(chatJs, /trigger\.setAttribute\('aria-expanded', String\(open\)\)/);
  assert.match(chatJs, /div\.setAttribute\('aria-pressed'/);
});

test('scrollable selector surfaces expose visible scrollbar affordances', () => {
  assert.match(chatCss, /\.custom-dropdown-options,[\s\S]*#slash-commands-popup,[\s\S]*\.radia-project-files-list/u);
  assert.match(chatCss, /scrollbar-color: var\(--scrollbar\) var\(--scrollbar-track\)/u);
  assert.match(chatCss, /scrollbar-width: auto/u);
  assert.match(chatCss, /::-webkit-scrollbar[\s\S]*width: 14px/u);
  assert.match(chatCss, /::-webkit-scrollbar-track[\s\S]*background: var\(--scrollbar-track\)/u);
  assert.match(chatCss, /::-webkit-scrollbar-thumb[\s\S]*min-height: 32px/u);
});

test('primary RadIA windows expose the package version in their captions', () => {
  assert.match(versionUnit, /function RadIAVersionedCaption/u);
  assert.match(dockableForm, /Result := RadIAVersionedCaption\(FCaption\)/u);
  assert.match(configForm, /Caption := RadIAVersionedCaption\('Rad IA Configuration'\)/u);
  assert.match(projectWizard, /Caption := RadIAVersionedCaption\('RadIA New Project'\)/u);
});

test('installers block when any Delphi IDE process is open', () => {
  assert.match(packageInstaller, /Get-Process bds/u);
  assert.match(packageInstaller, /Close all Delphi IDE instances before changing RadIA/u);
  assert.match(packageInstaller, /\$runningIDEs\.Count -gt 0/u);
  assert.doesNotMatch(packageInstaller, /Close all instances of the target Delphi IDE/u);
  assert.match(visualInstaller, /function PrepareToInstall/u);
  assert.match(visualInstaller, /function InitializeUninstall/u);
  assert.match(visualInstaller, /Win32_Process WHERE Name = "bds\.exe"/u);
  assert.match(visualInstaller, /Close all Delphi IDE instances before installing/u);
});

test('every static chat button provides contextual help', () => {
  const buttons = [...chatHtml.matchAll(/<button\b[\s\S]*?<\/button>/gu)];
  assert.ok(buttons.length > 0);
  buttons.forEach(match => {
    const openingTag = match[0].slice(0, match[0].indexOf('>') + 1);
    assert.match(openingTag, /\btitle="[^"]+"/u, openingTag);
  });
});

test('model selector remains governed by the active chat executor', () => {
  assert.match(chatJs, /let modelSelectionEnabled = true/);
  assert.match(chatJs, /data\.modelSelectionEnabled !== false/);
  assert.match(chatJs, /data\.enabled !== false/);
  assert.match(chatJs, /modelSelectionEnabled && !requestInProgress/);
});

test('execution scopes are visible, explained, and reversible without restarting the IDE', () => {
  assert.match(chatHtml, /id="btn-execution-scope"[^>]*title="[^"]+"/u);
  assert.match(chatHtml, /id="execution-scope-dialog"/u);
  assert.match(chatHtml, /Active project/u);
  assert.match(chatHtml, /Current chat session/u);
  assert.match(chatHtml, /Next request only/u);
  assert.match(chatHtml, /Restore all inheritance/u);
  assert.match(chatHtml, /id="btn-export-execution-scope"/u);
  assert.match(chatJs, /action: 'show_execution_scope'/u);
  assert.match(chatJs, /operation: 'inherit'/u);
  assert.match(chatJs, /action: 'export_execution_scope'/u);
  assert.match(chatJs, /Source: \$\{setting\.origin\}/u);
  assert.match(chatJs, /executionScopeDialog\.showModal\(\)/u);
});

test('disabled agent token budget is presented as unlimited', () => {
  assert.match(chatJs, /state\.maxTotalTokens > 0/u);
  assert.match(chatJs, /tokens \(unlimited\)/u);
});

test('runtime tool catalog explains discovery, risk, activation, and arguments', () => {
  assert.match(chatJs, /Search tools by name, purpose, or risk/);
  assert.match(chatJs, /How and when to use/);
  assert.match(chatJs, /Direct invocation:/);
  assert.match(chatJs, /Accepted arguments/);
  assert.match(chatJs, /tool\.inputSchema/);
});

test('configuration controls enable centralized contextual hints', () => {
  assert.match(configFrame, /procedure TRadIAFrameAIConfig\.ConfigureControlHints/);
  assert.match(configFrame, /procedure TRadIAFrameAIConfig\.ConfigureOperationalHints/);
  assert.match(configFrame, /LControl\.Hint := AHint/);
  assert.match(configFrame, /LControl\.ShowHint := True/);
  assert.match(configFrame, /ConfigureControlHints;/);
});

test('configuration separates focused pages and exposes CLI child navigation', () => {
  const configForm = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ConfigForm.pas'),
    'utf8'
  );

  assert.match(configFrame, /FTsKnowledge\.Caption := 'Knowledge & Embeddings'/u);
  assert.match(configFrame, /FTsEditorAssistance\.Caption := 'Editor Assistance'/u);
  assert.match(configFrame, /FTsCategoryOverview\.Caption := 'Category Overview'/u);
  assert.match(configFrame, /Enable ghost text \(inline completion/u);
  assert.match(configFrame, /FPnlCliMcp\.VertScrollBar\.Tracking := True/u);
  assert.match(configForm, /AddChild\(LNodeCli, 'External CLI clients'\)/u);
  assert.match(configForm, /AddChild\(LNodeCli, 'Chat Orchestration'\)/u);
  assert.match(configForm, /AddChild\(LNodeExternalCli, 'Codex CLI'\)/u);
  assert.match(configForm, /AddChild\(LNodeCli, 'MCP Connection'\)/u);
  assert.match(configForm, /AddChild\(LNodeCli, 'External MCP Servers'\)/u);
  assert.match(configFrame, /Items\.IndexOf\(ACategoryName\)/u);
  assert.match(configFrame, /External CLI: %s installation and authentication/u);
  assert.match(configFrame, /MCP client connection \(independent from chat orchestration\)/u);
  assert.match(configFrame, /SameText\(ACategoryName, 'AI Providers'\)/u);
  assert.match(configFrame, /SameText\(ACategoryName, 'CLI & MCP'\)/u);
});

test('programmatic external MCP frame has the VCL frame resource required at runtime', () => {
  assert.match(externalMcpFrame, /\{\$R \*\.dfm\}/u);
  assert.match(
    externalMcpFrameDfm,
    /object RadIAExternalMcpFrame: TRadIAExternalMcpFrame/u
  );
});

test('external MCP settings are separate, guided, and refresh without restart', () => {
  assert.match(configFrame, /FTsExternalMcp\.Caption := 'External MCP Servers'/u);
  assert.match(configFrame, /FExternalMcpFrame\.Parent := FTsExternalMcp/u);
  assert.match(externalMcpFrame, /FBtnServerTest\.Caption := 'Test'/u);
  assert.match(externalMcpFrame, /FBtnApply\.Caption := 'Apply'/u);
  assert.match(externalMcpFrame, /FBtnRefresh\.Caption := 'Refresh'/u);
  assert.match(externalMcpFrame, /FBtnImport\.Caption := 'Import\.\.\.'/u);
  assert.match(externalMcpFrame, /TRadIAExternalMcpConfigImporter\.ImportJson/u);
  assert.match(externalMcpFrame, /pending preview only/u);
  assert.match(externalMcpFrame, /SaveAndRefresh/u);
  assert.match(externalMcpFrame, /Refresh without restarting Delphi|refreshed without restarting Delphi/u);
  assert.match(externalMcpFrame, /procedure TRadIAExternalMcpFrame\.AddHint/u);
  assert.match(externalMcpFrame, /mtConfirmation/u);
  assert.match(externalMcpFrame, /TTask\.Run/u);
  assert.match(externalMcpFrame, /FScrollBox\.VertScrollBar\.Range := 860/u);
});

test('CLI and MCP setup exposes guided and recoverable actions', () => {
  assert.match(configFrame, /FBtnCliManual\.Caption := 'Manual steps'/u);
  assert.match(configFrame, /FBtnCliLogin\.Caption := 'Start login'/u);
  assert.match(configFrame, /MCP client connection \(independent from chat orchestration\)/u);
  assert.match(configFrame, /BuildPrerequisitePlan/u);
  assert.match(configFrame, /TRadIACliSetupHistory\.Append/u);
  assert.match(configFrame, /RefreshCliMcpDiagnostics/u);
});

test('diff review announces selection state and errors', () => {
  assert.match(diffHtml, /<output id="selection-summary" aria-live="polite"/);
  assert.match(diffHtml, /id="selection-error" role="alert" aria-live="assertive"/);
  assert.match(diffHtml, /setAttribute\(\s*'aria-pressed'/);
});
