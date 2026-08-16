/* global postMessageToDelphi */

const AGENT_GIT_TOOLS = new Set([
  'GetGitStatus',
  'GetGitDiff',
  'PreviewGitCommit',
  'CommitChanges'
]);

function looksLikePascalCode(code) {
  const text = String(code || '');
  const pascalSignals = [
    /\bprocedure\s+\w+/i,
    /\bfunction\s+\w+/i,
    /\bconstructor\s+\w+/i,
    /\bdestructor\s+\w+/i,
    /\bunit\s+\w+/i,
    /\binterface\b[\s\S]*\bimplementation\b/i,
    /\bbegin\b[\s\S]*\bend\s*[.;]/i,
    /\btry\b[\s\S]*\bfinally\b/i,
    /\bclass\s*(?:\(|;|$)/im,
    /:=/
  ];

  return pascalSignals.some((signal) => signal.test(text));
}

function normalizeCodeLanguage(language, code) {
  const normalized = String(language || 'pascal').trim().toLowerCase();
  const pascalAliases = ['delphi', 'objectpascal', 'object-pascal', 'pas'];
  const genericCodeLabels = [
    '',
    'code',
    'codigo',
    'c\u00F3digo',
    'snippet',
    'snippet de codigo',
    'snippet de c\u00F3digo'
  ];

  if (pascalAliases.includes(normalized) ||
      (genericCodeLabels.includes(normalized) && looksLikePascalCode(code))) {
    return 'pascal';
  }

  return normalized.replace(/[^a-z0-9_-]/gu, '') || 'pascal';
}

function escapeHtml(value) {
  return String(value || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function getMarkedTokenText(tokenOrText, fallback = '') {
  if (typeof tokenOrText === 'string') {
    return tokenOrText;
  }
  return tokenOrText?.text || tokenOrText?.raw || fallback;
}

function isSafeMarkdownLink(href) {
  const normalized = String(href || '')
    .replace(/[\u0000-\u0020]+/gu, '')
    .toLowerCase();
  const schemeMatch = /^([a-z][a-z0-9+.-]*):/u.exec(normalized);
  const scheme = schemeMatch?.[1] || '';
  return normalized !== '' &&
    (!scheme || ['http', 'https', 'mailto', 'file'].includes(scheme));
}

function renderCodeForLanguage(code, language) {
  if (Prism.languages[language]) {
    return Prism.highlight(code, Prism.languages[language], language);
  }
  return escapeHtml(code);
}

function getProjectFileAttributes(isProjectFile, safeFilepath) {
  if (!isProjectFile) {
    return '';
  }
  return `data-filepath="${safeFilepath}" data-project-file="true"`;
}

function getCodeHeaderTitle(language, highlightLanguage) {
  const normalized = String(language || 'pascal').trim();

  if (highlightLanguage === 'pascal') {
    return 'DELPHI';
  }

  return normalized.toUpperCase();
}

if (globalThis.Prism?.languages?.pascal) {
  Prism.languages.delphi = Prism.languages.pascal;
  Prism.languages.pas = Prism.languages.pascal;
  Prism.languages['object-pascal'] = Prism.languages.pascal;
}

marked.setOptions({
  gfm: true,
  breaks: true,
  pedantic: false,
  highlight: function(code, lang) {
    const language = normalizeCodeLanguage(lang, code);
    if (Prism.languages[language]) {
      return Prism.highlight(code, Prism.languages[language], language);
    }
    return code;
  }
});

const _codeRegistry = {};
let _codeRegistryCounter = 0;

const SVG_ICONS = {
  copy: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentC" +
    "olor\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rec" +
    "t x=\"9\" y=\"9\" width=\"13\" height=\"13\" rx=\"2\" ry=\"2\"></rect><path d=\"M5 15H4a2" +
    " 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1\"></path></svg>",
  apply: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentC" +
    "olor\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><pat" +
    "h d=\"M20 6L9 17l-5-5\"></path></svg>",
  check: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#10b981\"" +
    " stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"" +
    "M20 6L9 17l-5-5\"></path></svg>",
  edit: "<svg width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentC" +
    "olor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path " +
    "d=\"M12 20h9\"></path><path d=\"M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L1" +
    "6.5 3.5z\"></path></svg>",
  trash: "<svg width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentC" +
    "olor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyl" +
    "ine points=\"3 6 5 6 21 6\"></polyline><path d=\"M19 6v14a2 2 0 0 1-2 2H7a2 2 0" +
    " 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\"></path></svg>"
};

const renderer = new marked.Renderer();
renderer.html = function(tokenOrHtml) {
  return escapeHtml(tokenOrHtml?.raw || tokenOrHtml);
};
renderer.link = function(tokenOrHref, title, text) {
  const href = typeof tokenOrHref === 'object' ? tokenOrHref.href : tokenOrHref;
  const label = getMarkedTokenText(tokenOrHref, text || href);
  if (!isSafeMarkdownLink(href)) {
    return escapeHtml(label);
  }
  const safeTitle = typeof tokenOrHref === 'object' ? tokenOrHref.title : title;
  const titleAttribute = safeTitle ? ` title="${escapeHtml(safeTitle)}"` : '';
  return `<a href="${escapeHtml(href)}"${titleAttribute}>${escapeHtml(label)}</a>`;
};
renderer.image = function(tokenOrHref, title, text) {
  const label = getMarkedTokenText(tokenOrHref, text || title || 'Image');
  return `<span class="markdown-image-placeholder">${escapeHtml(label)}</span>`;
};
renderer.code = function(codeOrToken, lang) {
  let code = '';
  let language = '';

  if (typeof codeOrToken === 'string') {
    code = codeOrToken;
    language = lang || 'code';
  } else if (codeOrToken && typeof codeOrToken === 'object') {
    code = codeOrToken.text || '';
    language = codeOrToken.lang || lang || 'code';
  } else {
    code = String(codeOrToken || '');
    language = lang || 'code';
  }

  let filepath = '';
  let isProjectFile = false;
  const prefixMatch = /^(?:\/\/|\{#|\{\*|<!--)\s*filepath:\s*/i.exec(code);

  if (prefixMatch) {
    let rawPath = code.substring(prefixMatch[0].length).trim();
    if (!rawPath.includes('\n')) {
      if (rawPath.endsWith('-->')) rawPath = rawPath.substring(0, rawPath.length - 3).trim();
      else if (rawPath.endsWith('*}')) rawPath = rawPath.substring(0, rawPath.length - 2).trim();
      else if (rawPath.endsWith('}')) rawPath = rawPath.substring(0, rawPath.length - 1).trim();

      filepath = rawPath;
      isProjectFile = true;
      code = '';
    }
  }

  const id = 'cb_' + (++_codeRegistryCounter);
  _codeRegistry[id] = code;

  const highlightLanguage = normalizeCodeLanguage(language, code);
  const isPascal = highlightLanguage === 'pascal';
  const headerTitleText = getCodeHeaderTitle(language, highlightLanguage);
  const safeFilepath = escapeHtml(filepath);
  const headerTitle = isProjectFile
    ? `${escapeHtml(headerTitleText)} - ${safeFilepath}`
    : escapeHtml(headerTitleText);
  const renderedCode = renderCodeForLanguage(code, highlightLanguage);
  const projectFileAttributes = getProjectFileAttributes(isProjectFile, safeFilepath);

  return `
    <div class="code-block-container" ${projectFileAttributes}>
      <div class="code-header">
        <span>${headerTitle}</span>
        <div class="code-header-actions">
          <button class="copy-btn" title="Copy Code" onclick="copyCode(this, '${id}')">${SVG_ICONS.copy}</button>
          ${isPascal
            ? `<button class="apply-btn" title="Apply to Editor" ` +
              `onclick="applyCode('${id}')">${SVG_ICONS.apply}</button>`
            : ''}
        </div>
      </div>
      <pre><code class="language-${highlightLanguage}">${renderedCode}</code></pre>
    </div>
  `;
};
marked.use({
  renderer,
  gfm: true,
  breaks: true
});

const chatContainer   = document.getElementById('chat-container');
const btnClearChat    = document.getElementById('btn-clear-chat');
const btnHistory      = document.getElementById('btn-history');
const btnSettings     = document.getElementById('btn-settings');
const btnAgentMode    = document.getElementById('btn-agent-mode');
const btnTerminal     = document.getElementById('btn-terminal');
const btnAgentHistory = document.getElementById('btn-agent-history');
const btnProblems     = document.getElementById('btn-problems');
const problemsBadge   = document.getElementById('problems-badge');
const problemsPanel   = document.getElementById('problems-panel');
const problemsSummary = document.getElementById('problems-summary');
const problemsList    = document.getElementById('problems-list');
const problemsSeverityFilter = document.getElementById('problems-severity-filter');
const problemsCategoryFilter = document.getElementById('problems-category-filter');
const btnCloseProblems = document.getElementById('btn-close-problems');
const btnClearProblems = document.getElementById('btn-clear-problems');
const btnCliNewSession = document.getElementById('btn-cli-new-session');
const btnJourneyContext = document.getElementById('btn-journey-context');
const btnExecutionScope = document.getElementById('btn-execution-scope');
const btnComposerAdvanced = document.getElementById('btn-composer-advanced');
const composerAdvancedOptions = document.getElementById('composer-advanced-options');
const executionScopeDialog = document.getElementById('execution-scope-dialog');
const executionScopeKind = document.getElementById('execution-scope-kind');
const executionScopeFields = document.getElementById('execution-scope-fields');
const executionScopeNote = document.getElementById('execution-scope-note');
const btnClearExecutionScope = document.getElementById('btn-clear-execution-scope');
const btnExportExecutionScope = document.getElementById('btn-export-execution-scope');
const executionRoute  = document.getElementById('execution-route');
const composerRoute   = document.getElementById('composer-route');
const executionRouteSelector = document.getElementById('select-execution-route');
const reasoningEffortSelector = document.getElementById('select-reasoning-effort');
const effortDropdownWrapper = document.getElementById('effort-dropdown-wrapper');
const effortDropdownTrigger = document.getElementById('effort-dropdown-trigger');
const effortDropdownValue = document.getElementById('effort-dropdown-value');
const effortOptionsList = document.getElementById('effort-options-list');

function setComposerAdvancedVisible(visible) {
  if (!btnComposerAdvanced || !composerAdvancedOptions) return;
  composerAdvancedOptions.classList.toggle('hidden', !visible);
  btnComposerAdvanced.setAttribute('aria-expanded', String(visible));
  btnComposerAdvanced.setAttribute(
    'aria-label',
    visible ? 'Hide advanced execution settings' : 'Show advanced execution settings'
  );
  btnComposerAdvanced.title = visible
    ? 'Hide executor, session, journey, and scope settings'
    : 'Show executor, session, journey, and scope settings';
  const label = btnComposerAdvanced.querySelector('.btn-label');
  if (label) label.textContent = visible ? 'Less' : 'More';
}
let activeExecutionRoute = {
  displayName: 'Native',
  label: 'Chat | Native provider',
  mode: 'chat',
  transport: 'native'
};
let activeResponseContext = null;

const ROUTE_AVATARS = {
  native: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2l1.5 5.5L19 9l-5.5 ' +
    '1.5L12 16l-1.5-5.5L5 9l5.5-1.5L12 2z"/><path d="M18 15l.8 2.2L21 18l-2.2.8L18 21l-.8-2.2L15 ' +
    '18l2.2-.8L18 15z"/></svg>',
  cli: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" ' +
    'height="16" rx="2"/><path d="M7 9l3 3-3 3M12 15h5"/></svg>',
  mcp: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="5" r="2"/>' +
    '<circle cx="5" cy="18" r="2"/><circle cx="19" cy="18" r="2"/><path d="M11 7L6 16M13 7l5 9M7 18h10"/>' +
    '</svg>'
};

const promptTextarea  = document.getElementById('prompt-textarea');
const btnSendPrompt   = document.getElementById('btn-send-prompt');
const btnQueuePrompt  = document.getElementById('btn-queue-prompt');
const queuedPromptsBar = document.getElementById('queued-prompts');
const queuedPromptsText = document.getElementById('queued-prompts-text');
const btnEditQueued = document.getElementById('btn-edit-queued');
const btnClearQueued = document.getElementById('btn-clear-queued');
const selectProvider  = document.getElementById('select-provider');
const selectModel     = document.getElementById('select-model');
const modelDropdownWrapper = document.getElementById('model-dropdown-wrapper');
const modelDropdownTrigger = document.getElementById('model-dropdown-trigger');
const modelDropdownValue   = document.getElementById('model-dropdown-value');
const modelSearchInput     = document.getElementById('model-search-input');
const modelOptionsList     = document.getElementById('model-options-list');
const providerDropdownWrapper = document.getElementById('provider-dropdown-wrapper');
const providerDropdownTrigger = document.getElementById('provider-dropdown-trigger');
const providerDropdownValue   = document.getElementById('provider-dropdown-value');
const providerOptionsList     = document.getElementById('provider-options-list');
const statusBar       = document.getElementById('status-bar');
const statusText      = document.getElementById('status-text');
const contextBar      = document.getElementById('context-bar');
const contextText     = document.getElementById('context-text');
let lifecycleStateTimer = 0;

function captureLifecycleState() {
  postMessageToDelphi({
    action: 'webview_lifecycle_state',
    state: {
      draft: String(promptTextarea?.value || '').slice(0, 12000),
      scrollTop: Math.max(0, Math.round(chatContainer?.scrollTop || 0)),
      advanced: btnComposerAdvanced?.getAttribute('aria-expanded') === 'true'
    }
  });
}

function scheduleLifecycleStateCapture() {
  globalThis.clearTimeout(lifecycleStateTimer);
  lifecycleStateTimer = globalThis.setTimeout(captureLifecycleState, 120);
}

function restoreLifecycleState(state, smoke = false) {
  if (!state || typeof state !== 'object') return;
  const draft = String(state.draft || '').slice(0, 12000);
  if (promptTextarea && !promptTextarea.value) {
    promptTextarea.value = draft;
    promptTextarea.dispatchEvent(new Event('input'));
  }
  setComposerAdvancedVisible(state.advanced === true);
  const scrollTop = Math.max(0, Math.min(10000000, Number(state.scrollTop) || 0));
  [0, 100, 500].forEach(delay => {
    globalThis.setTimeout(() => {
      if (chatContainer) chatContainer.scrollTop = scrollTop;
    }, delay);
  });
  if (smoke) {
    globalThis.setTimeout(() => {
      postMessageToDelphi({
        action: 'webview_lifecycle_smoke_result',
        draftRestored: promptTextarea?.value === 'radia-webview-recovery-draft',
        advancedRestored: btnComposerAdvanced?.getAttribute('aria-expanded') === 'true'
      });
    }, 600);
  }
}

function beginLifecycleSmoke() {
  if (promptTextarea) {
    promptTextarea.value = 'radia-webview-recovery-draft';
    promptTextarea.dispatchEvent(new Event('input'));
  }
  if (btnComposerAdvanced?.getAttribute('aria-expanded') !== 'true') {
    btnComposerAdvanced?.click();
  }
  captureLifecycleState();
  globalThis.setTimeout(() => {
    postMessageToDelphi({ action: 'webview_lifecycle_smoke_ready' });
  }, 300);
}

globalThis.beginLifecycleSmoke = beginLifecycleSmoke;

const sessionsSidebar = document.getElementById('sessions-sidebar');
const btnNewChatSidebar = document.getElementById('btn-new-chat-sidebar');
const sessionsList    = document.getElementById('sessions-list');

let SLASH_COMMANDS = [
  { name: '/explain', desc: 'Explains the selected code in the editor', shortcut: '' },
  { name: '/refactor', desc: 'Optimizes and refactors the selected code', shortcut: '' },
  { name: '/bugs', desc: 'Finds bugs and memory leaks in the selected code', shortcut: '' },
  { name: '/doc', desc: 'Generates XML documentation for the selected method', shortcut: '' },
  { name: '/template', desc: 'Opens the prompt templates library', shortcut: '' },
  { name: '/stacktrace', desc: 'Analyzes an error log or stack trace and points out the root cause', shortcut: '' },
  { name: '/review', desc: 'Performs static analysis on the active unit (leaks/SOLID)', shortcut: '' },
  { name: '/createproject', desc: 'Generates a complete Delphi project from specification', shortcut: '' }
];
let AVAILABLE_TOOLS = [];
let agentModeEnabled = true;
const TOOL_CARDS = new Map();
const AGENT_CARDS = new Map();
const COLLECTED_PROBLEMS = new Map();
let currentProblemSessionId = '';

function setAgentMode(enabled) {
  agentModeEnabled = enabled !== false;
  btnAgentMode.classList.toggle('agent-mode-enabled', agentModeEnabled);
  btnAgentMode.classList.toggle('agent-mode-disabled', !agentModeEnabled);
  btnAgentMode.title = agentModeEnabled
    ? 'Agent mode is on: RadIA may use IDE tools after policy and consent checks'
    : 'Agent mode is off: messages use chat only and cannot execute IDE tools';
  btnAgentMode.setAttribute(
    'aria-label',
    `Agent Mode: ${agentModeEnabled ? 'On' : 'Off'}`
  );
  btnAgentMode.setAttribute('aria-pressed', String(agentModeEnabled));
  btnAgentMode.querySelector('.btn-label').textContent = agentModeEnabled ? 'Agent' : 'Chat';
  btnAgentMode.setAttribute('aria-label', `Mode: ${agentModeEnabled ? 'Agent' : 'Chat'}`);
  executionRouteSelector.disabled = requestInProgress;
  updateComposerRoute();
}

function createAgentControl(label, action, disabled = false) {
  const button = document.createElement('button');
  button.className = 'agent-control-button';
  button.textContent = label;
  button.title = `${label} the current agent run`;
  button.disabled = disabled;
  button.addEventListener('click', () => {
    postMessageToDelphi({ action });
  });
  return button;
}

function parseAgentStepResult(step) {
  if (!step.success || !step.result) {
    return null;
  }
  if (typeof step.result === 'object') {
    return step.result;
  }
  try {
    return JSON.parse(step.result);
  } catch {
    return null;
  }
}

function appendAgentPatchReview(details, step) {
  const result = parseAgentStepResult(step);
  if (!result) {
    return;
  }
  const files = RadIAAgentDiff.extractFiles(step.toolName, result);
  if (files.length === 0) {
    return;
  }
  const review = document.createElement('section');
  review.className = 'agent-step-diff';
  const title = document.createElement('strong');
  title.textContent = `Reviewed changes (${files.length} file(s))`;
  const note = document.createElement('p');
  note.textContent =
    'Review-only snapshot. Applying or reverting still follows the agent consent flow.';
  review.appendChild(title);
  review.appendChild(note);
  files.forEach(file => {
    const hunk = RadIAAgentDiff.buildHunk(
      file.originalContent,
      file.proposedContent
    );
    const fileDetails = document.createElement('details');
    fileDetails.open = files.length === 1;
    const fileSummary = document.createElement('summary');
    fileSummary.textContent = file.targetFile || 'Changed file';
    const hunkMetadata = document.createElement('div');
    hunkMetadata.className = 'agent-step-diff-metadata';
    hunkMetadata.textContent =
      `Starting at line ${hunk.originalStartLine} · ` +
      `${hunk.originalChangedLines} removed · ` +
      `${hunk.proposedChangedLines} added`;
    const comparison = document.createElement('div');
    comparison.className = 'patch-preview-comparison';
    const before = document.createElement('pre');
    before.className = 'patch-preview-before';
    before.textContent = hunk.original;
    const after = document.createElement('pre');
    after.className = 'patch-preview-after';
    after.textContent = hunk.proposed;
    comparison.appendChild(before);
    comparison.appendChild(after);
    fileDetails.appendChild(fileSummary);
    fileDetails.appendChild(hunkMetadata);
    fileDetails.appendChild(comparison);
    review.appendChild(fileDetails);
  });
  details.appendChild(review);
}

function appendAgentGitDiff(evidence, result) {
  if (typeof result.diff !== 'string') {
    return;
  }
  const summary = RadIAAgentGit.summarizeDiff(result.diff);
  const metadata = document.createElement('div');
  metadata.className = 'agent-step-git-metadata';
  metadata.textContent =
    `${summary.files.length} file(s) · ` +
    `${summary.additions} addition(s) · ${summary.removals} removal(s)`;
  const diff = document.createElement('pre');
  diff.className = 'agent-step-git-diff';
  const maximumVisibleLines = 2000;
  summary.tokens.slice(0, maximumVisibleLines).forEach(token => {
    const line = document.createElement('span');
    line.className = `is-${token.kind}`;
    line.textContent = token.text + '\n';
    diff.appendChild(line);
  });
  if (summary.tokens.length > maximumVisibleLines) {
    const truncated = document.createElement('span');
    truncated.className = 'is-header';
    truncated.textContent =
      `… ${summary.tokens.length - maximumVisibleLines} additional line(s) hidden`;
    diff.appendChild(truncated);
  }
  evidence.appendChild(metadata);
  evidence.appendChild(diff);
}

function appendAgentGitEvidence(details, step) {
  if (!AGENT_GIT_TOOLS.has(step.toolName)) {
    return;
  }
  const result = parseAgentStepResult(step);
  if (!result) {
    return;
  }
  const evidence = document.createElement('section');
  evidence.className = 'agent-step-git';
  const title = document.createElement('strong');
  title.textContent = 'Git evidence';
  evidence.appendChild(title);
  if (step.toolName === 'GetGitStatus' && typeof result.status === 'string') {
    const status = document.createElement('pre');
    status.textContent = result.status || 'Working tree clean';
    evidence.appendChild(status);
  }
  if (step.toolName === 'PreviewGitCommit') {
    const preview = document.createElement('div');
    preview.className = 'agent-step-git-metadata';
    const paths = Array.isArray(result.paths) ? result.paths.length : 0;
    preview.textContent =
      `Message: ${result.message || ''} · ${paths} selected path(s) · ` +
      `Fingerprint: ${result.fingerprint || 'unavailable'}`;
    evidence.appendChild(preview);
  }
  if (step.toolName === 'CommitChanges' && result.committed === true) {
    const commit = document.createElement('code');
    commit.textContent = `Local commit: ${result.commit || 'unavailable'}`;
    evidence.appendChild(commit);
  }
  appendAgentGitDiff(evidence, result);
  details.appendChild(evidence);
}

function appendAgentDebugList(evidence, items, formatter, ordered = false) {
  const list = document.createElement(ordered ? 'ol' : 'ul');
  RadIAAgentDebug.boundedItems(items).forEach(item => {
    const row = document.createElement('li');
    row.textContent = formatter(item);
    list.appendChild(row);
  });
  evidence.appendChild(list);
}

function appendAgentDebugState(evidence, result) {
  const state = document.createElement('div');
  state.className = 'agent-step-debug-metadata';
  state.textContent =
    `State: ${result.state || 'unavailable'} · ` +
    `Process: ${result.osProcessId || result.processId || 0} · ` +
    `Threads: ${result.threadCount || 0} · ` +
    `Breakpoints: ${result.breakpointCount || 0}`;
  evidence.appendChild(state);
  if (result.location || result.executableName) {
    const location = document.createElement('code');
    location.textContent =
      `${result.executableName || 'process'} · ${result.location || 'no source location'}`;
    evidence.appendChild(location);
  }
}

function appendAgentDebugBreakpoints(evidence, result) {
  if (Array.isArray(result.breakpoints)) {
    appendAgentDebugList(evidence, result.breakpoints, breakpoint =>
      `${breakpoint.enabled ? 'Enabled' : 'Disabled'} · ` +
      `${breakpoint.valid ? 'valid' : 'pending'} · ` +
      `${breakpoint.fileName || 'unknown'}:${breakpoint.lineNumber || 0}`
    );
    return;
  }
  const action = document.createElement('div');
  action.className = 'agent-step-debug-metadata';
  action.textContent =
    `${result.action || 'Breakpoint update'} · ` +
    `${result.fileName || 'unknown'}:${result.lineNumber || 0} · ` +
    `Undo with ${result.inverseTool || 'the inverse tool'}`;
  evidence.appendChild(action);
}

function appendAgentDebugCallStack(evidence, result) {
  const status = document.createElement('div');
  status.className = 'agent-step-debug-metadata';
  status.textContent =
    `${result.accessible ? 'Accessible' : 'Unavailable'} · ` +
    `${result.status || 'unknown'} · ${result.count || 0} frame(s)`;
  evidence.appendChild(status);
  appendAgentDebugList(evidence, result.frames, frame =>
    `${frame.index ?? '?'} · ${frame.header || 'frame'} · ` +
    `${frame.fileName || 'no source'}:${frame.lineNumber || 0}`,
  true);
}

function appendAgentDebugAction(evidence, result) {
  const action = document.createElement('div');
  action.className = 'agent-step-debug-metadata';
  action.textContent =
    `${result.stateBefore || 'unknown'} → ${result.stateAfter || 'unknown'} · ` +
    `${result.message || (result.accepted ? 'Accepted' : 'Completed')}`;
  evidence.appendChild(action);
}

function appendAgentDebugValue(evidence, result) {
  const value = document.createElement('dl');
  const expression = document.createElement('dt');
  expression.textContent = result.expression || 'Expression';
  const output = document.createElement('dd');
  output.textContent =
    `${result.result ?? 'unavailable'} · ${result.status || 'unknown'} · ` +
    `${result.canModify ? 'modifiable' : 'read-only'}`;
  value.appendChild(expression);
  value.appendChild(output);
  evidence.appendChild(value);
}

function appendAgentDebugWatches(evidence, result) {
  if (Array.isArray(result.watches)) {
    appendAgentDebugList(evidence, result.watches, watch => {
      if (typeof watch === 'string') {
        return watch;
      }
      return `${watch.expression || 'expression'} = ${watch.result ?? 'unavailable'} · ` +
        `${watch.status || 'unknown'}`;
    });
    return;
  }
  const watch = document.createElement('div');
  watch.className = 'agent-step-debug-metadata';
  watch.textContent = `${result.expression || 'Watch'} · updated`;
  evidence.appendChild(watch);
}

function appendAgentDebugTimeline(evidence, result) {
  appendAgentDebugList(evidence, result.events, event =>
    `#${event.sequence || 0} · ${event.timestampUtc || 'unknown time'} · ` +
    `${event.kind || 'event'} · ${event.state || 'unknown'} · ` +
    `${event.details || ''}`,
  true);
}

const AGENT_DEBUG_RENDERERS = {
  state: appendAgentDebugState,
  breakpoints: appendAgentDebugBreakpoints,
  callStack: appendAgentDebugCallStack,
  action: appendAgentDebugAction,
  value: appendAgentDebugValue,
  watches: appendAgentDebugWatches,
  timeline: appendAgentDebugTimeline
};

function appendAgentDebugEvidence(details, step) {
  const kind = RadIAAgentDebug.evidenceKind(step.toolName);
  const renderer = AGENT_DEBUG_RENDERERS[kind];
  if (!renderer) {
    return;
  }
  const result = parseAgentStepResult(step);
  if (!result) {
    return;
  }
  const evidence = document.createElement('section');
  evidence.className = 'agent-step-debug';
  const title = document.createElement('strong');
  title.textContent = 'Debug evidence';
  evidence.appendChild(title);
  renderer(evidence, result);
  details.appendChild(evidence);
}

const AGENT_DEVELOPMENT_TRANSACTION_TOOLS = new Set([
  'PrepareDevelopmentTransaction',
  'ApplyDevelopmentTransaction',
  'RevertDevelopmentTransaction',
  'RejectDevelopmentTransactionStep',
  'RevertDevelopmentTransactionStep'
]);

function appendAgentDevelopmentPlan(details, step) {
  if (!AGENT_DEVELOPMENT_TRANSACTION_TOOLS.has(step.toolName)) {
    return;
  }
  const result = parseAgentStepResult(step);
  if (!result || !Array.isArray(result.operations)) {
    return;
  }
  const plan = document.createElement('section');
  plan.className = 'agent-development-plan';
  const title = document.createElement('strong');
  title.textContent = `Code/Design plan · ${result.state || 'unknown'}`;
  plan.appendChild(title);
  const list = document.createElement('ol');
  result.operations.forEach(operation => {
    const item = document.createElement('li');
    const state = String(operation.state || 'pending');
    item.className = `is-${state}`;
    const label = document.createElement('strong');
    label.textContent = operation.label || operation.kind || 'Development step';
    const metadata = document.createElement('span');
    metadata.textContent =
      `${operation.kind || 'unknown'} · ${state} · ` +
      `${operation.previewId || 'no preview'}`;
    item.appendChild(label);
    item.appendChild(metadata);
    list.appendChild(item);
  });
  plan.appendChild(list);
  details.appendChild(plan);
}

function createAgentStep(step, status) {
  const item = document.createElement('li');
  item.className = `agent-run-step ${step.success ? 'is-success' : 'is-failure'}`;
  if (step.mutation) item.classList.add('is-mutation');

  const details = document.createElement('details');
  const summary = document.createElement('summary');
  const outcome = step.success ? 'completed' : (step.errorCode || 'failed');
  const duration = Math.max(0, step.durationMilliseconds || 0);
  summary.textContent =
    `${step.index}. ${step.toolName} — ${outcome} · ${duration} ms` +
    (step.mutation ? ' · mutation' : '') +
    (step.replayOfStepIndex ? ` · replay of ${step.replayOfStepIndex}` : '');
  details.appendChild(summary);

  const metadata = document.createElement('div');
  metadata.className = 'agent-run-step-metadata';
  metadata.textContent =
    `Correlation: ${step.correlationId || 'unavailable'} · ` +
    `Started: ${Math.max(0, step.startedElapsedMilliseconds || 0)} ms · ` +
    `Risk: ${step.risk || 'unknown'}`;
  details.appendChild(metadata);

  appendCopyablePayload(details, step.arguments, 'Arguments');
  appendCopyablePayload(
    details,
    step.success ? step.result : step.errorMessage,
    step.success ? 'Result' : 'Error'
  );
  appendAgentPatchReview(details, step);
  appendAgentGitEvidence(details, step);
  appendAgentDebugEvidence(details, step);
  appendAgentDevelopmentPlan(details, step);
  const replay = document.createElement('button');
  replay.className = 'agent-step-replay';
  replay.textContent = 'Replay step';
  replay.disabled = status !== 'paused';
  replay.title = status === 'paused'
    ? 'Replay this exact audited tool call'
    : 'Pause the agent run before replaying a step';
  replay.addEventListener('click', () => {
    const warning =
      `Replay mutating step ${step.index} (${step.toolName}) with the same arguments?`;
    if (step.mutation && !confirm(warning)) return;
    postMessageToDelphi({
      action: 'replay_agent_step',
      stepIndex: step.index
    });
  });
  details.appendChild(replay);
  item.appendChild(details);
  return item;
}

function renderAgentImpact(card, steps) {
  const impact = card.querySelector('.agent-run-impact');
  impact.replaceChildren();
  const riskOrder = {
    unknown: 0,
    readOnly: 1,
    reversibleWrite: 2,
    structuralWrite: 3,
    execution: 4,
    destructive: 5,
    sensitive: 6
  };
  let highestRisk = 'unknown';
  const files = [];
  steps.forEach(step => {
    const risk = step.risk || 'unknown';
    if ((riskOrder[risk] || 0) > (riskOrder[highestRisk] || 0)) {
      highestRisk = risk;
    }
    const affectedFiles = Array.isArray(step.affectedFiles) ? step.affectedFiles : [];
    affectedFiles.forEach(file => {
      if (!files.some(existing => existing.toLowerCase() === file.toLowerCase())) {
        files.push(file);
      }
    });
  });
  const details = document.createElement('details');
  const summary = document.createElement('summary');
  summary.textContent = `Highest risk: ${highestRisk} · ${files.length} affected file(s)`;
  details.appendChild(summary);
  if (files.length > 0) {
    const list = document.createElement('ul');
    files.forEach(file => {
      const item = document.createElement('li');
      item.textContent = file;
      list.appendChild(item);
    });
    details.appendChild(list);
  }
  impact.appendChild(details);
}

function getAgentValidationStatuses(validation) {
  const buildStatus = validation.buildStatus ||
    (validation.buildPassed ? 'succeeded' : 'notRun');
  let testStatus = 'not-run';
  let executionStatus = 'not-run';
  let debugStatus = 'not-run';
  let coverageLabel = 'Coverage';
  if (validation.testsRun) {
    testStatus = validation.testsPassed ? 'passed' : 'failed';
  }
  if (validation.executionRun) {
    executionStatus = validation.executionPassed ? 'passed' : 'failed';
  }
  if (validation.debugObserved) {
    debugStatus = 'observed';
  }
  if (validation.coverageAvailable) {
    coverageLabel = `Coverage ${Math.max(0, validation.coveragePercent || 0)}%`;
  }
  return {
    buildStatus,
    testStatus,
    executionStatus,
    debugStatus,
    coverageLabel
  };
}

function renderAgentValidation(card, state) {
  const validation = state.validation || {};
  const validationElement = card.querySelector('.agent-run-validation');
  const statuses = getAgentValidationStatuses(validation);
  const {
    buildStatus,
    testStatus,
    executionStatus,
    debugStatus,
    coverageLabel
  } = statuses;
  validationElement.replaceChildren();
  const indicators = [
    ['Changes', validation.mutationPending ? 'pending' : 'clean'],
    ['Build', buildStatus === 'succeeded' ? 'passed' : 'not-passed'],
    ['Tests', testStatus],
    ['Execution', executionStatus],
    ['Debug', debugStatus],
    [
      coverageLabel,
      validation.coverageAvailable ? 'available' : 'not-run'
    ]
  ];
  indicators.forEach(([label, value]) => {
    const indicator = document.createElement('span');
    indicator.className = `agent-validation-indicator is-${value}`;
    indicator.textContent = `${label}: ${value.replace('-', ' ')}`;
    validationElement.appendChild(indicator);
  });
  const evidenceLines = [];
  if (buildStatus !== 'notRun') {
    evidenceLines.push(
      `Build: ${buildStatus} · ` +
      `${Math.max(0, validation.buildDurationMilliseconds || 0)} ms · ` +
      `${Math.max(0, validation.buildMessageCount || 0)} compiler message(s)`
    );
  }
  if (validation.testsRun) {
    evidenceLines.push(
      `DUnitX: ${validation.testStatus || testStatus} · ` +
      `${Math.max(0, validation.testDurationMilliseconds || 0)} ms · ` +
      `${Math.max(0, validation.testTotal || 0)} total · ` +
      `${Math.max(0, validation.testPassed || 0)} passed · ` +
      `${Math.max(0, validation.testFailed || 0)} failed · ` +
      `${Math.max(0, validation.testErrors || 0)} error(s) · ` +
      `${Math.max(0, validation.testIgnored || 0)} ignored`
    );
  }
  if (validation.coverageAvailable) {
    evidenceLines.push(
      `Coverage: ${Math.max(0, validation.coveragePercent || 0)}% · ` +
      `${Math.max(0, validation.coverageCoveredLines || 0)}/` +
      `${Math.max(0, validation.coverageSourceLines || 0)} line(s) · ` +
      `${Math.max(0, validation.coverageSourceFiles || 0)} source file(s) · ` +
      `${validation.coverageReportPath || 'authoritative report'}`
    );
  }
  if (validation.executionRun) {
    evidenceLines.push(
      `Execution: ${validation.executionTool || 'unknown'} · ` +
      `${validation.executionPassed ? 'succeeded' : 'failed'} · ` +
      `${Math.max(0, validation.executionDurationMilliseconds || 0)} ms`
    );
  }
  if (validation.debugObserved) {
    evidenceLines.push(
      `Debug: ${validation.debugState || 'observed'} · ` +
      `timeline sequence ${Math.max(0, validation.debugLastSequence || 0)}`
    );
  }
  if (evidenceLines.length > 0) {
    const evidence = document.createElement('details');
    evidence.className = 'agent-validation-evidence';
    const summary = document.createElement('summary');
    summary.textContent = 'Validation evidence';
    const content = document.createElement('pre');
    content.textContent = evidenceLines.join('\n');
    evidence.appendChild(summary);
    evidence.appendChild(content);
    validationElement.appendChild(evidence);
  }
}

function renderAgentPlanItems(planElement, plan) {
  planElement.replaceChildren();
  plan.forEach(planStep => {
    const item = document.createElement('li');
    const title = planStep?.title || 'Planned step';
    const description = planStep?.description || '';
    item.textContent = description ? `${title} — ${description}` : title;
    planElement.appendChild(item);
  });
}

const PROJECT_OPERATION_STAGES = [
  { id: 'prepare', label: 'Preparing request', tools: [] },
  { id: 'preview', label: 'Reviewing project structure', tools: ['PreviewProjectTemplate'] },
  { id: 'create', label: 'Creating project files', tools: ['CreateProjectFromTemplate'] },
  {
    id: 'open',
    label: 'Opening project in Delphi',
    tools: ['OpenCreatedProject', 'ValidateCreatedProject']
  },
  {
    id: 'build',
    label: 'Building the project',
    tools: ['ValidateCreatedProject', 'BuildProject']
  },
  { id: 'complete', label: 'Project ready', tools: [] }
];

function isProjectCreationRun(state) {
  const objective = String(state.objective || '').toLowerCase();
  const planText = (Array.isArray(state.plan) ? state.plan : [])
    .map(step => `${step?.title || ''} ${step?.description || ''}`)
    .join(' ')
    .toLowerCase();
  const steps = Array.isArray(state.steps) ? state.steps : [];
  const hasProjectTool = steps.some(step => PROJECT_OPERATION_STAGES.some(stage =>
    stage.tools.includes(step.toolName)
  ));
  return hasProjectTool || /\b(create|generate|new)\b.*\bproject\b/u.test(`${objective} ${planText}`);
}

function getProjectStageState(stage, state) {
  const steps = Array.isArray(state.steps) ? state.steps : [];
  const matchingSteps = steps.filter(step => stage.tools.includes(step.toolName));
  const stageSucceeded = step => {
    if (!step.success) return false;
    if (stage.id !== 'build' || step.toolName !== 'ValidateCreatedProject') return true;
    const result = parseAgentStepResult(step);
    return result?.buildSucceeded === true;
  };
  const failed = matchingSteps.some(step => !stageSucceeded(step));
  if (failed) return 'failed';
  if (matchingSteps.length > 0) return 'completed';
  if (stage.id === 'prepare') return 'completed';
  if (stage.id === 'complete' && state.status === 'completed') return 'completed';

  const stageIndex = PROJECT_OPERATION_STAGES.indexOf(stage);
  const furthestCompletedIndex = PROJECT_OPERATION_STAGES.reduce((furthest, candidate, index) => {
    const wasCompleted = steps.some(step => {
      if (!candidate.tools.includes(step.toolName) || !step.success) return false;
      if (candidate.id !== 'build' || step.toolName !== 'ValidateCreatedProject') return true;
      return parseAgentStepResult(step)?.buildSucceeded === true;
    });
    return wasCompleted ? Math.max(furthest, index) : furthest;
  }, 0);
  if (state.status === 'failed' || state.status === 'cancelled') return 'pending';
  return stageIndex === furthestCompletedIndex + 1 ? 'current' : 'pending';
}

function renderProjectOperationSummary(card, state) {
  const summary = card.querySelector('.agent-operation-summary');
  const stagesElement = card.querySelector('.agent-operation-stages');
  const exclusions = card.querySelector('.agent-operation-exclusions');
  const result = card.querySelector('.agent-operation-result');
  const actions = card.querySelector('.agent-operation-actions');
  const isProjectRun = isProjectCreationRun(state);
  summary.hidden = !isProjectRun;
  if (!isProjectRun) return;

  stagesElement.replaceChildren();
  PROJECT_OPERATION_STAGES.forEach(stage => {
    const stageState = getProjectStageState(stage, state);
    const item = document.createElement('li');
    const marker = document.createElement('span');
    const label = document.createElement('span');
    item.className = `agent-operation-stage is-${stageState}`;
    item.setAttribute('aria-current', stageState === 'current' ? 'step' : 'false');
    marker.className = 'agent-operation-marker';
    marker.setAttribute('aria-hidden', 'true');
    label.textContent = stage.label;
    item.append(marker, label);
    stagesElement.appendChild(item);
  });
  exclusions.textContent = 'Not added automatically: DUnitX and other optional features.';
  result.textContent = state.status === 'completed'
    ? 'Result: the requested project is ready. Optional additions remain your choice.'
    : 'Expected result: the requested project opens in Delphi and builds successfully.';
  actions.replaceChildren();
  if (state.status !== 'completed') return;
  [
    ['Add DUnitX tests', 'Add a DUnitX test project to the project that was just created.'],
    ['Review optional additions', 'Show optional additions for the project that was just created.']
  ].forEach(([label, prompt]) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'agent-operation-action';
    button.textContent = label;
    button.title = `${label}; this only prepares a request for your review`;
    button.addEventListener('click', () => setPromptText(prompt));
    actions.appendChild(button);
  });
}

function openAgentPlanEditor(planElement, plan) {
  planElement.replaceChildren();
  const editor = document.createElement('div');
  editor.className = 'agent-plan-editor';
  const rows = [];
  const addRow = planStep => {
    const index = rows.length;
    const row = document.createElement('div');
    row.className = 'agent-plan-editor-row';
    const title = document.createElement('input');
    title.type = 'text';
    title.maxLength = 200;
    title.required = true;
    title.value = planStep?.title || `Step ${index + 1}`;
    title.setAttribute('aria-label', `Step ${index + 1} title`);
    const description = document.createElement('textarea');
    description.maxLength = 2000;
    description.rows = 2;
    description.value = planStep?.description || '';
    description.setAttribute('aria-label', `Step ${index + 1} description`);
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = 'Remove step';
    remove.title = 'Remove this step from the pending plan';
    const entry = { row, title, description };
    remove.addEventListener('click', () => {
      if (rows.length <= 1) return;
      rows.splice(rows.indexOf(entry), 1);
      row.remove();
    });
    row.append(title, description, remove);
    editor.appendChild(row);
    rows.push(entry);
  };
  plan.forEach(addRow);
  const actions = document.createElement('div');
  actions.className = 'agent-plan-editor-actions';
  const add = document.createElement('button');
  add.textContent = 'Add step';
  add.title = 'Append a new step to the pending agent plan';
  add.addEventListener('click', () => {
    if (rows.length >= 50) return;
    addRow({ title: `Step ${rows.length + 1}`, description: '' });
    editor.appendChild(actions);
    rows.at(-1).title.focus();
  });
  const save = document.createElement('button');
  save.textContent = 'Save plan';
  save.title = 'Validate and replace the pending plan without executing it';
  save.addEventListener('click', () => {
    const updatedPlan = rows.map(row => ({
      title: row.title.value.trim(),
      description: row.description.value.trim()
    }));
    const invalidRow = rows.find(row => !row.title.value.trim());
    if (invalidRow) {
      invalidRow.title.focus();
      invalidRow.title.reportValidity();
      return;
    }
    postMessageToDelphi({ action: 'update_agent_plan', plan: updatedPlan });
  });
  const cancel = document.createElement('button');
  cancel.textContent = 'Cancel edit';
  cancel.title = 'Discard plan edits and keep the current pending plan';
  cancel.addEventListener('click', () => renderAgentPlanItems(planElement, plan));
  actions.append(add, save, cancel);
  editor.appendChild(actions);
  planElement.appendChild(editor);
  rows[0]?.title.focus();
}

function renderAgentHistory(data) {
  const panel = document.createElement('section');
  panel.className = 'agent-history-panel';

  const header = document.createElement('div');
  header.className = 'agent-history-header';
  const title = document.createElement('strong');
  title.textContent = `Agent runs (${data.total || 0})`;
  const search = document.createElement('input');
  search.type = 'search';
  search.placeholder = 'Search objective, status, or session ID';
  search.value = data.query || '';
  const submitSearch = () => {
    postMessageToDelphi({
      action: 'search_agent_history',
      query: search.value.trim()
    });
  };
  search.addEventListener('keydown', event => {
    if (event.key === 'Enter') submitSearch();
  });
  const searchButton = document.createElement('button');
  searchButton.textContent = 'Search';
  searchButton.title = 'Search local agent run metadata without exposing tool payloads';
  searchButton.addEventListener('click', submitSearch);
  header.append(title, search, searchButton);
  panel.appendChild(header);

  const runs = Array.isArray(data.runs) ? data.runs : [];
  const list = document.createElement('ol');
  list.className = 'agent-history-list';
  runs.forEach(run => {
    const item = document.createElement('li');
    const runTitle = document.createElement('strong');
    runTitle.textContent = run.objective || 'Untitled agent run';
    const metadata = document.createElement('span');
    metadata.textContent =
      `${run.status || 'unknown'} · ${run.stepCount || 0} steps · ` +
      `${run.updatedAtUtc || 'unknown time'} · ${run.sessionId || ''}`;
    item.append(runTitle, metadata);
    list.appendChild(item);
  });
  if (runs.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'agent-history-empty';
    empty.textContent = 'No persisted agent runs match this search.';
    panel.appendChild(empty);
  } else {
    panel.appendChild(list);
  }
  chatContainer.appendChild(panel);
  search.focus();
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

function renderAgentState(data) {
  const state = data?.state;
  if (!state || typeof state !== 'object') return;

  const sessionId = state.sessionId || 'active';
  let card = AGENT_CARDS.get(sessionId);
  if (!card) {
    card = document.createElement('section');
    card.className = 'agent-run-card';
    card.innerHTML =
      '<div class="agent-run-header">' +
      '<strong>Agent run</strong><span class="agent-run-status"></span>' +
      '</div><div class="agent-run-objective"></div>' +
      '<section class="agent-operation-summary" hidden>' +
      '<div class="agent-operation-heading">What RadIA is doing</div>' +
      '<ol class="agent-operation-stages"></ol>' +
      '<p class="agent-operation-exclusions"></p>' +
      '<p class="agent-operation-result"></p>' +
      '<div class="agent-operation-actions"></div></section>' +
      '<div class="agent-run-message"></div>' +
      '<ol class="agent-run-plan"></ol>' +
      '<details class="agent-technical-details"><summary>Technical details</summary>' +
      '<div class="agent-run-metrics"></div>' +
      '<div class="agent-run-validation"></div>' +
      '<div class="agent-run-impact"></div>' +
      '<ol class="agent-run-steps"></ol></details>' +
      '<div class="agent-run-controls"></div>';
    AGENT_CARDS.set(sessionId, card);
    chatContainer.appendChild(card);
  }

  const status = state.status || 'unknown';
  card.dataset.status = status;
  card.querySelector('.agent-run-status').textContent = status;
  card.querySelector('.agent-run-objective').textContent = state.objective || '';
  card.querySelector('.agent-run-message').textContent = state.message || '';
  const steps = Array.isArray(state.steps) ? state.steps : [];
  renderProjectOperationSummary(card, state);
  const elapsedSeconds = Math.round((state.elapsedMilliseconds || 0) / 1000);
  const tokenBudget = state.maxTotalTokens > 0
    ? `${state.totalTokens || 0}/${state.maxTotalTokens} tokens`
    : `${state.totalTokens || 0} tokens (unlimited)`;
  let metricsText =
    `${steps.length}/${state.maxSteps || 0} steps · ` +
    `${tokenBudget} · ` +
    `${elapsedSeconds}s/${Math.round((state.maxDurationMilliseconds || 0) / 1000)}s`;
  if (state.pricingConfigured) {
    const estimatedCost = (state.estimatedCostMicros || 0) / 1000000;
    const costLimit = (state.maxEstimatedCostMicros || 0) / 1000000;
    metricsText += ` · USD ${estimatedCost.toFixed(4)}/${costLimit.toFixed(2)}`;
  } else {
    metricsText += ' · cost pricing not configured';
  }
  const compaction = state.resultCompactionMetrics;
  if (compaction?.appliedCount > 0) {
    const original = Math.max(0, compaction.originalCharacters || 0);
    const compacted = Math.max(0, compaction.compactedCharacters || 0);
    const saved = Math.max(0, original - compacted);
    const savedPercent = original > 0 ? Math.round((saved / original) * 100) : 0;
    metricsText += ` · RTK saved ${saved.toLocaleString()} chars (${savedPercent}%)`;
  }
  card.querySelector('.agent-run-metrics').textContent = metricsText;
  renderAgentValidation(card, state);
  renderAgentImpact(card, steps);

  const planElement = card.querySelector('.agent-run-plan');
  const plan = Array.isArray(state.plan) ? state.plan : [];
  renderAgentPlanItems(planElement, plan);

  const stepsElement = card.querySelector('.agent-run-steps');
  stepsElement.replaceChildren();
  steps.forEach(step => {
    stepsElement.appendChild(createAgentStep(step, status));
  });

  const controls = card.querySelector('.agent-run-controls');
  controls.replaceChildren();
  if (status === 'awaitingApproval') {
    const approvalHint = document.createElement('p');
    approvalHint.className = 'agent-approval-hint';
    approvalHint.textContent =
      'Review the plan, then select Approve plan or type /agent resume to continue.';
    controls.appendChild(approvalHint);
  }
  controls.appendChild(createAgentControl(
    'Approve plan',
    'approve_agent',
    status !== 'awaitingApproval'
  ));
  const editPlan = document.createElement('button');
  editPlan.className = 'agent-control-button';
  editPlan.textContent = 'Edit plan';
  editPlan.title = 'Review and change pending plan steps before approval';
  editPlan.disabled = status !== 'awaitingApproval' || plan.length === 0;
  editPlan.addEventListener('click', () => openAgentPlanEditor(planElement, plan));
  controls.appendChild(editPlan);
  controls.appendChild(createAgentControl('Pause', 'pause_agent', status !== 'running'));
  controls.appendChild(createAgentControl('Resume', 'resume_agent', status !== 'paused'));
  controls.appendChild(createAgentControl(
    'Cancel',
    'cancel_request',
    status !== 'running'
  ));
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

function formatToolPayload(payload) {
  if (payload === undefined || payload === null) {
    return '';
  }

  if (typeof payload === 'string') {
    return payload;
  }

  return JSON.stringify(payload, null, 2);
}

function updateExecutionRoute(route) {
  if (!executionRoute || !route) return;
  activeExecutionRoute = { ...activeExecutionRoute, ...route };
  executionRoute.textContent = `Effective: ${route.label || 'Chat | Native provider'}`;
  executionRoute.title = route.details || route.label || 'Effective execution route';
  executionRoute.dataset.mode = route.mode || 'chat';
  executionRoute.dataset.transport = route.transport || 'native';
  executionRouteSelector.value = route.orchestrator === 'external-cli'
    ? (route.cliClientId || 'codex')
      : 'native';
  if (btnCliNewSession) {
    btnCliNewSession.hidden = route.orchestrator !== 'external-cli';
    btnCliNewSession.disabled = requestInProgress || route.cliSessionState !== 'resume';
  }
  if (btnJourneyContext) {
    const isLinked = route.journeyState === 'linked';
    btnJourneyContext.disabled = requestInProgress;
    btnJourneyContext.querySelector('.btn-label').textContent = isLinked ? 'Detach' : 'Link';
    btnJourneyContext.title = isLinked
      ? 'Detach this conversation from the shared journey context'
      : 'Link chat, terminal, and editor to a journey for the active project';
  }
  updateComposerRoute();
}

function createIntentRecommendationButton(label, action, primary = false) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = primary
    ? 'intent-recommendation-button primary'
    : 'intent-recommendation-button';
  button.textContent = label;
  button.addEventListener('click', () => {
    postMessageToDelphi({ action });
    if (action !== 'review_intent_recommendation') {
      button.closest('.intent-recommendation-card')
        ?.querySelectorAll('button')
        .forEach(item => { item.disabled = true; });
    }
  });
  return button;
}

function renderIntentRecommendation(data) {
  const card = document.createElement('section');
  card.className = 'intent-recommendation-card';
  card.setAttribute('aria-label', 'Recommended execution route');

  const heading = document.createElement('div');
  heading.className = 'intent-recommendation-heading';
  const title = document.createElement('strong');
  title.textContent = `Recommended: ${data.intent || 'guided work'}`;
  const confidence = document.createElement('span');
  confidence.className = 'intent-recommendation-confidence';
  confidence.textContent = `${data.confidence || 'unknown'} confidence`;
  heading.append(title, confidence);

  const explanation = document.createElement('p');
  explanation.textContent = data.explanation || '';
  const route = document.createElement('code');
  route.textContent = data.command || data.route || '';

  const controls = document.createElement('div');
  controls.className = 'intent-recommendation-controls';
  controls.append(
    createIntentRecommendationButton(
      'Use recommended route',
      'accept_intent_recommendation',
      true
    ),
    createIntentRecommendationButton('Review command', 'review_intent_recommendation'),
    createIntentRecommendationButton('Continue as chat', 'dismiss_intent_recommendation')
  );

  card.append(heading, explanation, route, controls);
  chatContainer.appendChild(card);
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

function getExecutionRouteKind(route = activeExecutionRoute) {
  const transport = route.transport || 'native';
  if (transport.includes('cli')) return 'cli';
  if (transport === 'mcp') return 'mcp';
  return 'native';
}

function decorateExecutionAvatar(avatar, route = activeExecutionRoute) {
  const avatarKind = getExecutionRouteKind(route);
  const routeTitle = route.details || route.label || 'Effective execution route';
  const marker = document.createElement('span');

  avatar.innerHTML = ROUTE_AVATARS[avatarKind];
  avatar.classList.remove('provider-avatar-badge');
  avatar.classList.add('execution-avatar', `route-${avatarKind}`);
  avatar.title = routeTitle;
  marker.className = 'message-route-marker';
  marker.textContent = 'N';
  if (avatarKind === 'cli') {
    marker.textContent = '>_';
  } else if (avatarKind === 'mcp') {
    marker.textContent = 'M';
  }
  marker.title = routeTitle;
  avatar.appendChild(marker);
}

function decorateAssistantRoute(wrapper, avatar, header) {
  const route = activeExecutionRoute;
  const transport = route.transport || 'native';
  const avatarKind = getExecutionRouteKind(route);
  const routeLabel = document.createElement('span');
  const routeTitle = route.details || route.label || 'Effective execution route';

  wrapper.dataset.executionTransport = transport;
  decorateExecutionAvatar(avatar, route);

  routeLabel.className = 'message-route-label';
  routeLabel.textContent = route.displayName || avatarKind.toUpperCase();
  routeLabel.title = routeTitle;
  header.appendChild(routeLabel);
}

function updateComposerRoute() {
  if (!composerRoute) return;
  const routeName = activeExecutionRoute.displayName || 'Native';
  const selectedModel = modelSelectionEnabled ? selectModel?.value : '';
  let cliSessionState = 'New';
  if (activeExecutionRoute.cliSessionState === 'resume') cliSessionState = 'Resume';
  const cliSession = activeExecutionRoute.orchestrator === 'external-cli'
    ? `Session: ${cliSessionState}`
    : '';
  const journey = activeExecutionRoute.journeyState === 'linked'
    ? `Journey: ${String(activeExecutionRoute.journeyId || '').slice(0, 8)}`
    : 'Journey: Detached';
  composerRoute.textContent = `Auth: ${[routeName, selectedModel, cliSession, journey].filter(Boolean).join(' | ')}`;
  composerRoute.title = activeExecutionRoute.details || activeExecutionRoute.label || routeName;
  composerRoute.dataset.transport = activeExecutionRoute.transport || 'native';
}

function createResponseTechnicalSummary(wrapper, provider, model) {
  if (!wrapper || wrapper.querySelector('.response-technical-summary')) return;
  const context = activeResponseContext;
  const route = context?.route || activeExecutionRoute;
  const durationMs = context?.startedAt ? Date.now() - context.startedAt : 0;
  const details = document.createElement('details');
  const summary = document.createElement('summary');
  const routeName = route.displayName || getExecutionRouteKind(route).toUpperCase();
  const summaryParts = [routeName];

  if (durationMs > 0) summaryParts.push(`${(durationMs / 1000).toFixed(1)} s`);
  summary.textContent = summaryParts.join(' · ');
  summary.title = 'Show technical details for this response';
  details.className = 'response-technical-summary';
  details.appendChild(summary);

  const metadata = document.createElement('div');
  metadata.className = 'response-technical-metadata';
  [provider, model, route.label].filter(Boolean).forEach(value => {
    const item = document.createElement('span');
    item.textContent = value;
    metadata.appendChild(item);
  });
  if (context?.tools?.size) {
    context.tools.forEach(toolName => {
      const item = document.createElement('span');
      item.className = 'response-tool-chip';
      item.textContent = toolName;
      metadata.appendChild(item);
    });
  }
  details.appendChild(metadata);
  wrapper.querySelector('.message-body')?.appendChild(details);
}

function copyTextWithFeedback(button, text) {
  return navigator.clipboard.writeText(String(text ?? '')).then(() => {
    const original = button.innerHTML;
    button.innerHTML = SVG_ICONS.check;
    setTimeout(() => { button.innerHTML = original; }, 2000);
  });
}

function createTextCopyButton(textProvider, title, className = '') {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = `text-copy-button ${className}`.trim();
  button.innerHTML = SVG_ICONS.copy;
  button.title = title;
  button.setAttribute('aria-label', title);
  button.addEventListener('click', () => copyTextWithFeedback(button, textProvider()));
  return button;
}

function appendCopyablePayload(container, payload, title) {
  const text = formatToolPayload(payload);
  const toolbar = document.createElement('div');
  toolbar.className = 'copyable-payload-header';
  const label = document.createElement('strong');
  label.textContent = title;
  toolbar.appendChild(label);
  toolbar.appendChild(createTextCopyButton(() => text, `Copy ${title.toLowerCase()}`));
  const block = document.createElement('pre');
  block.textContent = text;
  container.appendChild(toolbar);
  container.appendChild(block);
}

function createToolCard(name, correlationId) {
  const card = document.createElement('section');
  card.className = 'tool-card';
  card.dataset.correlationId = correlationId || '';

  const header = document.createElement('div');
  header.className = 'tool-card-header';

  const title = document.createElement('strong');
  title.textContent = name || 'IDE tool';

  const status = document.createElement('span');
  status.className = 'tool-card-status';
  status.textContent = 'Running';

  const content = document.createElement('div');
  content.className = 'tool-card-content';

  const headerActions = document.createElement('div');
  headerActions.className = 'tool-card-header-actions';
  const copyButton = createTextCopyButton(
    () => card.dataset.copyText || content.textContent || '',
    'Copy tool result'
  );
  copyButton.disabled = true;
  headerActions.appendChild(status);
  headerActions.appendChild(copyButton);

  header.appendChild(title);
  header.appendChild(headerActions);
  card.appendChild(header);
  card.appendChild(content);
  chatContainer.appendChild(card);
  chatContainer.scrollTop = chatContainer.scrollHeight;
  return card;
}

function showTools(tools) {
  AVAILABLE_TOOLS = Array.isArray(tools) ? tools : [];

  const card = document.createElement('section');
  card.className = 'tool-catalog';

  const title = document.createElement('h3');
  title.textContent = `Available IDE tools (${AVAILABLE_TOOLS.length})`;
  card.appendChild(title);

  const guidance = document.createElement('p');
  guidance.className = 'tool-catalog-guidance';
  guidance.textContent = 'Search by name or purpose. Use /tool Name with JSON arguments, ' +
    'or describe the objective in agent mode and RadIA will select an appropriate tool.';
  card.appendChild(guidance);

  if (AVAILABLE_TOOLS.length === 0) {
    const empty = document.createElement('p');
    empty.textContent = 'No IDE tools are available.';
    card.appendChild(empty);
  } else {
    const search = document.createElement('input');
    search.className = 'tool-catalog-search';
    search.type = 'search';
    search.placeholder = 'Search tools by name, purpose, or risk...';
    search.setAttribute('aria-label', 'Search available IDE tools');
    search.title = 'Filter the runtime tool catalog without executing a tool';
    card.appendChild(search);

    const items = [];
    AVAILABLE_TOOLS.forEach(tool => {
      const item = document.createElement('div');
      item.className = 'tool-catalog-item';

      const summary = document.createElement('div');
      summary.className = 'tool-catalog-summary';

      const name = document.createElement('code');
      name.textContent = `/tool ${tool.name}`;

      const description = document.createElement('span');
      description.textContent = tool.description || 'No operational description is available.';

      const risk = document.createElement('span');
      risk.className = `tool-risk tool-risk-${tool.risk || 'sensitive'}`;
      risk.textContent = `Risk: ${tool.risk || 'sensitive'}`;

      const details = document.createElement('details');
      details.className = 'tool-catalog-details';
      const detailsSummary = document.createElement('summary');
      detailsSummary.textContent = 'How and when to use';
      detailsSummary.title = 'Show invocation guidance and accepted JSON arguments';

      const activation = document.createElement('p');
      activation.textContent = 'Direct invocation: ' +
        `/tool ${tool.name} { ... }. In agent mode it is selected only when the objective ` +
        'requires this capability and the current IDE context allows it.';

      const schemaLabel = document.createElement('strong');
      schemaLabel.textContent = 'Accepted arguments';
      const schema = document.createElement('pre');
      schema.textContent = tool.inputSchema || '{}';

      summary.append(name, description, risk);
      details.append(detailsSummary, activation, schemaLabel, schema);
      item.append(summary, details);
      item.dataset.searchText = [
        tool.name,
        tool.description,
        tool.risk
      ].join(' ').toLowerCase();
      items.push(item);
      card.appendChild(item);
    });

    search.addEventListener('input', () => {
      const query = search.value.trim().toLowerCase();
      items.forEach(item => {
        item.hidden = query && !item.dataset.searchText.includes(query);
      });
    });
  }

  chatContainer.appendChild(card);
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

function renderToolCall(data) {
  if (activeResponseContext && data.name) {
    activeResponseContext.tools.add(data.name);
  }
  updateActiveExecutionStage(`Running ${data.name || 'IDE tool'}…`);
  const card = createToolCard(data.name, data.correlationId);
  const content = card.querySelector('.tool-card-content');
  content.textContent = formatToolPayload(data.arguments ?? data.argumentsText);
  TOOL_CARDS.set(data.correlationId, card);
}

function createToolArgumentsButton(label, toolName, args) {
  const button = document.createElement('button');
  button.className = 'tool-action-button';
  button.type = 'button';
  button.textContent = label;
  button.title = `Run ${toolName} with the prepared arguments after policy and consent checks`;
  button.addEventListener('click', () => {
    button.disabled = true;
    postMessageToDelphi({
      action: 'execute_tool',
      name: toolName,
      arguments: args
    });
  });
  return button;
}

function createToolActionButton(label, toolName, previewId) {
  return createToolArgumentsButton(label, toolName, { previewId });
}

function problemSeverityRank(severity) {
  return {
    critical: 0,
    error: 1,
    warning: 2,
    information: 3
  }[severity] ?? 4;
}

function createProblemAction(label, title, handler) {
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = label;
  button.title = title;
  button.addEventListener('click', handler);
  return button;
}

function renderProblemsPanel() {
  const severityFilter = problemsSeverityFilter.value;
  const categoryFilter = problemsCategoryFilter.value;
  const problems = [...COLLECTED_PROBLEMS.values()].sort((left, right) => {
    const severity = problemSeverityRank(left.severity) -
      problemSeverityRank(right.severity);
    return severity || String(left.message).localeCompare(String(right.message));
  });
  const visible = problems.filter(problem =>
    (severityFilter === 'all' || problem.severity === severityFilter) &&
    (categoryFilter === 'all' || problem.category === categoryFilter)
  );

  problemsBadge.textContent = problems.length > 99 ? '99+' : String(problems.length);
  problemsBadge.classList.toggle('hidden', problems.length === 0);
  problemsSummary.textContent = problems.length === 0
    ? 'No problems collected'
    : `${visible.length} shown · ${problems.length} collected`;
  problemsList.replaceChildren();

  if (visible.length === 0) {
    const empty = document.createElement('li');
    empty.className = 'problems-empty';
    empty.textContent = problems.length === 0
      ? 'Run a build, test, diagnostic, or review to collect actionable findings.'
      : 'No problem matches the selected filters.';
    problemsList.appendChild(empty);
    return;
  }

  visible.forEach(problem => {
    const item = document.createElement('li');
    item.className = 'problem-item';
    item.dataset.severity = problem.severity || 'information';

    const heading = document.createElement('div');
    heading.className = 'problem-heading';
    const title = document.createElement('strong');
    title.textContent = problem.title || problem.code || 'Problem';
    const severity = document.createElement('span');
    severity.className = 'problem-severity';
    severity.textContent = problem.severity || 'information';
    heading.append(title, severity);

    const message = document.createElement('div');
    message.className = 'problem-message';
    message.textContent = problem.message || '';

    const meta = document.createElement('div');
    meta.className = 'problem-meta';
    meta.textContent = [
      problem.category || 'general',
      problem.sourceTool || '',
      problem.fileName
        ? `${problem.fileName}:${Math.max(1, problem.line || 1)}`
        : ''
    ].filter(Boolean).join(' · ');

    const actions = document.createElement('div');
    actions.className = 'problem-actions';
    if (problem.fileName) {
      actions.appendChild(createProblemAction(
        'Open source',
        'Open this location in the Delphi editor after policy checks',
        () => postMessageToDelphi({
          action: 'execute_tool',
          name: 'NavigateToFile',
          arguments: {
            fileName: problem.fileName,
            line: Math.max(1, problem.line || 1),
            column: Math.max(1, problem.column || 1)
          }
        })
      ));
    }
    if (problem.recommendedCommand) {
      actions.appendChild(createProblemAction(
        'Review action',
        `Prepare ${problem.recommendedCommand} without running it`,
        () => {
          setPromptText(problem.recommendedCommand);
          problemsPanel.classList.add('collapsed');
          problemsPanel.setAttribute('inert', '');
          btnProblems.setAttribute('aria-expanded', 'false');
        }
      ));
    }
    if (problem.fixId) {
      actions.appendChild(createProblemAction(
        'Preview fix',
        'Prepare a fingerprinted preview without changing the file',
        () => postMessageToDelphi({
          action: 'execute_tool',
          name: 'PrepareCodeValidationFix',
          arguments: { id: problem.fixId }
        })
      ));
    }

    item.append(heading, message, meta);
    if (actions.childElementCount > 0) item.appendChild(actions);
    problemsList.appendChild(item);
  });
}

function collectToolProblems(result) {
  const problems = Array.isArray(result?._radiaProblems)
    ? result._radiaProblems
    : [];
  problems.forEach(problem => {
    if (problem?.id && problem?.message) {
      COLLECTED_PROBLEMS.set(problem.id, problem);
    }
  });
  renderProblemsPanel();
}

function clearCollectedProblems() {
  COLLECTED_PROBLEMS.clear();
  renderProblemsPanel();
}

function renderKnowledgeSearchResult(card, result) {
  const content = card.querySelector('.tool-card-content');
  const results = Array.isArray(result.results) ? result.results : [];
  content.replaceChildren();

  const summary = document.createElement('div');
  summary.className = 'knowledge-result-summary';
  summary.textContent = [
    `${results.length} result(s) for “${result.query || ''}”`,
    `${Math.max(0, result.durationMs || 0)} ms`
  ].join(' · ');
  content.appendChild(summary);

  results.forEach(item => {
    const source = document.createElement('section');
    source.className = 'knowledge-result-source';

    const title = document.createElement('strong');
    title.textContent = `${item.fileName || ''}:${Math.max(1, item.startLine || 1)}`;
    source.appendChild(title);

    const detail = document.createElement('span');
    detail.className = 'knowledge-result-detail';
    detail.textContent = [
      item.symbol || 'source chunk',
      item.explanation || '',
      `score ${Math.max(0, item.score || 0)}`
    ].filter(Boolean).join(' · ');
    source.appendChild(detail);

    const excerpt = document.createElement('pre');
    excerpt.textContent = item.content || '';
    source.appendChild(excerpt);

    const navigation = item.navigation || {};
    if (navigation.tool && navigation.arguments) {
      source.appendChild(
        createToolArgumentsButton(
          'Open source',
          navigation.tool,
          navigation.arguments
        )
      );
    }
    content.appendChild(source);
  });
}

function renderKnowledgeDocumentResult(card, result) {
  const content = card.querySelector('.tool-card-content');
  const chunks = Array.isArray(result.chunks) ? result.chunks : [];
  content.replaceChildren();

  const summary = document.createElement('div');
  summary.className = 'knowledge-result-summary';
  summary.textContent = `${chunks.length} chunk(s) from ${result.fileName || ''}`;
  content.appendChild(summary);

  chunks.forEach(item => {
    const source = document.createElement('section');
    source.className = 'knowledge-result-source';

    const title = document.createElement('strong');
    title.textContent = [
      result.fileName || '',
      Math.max(1, item.startLine || 1)
    ].join(':');
    source.appendChild(title);

    const detail = document.createElement('span');
    detail.className = 'knowledge-result-detail';
    detail.textContent = item.symbol || 'source chunk';
    source.appendChild(detail);

    const excerpt = document.createElement('pre');
    excerpt.textContent = item.content || '';
    source.appendChild(excerpt);

    const navigation = item.navigation || {};
    if (navigation.tool && navigation.arguments) {
      source.appendChild(
        createToolArgumentsButton(
          'Open source',
          navigation.tool,
          navigation.arguments
        )
      );
    }
    content.appendChild(source);
  });
}

function renderLocalDatabaseSchema(card, result) {
  const content = card.querySelector('.tool-card-content');
  const objects = Array.isArray(result.objects) ? result.objects : [];
  content.replaceChildren();

  const summary = document.createElement('div');
  summary.className = 'database-result-summary';
  summary.textContent = `${objects.length} schema object(s) · read-only SQLite`;
  content.appendChild(summary);

  objects.forEach(item => {
    const details = document.createElement('details');
    details.className = 'database-schema-object';
    const heading = document.createElement('summary');
    const columns = Array.isArray(item.columns) ? item.columns : [];
    heading.textContent = `${item.objectType || 'table'} ${item.name || ''} · ` +
      `${columns.length} column(s)`;
    const list = document.createElement('ul');
    columns.forEach(column => {
      const entry = document.createElement('li');
      entry.textContent = [
        column.name || '',
        column.dataType || 'untyped',
        column.primaryKey ? 'primary key' : '',
        column.notNull ? 'not null' : '',
        column.sensitive ? 'sensitive (redacted in previews)' : ''
      ].filter(Boolean).join(' · ');
      list.appendChild(entry);
    });
    details.append(heading, list);
    content.appendChild(details);
  });
}

function renderLocalDatabaseQuery(card, result) {
  const content = card.querySelector('.tool-card-content');
  const columns = Array.isArray(result.columns) ? result.columns : [];
  const rows = Array.isArray(result.rows) ? result.rows : [];
  const pageSize = 25;
  let page = 0;
  content.replaceChildren();

  const summary = document.createElement('div');
  summary.className = 'database-result-summary';
  const resultState = result.truncated
    ? `limited to ${result.maxRows || rows.length}`
    : 'complete preview';
  summary.textContent = `${rows.length} row(s) · read-only · ` +
    resultState;
  content.appendChild(summary);

  const viewport = document.createElement('div');
  viewport.className = 'database-grid-viewport';
  const table = document.createElement('table');
  table.className = 'database-grid';
  const header = document.createElement('thead');
  const headerRow = document.createElement('tr');
  columns.forEach(column => {
    const cell = document.createElement('th');
    cell.scope = 'col';
    cell.textContent = String(column ?? '');
    headerRow.appendChild(cell);
  });
  header.appendChild(headerRow);
  const body = document.createElement('tbody');
  table.append(header, body);
  viewport.appendChild(table);
  content.appendChild(viewport);

  const controls = document.createElement('div');
  controls.className = 'database-grid-controls';
  const previous = document.createElement('button');
  previous.type = 'button';
  previous.textContent = 'Previous';
  previous.title = 'Show the previous 25 sanitized rows';
  const indicator = document.createElement('span');
  const next = document.createElement('button');
  next.type = 'button';
  next.textContent = 'Next';
  next.title = 'Show the next 25 sanitized rows';
  const copyCsv = createTextCopyButton(
    () => String(result.exportCsv || ''),
    'Copy sanitized CSV'
  );
  copyCsv.disabled = !result.exportCsv;

  const renderPage = () => {
    body.replaceChildren();
    const start = page * pageSize;
    rows.slice(start, start + pageSize).forEach(row => {
      const rowElement = document.createElement('tr');
      (Array.isArray(row) ? row : []).forEach(value => {
        const cell = document.createElement('td');
        cell.textContent = value === null ? 'NULL' : String(value);
        rowElement.appendChild(cell);
      });
      body.appendChild(rowElement);
    });
    const pageCount = Math.max(1, Math.ceil(rows.length / pageSize));
    indicator.textContent = `Page ${Math.min(page + 1, pageCount)} of ${pageCount}`;
    previous.disabled = page === 0;
    next.disabled = page + 1 >= pageCount;
  };
  previous.addEventListener('click', () => {
    page = Math.max(0, page - 1);
    renderPage();
  });
  next.addEventListener('click', () => {
    page = Math.min(Math.max(0, Math.ceil(rows.length / pageSize) - 1), page + 1);
    renderPage();
  });
  controls.append(previous, indicator, next, copyCsv);
  content.appendChild(controls);
  renderPage();
}

function createHealthActionButton(command) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'tool-action-button project-health-action';
  button.textContent = 'Prepare action';
  button.title = command;
  button.addEventListener('click', () => setPromptText(command));
  return button;
}

function renderProjectHealth(card, result) {
  const content = card.querySelector('.tool-card-content');
  const risks = Array.isArray(result.risks) ? result.risks : [];
  content.replaceChildren();

  const summary = document.createElement('div');
  summary.className = 'project-health-summary';

  const score = document.createElement('strong');
  score.className = `project-health-score project-health-${result.health || 'attention'}`;
  score.textContent = `${Math.max(0, result.score ?? 0)}/100`;

  const project = document.createElement('span');
  project.textContent = result.projectName || 'No active project';
  summary.appendChild(score);
  summary.appendChild(project);
  content.appendChild(summary);

  if (risks.length === 0) {
    const healthy = document.createElement('div');
    healthy.className = 'project-health-empty';
    healthy.textContent = 'No project health risks were detected.';
    content.appendChild(healthy);
    return;
  }

  risks.forEach(risk => {
    const item = document.createElement('section');
    item.className = 'project-health-risk';

    const header = document.createElement('div');
    header.className = 'project-health-risk-header';

    const severity = document.createElement('span');
    severity.className = `project-health-severity severity-${risk.severity || 'medium'}`;
    severity.textContent = risk.severity || 'medium';
    header.appendChild(severity);
    header.append(risk.code || 'project_risk');
    item.appendChild(header);

    const message = document.createElement('div');
    message.textContent = risk.message || '';
    item.appendChild(message);

    if (risk.recommendedCommand) {
      item.appendChild(createHealthActionButton(risk.recommendedCommand));
    }
    content.appendChild(item);
  });
}

function doctorActionCommand(nextAction) {
  const commands = {
    open_provider_settings: '/settings',
    repair_web_assets: '/settings',
    configure_cli: '/settings',
    provision_mcp: '/settings',
    repair_external_mcp: '/settings',
    open_terminal_fallback: '/terminal',
    repair_package: '/doctor',
    run_first_read_only_tool: '/tool GetIDEState {}'
  };
  return commands[nextAction] || '/status';
}

function renderChatPreflight(data) {
  const wrapper = addMessage(
    'assistant',
    `### ${data.title || 'RadIA setup required'}\n\n${data.message || ''}`
  );
  const content = wrapper.querySelector('.message-content');
  const actions = document.createElement('div');
  actions.className = 'chat-preflight-actions';

  const settings = document.createElement('button');
  settings.type = 'button';
  settings.className = 'tool-action-button';
  settings.textContent = 'Open Settings';
  settings.title = 'Open the RadIA settings required by the selected execution route';
  settings.addEventListener('click', () => {
    postMessageToDelphi({ action: 'open_settings' });
  });

  const doctor = createHealthActionButton('/doctor');
  doctor.textContent = 'Run /doctor';
  doctor.title = 'Prepare the complete local readiness diagnostic';
  actions.appendChild(settings);
  actions.appendChild(doctor);
  content.appendChild(actions);

  if (data.pendingPrompt) {
    setPromptText(data.pendingPrompt);
  }
}

function renderInstallationHealth(card, result) {
  const content = card.querySelector('.tool-card-content');
  const checks = Array.isArray(result.checkDetails)
    ? result.checkDetails
    : [];
  const activeChecks = Array.isArray(result.activeChecks)
    ? result.activeChecks
    : [];
  const route = result.effectiveRoute || {};
  content.replaceChildren();

  const summary = document.createElement('div');
  summary.className = 'doctor-summary';
  const score = document.createElement('strong');
  score.className = `doctor-score doctor-${result.status || 'attention'}`;
  score.textContent = `${Math.max(0, result.readinessScore ?? 0)}/100`;
  const label = document.createElement('span');
  label.textContent = result.summary || 'RadIA installation diagnostic';
  summary.appendChild(score);
  summary.appendChild(label);
  content.appendChild(summary);

  const routeSummary = document.createElement('div');
  routeSummary.className = 'doctor-route';
  routeSummary.textContent = [
    `Orchestration: ${route.orchestration || 'unknown'}`,
    `Transport: ${route.providerTransport || 'unknown'}`,
    `CLI: ${route.effectiveCli || 'not required'}`,
    `MCP required: ${route.mcpRequired ? 'yes' : 'no'}`
  ].join(' · ');
  content.appendChild(routeSummary);

  [...checks, ...activeChecks].forEach(check => {
    const item = document.createElement('section');
    item.className = `doctor-check doctor-check-${check.status || 'failed'}`;
    const title = document.createElement('strong');
    title.textContent = check.id || 'diagnostic check';
    const state = document.createElement('span');
    state.className = 'doctor-check-state';
    state.textContent = check.status || 'unknown';
    item.appendChild(title);
    item.appendChild(state);
    const message = document.createElement('div');
    message.textContent = check.message || '';
    item.appendChild(message);
    if (check.status !== 'passed' &&
      check.status !== 'not-required' && check.action) {
      const action = createHealthActionButton(check.action);
      action.textContent = 'Show next step';
      item.appendChild(action);
    }
    content.appendChild(item);
  });

  const nextAction = createHealthActionButton(
    doctorActionCommand(result.nextAction)
  );
  nextAction.textContent = result.status === 'ready'
    ? 'Test first IDE tool'
    : 'Prepare recommended action';
  content.appendChild(nextAction);
}

function renderPatchPreview(card, result, actionName) {
  const content = card.querySelector('.tool-card-content');
  content.replaceChildren();

  const file = document.createElement('div');
  file.className = 'patch-preview-file';
  file.textContent = result.targetFile || '';

  const comparison = document.createElement('div');
  comparison.className = 'patch-preview-comparison';

  const before = document.createElement('pre');
  before.className = 'patch-preview-before';
  before.textContent = result.originalContent || '';

  const after = document.createElement('pre');
  after.className = 'patch-preview-after';
  after.textContent = result.proposedContent || '';

  comparison.appendChild(before);
  comparison.appendChild(after);
  content.appendChild(file);
  content.appendChild(comparison);
  content.appendChild(
    createToolActionButton(
      actionName === 'RevertPatch' ? 'Revert patch' : 'Apply reviewed patch',
      actionName,
      result.previewId
    )
  );
}

function formatComponentBounds(bounds) {
  if (!bounds) {
    return '';
  }
  return [
    `Left: ${bounds.left}`,
    `Top: ${bounds.top}`,
    `Width: ${bounds.width}`,
    `Height: ${bounds.height}`
  ].join('\n');
}

function renderComponentLayoutPreview(card, result, actionName) {
  const content = card.querySelector('.tool-card-content');
  content.replaceChildren();

  const component = document.createElement('div');
  component.className = 'patch-preview-file';
  component.textContent =
    `${result.componentName || ''} — ${result.formFileName || ''}`;

  const comparison = document.createElement('div');
  comparison.className = 'patch-preview-comparison';

  const before = document.createElement('pre');
  before.className = 'patch-preview-before';
  before.textContent = formatComponentBounds(result.originalBounds);

  const after = document.createElement('pre');
  after.className = 'patch-preview-after';
  after.textContent = formatComponentBounds(result.proposedBounds);

  comparison.appendChild(before);
  comparison.appendChild(after);
  content.appendChild(component);
  content.appendChild(comparison);
  content.appendChild(
    createToolActionButton(
      actionName === 'RevertComponentLayout'
        ? 'Revert component layout'
        : 'Apply reviewed layout',
      actionName,
      result.previewId
    )
  );
}

function renderComponentPropertyPreview(card, result, actionName) {
  const content = card.querySelector('.tool-card-content');
  content.replaceChildren();

  const component = document.createElement('div');
  component.className = 'patch-preview-file';
  component.textContent = [
    result.componentName || '',
    result.propertyName || '',
    result.propertyType || ''
  ].filter(Boolean).join(' — ');

  const comparison = document.createElement('div');
  comparison.className = 'patch-preview-comparison';

  const before = document.createElement('pre');
  before.className = 'patch-preview-before';
  before.textContent = result.originalValue ?? '';

  const after = document.createElement('pre');
  after.className = 'patch-preview-after';
  after.textContent = result.proposedValue ?? '';

  comparison.appendChild(before);
  comparison.appendChild(after);
  content.appendChild(component);
  content.appendChild(comparison);
  content.appendChild(
    createToolActionButton(
      actionName === 'RevertComponentProperty'
        ? 'Revert component property'
        : 'Apply reviewed property',
      actionName,
      result.previewId
    )
  );
}

const TOOL_RESULT_RENDERERS = {
  GetInstallationHealth: [renderInstallationHealth, ''],
  RunInstallationDeepDiagnostic: [renderInstallationHealth, ''],
  GetProjectHealth: [renderProjectHealth, ''],
  SearchProjectKnowledge: [renderKnowledgeSearchResult, ''],
  GetKnowledgeDocument: [renderKnowledgeDocumentResult, ''],
  InspectLocalSQLiteDatabase: [renderLocalDatabaseSchema, ''],
  PreviewLocalSQLiteQuery: [renderLocalDatabaseQuery, ''],
  PreparePatch: [renderPatchPreview, 'ApplyPatch'],
  ApplyPatch: [renderPatchPreview, 'RevertPatch'],
  PrepareComponentLayout: [
    renderComponentLayoutPreview,
    'ApplyComponentLayout'
  ],
  ApplyComponentLayout: [
    renderComponentLayoutPreview,
    'RevertComponentLayout'
  ],
  RevertComponentLayout: [
    renderComponentLayoutPreview,
    'ApplyComponentLayout'
  ],
  PrepareComponentProperty: [
    renderComponentPropertyPreview,
    'ApplyComponentProperty'
  ],
  ApplyComponentProperty: [
    renderComponentPropertyPreview,
    'RevertComponentProperty'
  ],
  RevertComponentProperty: [
    renderComponentPropertyPreview,
    'ApplyComponentProperty'
  ]
};

function renderDefaultToolResult(content, data) {
  content.textContent = data.success
    ? formatToolPayload(data.result ?? data.resultText)
    : `${data.errorCode || 'tool_error'}: ${data.errorMessage || 'Tool execution failed.'}`;
}

function renderToolResult(data) {
  const card = TOOL_CARDS.get(data.correlationId) ||
    createToolCard(data.name, data.correlationId);
  const status = card.querySelector('.tool-card-status');
  const content = card.querySelector('.tool-card-content');
  const copyButton = card.querySelector('.text-copy-button');
  const renderer = data.success && data.result
    ? TOOL_RESULT_RENDERERS[data.name]
    : undefined;

  card.classList.toggle('tool-card-error', !data.success);
  status.textContent = data.success ? 'Completed' : 'Failed';
  if (data.success && data.result) collectToolProblems(data.result);
  if (renderer) {
    renderer[0](card, data.result, renderer[1]);
  } else {
    renderDefaultToolResult(content, data);
  }
  card.dataset.copyText = data.success
    ? formatToolPayload(data.result ?? data.resultText)
    : `${data.errorCode || 'tool_error'}: ${data.errorMessage || 'Tool execution failed.'}`;
  if (copyButton) copyButton.disabled = false;
  updateActiveExecutionStage(data.success ? 'Processing tool result…' : 'Tool execution failed');
  TOOL_CARDS.delete(data.correlationId);
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

const VISUAL_RUNTIME_CARDS = new Map();

function createVisualRuntimeCard(sessionId) {
  const card = document.createElement('section');
  card.className = 'visual-runtime-card';
  card.dataset.sessionId = sessionId;

  const header = document.createElement('header');
  header.className = 'visual-runtime-header';
  const title = document.createElement('strong');
  title.textContent = 'Runtime visual validation';
  const state = document.createElement('span');
  state.className = 'visual-runtime-state';
  header.append(title, state);

  const captures = document.createElement('div');
  captures.className = 'visual-runtime-captures';
  const timeline = document.createElement('ol');
  timeline.className = 'visual-runtime-timeline';
  card.append(header, captures, timeline);
  chatContainer.appendChild(card);
  VISUAL_RUNTIME_CARDS.set(sessionId, card);
  return card;
}

function renderVisualRuntimeCapture(container, capture) {
  const figure = document.createElement('figure');
  figure.className = `visual-runtime-capture capture-${capture.phase || 'unknown'}`;
  const caption = document.createElement('figcaption');
  caption.textContent = capture.phase === 'after' ? 'After' : 'Before';
  const image = document.createElement('img');
  image.alt = `${caption.textContent} capture of the authorized runtime window`;
  image.loading = 'lazy';
  if (typeof capture.dataUrl === 'string' &&
      capture.dataUrl.startsWith('data:image/png;base64,')) {
    image.src = capture.dataUrl;
  }
  const dimensions = document.createElement('small');
  dimensions.textContent = `${capture.width || 0} x ${capture.height || 0}`;
  figure.append(caption, image, dimensions);
  container.appendChild(figure);
}

function renderVisualRuntimeSession(data) {
  if (!data?.sessionId) return;
  const card = VISUAL_RUNTIME_CARDS.get(data.sessionId) ||
    createVisualRuntimeCard(data.sessionId);
  const state = card.querySelector('.visual-runtime-state');
  const captures = card.querySelector('.visual-runtime-captures');
  const timeline = card.querySelector('.visual-runtime-timeline');
  state.textContent = data.state || 'active';
  state.dataset.state = data.state || 'active';
  captures.replaceChildren();
  (Array.isArray(data.captures) ? data.captures : []).forEach(capture => {
    renderVisualRuntimeCapture(captures, capture);
  });
  timeline.replaceChildren();
  (Array.isArray(data.events) ? data.events : []).forEach(event => {
    const item = document.createElement('li');
    const label = document.createElement('strong');
    label.textContent = event.status || event.kind || 'event';
    const details = document.createElement('span');
    details.textContent = event.details || '';
    item.append(label, details);
    timeline.appendChild(item);
  });
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

let slashPopupVisible = false;
let slashPopupSelectedIndex = 0;
let filteredSlashCommands = [];

const chatWrapper          = document.getElementById('chat-wrapper');
const mainLayout           = document.getElementById('main-layout');
const generatorsWrapper    = document.getElementById('generators-wrapper');
const chatScrollbar        = document.getElementById('chat-scrollbar');
const chatScrollbarThumb   = document.getElementById('chat-scrollbar-thumb');
const btnGenerators        = document.getElementById('btn-generators');
const btnGenerateModel     = document.getElementById('btn-generate-model');
const btnCopyGenerator     = document.getElementById('btn-copy-generator');
const btnInsertGenerator   = document.getElementById('btn-insert-generator');
const generatorInput       = document.getElementById('generator-input');
const generatorInputType   = document.getElementById('generator-input-type');
const generatorOutputType  = document.getElementById('generator-output-type');
const generatorPreviewCard = document.getElementById('generator-preview-card');
const generatorOutputCode  = document.getElementById('generator-output-code');

let generatorAccumulatedCode = '';
let isChatScrollbarDragging = false;
let chatScrollbarDragStartY = 0;
let chatScrollbarDragStartScrollTop = 0;
let welcomeScreen = null;
let historyLoadRequested = false;

const QUICK_ACTIONS = [
  {
    label: 'Understand this project',
    description: 'Architecture, health, and the best next action',
    command: '/health',
    icon: "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.9" +
    "\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M8 9l-3 3 3 3\"></p" +
    "ath><path d=\"M16 9l3 3-3 3\"></path><path d=\"M14 5l-4 14\"></path></svg>"
  },
  {
    label: 'Fix a problem',
    description: 'Investigate, prepare a reviewed change, and validate it',
    command: 'Find the cause of this problem, prepare a safe fix, and validate the result: ',
    icon: "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.9" +
    "\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M8 6.5a4 4 0 0 1 8" +
    " 0\"></path><path d=\"M8 7h8v6a4 4 0 0 1-8 0V7z\"></path><path d=\"M4 13h4\"></pa" +
    "th><path d=\"M16 13h4\"></path><path d=\"M6 19l2.5-2.5\"></path><path d=\"M18 19l" +
    "-2.5-2.5\"></path><path d=\"M12 7v10\"></path></svg>"
  },
  {
    label: 'Create something',
    description: 'Projects, forms, units, APIs, tests, and features',
    command: 'Create ',
    icon: "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.9" +
    "\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 7h10\"></path><p" +
    "ath d=\"M14 4l3 3-3 3\"></path><path d=\"M17 17H7\"></path><path d=\"M10 14l-3 3 " +
    "3 3\"></path></svg>"
  },
  {
    label: 'Debug an application',
    description: 'Reproduce a runtime failure and inspect the debugger',
    command: '/journey debug ',
    icon: "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.9" +
    "\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M4 12l5 5L20 6\"></" +
    "path><path d=\"M19 13v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h8\"></pa" +
    "th></svg>"
  }
];

function updateChatScrollbar() {
  if (!chatContainer || !chatWrapper || !chatScrollbar || !chatScrollbarThumb) return;

  const footerHeight = chatWrapper.offsetHeight - chatContainer.offsetHeight;
  chatWrapper.style.setProperty('--chat-footer-height', `${Math.max(0, footerHeight)}px`);

  const scrollHeight = chatContainer.scrollHeight;
  const clientHeight = chatContainer.clientHeight;
  const maxScrollTop = scrollHeight - clientHeight;

  if (maxScrollTop <= 1) {
    chatScrollbar.classList.add('hidden');
    return;
  }

  chatScrollbar.classList.remove('hidden');

  const trackHeight = chatScrollbar.clientHeight;
  const thumbHeight = Math.max(40, Math.round((clientHeight / scrollHeight) * trackHeight));
  const maxThumbTop = Math.max(0, trackHeight - thumbHeight);
  const thumbTop = Math.round((chatContainer.scrollTop / maxScrollTop) * maxThumbTop);

  chatScrollbarThumb.style.height = `${thumbHeight}px`;
  chatScrollbarThumb.style.transform = `translateY(${thumbTop}px)`;
}

function bindChatScrollbar() {
  if (!chatContainer || !chatScrollbar || !chatScrollbarThumb) return;

  chatContainer.addEventListener('scroll', () => {
    updateChatScrollbar();
    scheduleLifecycleStateCapture();
  });
  globalThis.addEventListener('resize', updateChatScrollbar);

  chatScrollbarThumb.addEventListener('mousedown', (event) => {
    isChatScrollbarDragging = true;
    chatScrollbarDragStartY = event.clientY;
    chatScrollbarDragStartScrollTop = chatContainer.scrollTop;
    chatScrollbar.classList.add('dragging');
    event.preventDefault();
  });

  chatScrollbar.addEventListener('mousedown', (event) => {
    if (event.target === chatScrollbarThumb) return;

    const rect = chatScrollbar.getBoundingClientRect();
    const thumbHeight = chatScrollbarThumb.offsetHeight;
    const targetTop = event.clientY - rect.top - (thumbHeight / 2);
    const maxThumbTop = Math.max(1, chatScrollbar.clientHeight - thumbHeight);
    const maxScrollTop = chatContainer.scrollHeight - chatContainer.clientHeight;

    chatContainer.scrollTop = (targetTop / maxThumbTop) * maxScrollTop;
    event.preventDefault();
  });

  document.addEventListener('mousemove', (event) => {
    if (!isChatScrollbarDragging) return;

    const thumbHeight = chatScrollbarThumb.offsetHeight;
    const maxThumbTop = Math.max(1, chatScrollbar.clientHeight - thumbHeight);
    const maxScrollTop = chatContainer.scrollHeight - chatContainer.clientHeight;
    const scrollDelta = ((event.clientY - chatScrollbarDragStartY) / maxThumbTop) * maxScrollTop;

    chatContainer.scrollTop = chatScrollbarDragStartScrollTop + scrollDelta;
    event.preventDefault();
  });

  document.addEventListener('mouseup', () => {
    if (!isChatScrollbarDragging) return;

    isChatScrollbarDragging = false;
    chatScrollbar.classList.remove('dragging');
  });

  if (globalThis.ResizeObserver) {
    const resizeObserver = new globalThis.ResizeObserver(updateChatScrollbar);
    resizeObserver.observe(chatContainer);
    resizeObserver.observe(chatWrapper);
  }

  const mutationObserver = new MutationObserver(() => globalThis.requestAnimationFrame(updateChatScrollbar));
  mutationObserver.observe(chatContainer, { childList: true, subtree: true, characterData: true });
  globalThis.requestAnimationFrame(updateChatScrollbar);
}

function setPromptText(text) {
  promptTextarea.value = text;
  promptTextarea.focus();
  promptTextarea.style.height = 'auto';
  promptTextarea.style.height = promptTextarea.scrollHeight + 'px';
  promptTextarea.selectionStart = promptTextarea.selectionEnd = promptTextarea.value.length;
}

function hideWelcomeScreen() {
  if (welcomeScreen) {
    welcomeScreen.remove();
    welcomeScreen = null;
  }
}

function requestHistoryLoad() {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }

  historyLoadRequested = true;
  postMessageToDelphi({ action: 'load_history' });
}

function showWelcomeScreen() {
  if (!chatContainer || chatContainer.querySelector('.message-wrapper, .typing-wrapper')) return;
  if (welcomeScreen) return;

  welcomeScreen = document.createElement('section');
  welcomeScreen.className = 'welcome-screen';
  welcomeScreen.innerHTML = `
    <div class="welcome-orbit" aria-hidden="true">
      <span class="welcome-orbit-ring ring-one"></span>
      <span class="welcome-orbit-ring ring-two"></span>
      <span class="welcome-core">
        <svg viewBox="0 0 24 24" fill="none">
          <path d="M12 3l2.3 6.1L21 12l-6.7 2.9L12 21l-2.3-6.1L3 12l6.7-2.9L12 3z" fill="currentColor"></path>
        </svg>
      </span>
    </div>
    <h1>What do you want to accomplish?</h1>
    <p class="welcome-intro">
      Start with your goal. Rad IA keeps the effective route visible and lets you customize every detail.
    </p>
    <div class="welcome-actions"></div>
    <div class="welcome-capabilities" aria-label="Rad IA platform capabilities">
      <span>Code</span><span>Build</span><span>Tests</span><span>Debugger</span>
      <span>Form Designer</span><span>Terminal</span><span>MCP</span><span>Skills</span>
    </div>
    <button type="button" class="welcome-capabilities-btn">Explore all capabilities</button>
    <button type="button" class="welcome-history-btn">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
        <path d="M3 12a9 9 0 1 0 3-6.7"></path>
        <path d="M3 4v5h5"></path>
        <path d="M12 7v5l3 2"></path>
      </svg>
      <span>Open chats</span>
    </button>
  `;

  const actionsContainer = welcomeScreen.querySelector('.welcome-actions');
  QUICK_ACTIONS.forEach((action) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'welcome-action-btn';
    button.innerHTML = `<span class="welcome-action-icon">${action.icon}</span>` +
      `<span class="welcome-action-copy"><strong>${action.label}</strong>` +
      `<small>${action.description}</small></span>`;
    button.title = `Prepare ${action.command} in the prompt without sending it`;
    button.addEventListener('click', () => setPromptText(action.command));
    actionsContainer.appendChild(button);
  });

  welcomeScreen.querySelector('.welcome-capabilities-btn').addEventListener(
    'click',
    () => setPromptText('/help')
  );
  welcomeScreen.querySelector('.welcome-history-btn').addEventListener('click', requestHistoryLoad);
  chatContainer.appendChild(welcomeScreen);
  updateChatScrollbar();
}

const SENDER_INFO = {
  user: {
    name: 'User',
    icon: "<svg width=\"28\" height=\"28\" viewBox=\"0 0 24 24\" fill=\"none\" xmlns=\"http://ww" +
    "w.w3.org/2000/svg\"><circle cx=\"12\" cy=\"12\" r=\"12\" fill=\"#4E4E52\"/><path d=\"M" +
    "12 11C13.6569 11 15 9.65685 15 8C15 6.34315 13.6569 5 12 5C10.3431 5 9 6.343" +
    "15 9 8C9 9.65685 10.3431 11 12 11Z\" fill=\"#F1F1F1\"/><path d=\"M12 12.5C9.33 1" +
    "2.5 4 13.84 4 16.5V18H20V16.5C20 13.84 14.67 12.5 12 12.5Z\" fill=\"#F1F1F1\"/>" +
    "</svg>",
    avatarClass: 'user-avatar',
    headerClass: 'user-header'
  },
  assistant: {
    name: 'Rad IA',
    icon: "<svg width=\"28\" height=\"28\" viewBox=\"0 0 24 24\" fill=\"none\" xmlns=\"http://ww" +
    "w.w3.org/2000/svg\"><circle cx=\"12\" cy=\"12\" r=\"12\" fill=\"var(--accent)\"/><pat" +
    "h d=\"M12 6L13.8 10.2L18 12L13.8 13.8L12 18L10.2 13.8L6 12L10.2 10.2L12 6Z\" f" +
    "ill=\"#FFFFFF\"/></svg>",
    avatarClass: 'ai-avatar',
    headerClass: 'ai-header'
  },
  system: {
    name: 'System',
    icon: "<svg width=\"28\" height=\"28\" viewBox=\"0 0 24 24\" fill=\"none\" xmlns=\"http://ww" +
    "w.w3.org/2000/svg\"><circle cx=\"12\" cy=\"12\" r=\"12\" fill=\"var(--accent)\"/><pat" +
    "h d=\"M12 6L13.8 10.2L18 12L13.8 13.8L12 18L10.2 13.8L6 12L10.2 10.2L12 6Z\" f" +
    "ill=\"#FFFFFF\"/></svg>",
    avatarClass: 'ai-avatar',
    headerClass: 'ai-header'
  }
};

const PROVIDER_ICONS = {
  gemini: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" xmlns=\"http://ww" +
    "w.w3.org/2000/svg\"><path d=\"M20.616 10.835a14.147 14.147 0 01-4.45-3.001 14." +
    "111 14.111 0 01-3.678-6.452.503.503 0 00-.975 0 14.134 14.134 0 01-3.679 6.4" +
    "52 14.155 14.155 0 01-4.45 3.001c-.65.28-1.318.505-2.002.678a.502.502 0 000 " +
    ".975c.684.172 1.35.397 2.002.677a14.147 14.147 0 014.45 3.001 14.112 14.112 " +
    "0 013.679 6.453.502.502 0 00.975 0c.172-.685.397-1.351.677-2.003a14.145 14.1" +
    "45 0 013.001-4.45 14.113 14.113 0 016.453-3.678.503.503 0 000-.975 13.245 13" +
    ".245 0 01-2.003-.678z\" fill=\"url(#gemini-grad)\"/><defs><linearGradient id=\"g" +
    "emini-grad\" x1=\"2\" y1=\"2\" x2=\"22\" y2=\"22\" gradientUnits=\"userSpaceOnUse\"><st" +
    "op offset=\"0%\" stop-color=\"#4285F4\"/><stop offset=\"50%\" stop-color=\"#9B51E0\"" +
    "/><stop offset=\"100%\" stop-color=\"#E289F2\"/></linearGradient></defs></svg>",
  openai: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#10A37F\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M9.205 8.658v-2.26c0-.19.072-.333.238-.428l4." +
    "543-2.616c.619-.357 1.356-.523 2.117-.523 2.854 0 4.662 2.212 4.662 4.566 0 " +
    ".167 0 .357-.024.547l-4.71-2.759a.797.797 0 00-.856 0l-5.97 3.473zm10.609 8." +
    "8V12.06c0-.333-.143-.57-.429-.737l-5.97-3.473 1.95-1.118a.433.433 0 01.476 0" +
    "l4.543 2.617c1.309.76 2.189 2.378 2.189 3.948 0 1.808-1.07 3.473-2.76 4.163z" +
    "M7.802 12.703l-1.95-1.142c-.167-.095-.239-.238-.239-.428V5.899c0-2.545 1.95-" +
    "4.472 4.591-4.472 1 0 1.927.333 2.712.928L8.23 5.067c-.285.166-.428.404-.428" +
    ".737v6.898zM12 15.128l-2.795-1.57v-3.33L12 8.658l2.795 1.57v3.33L12 15.128zm" +
    "1.796 7.23c-1 0-1.927-.332-2.712-.927l4.686-2.712c.285-.166.428-.404.428-.73" +
    "7v-6.898l1.974 1.142c.167.095.238.238.238.428v5.233c0 2.545-1.974 4.472-4.61" +
    "4 4.472zm-5.637-5.303l-4.544-2.617c-1.308-.761-2.188-2.378-2.188-3.948A4.482" +
    " 4.482 0 014.21 6.327v5.423c0 .333.143.571.428.738l5.947 3.449-1.95 1.118a.4" +
    "32.432 0 01-.476 0zm-.262 3.9c-2.688 0-4.662-2.021-4.662-4.519 0-.19.024-.38" +
    ".047-.57l4.686 2.71c.286.167.571.167.856 0l5.97-3.448v2.26c0 .19-.07.333-.23" +
    "7.428l-4.543 2.616c-.619.357-1.356.523-2.117.523zm5.899 2.83a5.947 5.947 0 0" +
    "05.827-4.756C22.287 18.339 24 15.84 24 13.296c0-1.665-.713-3.282-1.998-4.448" +
    ".119-.5.19-.999.19-1.498 0-3.401-2.759-5.947-5.946-5.947-.642 0-1.26.095-1.8" +
    "8.31A5.962 5.962 0 0010.205 0a5.947 5.947 0 00-5.827 4.757C1.713 5.447 0 7.9" +
    "45 0 10.49c0 1.666.713 3.283 1.998 4.448-.119.5-.19 1-.19 1.499 0 3.401 2.75" +
    "9 5.946 5.946 5.946.642 0 1.26-.095 1.88-.309a5.96 5.96 0 004.162 1.713z\" fi" +
    "ll=\"#10A37F\"/></svg>",
  claude: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#D97706\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M4.709 15.955l4.72-2.647.08-.23-.08-.128H9.2l" +
    "-.79-.048-2.698-.073-2.339-.097-2.266-.122-.571-.121L0 11.784l.055-.352.48-." +
    "321.686.06 1.52.103 2.278.158 1.652.097 2.449.255h.389l.055-.157-.134-.098-." +
    "103-.097-2.358-1.596-2.552-1.688-1.336-.972-.724-.491-.364-.462-.158-1.008.6" +
    "56-.722.881.06.225.061.893.686 1.908 1.476 2.491 1.833.365.304.145-.103.019-" +
    ".073-.164-.274-1.355-2.446-1.446-2.49-.644-1.032-.17-.619a2.97 2.97 0 01-.10" +
    "4-.729L6.283.134 6.696 0l.996.134.42.364.62 1.414 1.002 2.229 1.555 3.03.456" +
    ".898.243.832.091.255h.158V9.01l.128-1.706.237-2.095.23-2.695.08-.76.376-.91." +
    "747-.492.584.28.48.685-.067.444-.286 1.851-.559 2.903-.364 1.942h.212l.243-." +
    "242.985-1.306 1.652-2.064.73-.82.85-.904.547-.431h1.033l.76 1.129-.34 1.166-" +
    "1.064 1.347-.881 1.142-1.264 1.7-.79 1.36.073.11.188-.02 2.856-.606 1.543-.2" +
    "8 1.841-.315.833.388.091.395-.328.807-1.969.486-2.309.462-3.439.813-.042.03." +
    "049.061 1.549.146.662.036h1.622l3.02.225.79.522.474.638-.079.485-1.215.62-1." +
    "64-.389-3.829-.91-1.312-.329h-.182v.11l1.093 1.068 2.006 1.81 2.509 2.33.127" +
    ".578-.322.455-.34-.049-2.205-1.657-.851-.747-1.926-1.62h-.128v.17l.444.649 2" +
    ".345 3.521.122 1.08-.17.353-.608.213-.668-.122-1.374-1.925-1.415-2.167-1.143" +
    "-1.943-.14.08-.674 7.254-.316.37-.729.28-.607-.461-.322-.747.322-1.476.389-1" +
    ".924.315-1.53.286-1.9.17-.632-.012-.042-.14.018-1.434 1.967-2.18 2.945-1.726" +
    " 1.845-.414.164-.717-.37.067-.662.401-.589 2.388-3.036 1.44-1.882.93-1.086-." +
    "006-.158h-.055L4.132 18.56l-1.13.146-.487-.456.061-.746.231-.243 1.908-1.312" +
    "-.006.006z\" fill=\"#D97706\"/></svg>",
  deepseek: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#0D53FF\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M23.748 4.482c-.254-.124-.364.113-.512.234-.0" +
    "51.039-.094.09-.137.136-.372.397-.806.657-1.373.626-.829-.046-1.537.214-2.16" +
    "3.848-.133-.782-.575-1.248-1.247-1.548-.352-.156-.708-.311-.955-.65-.172-.24" +
    "1-.219-.51-.305-.774-.055-.16-.11-.323-.293-.35-.2-.031-.278.136-.356.276-.3" +
    "13.572-.434 1.202-.422 1.84.027 1.436.633 2.58 1.838 3.393.137.093.172.187.1" +
    "29.323-.082.28-.18.552-.266.833-.055.179-.137.217-.329.14a5.526 5.526 0 01-1" +
    ".736-1.18c-.857-.828-1.631-1.742-2.597-2.458a11.365 11.365 0 00-.689-.471c-." +
    "985-.957.13-1.743.388-1.836.27-.098.093-.432-.779-.428-.872.004-1.67.295-2.6" +
    "87.684a3.055 3.055 0 01-.465.137 9.597 9.597 0 00-2.883-.102c-1.885.21-3.39 " +
    "1.102-4.497 2.623C.082 8.606-.231 10.684.152 12.85c.403 2.284 1.569 4.175 3." +
    "36 5.653 1.858 1.533 3.997 2.284 6.438 2.14 1.482-.085 3.133-.284 4.994-1.86" +
    ".47.234.962.327 1.78.397.63.059 1.236-.03 1.705-.128.735-.156.684-.837.419-." +
    "961-2.155-1.004-1.682-.595-2.113-.926 1.096-1.296 2.746-2.642 3.392-7.003.05" +
    "-.347.007-.565 0-.845-.004-.17.035-.237.23-.256a4.173 4.173 0 001.545-.475c1" +
    ".396-.763 1.96-2.015 2.093-3.517.02-.23-.004-.467-.247-.588zM11.581 18c-2.08" +
    "9-1.642-3.102-2.183-3.52-2.16-.392.024-.321.471-.235.763.09.288.207.486.371." +
    "739.114.167.192.416-.113.603-.673.416-1.842-.14-1.897-.167-1.361-.802-2.5-1." +
    "86-3.301-3.307-.774-1.393-1.224-2.887-1.298-4.482-.02-.386.093-.522.477-.592" +
    "a4.696 4.696 0 011.529-.039c2.132.312 3.946 1.265 5.468 2.774.868.86 1.525 1" +
    ".887 2.202 2.891.72 1.066 1.494 2.082 2.48 2.914.348.292.625.514.891.677-.80" +
    "2.09-2.14.11-3.054-.614zm1-6.44a.306.306 0 01.415-.287.302.302 0 01.2.288.30" +
    "6.306 0 01-.31.307.303.303 0 01-.304-.308zm3.11 1.596c-.2.081-.399.151-.59.1" +
    "6a1.245 1.245 0 01-.798-.254c-.274-.23-.47-.358-.552-.758a1.73 1.73 0 01.016" +
    "-.588c.07-.327-.008-.537-.239-.727-.187-.156-.426-.199-.688-.199a.559.559 0 " +
    "01-.254-.078c-.11-.054-.2-.19-.114-.358.028-.054.16-.186.192-.21.356-.202.76" +
    "7-.136 1.146.016.352.144.618.408 1.001.782.391.451.462.576.685.914.176.265.3" +
    "36.537.445.848.067.195-.019.354-.25.452z\" fill=\"#0D53FF\"/></svg>",
  groq: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#F97316\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M12.036 2c-3.853-.035-7 3-7.036 6.781-.035 3." +
    "782 3.055 6.872 6.908 6.907h2.42v-2.566h-2.292c-2.407.028-4.38-1.866-4.408-4" +
    ".23-.029-2.362 1.901-4.298 4.308-4.326h.1c2.407 0 4.358 1.915 4.365 4.278v6." +
    "305c0 2.342-1.944 4.25-4.323 4.279a4.375 4.375 0 01-3.033-1.252l-1.851 1.818" +
    "A7 7 0 0012.029 22h.092c3.803-.056 6.858-3.083 6.879-6.816v-6.5C18.907 4.963" +
    " 15.817 2 12.036 2z\" fill=\"#F97316\"/></svg>",
  ollama: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"currentColor\" xmlns=\"h" +
    "ttp://www.w3.org/2000/svg\"><path d=\"M7.905 1.09c.216.085.411.225.588.41.295." +
    "306.544.744.734 1.263.191.522.315 1.1.362 1.68a5.054 5.054 0 012.049-.636l.0" +
    "51-.004c.87-.07 1.73.087 2.48.474.101.053.2.11.297.17.05-.569.172-1.134.36-1" +
    ".644.19-.52.439-.957.733-1.264a1.67 1.67 0 01.589-.41c.257-.1.53-.118.796-.0" +
    "42.401.114.745.368 1.016.737.248.337.434.769.561 1.287.23.934.27 2.163.115 3" +
    ".645l.053.04.026.019c.757.576 1.284 1.397 1.563 2.35.435 1.487.216 3.155-.53" +
    "4 4.088l-.018.021.002.003c.417.762.67 1.567.724 2.4l.002.03c.064 1.065-.2 2." +
    "137-.814 3.19l-.007.01.01.024c.472 1.157.62 2.322.438 3.486l-.006.039a.651.6" +
    "51 0 01-.747.536.648.648 0 01-.54-.742c.167-1.033.01-2.069-.48-3.123a.643.64" +
    "3 0 01.04-.617l.004-.006c.604-.924.854-1.83.8-2.72-.046-.779-.325-1.544-.8-2" +
    ".273a.644.644 0 01.18-.886l.009-.006c.243-.159.467-.565.58-1.12a4.229 4.229 " +
    "0 00-.095-1.974c-.205-.7-.58-1.284-1.105-1.683-.595-.454-1.383-.673-2.38-.61" +
    "a.653.653 0 01-.632-.371c-.314-.665-.772-1.141-1.343-1.436a3.288 3.288 0 00-" +
    "1.772-.332c-1.245.099-2.343.801-2.67 1.686a.652.652 0 01-.61.425c-1.067.002-" +
    "1.893.252-2.497.703-.522.39-.878.935-1.066 1.588a4.07 4.07 0 00-.068 1.886c." +
    "112.558.331 1.02.582 1.269l.008.007c.212.207.257.53.109.785-.36.622-.629 1.5" +
    "49-.673 2.44-.05 1.018.186 1.902.719 2.536l.016.019a.643.643 0 01.095.69c-.5" +
    "76 1.236-.753 2.252-.562 3.052a.652.652 0 01-1.269.298c-.243-1.018-.078-2.18" +
    "4.473-3.498l.014-.035-.008-.012a4.339 4.339 0 01-.598-1.309l-.005-.019a5.764" +
    " 5.764 0 01-.177-1.785c.044-.91.278-1.842.622-2.59l.012-.026-.002-.002c-.293" +
    "-.418-.51-.953-.63-1.545l-.005-.024a5.352 5.352 0 01.093-2.49c.262-.915.777-" +
    "1.701 1.536-2.269.06-.045.123-.09.186-.132-.159-1.493-.119-2.73.112-3.67.127" +
    "-.518.314-.95.562-1.287.27-.368.614-.622 1.015-.737.266-.076.54-.059.797.042" +
    "zm4.116 9.09c.936 0 1.8.313 2.446.855.63.527 1.005 1.235 1.005 1.94 0 .888-." +
    "406 1.58-1.133 2.022-.62.375-1.451.557-2.403.557-1.009 0-1.871-.259-2.493-.7" +
    "34-.617-.47-.963-1.13-.963-1.845 0-.707.398-1.417 1.056-1.946.668-.537 1.55-" +
    ".849 2.485-.849zm0 .896a3.07 3.07 0 00-1.916.65c-.461.37-.722.835-.722 1.25 " +
    "0 .428.21.829.61 1.134.455.347 1.124.548 1.943.548.799 0 1.473-.147 1.932-.4" +
    "26.463-.28.7-.686.7-1.257 0-.423-.246-.89-.683-1.256-.484-.405-1.14-.643-1.8" +
    "64-.643zm.662 1.21l.004.004c.12.151.095.37-.056.49l-.292.23v.446a.375.375 0 " +
    "01-.376.373.375.375 0 01-.376-.373v-.46l-.271-.218a.347.347 0 01-.052-.49.35" +
    "3.353 0 01.494-.051l.215.172.22-.174a.353.353 0 01.49.051zm-5.04-1.919c.478 " +
    "0 .867.39.867.871a.87.87 0 01-.868.871.87.87 0 01-.867-.87.87.87 0 01.867-.8" +
    "72zm8.706 0c.48 0 .868.39.868.871a.87.87 0 01-.868.871.87.87 0 01-.867-.87.8" +
    "7.87 0 01.867-.872zM7.44 2.3l-.003.002a.659.659 0 00-.285.238l-.005.006c-.13" +
    "8.189-.258.467-.348.832-.17.692-.216 1.631-.124 2.782.43-.128.899-.208 1.404" +
    "-.237l.01-.001.019-.034c.046-.082.095-.161.148-.239.123-.771.022-1.692-.253-" +
    "2.444-.134-.364-.297-.65-.453-.813a.628.628 0 00-.107-.09L7.44 2.3zm9.174.04" +
    "l-.002.001a.628.628 0 00-.107.09c-.156.163-.32.45-.453.814-.29.794-.387 1.77" +
    "6-.23 2.572l.058.097.008.014h.03a5.184 5.184 0 011.466.212c.086-1.124.038-2." +
    "043-.128-2.722-.09-.365-.21-.643-.349-.832l-.004-.006a.659.659 0 00-.285-.23" +
    "9h-.004z\"/></svg>",
  githubcopilot: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#5856D6\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M9 23l.073-.001a2.53 2.53 0 01-2.347-1.838l-." +
    "697-2.433a2.529 2.529 0 00-2.426-1.839h-.497l-.104-.002c-4.485 0-2.935-5.278" +
    "-1.75-9.225l.162-.525C2.412 3.99 3.883 1 6.25 1h8.86c1.12 0 2.106.745 2.422 " +
    "1.829l.715 2.453a2.53 2.53 0 002.247 1.823l.147.005.534.001c3.557.115 3.088 " +
    "3.745 2.156 7.206l-.113.413c-.154.548-.315 1.089-.47 1.607l-.163.525C21.588 " +
    "20.01 20.116 23 17.75 23h-8.75zm8.22-15.89l-3.856.001a2.526 2.526 0 00-2.35 " +
    "1.615L9.21 15.04a2.529 2.529 0 01-2.43 1.847l3.853.002c1.056 0 1.992-.661 2." +
    "361-1.644l1.796-6.287a2.529 2.529 0 012.43-1.848z\" fill=\"#5856D6\"/></svg>",
  azureopenai: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#0078D4\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M18.397 15.296H7.4a.51.51 0 00-.347.882l7.066" +
    " 6.595c.206.192.477.298.758.298h6.226l-2.706-7.775z\" fill-opacity=\".75\" fill" +
    "=\"#0078D4\"/><path d=\"M8.295.857c-.477 0-.9.304-1.053.756L.495 21.605a1.11 1." +
    "11 0 001.052 1.466h5.43c.477 0 .9-.304 1.053-.755l1.341-3.975-2.318-2.163a.5" +
    "1.51 0 01.347-.882h3L15.271.857H8.295z\" fill-opacity=\".5\" fill=\"#0078D4\"/><p" +
    "ath d=\"M17.193 1.613a1.11 1.11 0 00-1.052-.756h-7.81.035c.477 0 .9.304 1.052" +
    ".756l6.748 19.992a1.11 1.11 0 01-1.052 1.466h-.12 7.895a1.11 1.11 0 001.052-" +
    "1.466L17.193 1.613z\" fill=\"#0078D4\"/></svg>",
  qwen: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#615CED\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M12.604 1.34c.393.69.784 1.382 1.174 2.075a.1" +
    "8.18 0 00.157.091h5.552c.174 0 .322.11.446.327l1.454 2.57c.19.337.24.478.024" +
    ".837-.26.43-.513.864-.76 1.3l-.367.658c-.106.196-.223.28-.04.512l2.652 4.637" +
    "c.172.301.111.494-.043.77-.437.785-.882 1.564-1.335 2.34-.159.272-.352.375-." +
    "68.37-.777-.016-1.552-.01-2.327.016a.099.099 0 00-.081.05 575.097 575.097 0 " +
    "01-2.705 4.74c-.169.293-.38.363-.725.364-.997.003-2.002.004-3.017.002a.537.5" +
    "37 0 01-.465-.271l-1.335-2.323a.09.09 0 00-.083-.049H4.982c-.285.03-.553-.00" +
    "1-.805-.092l-1.603-2.77a.543.543 0 01-.002-.54l1.207-2.12a.198.198 0 000-.19" +
    "7 550.951 550.951 0 01-1.875-3.272l-.79-1.395c-.16-.31-.173-.496.095-.965.46" +
    "5-.813.927-1.625 1.387-2.436.132-.234.304-.334.584-.335a338.3 338.3 0 012.58" +
    "9-.001.124.124 0 00.107-.063l2.806-4.895a.488.488 0 01.422-.246c.524-.001 1." +
    "053 0 1.583-.006L11.704 1c.341-.003.724.032.9.34zm-3.432.403a.06.06 0 00-.05" +
    "2.03L6.254 6.788a.157.157 0 01-.135.078H3.253c-.056 0-.07.025-.041.074l5.81 " +
    "10.156c.025.042.013.062-.034.063l-2.795.015a.218.218 0 00-.2.116l-1.32 2.31c" +
    "-.044.078-.021.118.068.118l5.716.008c.046 0 .08.02.104.061l1.403 2.454c.046." +
    "081.092.082.139 0l5.006-8.76.783-1.382a.055.055 0 01.096 0l1.424 2.53a.122.1" +
    "22 0 00.107.062l2.763-.02a.04.04 0 00.035-.02.041.041 0 000-.04l-2.9-5.086a." +
    "108.108 0 010-.113l.293-.507 1.12-1.977c.024-.041.012-.062-.035-.062H9.2c-.0" +
    "59 0-.073-.026-.043-.077l1.434-2.505a.107.107 0 000-.114L9.225 1.774a.06.06 " +
    "0 00-.053-.031zm6.29 8.02c.046 0 .058.02.034.06l-.832 1.465-2.613 4.585a.056" +
    ".056 0 01-.05.029.058.058 0 01-.05-.029L8.498 9.841c-.02-.034-.01-.052.028-." +
    "054l.216-.012 6.722-.012z\" fill=\"#615CED\"/></svg>",
  mistral: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#FD5A24\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path clip-rule=\"evenodd\" d=\"M3.428 3.4h3.429v3.428h3." +
    "429v3.429h-.002 3.431V6.828h3.427V3.4h3.43v13.714H24v3.429H13.714v-3.428h-3." +
    "428v-3.429h-3.43v3.428h3.43v3.429H0v-3.429h3.428V3.4zm10.286 13.715h3.428v-3" +
    ".429h-3.427v3.429z\" fill=\"#FD5A24\"/></svg>",
  bedrock: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#FF9900\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M13.05 15.513h3.08c.214 0 .389.177.389.394v1." +
    "82a1.704 1.704 0 011.296 1.661c0 .943-.755 1.708-1.685 1.708-.931 0-1.686-.7" +
    "65-1.686-1.708 0-.807.554-1.484 1.297-1.662v-1.425h-2.69v4.663a.395.395 0 01" +
    "-.188.338l-2.69 1.641a.385.385 0 01-.405-.002l-4.926-3.086a.395.395 0 01-.18" +
    "5-.336V16.3L2.196 14.87A.395.395 0 012 14.555L2 14.528V9.406c0-.14.073-.27.1" +
    "92-.34l2.465-1.462V4.448c0-.129.062-.249.165-.322l.021-.014L9.77 1.058a.385." +
    "385 0 01.407 0l2.69 1.675a.395.395 0 01.185.336V7.6h3.856V5.683a1.704 1.704 " +
    "0 01-1.296-1.662c0-.943.755-1.708 1.685-1.708.931 0 1.685.765 1.685 1.708 0 " +
    ".807-.553 1.484-1.296 1.662v2.311a.391.391 0 01-.389.394h-4.245v1.806h6.624a" +
    "1.69 1.69 0 011.64-1.313c.93 0 1.685.764 1.685 1.707 0 .943-.754 1.708-1.685" +
    " 1.708a1.69 1.69 0 01-1.64-1.314H13.05v1.937h4.953l.915 1.18a1.66 1.66 0 01." +
    "84-.227c.931 0 1.685.764 1.685 1.707 0 .943-.754 1.708-1.685 1.708-.93 0-1.6" +
    "85-.765-1.685-1.708 0-.346.102-.668.276-.937l-.724-.935H13.05v1.806zM9.973 1" +
    ".856L7.93 3.122V6.09h-.778V3.604L5.435 4.669v2.945l2.11 1.36L9.712 7.61V5.33" +
    "4h.778V7.83c0 .136-.07.263-.184.335L7.963 9.638v2.081l1.422 1.009-.446.646-1" +
    ".406-.998-1.53 1.005-.423-.66 1.605-1.055v-1.99L5.038 8.29l-2.26 1.34v1.676l" +
    "1.972-1.189.398.677-2.37 1.429V14.3l2.166 1.258 2.27-1.368.397.677-2.176 1.3" +
    "11V19.3l1.876 1.175 2.365-1.426.398.678-2.017 1.216 1.918 1.201 2.298-1.403v" +
    "-5.78l-4.758 2.893-.4-.675 5.158-3.136V3.289L9.972 1.856zM16.13 18.47a.913.9" +
    "13 0 00-.908.92c0 .507.406.918.908.918a.913.913 0 00.907-.919.913.913 0 00-." +
    "907-.92zm3.63-3.81a.913.913 0 00-.908.92c0 .508.406.92.907.92a.913.913 0 00." +
    "908-.92.913.913 0 00-.908-.92zm1.555-4.99a.913.913 0 00-.908.92c0 .507.407.9" +
    "18.908.918a.913.913 0 00.907-.919.913.913 0 00-.907-.92zM17.296 3.1a.913.913" +
    " 0 00-.907.92c0 .508.406.92.907.92a.913.913 0 00.908-.92.913.913 0 00-.908-." +
    "92z\" fill=\"#FF9900\"/></svg>",
  openrouter: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"currentColor\" xmlns=\"h" +
    "ttp://www.w3.org/2000/svg\"><path d=\"M16.804 1.957l7.22 4.105v.087L16.73 10.2" +
    "1l.017-2.117-.821-.03c-1.059-.028-1.611.002-2.268.11-1.064.175-2.038.577-3.1" +
    "47 1.352L8.345 11.03c-.284.195-.495.336-.68.455l-.515.322-.397.234.385.23.53" +
    ".338c.476.314 1.17.796 2.701 1.866 1.11.775 2.083 1.177 3.147 1.352l.3.045c." +
    "694.091 1.375.094 2.825.033l.022-2.159 7.22 4.105v.087L16.589 22l.014-1.862-" +
    ".635.022c-1.386.042-2.137.002-3.138-.162-1.694-.28-3.26-.926-4.881-2.059l-2." +
    "158-1.5a21.997 21.997 0 00-.755-.498l-.467-.28a55.927 55.927 0 00-.76-.43C2." +
    "908 14.73.563 14.116 0 14.116V9.888l.14.004c.564-.007 2.91-.622 3.809-1.124l" +
    "1.016-.58.438-.274c.428-.28 1.072-.726 2.686-1.853 1.621-1.133 3.186-1.78 4." +
    "881-2.059 1.152-.19 1.974-.213 3.814-.138l.02-1.907z\" fill=\"currentColor\"/><" +
    "/svg>",
  lmstudio: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"#EC4899\" xmlns=\"http:/" +
    "/www.w3.org/2000/svg\"><path d=\"M2.84 2a1.273 1.273 0 100 2.547h14.107a1.273 " +
    "1.273 0 100-2.547H2.84zM7.935 5.33a1.273 1.273 0 000 2.548H22.04a1.274 1.274" +
    " 0 000-2.547H7.935zM3.624 9.935c0-.704.57-1.274 1.274-1.274h14.106a1.274 1.2" +
    "74 0 010 2.547H4.898c-.703 0-1.274-.57-1.274-1.273zM1.273 12.188a1.273 1.273" +
    " 0 100 2.547H15.38a1.274 1.274 0 000-2.547H1.273zM3.624 16.792c0-.704.57-1.2" +
    "74 1.274-1.274h14.106a1.273 1.273 0 110 2.547H4.898c-.703 0-1.274-.57-1.274-" +
    "1.273zM13.029 18.849a1.273 1.273 0 100 2.547h9.698a1.273 1.273 0 100-2.547h-" +
    "9.698z\" fill-opacity=\".3\" fill=\"#EC4899\"/><path d=\"M2.84 2a1.273 1.273 0 100" +
    " 2.547h10.287a1.274 1.274 0 000-2.547H2.84zM7.935 5.33a1.273 1.273 0 000 2.5" +
    "48H18.22a1.274 1.274 0 000-2.547H7.935zM3.624 9.935c0-.704.57-1.274 1.274-1." +
    "274h10.286a1.273 1.273 0 010 2.547H4.898c-.703 0-1.274-.57-1.274-1.273zM1.27" +
    "3 12.188a1.273 1.273 0 100 2.547H11.56a1.274 1.274 0 000-2.547H1.273zM3.624 " +
    "16.792c0-.704.57-1.274 1.274-1.274h10.286a1.273 1.273 0 110 2.547H4.898c-.70" +
    "3 0-1.274-.57-1.274-1.273zM13.029 18.849a1.273 1.273 0 100 2.547h5.78a1.273 " +
    "1.273 0 100-2.547h-5.78z\" fill=\"#EC4899\"/></svg>",
  generic: "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentC" +
    "olor\" stroke-width=\"2.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\" xmln" +
    "s=\"http://www.w3.org/2000/svg\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M12 " +
    "16v-4M12 8h.01\"/></svg>"
};

function getProviderIcon(providerId) {
  if (!providerId) return PROVIDER_ICONS.generic;
  const key = String(providerId).toLowerCase().replaceAll(/[^a-z0-9]/g, '');
  return PROVIDER_ICONS[key] || PROVIDER_ICONS.generic;
}

let requestInProgress = false;
let cliActivityCard = null;
let cliActivityLog = null;
let cliActivityStatus = null;
let cliActivityStartedAt = 0;

function summarizeCliActivity(text, phase) {
  if (phase === 'started') return 'Preparing the CLI environment...';
  if (phase === 'completed') return 'CLI task completed.';
  if (phase === 'cancelled') return 'CLI task cancelled.';
  if (phase === 'failed') return 'CLI task failed.';
  const normalized = String(text || '').toLowerCase();
  if (normalized.includes('command_execution')) return 'Executing a command...';
  if (normalized.includes('file_change')) return 'Updating project files...';
  if (normalized.includes('mcp_tool_call')) return 'Calling an MCP tool...';
  if (normalized.includes('turn.started')) return 'Analyzing the request...';
  if (normalized.includes('turn.completed')) return 'Finishing this step...';
  if (phase === 'warning') return 'CLI reported diagnostic output.';
  return 'CLI is working...';
}

function renderCliActivity(data) {
  if (!cliActivityCard || data.phase === 'started') {
    cliActivityCard = document.createElement('details');
    cliActivityCard.className = 'cli-activity-card';
    const summary = document.createElement('summary');
    cliActivityStatus = document.createElement('span');
    cliActivityStatus.className = 'cli-activity-status';
    summary.appendChild(cliActivityStatus);
    const meta = document.createElement('span');
    meta.className = 'cli-activity-meta';
    meta.textContent = data.cli || 'CLI';
    summary.appendChild(meta);
    cliActivityLog = document.createElement('pre');
    cliActivityLog.className = 'cli-activity-log';
    cliActivityCard.appendChild(summary);
    cliActivityCard.appendChild(cliActivityLog);
    chatContainer.appendChild(cliActivityCard);
    cliActivityStartedAt = Date.now();
  }
  cliActivityStatus.textContent = summarizeCliActivity(data.text, data.phase);
  cliActivityCard.dataset.phase = data.phase || 'output';
  if (data.text) {
    const elapsed = Math.max(0, Math.round((Date.now() - cliActivityStartedAt) / 1000));
    cliActivityLog.textContent += `[${elapsed}s] ${data.text}`;
    if (!String(data.text).endsWith('\n')) cliActivityLog.textContent += '\n';
    if (cliActivityLog.textContent.length > 100000) {
      cliActivityLog.textContent = cliActivityLog.textContent.slice(-100000);
    }
  }
  chatContainer.scrollTop = chatContainer.scrollHeight;
}
let modelSelectionEnabled = true;
const _promptHistory = [];
let _promptHistoryIndex = -1;
let _promptDraft = '';
const queuedPrompts = [];
const MAX_QUEUED_PROMPTS = 5;

function canChangeSession() {
  return !requestInProgress;
}

function showSessionLockedStatus() {
  showTransientStatus('Wait for the current response to finish, or cancel it before switching chats.');
}

function updateSessionControlsState() {
  const disabled = requestInProgress;
  const activeComposerButtons = new Set([
    btnSendPrompt,
    btnQueuePrompt,
    btnEditQueued,
    btnClearQueued
  ]);
  document.querySelectorAll('button').forEach(button => {
    button.disabled = disabled && !activeComposerButtons.has(button);
  });
  sessionsSidebar.classList.toggle('sessions-locked', disabled);
}

function updateQueuedPrompts() {
  const count = queuedPrompts.length;
  queuedPromptsBar.classList.toggle('hidden', count === 0);
  if (count === 0) {
    queuedPromptsText.textContent = '';
    return;
  }
  const preview = queuedPrompts[0].replaceAll(/\s+/g, ' ').slice(0, 80);
  queuedPromptsText.textContent = `${count} queued · Next: ${preview}`;
}

function rememberPrompt(text) {
  if (_promptHistory.length === 0 || _promptHistory.at(-1) !== text) {
    _promptHistory.push(text);
    if (_promptHistory.length > 100) _promptHistory.shift();
  }
  _promptHistoryIndex = -1;
  _promptDraft = '';
}

function clearPromptEditor() {
  promptTextarea.value = '';
  promptTextarea.style.height = 'auto';
  hideSlashPopup();
}

function submitPrompt(text, clearEditor = true) {
  rememberPrompt(text);
  hideWelcomeScreen();
  postMessageToDelphi({ action: 'send_prompt', text: text });
  if (clearEditor) clearPromptEditor();
}

function queuePrompt() {
  const text = promptTextarea.value.trim();
  if (!text) return;
  if (queuedPrompts.length >= MAX_QUEUED_PROMPTS) {
    showTransientStatus(`Queue limit reached (${MAX_QUEUED_PROMPTS} messages).`);
    return;
  }
  queuedPrompts.push(text);
  clearPromptEditor();
  updateQueuedPrompts();
  showTransientStatus('Message queued for the current conversation.');
  promptTextarea.focus();
}

function dispatchNextQueuedPrompt() {
  if (requestInProgress || queuedPrompts.length === 0) return;
  const text = queuedPrompts.shift();
  updateQueuedPrompts();
  submitPrompt(text, false);
}

promptTextarea.addEventListener('input', () => {
  promptTextarea.style.height = 'auto';
  promptTextarea.style.height = promptTextarea.scrollHeight + 'px';

  const text = promptTextarea.value;
  if (text.startsWith('/')) {
    showSlashPopup(text);
  } else {
    hideSlashPopup();
  }
  scheduleLifecycleStateCapture();
});

function handleSlashPopupKeydown(e) {
  if (e.key === 'ArrowUp') {
    e.preventDefault();
    if (filteredSlashCommands.length > 0) {
      slashPopupSelectedIndex = (
        slashPopupSelectedIndex - 1 + filteredSlashCommands.length
      ) % filteredSlashCommands.length;
      renderSlashCommands();
    }
    return true;
  } else if (e.key === 'ArrowDown') {
    e.preventDefault();
    if (filteredSlashCommands.length > 0) {
      slashPopupSelectedIndex = (slashPopupSelectedIndex + 1) % filteredSlashCommands.length;
      renderSlashCommands();
    }
    return true;
  } else if (e.key === 'Enter') {
    e.preventDefault();
    if (filteredSlashCommands.length > 0) {
      insertSlashCommand(filteredSlashCommands[slashPopupSelectedIndex].name);
    }
    return true;
  } else if (e.key === 'Escape') {
    e.preventDefault();
    hideSlashPopup();
    return true;
  }
  return false;
}

function handleArrowUp() {
  const textBeforeCursor = promptTextarea.value.substring(0, promptTextarea.selectionStart);
  if (textBeforeCursor.includes('\n') || _promptHistory.length === 0) return false;

  if (_promptHistoryIndex === -1) {
    _promptDraft = promptTextarea.value;
    _promptHistoryIndex = _promptHistory.length - 1;
  } else if (_promptHistoryIndex > 0) {
    _promptHistoryIndex--;
  }

  promptTextarea.value = _promptHistory[_promptHistoryIndex];
  setTimeout(() => {
    promptTextarea.selectionStart = promptTextarea.selectionEnd = promptTextarea.value.length;
    promptTextarea.dispatchEvent(new Event('input'));
  }, 0);
  return true;
}

function handleArrowDown() {
  const textAfterCursor = promptTextarea.value.substring(promptTextarea.selectionEnd);
  if (textAfterCursor.includes('\n') || _promptHistoryIndex === -1) return false;

  if (_promptHistoryIndex < _promptHistory.length - 1) {
    _promptHistoryIndex++;
    promptTextarea.value = _promptHistory[_promptHistoryIndex];
  } else {
    _promptHistoryIndex = -1;
    promptTextarea.value = _promptDraft;
  }

  setTimeout(() => {
    promptTextarea.selectionStart = promptTextarea.selectionEnd = promptTextarea.value.length;
    promptTextarea.dispatchEvent(new Event('input'));
  }, 0);
  return true;
}

function handleHistoryKeydown(e) {
  if (e.key === 'ArrowUp') {
    if (handleArrowUp()) {
      e.preventDefault();
      return true;
    }
  } else if (e.key === 'ArrowDown') {
    if (handleArrowDown()) {
      e.preventDefault();
      return true;
    }
  }
  return false;
}

promptTextarea.addEventListener('keydown', (e) => {
  if (slashPopupVisible) {
    if (handleSlashPopupKeydown(e)) return;
  } else if (e.key === 'Enter' && e.ctrlKey) {
    e.preventDefault();
    if (requestInProgress) queuePrompt();
    else handleSend();
  } else {
    handleHistoryKeydown(e);
  }
});

btnSendPrompt.addEventListener('click', handleSend);
btnQueuePrompt.addEventListener('click', queuePrompt);
btnEditQueued.addEventListener('click', () => {
  if (queuedPrompts.length === 0) return;
  const currentText = promptTextarea.value.trim();
  const queuedText = queuedPrompts.shift();
  if (currentText) queuedPrompts.unshift(currentText);
  promptTextarea.value = queuedText;
  promptTextarea.dispatchEvent(new Event('input'));
  updateQueuedPrompts();
  promptTextarea.focus();
});
btnClearQueued.addEventListener('click', () => {
  queuedPrompts.length = 0;
  updateQueuedPrompts();
  showTransientStatus('Queued messages cleared.');
  promptTextarea.focus();
});

btnAgentMode.addEventListener('click', () => {
  postMessageToDelphi({
    action: 'set_agent_mode',
    enabled: !agentModeEnabled
  });
});

function handleSend() {
  if (requestInProgress) {
    postMessageToDelphi({ action: 'cancel_request' });
    return;
  }

  const text = promptTextarea.value.trim();
  if (!text) return;
  submitPrompt(text);
}

function showTab(tabName) {
  if (tabName === 'generators') {
    sessionsSidebar.classList.add('collapsed');
    mainLayout.classList.add('generator-mode');
    chatWrapper.classList.add('hidden');
    generatorsWrapper.classList.remove('hidden');
    btnGenerators.classList.add('active');
  } else {
    mainLayout.classList.remove('generator-mode');
    generatorsWrapper.classList.add('hidden');
    chatWrapper.classList.remove('hidden');
    btnGenerators.classList.remove('active');
  }
}

btnGenerators.addEventListener('click', () => {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }
  if (generatorsWrapper.classList.contains('hidden')) {
    showTab('generators');
  } else {
    showTab('chat');
  }
});

btnClearChat.addEventListener('click', () => {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }
  if (confirm('Clear the current conversation history?')) {
    postMessageToDelphi({ action: 'clear_chat' });
  }
});

btnProblems.addEventListener('click', () => {
  const willOpen = problemsPanel.classList.contains('collapsed');
  problemsPanel.classList.toggle('collapsed', !willOpen);
  problemsPanel.toggleAttribute('inert', !willOpen);
  btnProblems.setAttribute('aria-expanded', String(willOpen));
  if (willOpen) renderProblemsPanel();
});

btnCloseProblems.addEventListener('click', () => {
  problemsPanel.classList.add('collapsed');
  problemsPanel.setAttribute('inert', '');
  btnProblems.setAttribute('aria-expanded', 'false');
  btnProblems.focus();
});

btnClearProblems.addEventListener('click', clearCollectedProblems);
problemsSeverityFilter.addEventListener('change', renderProblemsPanel);
problemsCategoryFilter.addEventListener('change', renderProblemsPanel);

btnHistory.addEventListener('click', () => {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }
  if (!generatorsWrapper.classList.contains('hidden')) {
    showTab('chat');
  }
  if (sessionsSidebar.classList.contains('collapsed') && !historyLoadRequested) {
    requestHistoryLoad();
  }
  sessionsSidebar.classList.toggle('collapsed');
  btnHistory.setAttribute(
    'aria-expanded',
    String(!sessionsSidebar.classList.contains('collapsed'))
  );
});

btnSettings.addEventListener('click', () => {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }
  postMessageToDelphi({ action: 'open_settings' });
});

btnTerminal.addEventListener('click', () => {
  postMessageToDelphi({ action: 'open_terminal' });
});

btnAgentHistory.addEventListener('click', () => {
  postMessageToDelphi({ action: 'search_agent_history', query: '' });
});


btnNewChatSidebar.addEventListener('click', () => {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }
  showTab('chat');
  postMessageToDelphi({ action: 'new_chat' });
});

btnGenerateModel.addEventListener('click', () => {
  const inputVal = generatorInput.value.trim();
  if (!inputVal) return;

  btnGenerateModel.disabled = true;
  btnGenerateModel.textContent = 'Generating...';
  generatorAccumulatedCode = '';
  generatorPreviewCard.classList.add('hidden');
  generatorOutputCode.textContent = '';

  postMessageToDelphi({
    action: 'generate_dto',
    input: inputVal,
    inputType: generatorInputType.value,
    outputType: generatorOutputType.value
  });
});

btnCopyGenerator.addEventListener('click', () => {
  navigator.clipboard.writeText(generatorAccumulatedCode).then(() => {
    const orig = btnCopyGenerator.innerHTML;
    btnCopyGenerator.innerHTML = SVG_ICONS.check;
    setTimeout(() => { btnCopyGenerator.innerHTML = orig; }, 2000);
  });
});

btnInsertGenerator.addEventListener('click', () => {
  postMessageToDelphi({ action: 'apply_code', code: generatorAccumulatedCode });
  const orig = btnInsertGenerator.innerHTML;
  btnInsertGenerator.innerHTML = SVG_ICONS.check;
  setTimeout(() => { btnInsertGenerator.innerHTML = orig; }, 2000);
});

selectProvider.addEventListener('change', () => {
  postMessageToDelphi({ action: 'change_provider', provider: selectProvider.value });
});

selectModel.addEventListener('change', () => {
  postMessageToDelphi({ action: 'change_model', model: selectModel.value });
});

executionRouteSelector.addEventListener('change', () => {
  postMessageToDelphi({
    action: 'set_agent_executor',
    executor: executionRouteSelector.value
  });
});
reasoningEffortSelector.addEventListener('change', () => {
  postMessageToDelphi({
    action: 'set_reasoning_effort',
    effort: reasoningEffortSelector.value
  });
});

btnCliNewSession?.addEventListener('click', () => {
  postMessageToDelphi({ action: 'reset_cli_session' });
});

btnJourneyContext?.addEventListener('click', () => {
  postMessageToDelphi({ action: 'toggle_journey_context' });
});

btnExecutionScope?.addEventListener('click', () => {
  postMessageToDelphi({ action: 'show_execution_scope' });
});

btnComposerAdvanced?.addEventListener('click', () => {
  const visible = btnComposerAdvanced.getAttribute('aria-expanded') !== 'true';
  setComposerAdvancedVisible(visible);
  scheduleLifecycleStateCapture();
});

btnClearExecutionScope?.addEventListener('click', () => {
  postMessageToDelphi({
    action: 'update_execution_scope',
    operation: 'clear',
    scope: executionScopeKind.value
  });
});

btnExportExecutionScope?.addEventListener('click', () => {
  postMessageToDelphi({
    action: 'export_execution_scope',
    scope: executionScopeKind.value
  });
});

const EXECUTION_SCOPE_FIELDS = [
  ['provider', 'Provider'],
  ['model', 'Model'],
  ['executor', 'Executor'],
  ['maxTokens', 'Maximum tokens'],
  ['timeoutMs', 'Timeout (ms)'],
  ['tokenBudget', 'Agent token budget']
];

function updateExecutionScope(data) {
  executionScopeFields.replaceChildren();
  executionScopeKind.querySelector('option[value="project"]').disabled =
    data.projectAvailable === false;
  executionScopeKind.querySelector('option[value="session"]').disabled =
    data.sessionAvailable === false;
  if (executionScopeKind.selectedOptions[0]?.disabled) {
    executionScopeKind.value = 'request';
  }
  btnExportExecutionScope.disabled = executionScopeKind.value === 'request';
  executionScopeNote.textContent =
    'Effective values are shown below. The source identifies the scope currently winning precedence.';
  EXECUTION_SCOPE_FIELDS.forEach(([field, label]) => {
    const setting = data[field] || { value: '', origin: 'default' };
    const row = document.createElement('div');
    row.className = 'execution-scope-row';
    const name = document.createElement('strong');
    name.textContent = label;
    const value = document.createElement('label');
    value.className = 'execution-scope-value';
    const input = document.createElement('input');
    input.value = setting.value || '';
    input.setAttribute('aria-label', `${label} override`);
    input.title = `Effective value from ${setting.origin}. Edit and select Apply to override it.`;
    const origin = document.createElement('span');
    origin.className = 'execution-scope-origin';
    origin.textContent = `Source: ${setting.origin}`;
    value.append(input, origin);
    const apply = document.createElement('button');
    apply.type = 'button';
    apply.textContent = 'Apply';
    apply.title = `Override ${label.toLowerCase()} for the selected scope`;
    apply.addEventListener('click', () => {
      postMessageToDelphi({
        action: 'update_execution_scope',
        operation: 'set',
        scope: executionScopeKind.value,
        field,
        value: input.value
      });
    });
    const inherit = document.createElement('button');
    inherit.type = 'button';
    inherit.textContent = 'Inherit';
    inherit.title = `Remove the selected-scope override for ${label.toLowerCase()}`;
    inherit.addEventListener('click', () => {
      postMessageToDelphi({
        action: 'update_execution_scope',
        operation: 'inherit',
        scope: executionScopeKind.value,
        field
      });
    });
    row.append(name, value, apply, inherit);
    executionScopeFields.appendChild(row);
  });
  if (!executionScopeDialog.open) {
    executionScopeDialog.showModal();
  }
}

executionScopeKind?.addEventListener('change', () => {
  btnExportExecutionScope.disabled = executionScopeKind.value === 'request';
});

function setDropdownOpen(wrapper, trigger, open) {
  wrapper.classList.toggle('open', open);
  trigger.setAttribute('aria-expanded', String(open));
}

function closeDropdowns() {
  setDropdownOpen(modelDropdownWrapper, modelDropdownTrigger, false);
  setDropdownOpen(providerDropdownWrapper, providerDropdownTrigger, false);
  setDropdownOpen(effortDropdownWrapper, effortDropdownTrigger, false);
}

function updateEffortSelection(effort = 'medium') {
  reasoningEffortSelector.value = effort;
  const options = effortOptionsList.querySelectorAll('.custom-dropdown-option');
  options.forEach(option => {
    const selected = option.dataset.effort === effort;
    option.classList.toggle('selected', selected);
    option.setAttribute('aria-pressed', String(selected));
    if (selected) effortDropdownValue.textContent = option.textContent;
  });
}

function toggleEffortDropdown() {
  setDropdownOpen(modelDropdownWrapper, modelDropdownTrigger, false);
  setDropdownOpen(providerDropdownWrapper, providerDropdownTrigger, false);
  const open = !effortDropdownWrapper.classList.contains('open');
  setDropdownOpen(effortDropdownWrapper, effortDropdownTrigger, open);
  if (open) {
    const selected = effortOptionsList.querySelector('[aria-pressed="true"]');
    (selected || effortOptionsList.querySelector('button'))?.focus();
  }
}

effortDropdownTrigger.addEventListener('click', (event) => {
  event.stopPropagation();
  toggleEffortDropdown();
});

effortOptionsList.querySelectorAll('.custom-dropdown-option').forEach(option => {
  option.addEventListener('click', (event) => {
    event.stopPropagation();
    updateEffortSelection(option.dataset.effort);
    reasoningEffortSelector.dispatchEvent(new Event('change'));
    setDropdownOpen(effortDropdownWrapper, effortDropdownTrigger, false);
    effortDropdownTrigger.focus();
  });
});

function toggleModelDropdown() {
  if (modelDropdownWrapper.classList.contains('disabled')) return;
  setDropdownOpen(providerDropdownWrapper, providerDropdownTrigger, false);
  const open = !modelDropdownWrapper.classList.contains('open');
  setDropdownOpen(modelDropdownWrapper, modelDropdownTrigger, open);
  if (open) {
    modelSearchInput.value = '';
    filterModels('');
    modelSearchInput.focus();
  }
}

modelDropdownTrigger.addEventListener('click', (e) => {
  e.stopPropagation();
  toggleModelDropdown();
});

modelDropdownTrigger.addEventListener('keydown', (e) => {
  if (e.key !== 'Enter' && e.key !== ' ') return;
  e.preventDefault();
  e.stopPropagation();
  toggleModelDropdown();
});

modelSearchInput.addEventListener('click', (e) => {
  e.stopPropagation();
});

modelSearchInput.addEventListener('input', () => {
  filterModels(modelSearchInput.value.trim().toLowerCase());
});

function filterModels(query) {
  const options = modelOptionsList.getElementsByClassName('custom-dropdown-option');
  for (let opt of options) {
    const text = opt.textContent.toLowerCase();
    if (text.includes(query)) {
      opt.style.display = '';
    } else {
      opt.style.display = 'none';
    }
  }
}

function toggleProviderDropdown() {
  if (providerDropdownWrapper.classList.contains('disabled')) return;
  setDropdownOpen(modelDropdownWrapper, modelDropdownTrigger, false);
  const open = !providerDropdownWrapper.classList.contains('open');
  setDropdownOpen(providerDropdownWrapper, providerDropdownTrigger, open);
  if (open) {
    const selected = providerOptionsList.querySelector('[aria-pressed="true"]');
    const first = providerOptionsList.querySelector('button');
    (selected || first)?.focus();
  }
}

providerDropdownTrigger.addEventListener('click', (e) => {
  e.stopPropagation();
  toggleProviderDropdown();
});

providerDropdownTrigger.addEventListener('keydown', (e) => {
  if (e.key !== 'Enter' && e.key !== ' ') return;
  e.preventDefault();
  e.stopPropagation();
  toggleProviderDropdown();
});

document.addEventListener('click', () => {
  closeDropdowns();
  hideSlashPopup();
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  closeDropdowns();
  hideSlashPopup();
});

function showSlashPopup(filterText) {
  filteredSlashCommands = SLASH_COMMANDS.filter(cmd =>
    cmd.name.toLowerCase().startsWith(filterText.toLowerCase())
  );

  if (filteredSlashCommands.length === 0) {
    hideSlashPopup();
    return;
  }

  const popup = document.getElementById('slash-commands-popup');
  popup.classList.remove('hidden');
  slashPopupVisible = true;
  renderSlashCommands();
}

function hideSlashPopup() {
  const popup = document.getElementById('slash-commands-popup');
  if (popup) {
    popup.classList.add('hidden');
  }
  slashPopupVisible = false;
}

function renderSlashCommands() {
  const popup = document.getElementById('slash-commands-popup');
  popup.replaceChildren();

  if (slashPopupSelectedIndex >= filteredSlashCommands.length) {
    slashPopupSelectedIndex = 0;
  }

  filteredSlashCommands.forEach((cmd, idx) => {
    const item = document.createElement('li');
    item.classList.add('slash-command-item');
    if (idx === slashPopupSelectedIndex) {
      item.classList.add('selected');
    }

    const info = document.createElement('div');
    info.className = 'slash-command-info';
    appendCommandText(info, 'slash-command-name', cmd.name);
    appendCommandText(info, 'slash-command-desc', cmd.desc);
    if (cmd.usage) appendCommandText(info, 'slash-command-usage', cmd.usage);
    if (cmd.example) appendCommandText(info, 'slash-command-example', `Example: ${cmd.example}`);
    item.appendChild(info);
    if (cmd.shortcut) appendCommandText(item, 'slash-command-shortcut', cmd.shortcut);

    item.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      insertSlashCommand(cmd.usage || cmd.name);
    });

    popup.appendChild(item);
  });
}

