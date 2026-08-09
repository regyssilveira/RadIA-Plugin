const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const documentationRoot = path.join(repositoryRoot, 'docs');

function markdownFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return markdownFiles(entryPath);
    }
    return entry.isFile() && entry.name.endsWith('.md') ? [entryPath] : [];
  });
}

function headingSlug(heading) {
  return heading
    .trim()
    .toLowerCase()
    .replace(/<[^>]+>/gu, '')
    .replace(/[`*_~]/gu, '')
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/gu, '-');
}

function markdownAnchors(fileName) {
  return new Set(
    fs.readFileSync(fileName, 'utf8')
      .split(/\r?\n/gu)
      .filter(line => /^#{1,6} /u.test(line))
      .map(line => headingSlug(line.replace(/^#{1,6} /u, '')))
  );
}

const files = [
  path.join(repositoryRoot, 'README.md'),
  ...markdownFiles(documentationRoot)
];
const mojibakePattern = /[\u00c3\u00c2\ufffd]|\u00e2[\u0080-\u00bf]/u;
const markdownLinkPattern = /!?\[[^\]]*\]\((?<target>[^)]+)\)/gu;
const packageVersion = JSON.parse(
  fs.readFileSync(path.join(repositoryRoot, 'package.json'), 'utf8')
).version;

test('documentation has no common mojibake markers', () => {
  files.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    assert.doesNotMatch(content, mojibakePattern, path.relative(repositoryRoot, fileName));
  });
});

test('documentation local links resolve to existing paths', () => {
  files.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    for (const match of content.matchAll(markdownLinkPattern)) {
      let target = match.groups.target.trim();
      if (target.startsWith('<') && target.endsWith('>')) {
        target = target.slice(1, -1);
      }
      const [targetPath, fragment = ''] = target.split('#', 2);
      if (/^[a-z][a-z0-9+.-]*:/iu.test(targetPath)) {
        continue;
      }
      const resolved = targetPath
        ? path.resolve(path.dirname(fileName), decodeURIComponent(targetPath))
        : fileName;
      assert.ok(
        fs.existsSync(resolved),
        `${path.relative(repositoryRoot, fileName)} references missing path: ${targetPath}`
      );
      if (fragment && resolved.endsWith('.md')) {
        assert.ok(
          markdownAnchors(resolved).has(decodeURIComponent(fragment).toLowerCase()),
          `${path.relative(repositoryRoot, fileName)} references missing anchor: ${target}`
        );
      }
    }
  });
});

test('tracked documentation has complete Portuguese and English pairs', () => {
  const trackedMarkdown = childProcess.execFileSync(
    'git',
    ['ls-files', 'docs/*.md', 'docs/**/*.md'],
    { cwd: repositoryRoot, encoding: 'utf8' }
  ).trim().split(/\r?\n/u).filter(Boolean);
  const trackedSet = new Set(trackedMarkdown);

  trackedMarkdown.forEach(fileName => {
    const counterpart = fileName.endsWith('.en.md')
      ? fileName.replace(/\.en\.md$/u, '.md')
      : fileName.replace(/\.md$/u, '.en.md');
    assert.ok(
      trackedSet.has(counterpart) || fs.existsSync(path.join(repositoryRoot, counterpart)),
      `${fileName} is missing its language counterpart: ${counterpart}`
    );
  });
});

test('English documentation links to English counterparts when available', () => {
  const intentionalPortugueseLinks = new Set([
    'README.en.md->README.md',
    'rtk_execution_plan.en.md->rtk_execution_plan.md'
  ]);

  markdownFiles(documentationRoot)
    .filter(fileName => fileName.endsWith('.en.md'))
    .forEach(fileName => {
      const content = fs.readFileSync(fileName, 'utf8');
      for (const match of content.matchAll(markdownLinkPattern)) {
        const target = match.groups.target.trim().replace(/^<|>$/gu, '').split('#', 1)[0];
        if (!target.endsWith('.md') || /^[a-z][a-z0-9+.-]*:/iu.test(target) ||
            target.endsWith('.en.md')) {
          continue;
        }
        const resolved = path.resolve(path.dirname(fileName), decodeURIComponent(target));
        const englishCounterpart = resolved.replace(/\.md$/u, '.en.md');
        if (!fs.existsSync(englishCounterpart)) {
          continue;
        }
        const key = `${path.relative(documentationRoot, fileName)}->${target}`
          .replaceAll('\\', '/');
        assert.ok(intentionalPortugueseLinks.has(key), `${key} should use its English counterpart`);
      }
    });
});

test('every built-in tool has an operational description and activation guidance', () => {
  const manifestPath = path.join(documentationRoot, 'runtime_tools.json');
  const referencePath = path.join(documentationRoot, 'internal_tools_reference.md');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const reference = fs.readFileSync(referencePath, 'utf8');
  const documentedTools = new Map();
  const toolRowPattern = /^\| `([^`]+)` \| ([^|]+) \| ([^|]+) \|$/gmu;

  for (const match of reference.matchAll(toolRowPattern)) {
    documentedTools.set(match[1], {
      purpose: match[2].trim(),
      activation: match[3].trim()
    });
  }

  const registeredTools = manifest.groups.flatMap(group => group.tools);
  assert.equal(registeredTools.length, 130);
  assert.equal(documentedTools.size, registeredTools.length);
  registeredTools.forEach(toolName => {
    const documentation = documentedTools.get(toolName);
    assert.ok(documentation, `Missing operational documentation for ${toolName}`);
    assert.ok(documentation.purpose.length >= 20, `Purpose is too short for ${toolName}`);
    assert.ok(documentation.activation.length >= 20, `Activation guidance is too short for ${toolName}`);
  });
});

test('generated runtime tool catalogs describe every tool in both languages', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(documentationRoot, 'runtime_tools.json'), 'utf8')
  );
  const toolNames = manifest.groups.flatMap(group => group.tools);
  const catalogs = [
    {
      path: path.join(documentationRoot, 'runtime_tool_catalog.md'),
      header: '| Ferramenta | O que faz | Unit de origem |',
      forbiddenHeading: '# RadIA built-in tool catalog'
    },
    {
      path: path.join(documentationRoot, 'runtime_tool_catalog.en.md'),
      header: '| Tool | Purpose | Source unit |',
      forbiddenHeading: '# Catálogo de ferramentas internas do RadIA'
    }
  ];

  catalogs.forEach(catalog => {
    const content = fs.readFileSync(catalog.path, 'utf8');
    assert.match(content, new RegExp(catalog.header.replaceAll('|', '\\|'), 'u'));
    assert.doesNotMatch(content, new RegExp(catalog.forbiddenHeading, 'u'));
    toolNames.forEach(toolName => {
      const rowPattern = new RegExp(
        '^\\| `' + toolName + '` \\| [^|]{20,} \\| `[^`]+` \\|$',
        'mu'
      );
      assert.match(content, rowPattern, `${path.basename(catalog.path)}: ${toolName}`);
    });
  });
});