function appendCommandText(parent, className, text) {
  const element = document.createElement('span');
  element.className = className;
  element.textContent = String(text ?? '');
  parent.appendChild(element);
}

function insertSlashCommand(commandText) {
  setPromptText(commandText + ' ');
  hideSlashPopup();
}

function shouldRenderMessageAsMarkdown(role, text) {
  return role === 'assistant' || role === 'system' || text.includes('```');
}

function addMessage(role, text, provider, model) {
  hideTypingIndicator();
  hideWelcomeScreen();
  if (text === undefined || text === null) {
    text = '';
  }
  const info = SENDER_INFO[role] || SENDER_INFO.assistant;

  const wrapper = document.createElement('div');
  wrapper.classList.add('message-wrapper', `message-${role}`);

  const avatar = document.createElement('div');
  avatar.classList.add('message-avatar', info.avatarClass);
  if (role === 'assistant' && provider) {
    avatar.innerHTML = getProviderIcon(provider);
    avatar.classList.add('provider-avatar-badge');
  } else {
    avatar.innerHTML = info.icon;
  }

  const body = document.createElement('div');
  body.classList.add('message-body');

  const header = document.createElement('div');
  header.classList.add('message-header', info.headerClass);
  let headerText = info.name;
  if (role === 'assistant' && provider && model) {
    headerText += ` - ${provider} (${model})`;
  }
  header.textContent = headerText;
  if (role === 'assistant') {
    decorateAssistantRoute(wrapper, avatar, header);
  }
  if (role === 'assistant' || role === 'system') {
    header.appendChild(createTextCopyButton(
      () => text,
      'Copy response',
      'message-copy-button'
    ));
  }

  const content = document.createElement('div');
  content.classList.add('message-content');

  if (shouldRenderMessageAsMarkdown(role, text)) {
    content.innerHTML = marked.parse(text);
    processProjectFiles(content);
  } else {
    const p = document.createElement('p');
    p.textContent = text;
    content.appendChild(p);
  }

  body.appendChild(header);
  body.appendChild(content);
  wrapper.appendChild(avatar);
  wrapper.appendChild(body);

  chatContainer.appendChild(wrapper);

  if (role === 'assistant') {
    createResponseTechnicalSummary(wrapper, provider, model);
    activeResponseContext = null;
  }

  setTimeout(() => {
    Prism.highlightAllUnder(wrapper);
  }, 10);

  chatContainer.scrollTop = chatContainer.scrollHeight;

  return wrapper;
}

function clearChat() {
  chatContainer.innerHTML = '';
  welcomeScreen = null;
  currentAssistantWrapper = null;
  currentAssistantContent = null;
  currentAssistantText = '';
  clearCollectedProblems();
  showWelcomeScreen();
}

function applyThemeVariables(themeInfo) {
  const root = document.documentElement;
  if (themeInfo.bgBase) root.style.setProperty('--bg-base', themeInfo.bgBase);
  if (themeInfo.bgPanel) root.style.setProperty('--bg-panel', themeInfo.bgPanel);
  if (themeInfo.bgInput) root.style.setProperty('--bg-input', themeInfo.bgInput);
  if (themeInfo.fgPrimary) root.style.setProperty('--fg-primary', themeInfo.fgPrimary);
  if (themeInfo.bgElevated) root.style.setProperty('--bg-elevated', themeInfo.bgElevated);
  if (themeInfo.fgSecondary) root.style.setProperty('--fg-secondary', themeInfo.fgSecondary);
  if (themeInfo.border) root.style.setProperty('--border', themeInfo.border);
  if (themeInfo.accent) root.style.setProperty('--accent', themeInfo.accent);
  if (themeInfo.codeBg) root.style.setProperty('--code-bg', themeInfo.codeBg);
  if (themeInfo.codeHeader) root.style.setProperty('--code-header', themeInfo.codeHeader);
  if (themeInfo.greenApply) root.style.setProperty('--green-apply', themeInfo.greenApply);
}