test('diagnostic commands are discoverable and clearly separated', () => {
  const commands = fs.readFileSync(
    path.join(documentationRoot, 'slash_commands.md'),
    'utf8'
  );
  const hub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');
  const englishHub = fs.readFileSync(
    path.join(documentationRoot, 'README.en.md'),
    'utf8'
  );

  assert.match(commands, /## Qual diagnóstico usar/u);
  assert.match(commands, /`\/doctor`/u);
  assert.match(commands, /`\/status`/u);
  assert.match(commands, /`\/health`/u);
  assert.match(commands, /`\/tools`/u);
  assert.match(commands, /credenciais nunca são incluídas/u);
  assert.match(hub, /slash_commands\.md#qual-diagnóstico-usar/u);
  assert.match(
    englishHub,
    /slash_commands\.en\.md#which-diagnostic-command-to-use/u
  );
});

test('scoped execution settings document precedence, safety, UI, and recovery', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'hierarchical_settings.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'hierarchical_settings.en.md'),
    'utf8'
  );
  const commands = fs.readFileSync(
    path.join(documentationRoot, 'slash_commands.md'),
    'utf8'
  );
  const hub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');

  assert.match(portuguese, /próxima solicitação;[\s\S]*sessão de chat atual;[\s\S]*projeto ativo/u);
  assert.match(portuguese, /Settings > Scope/u);
  assert.match(portuguese, /Restore all inheritance/u);
  assert.match(portuguese, /Export\s+scope\.\.\./u);
  assert.match(portuguese, /A exportação nunca é automática/u);
  assert.match(portuguese, /%APPDATA%\\RadIA\\settings\\scopes/u);
  assert.match(portuguese, /não o sobrescreve/u);
  assert.match(portuguese, /Credenciais, tokens e segredos não podem ser substituídos/u);
  assert.match(english, /Next-request overrides remain only in memory/u);
  assert.match(commands, /`\/scope <nível> inherit <campo>`/u);
  assert.match(commands, /`\/status settings`/u);
  assert.match(hub, /hierarchical_settings\.md/u);
});