function setTheme(themeInfo) {
  if (!themeInfo) return;

  if (typeof themeInfo === 'string') {
    const lowerTheme = themeInfo.toLowerCase();
    const themeName = lowerTheme.includes('dark') ? 'dark' : 'light';
    document.body.className = themeName + '-theme';
    updateChatScrollbar();
    return;
  }

  const themeName = themeInfo.theme === 'dark' ? 'dark' : 'light';
  document.body.className = themeName + '-theme';

  applyThemeVariables(themeInfo);
  updateChatScrollbar();
}

function copyCode(btn, id) {
  const code = _codeRegistry[id] || '';
  copyTextWithFeedback(btn, code);
}

function applyCode(id) {
  const code = _codeRegistry[id] || '';
  postMessageToDelphi({ action: 'insert_code', code: code });
}

function renderTokenStats(text) {
  const parts = String(text || '')
    .split('\u00B7')
    .map(part => part.trim())
    .filter(Boolean);

  statusText.innerHTML = '';

  parts.forEach((part, index) => {
    let labelText = '';
    let valueText = '';
    const lastSpaceIdx = part.lastIndexOf(' ');

    if (lastSpaceIdx !== -1) {
      const potentialValue = part.slice(lastSpaceIdx + 1);
      if (/^[0-9.,]+%?$/.test(potentialValue)) {
        labelText = part.slice(0, lastSpaceIdx).trim();
        valueText = potentialValue;
      }
    }

    const item = document.createElement('span');
    item.className = 'token-stat';

    if (valueText) {
      const label = document.createElement('span');
      label.className = 'token-stat-label';
      label.textContent = labelText;

      const value = document.createElement('span');
      value.className = 'token-stat-value';
      value.textContent = valueText;

      item.appendChild(label);
      item.appendChild(value);
    } else {
      item.textContent = part;
    }

    if (index > 0) {
      const separator = document.createElement('span');
      separator.className = 'token-stat-separator';
      separator.textContent = '\u00B7';
      statusText.appendChild(separator);
    }

    statusText.appendChild(item);
  });
}

function updateTokens(text) {
  if (text) {
    renderTokenStats(text);
    statusBar.classList.remove('hidden');
  } else {
    statusText.innerHTML = '';
    statusBar.classList.add('hidden');
  }
}

function showTransientStatus(text) {
  statusText.textContent = text;
  statusBar.classList.remove('hidden');
  globalThis.clearTimeout(showTransientStatus._timer);
  showTransientStatus._timer = globalThis.setTimeout(() => {
    if (statusText.textContent === text) {
      statusBar.classList.add('hidden');
    }
  }, 3000);
}

let typingIndicatorEl = null;
let typingTimerInterval = null;
let typingStartTime = 0;

function showTypingIndicator() {
  if (typingIndicatorEl) return;

  hideWelcomeScreen();
  const info = SENDER_INFO.assistant;
  const wrapper = document.createElement('div');
  wrapper.classList.add('typing-wrapper');

  const avatar = document.createElement('div');
  avatar.classList.add('message-avatar', info.avatarClass);
  decorateExecutionAvatar(avatar);

  const indicator = document.createElement('div');
  indicator.classList.add('typing-indicator-modern');
  indicator.innerHTML = `
    <div class="typing-header">
      <div class="typing-sparkle-container">
        <svg class="typing-sparkle-icon" viewBox="0 0 24 24">
          <path d="M12 2L14.7 9.3L22 12L14.7 14.7L12 22L9.3 14.7L2 12L9.3 9.3L12 2Z" fill="currentColor"/>
        </svg>
      </div>
      <span class="typing-status-text">Preparing response…</span>
      <span class="typing-timer">0.0s</span>
    </div>
    <div class="typing-skeleton">
      <div class="skeleton-line skeleton-short"></div>
      <div class="skeleton-line"></div>
      <div class="skeleton-line skeleton-medium"></div>
    </div>
  `;

  wrapper.appendChild(avatar);
  wrapper.appendChild(indicator);
  chatContainer.appendChild(wrapper);
  chatContainer.scrollTop = chatContainer.scrollHeight;
  typingIndicatorEl = wrapper;

  // Start real-time timer
  typingStartTime = Date.now();
  const timerEl = indicator.querySelector('.typing-timer');
  typingTimerInterval = setInterval(() => {
    if (timerEl) {
      const elapsed = ((Date.now() - typingStartTime) / 1000).toFixed(1);
      timerEl.textContent = `${elapsed}s`;
    }
  }, 100);
}