test('inline completion documents dedicated FIM, fallback, and diagnostics', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'inline_completion.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'inline_completion.en.md'),
    'utf8'
  );
  [portuguese, english].forEach(document => {
    assert.match(document, /Ollama/u);
    assert.match(document, /LM Studio/u);
    assert.match(document, /api\/generate/u);
    assert.match(document, /v1\/completions/u);
    assert.match(document, /Show Inline Completion Route Status/u);
    assert.match(document, /fallback/iu);
    assert.match(document, /lat[eê]ncia|latency/iu);
  });
});

test('inline completion smoke proves acceptance, one undo, and clean rejection', () => {
  const smoke = fs.readFileSync(
    path.join(repositoryRoot, 'scripts', 'Test-RadIA.IDESmoke.ps1'),
    'utf8'
  );
  const consolidator = fs.readFileSync(
    path.join(repositoryRoot, 'scripts', 'New-RadIA.InlineCompletionEvidence.ps1'),
    'utf8'
  );
  const requiredFields = [
    'InlineCompletionPreviewClean',
    'InlineCompletionAccepted',
    'InlineCompletionSingleUndo',
    'InlineCompletionUndoRestored',
    'InlineCompletionRejectedClean'
  ];
  requiredFields.forEach(field => {
    assert.ok(smoke.includes(field), `IDE smoke is missing ${field}`);
    assert.ok(consolidator.includes(field), `Evidence gate is missing ${field}`);
  });
  assert.match(smoke, /singleUndo=True/u);
  assert.doesNotMatch(smoke, /InlineCompletionSuggestionContent/u);
});

test('block review documents every decision surface and real gutter evidence', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'block_reviews.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'block_reviews.en.md'),
    'utf8'
  );
  const smoke = fs.readFileSync(
    path.join(repositoryRoot, 'scripts', 'Test-RadIA.IDESmoke.ps1'),
    'utf8'
  );
  const actions = [
    'reviewAccept', 'reviewReject', 'reviewNext', 'reviewPrevious',
    'reviewEdit', 'reviewExplain', 'reviewApply', 'reviewClear'
  ];
  actions.forEach(action => {
    assert.ok(portuguese.includes(action), `Portuguese guide is missing ${action}`);
    assert.ok(english.includes(action), `English guide is missing ${action}`);
  });
  ['PreparePatch', 'PrepareMultiFilePatch', 'ListBlockReviews',
    'DecideBlockReview', 'ApplyBlockReviews', 'ClearBlockReviews'].forEach(tool => {
    assert.ok(portuguese.includes(tool), `Portuguese guide is missing ${tool}`);
    assert.ok(english.includes(tool), `English guide is missing ${tool}`);
  });
  assert.match(portuguese, /gutter/u);
  assert.match(portuguese, /hash da revisão-base/u);
  assert.match(english, /base-revision hash/u);
  assert.ok(smoke.includes('BlockReviewPublished'));
  assert.ok(smoke.includes('BlockReviewGutterPainted'));
  assert.ok(smoke.includes('BlockReviewKeyboardAccepted'));
  assert.ok(smoke.includes('BlockReviewMouseRejected'));
});