function updateActiveExecutionStage(text) {
  const status = typingIndicatorEl?.querySelector('.typing-status-text');
  if (status) status.textContent = text;
}

function hideTypingIndicator() {
  if (typingTimerInterval) {
    clearInterval(typingTimerInterval);
    typingTimerInterval = null;
  }
  if (typingIndicatorEl) {
    typingIndicatorEl.remove();
    typingIndicatorEl = null;
  }
}

let currentAssistantWrapper = null;
let currentAssistantContent = null;
let currentAssistantText    = '';

function appendMessage(text, isDone, provider, model) {
  hideTypingIndicator();
  hideWelcomeScreen();

  if (text === undefined || text === null) {
    text = '';
  }

  if (!currentAssistantWrapper) {
    if (isDone && text === '') {
      return;
    }

    const info = SENDER_INFO.assistant;
    currentAssistantWrapper = document.createElement('div');
    currentAssistantWrapper.classList.add('message-wrapper', 'message-assistant');
    currentAssistantWrapper.dataset.responseStartedAt = String(activeResponseContext?.startedAt || Date.now());

    const avatar = document.createElement('div');
    avatar.classList.add('message-avatar', info.avatarClass);
    if (provider) {
      avatar.innerHTML = getProviderIcon(provider);
      avatar.classList.add('provider-avatar-badge');
    } else {
      avatar.innerHTML = info.icon;
    }

    const body = document.createElement('div');
    body.classList.add('message-body');

    const header = document.createElement('div');
    header.classList.add('message-header', info.headerClass);
    let headerText = info.name;
    if (provider && model) {
      headerText += ` - ${provider} (${model})`;
    }
    header.textContent = headerText;
    decorateAssistantRoute(currentAssistantWrapper, avatar, header);
    header.appendChild(createTextCopyButton(
      () => currentAssistantWrapper?.dataset.copyText || '',
      'Copy response',
      'message-copy-button'
    ));

    currentAssistantContent = document.createElement('div');
    currentAssistantContent.classList.add('message-content');

    body.appendChild(header);
    body.appendChild(currentAssistantContent);
    currentAssistantWrapper.appendChild(avatar);
    currentAssistantWrapper.appendChild(body);
    chatContainer.appendChild(currentAssistantWrapper);
  }

  currentAssistantText += text;
  currentAssistantWrapper.dataset.copyText = currentAssistantText;
  currentAssistantContent.innerHTML = marked.parse(currentAssistantText);

  Prism.highlightAllUnder(currentAssistantContent);

  chatContainer.scrollTop = chatContainer.scrollHeight;

  if (isDone) {
    processProjectFiles(currentAssistantContent);
    createResponseTechnicalSummary(currentAssistantWrapper, provider, model);
    activeResponseContext = null;
    currentAssistantWrapper = null;
    currentAssistantContent  = null;
    currentAssistantText     = '';
  }
}