test('primary documentation entry points expose task-oriented navigation', () => {
  const rootReadme = fs.readFileSync(path.join(repositoryRoot, 'README.md'), 'utf8');
  const documentationHub = fs.readFileSync(
    path.join(documentationRoot, 'README.md'),
    'utf8'
  );

  assert.match(rootReadme, /\[Documentação\]\(docs\/README\.md\)/u);
  assert.match(documentationHub, /## Quero começar a usar/u);
  assert.match(documentationHub, /## Quero realizar uma tarefa/u);
  assert.match(documentationHub, /## Agente, ferramentas e segurança/u);
  assert.match(documentationHub, /## Desenvolver e contribuir/u);
  assert.match(documentationHub, /## Planejamento e histórico/u);
});

test('current user-facing documents follow the package version', () => {
  const currentDocuments = [
    path.join(documentationRoot, 'README.md'),
    path.join(documentationRoot, 'user_manual.md'),
    path.join(documentationRoot, 'capabilities.md')
  ];

  currentDocuments.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    assert.match(
      content,
      new RegExp(`RadIA ${packageVersion.replaceAll('.', '\\\.')}`),
      path.relative(repositoryRoot, fileName)
    );
  });
});

test('operational release guides do not pin obsolete artifact names', () => {
  const operationalGuides = [
    path.join(documentationRoot, 'install_config.md'),
    path.join(documentationRoot, 'visual_installer.md'),
    path.join(documentationRoot, 'install_config.en.md'),
    path.join(documentationRoot, 'visual_installer.en.md')
  ];

  operationalGuides.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    assert.doesNotMatch(
      content,
      /RadIA-v2\.0\.0-(?:Setup|Delphi)/u,
      path.relative(repositoryRoot, fileName)
    );
  });
});

test('end-user installation guidance prioritizes the visual installer', () => {
  const portugueseGuide = fs.readFileSync(
    path.join(documentationRoot, 'install_config.md'),
    'utf8'
  );
  const englishGuide = fs.readFileSync(
    path.join(documentationRoot, 'install_config.en.md'),
    'utf8'
  );

  assert.match(portugueseGuide, /RadIA-v<versão>-Setup\.exe/u);
  assert.match(englishGuide, /RadIA-v<version>-Setup\.exe/u);
  assert.match(portugueseGuide, /contribuidores/u);
  assert.match(englishGuide, /contributors/u);
  assert.doesNotMatch(portugueseGuide, /Instalação Automatizada \(PowerShell\) - Recomendada/u);
  assert.doesNotMatch(englishGuide, /Automated Installation \(PowerShell\) - Recommended/u);
  assert.doesNotMatch(portugueseGuide, /Use sempre o ZIP correspondente/u);
  assert.doesNotMatch(englishGuide, /installer bundled in the release ZIP/u);
});

test('documentation hubs expose the settings map and security guidance', () => {
  const portugueseHub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');
  const englishHub = fs.readFileSync(path.join(documentationRoot, 'README.en.md'), 'utf8');
  const portugueseManual = fs.readFileSync(path.join(documentationRoot, 'user_manual.md'), 'utf8');
  const englishManual = fs.readFileSync(path.join(documentationRoot, 'user_manual.en.md'), 'utf8');
  const settings = [
    'Providers',
    'System',
    'Templates',
    'General / Logs',
    'Security & Consent',
    'Knowledge & Embeddings',
    'Editor Assistance',
    'CLI & MCP',
    'Memory Diagnostics'
  ];

  assert.match(portugueseHub, /user_manual\.md#24-mapa-das-configurações/u);
  assert.match(englishHub, /user_manual\.en\.md#21-settings-map/u);
  settings.forEach(setting => {
    assert.ok(portugueseManual.includes(setting), `Portuguese manual is missing ${setting}`);
    assert.ok(englishManual.includes(setting), `English manual is missing ${setting}`);
  });
  assert.match(portugueseManual, /tool_security_model\.md/u);
  assert.match(englishManual, /tool_security_model\.en\.md/u);
});

test('every visible settings group has a detailed central reference', () => {
  const portugueseReference = fs.readFileSync(
    path.join(documentationRoot, 'settings_reference.md'),
    'utf8'
  );
  const englishReference = fs.readFileSync(
    path.join(documentationRoot, 'settings_reference.en.md'),
    'utf8'
  );
  const visibleOptions = [
    'API Key',
    'Temperature',
    'Max Output Tokens',
    'Timeout',
    'Auto (Smart Parameters)',
    'Inject Delphi version',
    'Prefer concise AI responses',
    'Enable logging',
    'Log Folder Path',
    'Max Log File Size',
    'Enable local token quota',
    'Consent dialog timeout',
    'Show tool arguments',
    'Revoke session permissions',
    'Enable local semantic project knowledge',
    'remote embedding provider',
    'ghost text (inline completion)',
    'RadIA shortcut profile',
    'Chat executor',
    'CLI client',
    'CLI executable override',
    'Diagnose',
    'Install/Update channel',
    'MCP client configuration',
    'RadIA MCP bridge',
    'Connect / Repair',
    'Test Handshake',
    'FastMM5 root',
    'System Prompt',
    'Slash Command',
    'Restore Defaults'
  ];

  visibleOptions.forEach(option => {
    assert.ok(portugueseReference.includes(option), `Portuguese reference is missing ${option}`);
    assert.ok(englishReference.includes(option), `English reference is missing ${option}`);
  });
  assert.match(portugueseReference, /Quando alterar|Quando usar/u);
  assert.match(portugueseReference, /Efeito e cuidados/u);
  assert.match(englishReference, /When to use/u);
  assert.match(englishReference, /Effect and care/u);
});

test('CLI and MCP guidance covers every recovery outcome', () => {
  const portugueseReference = fs.readFileSync(
    path.join(documentationRoot, 'settings_reference.md'),
    'utf8'
  );
  const englishReference = fs.readFileSync(
    path.join(documentationRoot, 'settings_reference.en.md'),
    'utf8'
  );
  const portugueseScenarios = [
    'Tudo já configurado',
    'CLI ausente',
    'Node.js/npm ausente',
    'Usuário recusa',
    'Instalação falha',
    'Instalação manual',
    'Configuração MCP inválida',
    'Primeiro MCP'
  ];
  const englishScenarios = [
    'Everything is configured',
    'CLI is missing',
    'Node.js/npm is missing',
    'User declines',
    'Installation fails',
    'Manual installation',
    'MCP configuration is invalid',
    'First MCP setup'
  ];

  portugueseScenarios.forEach(scenario => assert.ok(portugueseReference.includes(scenario)));
  englishScenarios.forEach(scenario => assert.ok(englishReference.includes(scenario)));
  assert.match(portugueseReference, /não é necessário reiniciar o Delphi/u);
  assert.match(englishReference, /does not need a restart/u);
});

test('documentation maintenance is an explicit project rule', () => {
  const agentRules = fs.readFileSync(path.join(repositoryRoot, 'AGENTS.md'), 'utf8');
  const portuguesePolicy = fs.readFileSync(
    path.join(documentationRoot, 'documentation_policy.md'),
    'utf8'
  );
  const portugueseHub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');
  const englishHub = fs.readFileSync(path.join(documentationRoot, 'README.en.md'), 'utf8');

  assert.match(agentRules, /Documentação como parte do produto/u);
  assert.match(portuguesePolicy, /Toda mudança que adicione, remova, renomeie/u);
  assert.match(portugueseHub, /settings_reference\.md/u);
  assert.match(englishHub, /settings_reference\.en\.md/u);
});

test('agent result compaction documents preservation and fallback', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'agent_result_compaction.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'agent_result_compaction.en.md'),
    'utf8'
  );

  assert.match(portuguese, /resultado\s+integral/u);
  assert.match(portuguese, /fallback automático/u);
  assert.match(english, /complete result/u);
  assert.match(english, /falls\s+back to the original JSON/u);
});

test('internal RTK plan defines measurable gates and an executable sequence', () => {
  const plan = fs.readFileSync(
    path.join(documentationRoot, 'rtk_execution_plan.md'),
    'utf8'
  );
  const hub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');

  ['Fase 0', 'Fase 1', 'Fase 2', 'Fase 3', 'Fase 4', 'Fase 5', 'Fase 6', 'Fase 7']
    .forEach(phase => assert.ok(plan.includes(phase), `RTK plan is missing ${phase}`));
  assert.match(plan, /Redução mediana de pelo menos 30%/u);
  assert.match(plan, /GetToolResultRange/u);
  assert.match(plan, /RTK-001/u);
  assert.match(plan, /Gate F6 — viabilidade/u);
  assert.match(hub, /rtk_execution_plan\.md/u);
});