function processProjectFiles(contentElement) {
  if (!contentElement) return;

  const fileBlocks = contentElement.querySelectorAll('.code-block-container[data-project-file="true"]');
  if (fileBlocks.length === 0) return;

  if (contentElement.querySelector('.radia-project-panel')) return;

  const projectPanel = document.createElement('div');
  projectPanel.className = 'radia-project-panel';

  const header = document.createElement('div');
  header.className = 'radia-project-header';
  header.innerHTML = `
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" stroke-width="2.2" stroke-linecap="round"
      stroke-linejoin="round" style="color: var(--accent);">
      <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path>
    </svg>
    <span>PROJETO DELPHI GERADO</span>
  `;
  projectPanel.appendChild(header);

  const filesList = document.createElement('div');
  filesList.className = 'radia-project-files-list';

  fileBlocks.forEach((block) => {
    const filepath = block.dataset.filepath;
    const safeDisplayPath = escapeHtml(filepath);
    const ext = filepath.split('.').pop().toLowerCase();
    const copyBtn = block.querySelector('.copy-btn');
    if (!copyBtn) return;
    const onclickAttr = copyBtn.getAttribute('onclick') || '';
    const onclickMatch = onclickAttr.match(/'([^']+)'/);
    const blockId = onclickMatch ? onclickMatch[1] : '';

    let iconColor = 'var(--fg-secondary)';
    let fileIconSvg = `
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round"
        stroke-linejoin="round">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
        <polyline points="14 2 14 8 20 8"></polyline>
      </svg>
    `;

    if (ext === 'dpr' || ext === 'dproj') {
      iconColor = 'var(--accent)';
      fileIconSvg = `
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
          stroke="${iconColor}" stroke-width="2.5" stroke-linecap="round"
          stroke-linejoin="round">
          <polyline points="16 18 22 12 16 6"></polyline>
          <polyline points="8 6 2 12 8 18"></polyline>
        </svg>
      `;
    } else if (ext === 'pas') {
      iconColor = '#4caf50';
      fileIconSvg = `
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
          stroke="${iconColor}" stroke-width="2" stroke-linecap="round"
          stroke-linejoin="round">
          <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"></path>
          <polyline points="14 2 14 8 20 8"></polyline>
        </svg>
      `;
    } else if (ext === 'dfm') {
      iconColor = '#ff9800';
      fileIconSvg = `
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
          stroke="${iconColor}" stroke-width="2" stroke-linecap="round"
          stroke-linejoin="round">
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
          <line x1="9" y1="3" x2="9" y2="21"></line>
        </svg>
      `;
    }

    const item = document.createElement('div');
    item.className = 'radia-project-file-item';
    item.innerHTML = `
      <div class="file-item-info">
        <span class="file-item-icon" style="color: ${iconColor};">${fileIconSvg}</span>
        <span class="file-item-name" title="${safeDisplayPath}">${safeDisplayPath}</span>
      </div>
      <div class="file-item-actions">
        <button class="file-item-btn" title="View file code" onclick="scrollToBlock('${blockId}')">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round"
            stroke-linejoin="round">
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
            <circle cx="12" cy="12" r="3"></circle>
          </svg>
        </button>
      </div>
    `;
    filesList.appendChild(item);
  });
  projectPanel.appendChild(filesList);

  const actionBtn = document.createElement('button');
  actionBtn.className = 'radia-project-action-btn';
  actionBtn.title = 'Create the reviewed project files on disk and open the project in Delphi';
  actionBtn.innerHTML = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" stroke-width="2" stroke-linecap="round"
      stroke-linejoin="round"
      style="margin-right: 6px; display: inline-block; vertical-align: middle;">
      <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path>
      <polyline points="17 21 17 13 7 13 7 21"></polyline>
      <polyline points="7 3 7 8 15 8"></polyline>
    </svg>
    <span>Criar Projeto e Abrir na IDE</span>
  `;

  actionBtn.addEventListener('click', () => {
    const filesData = [];
    fileBlocks.forEach(block => {
      const filepath = block.dataset.filepath;
      const codeEl = block.querySelector('code');
      const content = codeEl ? codeEl.textContent : '';
      filesData.push({ path: filepath, content: content });
    });

    actionBtn.disabled = true;
    actionBtn.querySelector('span').textContent = 'Processando no Delphi...';

    postMessageToDelphi({
      action: 'create_project',
      files: filesData
    });

    setTimeout(() => {
      actionBtn.disabled = false;
      actionBtn.querySelector('span').textContent = 'Criar Projeto e Abrir na IDE';
    }, 4000);
  });

  projectPanel.appendChild(actionBtn);
  contentElement.appendChild(projectPanel);
}

function scrollToBlock(blockId) {
  const codeRegistryKey = Object.keys(_codeRegistry).find(key => key === blockId);
  if (codeRegistryKey) {
    const copyButton = document.querySelector(`button[onclick*="${blockId}"]`);
    if (copyButton) {
      const container = copyButton.closest('.code-block-container');
      if (container) {
        container.scrollIntoView({ behavior: 'smooth', block: 'center' });
        container.classList.add('highlight-flash');
        setTimeout(() => {
          container.classList.remove('highlight-flash');
        }, 1500);
      }
    }
  }
}

function initializeConfig(data) {
  selectProvider.innerHTML = '';
  providerOptionsList.innerHTML = '';

  let activeText = 'Provider...';
  let activeIcon = '';

  data.providers.forEach(p => {
    const opt = document.createElement('option');
    opt.value = p.value;
    opt.textContent = p.name;
    if (p.value === data.activeProvider) {
      opt.selected = true;
      activeText = p.name;
      activeIcon = getProviderIcon(p.value);
    }
    selectProvider.appendChild(opt);

    const div = document.createElement('button');
    div.type = 'button';
    div.classList.add('custom-dropdown-option');
    div.setAttribute('aria-pressed', String(p.value === data.activeProvider));
    if (p.value === data.activeProvider) {
      div.classList.add('selected');
    }

    const iconSpan = document.createElement('span');
    iconSpan.className = 'provider-opt-icon';
    iconSpan.innerHTML = getProviderIcon(p.value);

    const textSpan = document.createElement('span');
    textSpan.textContent = p.name;

    div.appendChild(iconSpan);
    div.appendChild(textSpan);

    div.addEventListener('click', () => {
      const prevSelected = providerOptionsList.querySelector('.custom-dropdown-option.selected');
      if (prevSelected) prevSelected.classList.remove('selected');
      if (prevSelected) prevSelected.setAttribute('aria-pressed', 'false');

      div.classList.add('selected');
      div.setAttribute('aria-pressed', 'true');
      selectProvider.value = p.value;
      selectProvider.dispatchEvent(new Event('change'));

      renderProviderDropdownValue(getProviderIcon(p.value), p.name);
      setDropdownOpen(providerDropdownWrapper, providerDropdownTrigger, false);
      providerDropdownTrigger.focus();
    });
    div.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter' && e.key !== ' ') return;
      e.preventDefault();
      div.click();
    });

    const listItem = document.createElement('li');
    listItem.appendChild(div);
    providerOptionsList.appendChild(listItem);
  });

  renderProviderDropdownValue(activeIcon, activeText);

  updateModelsList(data.models, data.activeModel, data.modelSelectionEnabled !== false);
  AVAILABLE_TOOLS = Array.isArray(data.tools) ? data.tools : [];
  setAgentMode(data.agentModeEnabled);
  updateExecutionRoute(data.executionRoute);
  updateEffortSelection(data.reasoningEffort || 'medium');

  if (data.slashCommands && Array.isArray(data.slashCommands)) {
    const baseCommands = [
      { name: '/template', desc: 'Opens the prompt templates library', shortcut: '' },
      { name: '/refactor', desc: 'Optimizes and refactors the selected code', shortcut: '' },
      { name: '/optimize', desc: 'Performs performance analysis and optimizations', shortcut: '' },
      { name: '/review', desc: 'Performs static analysis on the active unit (leaks/SOLID)', shortcut: '' }
    ];

    SLASH_COMMANDS = [...baseCommands];
    data.slashCommands.forEach(cmd => {
      const commandName = cmd.command.toLowerCase();
      SLASH_COMMANDS = SLASH_COMMANDS.filter(c => c.name.toLowerCase() !== commandName);

      SLASH_COMMANDS.push({
        name: cmd.command,
        desc: cmd.description || cmd.name,
        usage: cmd.usage || '',
        example: cmd.example || '',
        shortcut: ''
      });
    });
  }


}

function renderProviderDropdownValue(iconHtml, providerName) {
  providerDropdownValue.replaceChildren();
  if (iconHtml) {
    const icon = document.createElement('span');
    icon.innerHTML = iconHtml;
    providerDropdownValue.appendChild(icon);
  }
  const name = document.createElement('span');
  name.textContent = String(providerName ?? '');
  providerDropdownValue.appendChild(name);
}

function applyModelSelectionState() {
  const enabled = modelSelectionEnabled && !requestInProgress;
  selectModel.disabled = !enabled;
  modelDropdownWrapper.classList.toggle('disabled', !enabled);
  modelDropdownTrigger.setAttribute('aria-disabled', String(!enabled));
  modelDropdownTrigger.title = modelSelectionEnabled
    ? 'Select AI model'
    : modelDropdownValue.textContent;
}

function updateModelsList(models, activeModel, enabled = true) {
  modelSelectionEnabled = enabled;
  selectModel.innerHTML = '';

  if (!models || models.length === 0) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = 'No models available';
    selectModel.appendChild(opt);

    modelDropdownValue.textContent = 'No models available';
    modelOptionsList.innerHTML = '<li class="no-sessions">No models available</li>';
    applyModelSelectionState();
    updateComposerRoute();
    return;
  }

  modelOptionsList.innerHTML = '';

  models.forEach(m => {
    const opt = document.createElement('option');
    opt.value = m;
    opt.textContent = m;
    if (m === activeModel) {
      opt.selected = true;
    }
    selectModel.appendChild(opt);

    const div = document.createElement('button');
    div.type = 'button';
    div.classList.add('custom-dropdown-option');
    div.setAttribute('aria-pressed', String(m === activeModel));
    if (m === activeModel) {
      div.classList.add('selected');
      modelDropdownValue.textContent = m;
    }
    div.textContent = m;

    div.addEventListener('click', (e) => {
      e.stopPropagation();

      const selectedOpt = modelOptionsList.querySelector('.custom-dropdown-option.selected');
      if (selectedOpt) selectedOpt.classList.remove('selected');
      if (selectedOpt) selectedOpt.setAttribute('aria-pressed', 'false');
      div.classList.add('selected');
      div.setAttribute('aria-pressed', 'true');

      modelDropdownValue.textContent = m;
      selectModel.value = m;
      setDropdownOpen(modelDropdownWrapper, modelDropdownTrigger, false);

      selectModel.dispatchEvent(new Event('change'));
    });
    div.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter' && e.key !== ' ') return;
      e.preventDefault();
      div.click();
      modelDropdownTrigger.focus();
    });

    const listItem = document.createElement('li');
    listItem.appendChild(div);
    modelOptionsList.appendChild(listItem);
  });

  if (!activeModel && models.length > 0) {
    modelDropdownValue.textContent = 'Select model...';
  }
  applyModelSelectionState();
  updateComposerRoute();
}

function setRequestState(inProgress) {
  console.log('[DEBUG] setRequestState called with:', inProgress);
  requestInProgress = inProgress;
  if (inProgress) {
    activeResponseContext = {
      route: { ...activeExecutionRoute },
      startedAt: Date.now(),
      tools: new Set()
    };
  }
  updateSessionControlsState();
  if (inProgress) {
    btnSendPrompt.classList.add('stop-btn');
    btnSendPrompt.title = 'Cancel request';
    btnSendPrompt.setAttribute('aria-label', 'Cancel request');
    selectProvider.disabled = true;
    providerDropdownWrapper.classList.add('disabled');
    providerDropdownTrigger.setAttribute('aria-disabled', 'true');
    btnQueuePrompt.classList.remove('hidden');
    promptTextarea.placeholder = 'Add a follow-up, then select +1 to queue it...';
  } else {
    btnSendPrompt.classList.remove('stop-btn');
    btnSendPrompt.title = 'Send message (Ctrl+Enter)';
    btnSendPrompt.setAttribute('aria-label', 'Send message');
    selectProvider.disabled = false;
    providerDropdownWrapper.classList.remove('disabled');
    providerDropdownTrigger.setAttribute('aria-disabled', 'false');
    btnQueuePrompt.classList.add('hidden');
    promptTextarea.placeholder = 'Ask Rad IA or type / for commands...';
  }
  applyModelSelectionState();
  executionRouteSelector.disabled = inProgress;
  updateComposerRoute();
  if (!inProgress) setTimeout(dispatchNextQueuedPrompt, 0);
}

function setContextText(text) {
  if (text?.trim()) {
    contextText.innerText = text;
    contextBar.classList.remove('hidden');
  } else {
    contextBar.classList.add('hidden');
  }
}

function updateSessions(sessions, activeSessionId) {
  if (activeSessionId && currentProblemSessionId &&
      activeSessionId !== currentProblemSessionId) {
    clearCollectedProblems();
  }
  if (activeSessionId) currentProblemSessionId = activeSessionId;
  sessionsList.innerHTML = '';

  if (!sessions || sessions.length === 0) {
    sessionsList.innerHTML = `<li class="no-sessions">No conversations active</li>`;
    return;
  }

  sessions.forEach(session => {
    const item = document.createElement('li');
    item.classList.add('session-item');
    if (session.id === activeSessionId) {
      item.classList.add('active');
    }

    const nameEl = document.createElement('span');
    nameEl.classList.add('session-name');
    nameEl.textContent = session.name;

    nameEl.addEventListener('dblclick', () => startRename(item, session.id, nameEl));

    const actions = document.createElement('div');
    actions.classList.add('session-item-actions');

    const btnRename = document.createElement('button');
    btnRename.classList.add('session-action-btn');
    btnRename.disabled = requestInProgress;
    btnRename.title = "Rename Conversation";
    btnRename.setAttribute('aria-label', `Rename conversation ${session.name}`);
    btnRename.innerHTML = SVG_ICONS.edit;
    btnRename.addEventListener('click', (e) => {
      e.stopPropagation();
      if (!canChangeSession()) {
        showSessionLockedStatus();
        return;
      }
      startRename(item, session.id, nameEl);
    });

    const btnDelete = document.createElement('button');
    btnDelete.classList.add('session-action-btn', 'delete-btn');
    btnDelete.disabled = requestInProgress;
    btnDelete.title = "Delete Conversation";
    btnDelete.setAttribute('aria-label', `Delete conversation ${session.name}`);
    btnDelete.innerHTML = SVG_ICONS.trash;
    btnDelete.addEventListener('click', (e) => {
      e.stopPropagation();
      if (!canChangeSession()) {
        showSessionLockedStatus();
        return;
      }
      if (confirm(`Delete conversation "${session.name}"?`)) {
        postMessageToDelphi({ action: 'delete_session', id: session.id });
      }
    });

    actions.appendChild(btnRename);
    actions.appendChild(btnDelete);

    item.appendChild(nameEl);
    item.appendChild(actions);

    item.addEventListener('click', () => {
      if (item.classList.contains('renaming')) return;
      if (!canChangeSession()) {
        showSessionLockedStatus();
        return;
      }
      showTab('chat');
      postMessageToDelphi({ action: 'select_session', id: session.id });
    });

    sessionsList.appendChild(item);
  });

  updateSessionControlsState();
}

function startRename(item, sessionId, nameEl) {
  if (!canChangeSession()) {
    showSessionLockedStatus();
    return;
  }

  item.classList.add('renaming');
  const currentName = nameEl.textContent;

  const input = document.createElement('input');
  input.type = 'text';
  input.classList.add('session-rename-input');
  input.value = currentName;

  nameEl.style.display = 'none';
  nameEl.before(input);
  input.focus();
  input.select();

  function saveRename() {
    const newName = input.value.trim();
    if (newName && newName !== currentName && canChangeSession()) {
      postMessageToDelphi({ action: 'rename_session', id: sessionId, name: newName });
    }
    cleanup();
  }

  function cleanup() {
    input.remove();
    nameEl.style.display = '';
    item.classList.remove('renaming');
  }

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      saveRename();
    } else if (e.key === 'Escape') {
      cleanup();
    }
  });

  input.addEventListener('blur', saveRename);
}

function appendGeneratorCode(text, isDone) {
  if (text === undefined || text === null) text = '';

  if (generatorAccumulatedCode === '' && text !== '') {
    generatorPreviewCard.classList.remove('hidden');
    generatorOutputCode.textContent = '';
  }

  generatorAccumulatedCode += text;
  generatorOutputCode.textContent = generatorAccumulatedCode;

  if (isDone) {
    try {
      Prism.highlightElement(generatorOutputCode);
    } catch {
    }
    btnGenerateModel.disabled = false;
    btnGenerateModel.textContent = 'Generate Model';
  }
}

function updateMessage(text, isDone, provider, model) {
  hideTypingIndicator();
  hideWelcomeScreen();
  if (text === undefined || text === null) text = '';

  if (!currentAssistantWrapper) {
    const info = SENDER_INFO.assistant;
    currentAssistantWrapper = document.createElement('div');
    currentAssistantWrapper.classList.add('message-wrapper', 'message-assistant');
    currentAssistantWrapper.dataset.responseStartedAt = String(activeResponseContext?.startedAt || Date.now());

    const avatar = document.createElement('div');
    avatar.classList.add('message-avatar', info.avatarClass);
    if (provider) {
      avatar.innerHTML = getProviderIcon(provider);
      avatar.classList.add('provider-avatar-badge');
    } else {
      avatar.innerHTML = info.icon;
    }

    const body = document.createElement('div');
    body.classList.add('message-body');

    const header = document.createElement('div');
    header.classList.add('message-header', info.headerClass);
    let headerText = info.name;
    if (provider && model) {
      headerText += ` - ${provider} (${model})`;
    }
    header.textContent = headerText;
    decorateAssistantRoute(currentAssistantWrapper, avatar, header);
    header.appendChild(createTextCopyButton(
      () => currentAssistantWrapper?.dataset.copyText || '',
      'Copy response',
      'message-copy-button'
    ));

    currentAssistantContent = document.createElement('div');
    currentAssistantContent.classList.add('message-content');

    body.appendChild(header);
    body.appendChild(currentAssistantContent);
    currentAssistantWrapper.appendChild(avatar);
    currentAssistantWrapper.appendChild(body);
    chatContainer.appendChild(currentAssistantWrapper);
  }

  currentAssistantText = text;
  currentAssistantWrapper.dataset.copyText = currentAssistantText;
  currentAssistantContent.innerHTML = marked.parse(currentAssistantText);
  Prism.highlightAllUnder(currentAssistantContent);
  chatContainer.scrollTop = chatContainer.scrollHeight;

  if (isDone) {
    processProjectFiles(currentAssistantContent);
    createResponseTechnicalSummary(currentAssistantWrapper, provider, model);
    activeResponseContext = null;
    currentAssistantWrapper = null;
    currentAssistantContent  = null;
    currentAssistantText     = '';
  }
}

if (globalThis.chrome?.webview) {
  // globalThis.chrome.webview.addEventListener is a secure host-to-web channel.
  // event.origin is not present here as messages originate directly from the host Delphi process (bds.exe).
  globalThis.chrome.webview.addEventListener('message', event => {
    if (event.origin && event.origin !== '' && !event.origin.startsWith('file://')) {
      return;
    }
    const data = event.data;
    console.log('[DEBUG] Received message from Delphi:', data);
    switch (data.action) {
      case 'add_message':           addMessage(data.role, data.text, data.provider, data.model); break;
      case 'update_message':        updateMessage(data.text, data.isDone, data.provider, data.model); break;
      case 'clear_chat':            clearChat();                                                 break;
      case 'set_theme':             setTheme(data);                                              break;
      case 'update_tokens':         updateTokens(data.text);                                     break;
      case 'show_typing':           showTypingIndicator();                                       break;
      case 'hide_typing':           hideTypingIndicator();                                       break;
      case 'append_message':        appendMessage(data.text, data.isDone, data.provider, data.model); break;
      case 'initialize_config':     initializeConfig(data);                                      break;
      case 'update_models':
        updateModelsList(data.models, data.activeModel, data.enabled !== false);
        break;
      case 'set_request_state':     setRequestState(data.inProgress);                            break;
      case 'set_context':           setContextText(data.text);                                   break;
      case 'update_sessions':       updateSessions(data.sessions, data.activeSessionId);         break;
      case 'append_generator_code': appendGeneratorCode(data.text, data.isDone);                 break;
      case 'show_tools':            showTools(data.tools);                                       break;
      case 'tool_call':             renderToolCall(data);                                        break;
      case 'tool_result':           renderToolResult(data);                                      break;
      case 'chat_preflight':        renderChatPreflight(data);                                   break;
      case 'agent_mode_changed':    setAgentMode(data.enabled);                                  break;
      case 'execution_route':       updateExecutionRoute(data);                                  break;
      case 'execution_scope':       updateExecutionScope(data);                                  break;
      case 'agent_state':           renderAgentState(data);                                      break;
      case 'agent_history':         renderAgentHistory(data);                                    break;
      case 'visual_runtime_session': renderVisualRuntimeSession(data);                           break;
      case 'cli_activity':          renderCliActivity(data);                                    break;
      case 'intent_recommendation': renderIntentRecommendation(data);                            break;
      case 'restore_lifecycle_state': restoreLifecycleState(data.state, data.smoke === true);    break;
    }
  });
  postMessageToDelphi({ action: 'ready' });
}

bindChatScrollbar();
showWelcomeScreen();

// Expose handlers to globalThis for integration and template callbacks (resolves ESLint unused-vars and Sonar globals)
globalThis.copyCode = copyCode;
globalThis.applyCode = applyCode;
globalThis.scrollToBlock = scrollToBlock;
