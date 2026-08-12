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
  path.join(repositoryRoot, 'README.en.md'),
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
  ).trim().split(/\r?\n/u).filter(Boolean).filter(fileName => (
    fs.existsSync(path.join(repositoryRoot, fileName))
  ));
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

  [path.join(repositoryRoot, 'README.en.md'), ...markdownFiles(documentationRoot)
    .filter(fileName => fileName.endsWith('.en.md'))]
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
        const relativeSource = path.relative(documentationRoot, fileName).replaceAll('..\\', '');
        const key = `${relativeSource}->${target}`
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
  assert.equal(registeredTools.length, 148);
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

test('tracked documentation uses portable repository-relative links', () => {
  files.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    assert.doesNotMatch(
      content,
      /\]\(file:\/\/\//iu,
      `${path.relative(repositoryRoot, fileName)} contains a machine-specific file URI`
    );
  });
});

test('tracked textual documentation contains no competitor product references', () => {
  const trackedMarkdown = childProcess.execFileSync(
    'git',
    ['ls-files', 'README.md', 'README.en.md', 'docs/*.md', 'docs/**/*.md'],
    { cwd: repositoryRoot, encoding: 'utf8' }
  ).trim().split(/\r?\n/u).filter(Boolean).filter(fileName => (
    fs.existsSync(path.join(repositoryRoot, fileName))
  ));
  const forbiddenProducts = /aefos|(^|[^\p{L}\p{N}_])kai([^\p{L}\p{N}_]|$)/iu;

  trackedMarkdown.forEach(fileName => {
    const content = fs.readFileSync(path.join(repositoryRoot, fileName), 'utf8');
    assert.doesNotMatch(content, forbiddenProducts, fileName);
  });
});

test('every native slash command is explained in both command guides', () => {
  const portuguese = fs.readFileSync(path.join(documentationRoot, 'slash_commands.md'), 'utf8');
  const english = fs.readFileSync(path.join(documentationRoot, 'slash_commands.en.md'), 'utf8');
  const nativeCommands = [
    '/agent', '/agent run', '/agent plan', '/agent replay', '/agent pause', '/agent resume',
    '/agent cancel', '/agent history', '/help', '/terminal', '/settings', '/extensions',
    '/health', '/doctor', '/status', '/tools', '/revoke-tools', '/cli session', '/cli new',
    '/context', '/context new', '/context detach', '/context switch', '/scope', '/tool',
    '/extensions reload', '/journey', '/journey cancel'
  ];

  nativeCommands.forEach(command => {
    const escapedCommand = command.replaceAll(/[.*+?^${}()|[\]\\]/gu, '\\$&');
    const pattern = new RegExp('`' + escapedCommand + '(?:[ `])', 'u');
    assert.match(portuguese, pattern, `slash_commands.md: ${command}`);
    assert.match(english, pattern, `slash_commands.en.md: ${command}`);
  });
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
    assert.match(document, /Show Semantic Editor Context/u);
    assert.match(document, /fallback/iu);
    assert.match(document, /lat[eê]ncia|latency/iu);
    assert.match(document, /completionNext/u);
    assert.match(document, /completionPrevious/u);
    assert.match(document, /painel de alternativas|alternatives panel/iu);
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
    'InlineCompletionRejectedClean',
    'InlineCompletionAlternativesPainted',
    'InlineCompletionAlternativeCount'
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

test('every operational guide is reachable from a documentation hub', () => {
  const tracked = childProcess.execFileSync(
    'git',
    ['ls-files', 'docs/*.md', 'docs/**/*.md'],
    { cwd: repositoryRoot, encoding: 'utf8' }
  ).trim().split(/\r?\n/u).filter(Boolean).map(fileName => fileName.replaceAll('\\', '/'))
    .filter(fileName => fs.existsSync(path.join(repositoryRoot, fileName)));
  const trackedSet = new Set(tracked);
  const linksByFile = new Map();
  const historicalName = /(?:^docs\/adr\/|roadmap|backlog|goal|audit|checklist|migration|strategy|prioritization|_m\d+|_plan)/iu;

  tracked.forEach(fileName => {
    const links = [];
    const content = fs.readFileSync(path.join(repositoryRoot, fileName), 'utf8');
    for (const match of content.matchAll(markdownLinkPattern)) {
      const target = match.groups.target.trim().replace(/^<|>$/gu, '').split('#', 1)[0];
      if (!target || /^[a-z][a-z0-9+.-]*:/iu.test(target)) continue;
      const resolved = path.relative(
        repositoryRoot,
        path.resolve(repositoryRoot, path.dirname(fileName), decodeURIComponent(target))
      ).replaceAll('\\', '/');
      if (trackedSet.has(resolved)) links.push(resolved);
    }
    linksByFile.set(fileName, links);
  });

  const reachable = new Set();
  const pending = ['docs/README.md', 'docs/README.en.md'];
  while (pending.length > 0) {
    const fileName = pending.shift();
    if (reachable.has(fileName)) continue;
    reachable.add(fileName);
    (linksByFile.get(fileName) || []).forEach(link => pending.push(link));
  }

  const unreachableOperational = tracked.filter(fileName =>
    !reachable.has(fileName) && !historicalName.test(fileName)
  );
  assert.deepEqual(unreachableOperational, []);
});

test('leadership closure gate requires current integrated runtime evidence', () => {
  const gate = fs.readFileSync(
    path.join(repositoryRoot, 'scripts', 'New-RadIA.LeadershipClosureEvidence.ps1'),
    'utf8'
  );
  [
    'continuousDelphiJourney',
    'cyclesRequested',
    'InlineCompletionAccepted',
    'BlockReviewGutterPainted',
    'AgentRuntimePersisted',
    'DescendantCount',
    'realServerMatrixPassed',
    'sourceCommit',
    'productVersion'
  ].forEach(requirement => {
    assert.ok(gate.includes(requirement), `Closure gate is missing ${requirement}`);
  });
  assert.doesNotMatch(gate, /DescendantCount -eq 0/u);
});

test('current user-facing documents follow the package version', () => {
  const currentDocuments = [
    path.join(documentationRoot, 'README.md'),
    path.join(documentationRoot, 'README.en.md'),
    path.join(documentationRoot, 'user_manual.md'),
    path.join(documentationRoot, 'user_manual.en.md'),
    path.join(documentationRoot, 'capabilities.md'),
    path.join(documentationRoot, 'capabilities.en.md')
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

test('current release gates use the generated catalog size', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(documentationRoot, 'runtime_tools.json'), 'utf8')
  );
  const toolCount = manifest.groups.flatMap(group => group.tools).length;
  const portuguese = fs.readFileSync(path.join(documentationRoot, 'release_process.md'), 'utf8');
  const english = fs.readFileSync(path.join(documentationRoot, 'release_process.en.md'), 'utf8');
  const currentDocuments = [
    'terminal.md',
    'terminal.en.md'
  ];

  assert.match(portuguese, new RegExp(`todos com ${toolCount}\\s+ferramentas`, 'u'));
  assert.match(english, new RegExp(`all with ${toolCount} tools`, 'u'));
  assert.match(portuguese, /catálogo histórico de 95 tools/u);
  assert.match(english, /historical 95-tool catalog/u);
  currentDocuments.forEach(documentName => {
    const content = fs.readFileSync(path.join(documentationRoot, documentName), 'utf8');
    assert.match(
      content,
      new RegExp(`${toolCount}\\s+(?:ferramentas|tools)`, 'u'),
      documentName
    );
  });
});

test('release metadata and operational protocols follow the package version', () => {
  const escapedVersion = packageVersion.replaceAll('.', '\\.');
  const project = fs.readFileSync(path.join(repositoryRoot, 'RadIA.dproj'), 'utf8');
  const mcpPortuguese = fs.readFileSync(
    path.join(documentationRoot, 'mcp_integration_guide.md'),
    'utf8'
  );
  const mcpEnglish = fs.readFileSync(
    path.join(documentationRoot, 'mcp_integration_guide.en.md'),
    'utf8'
  );
  const cliPortuguese = fs.readFileSync(
    path.join(documentationRoot, 'cli_capability_matrix.md'),
    'utf8'
  );
  const cliEnglish = fs.readFileSync(
    path.join(documentationRoot, 'cli_capability_matrix.en.md'),
    'utf8'
  );
  const sonarProject = fs.readFileSync(
    path.join(repositoryRoot, 'sonar-project.properties'),
    'utf8'
  );

  assert.doesNotMatch(project, /FileVersion=2\.2\.1\.0/u);
  assert.match(project, new RegExp(`FileVersion=${escapedVersion}\\.0`, 'u'));
  assert.match(project, new RegExp(`ProductVersion=${escapedVersion}\\.0`, 'u'));
  [mcpPortuguese, mcpEnglish].forEach(document => {
    assert.match(document, new RegExp(`initialize[^\\n]+${escapedVersion}`, 'u'));
  });
  [cliPortuguese, cliEnglish].forEach(document => {
    assert.match(document, new RegExp(`RadIA ${escapedVersion}`, 'u'));
  });
  assert.match(sonarProject, new RegExp(`sonar\\.projectVersion=${escapedVersion}`, 'u'));
});

test('current entry points use the generated tool count and complete task navigation', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(documentationRoot, 'runtime_tools.json'), 'utf8')
  );
  const toolCount = manifest.groups.flatMap(group => group.tools).length;
  const portugueseReadme = fs.readFileSync(path.join(repositoryRoot, 'README.md'), 'utf8');
  const englishReadme = fs.readFileSync(path.join(repositoryRoot, 'README.en.md'), 'utf8');
  const portugueseHub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');
  const englishHub = fs.readFileSync(path.join(documentationRoot, 'README.en.md'), 'utf8');

  assert.ok(portugueseReadme.includes(`Catálogo das ${toolCount} ferramentas`));
  assert.ok(englishReadme.includes(`${toolCount}-tool runtime catalog`));
  [portugueseHub, englishHub].forEach(hub => {
    ['terminal', 'git_workflow', 'internal_tools_reference', 'settings_reference']
      .forEach(target => assert.ok(hub.includes(target), `Documentation hub is missing ${target}`));
  });

  const evidenceScripts = fs.readdirSync(path.join(repositoryRoot, 'scripts'))
    .filter(fileName => /^New-RadIA\..*Evidence\.ps1$/u.test(fileName));
  evidenceScripts.forEach(fileName => {
    const script = fs.readFileSync(path.join(repositoryRoot, 'scripts', fileName), 'utf8');
    const configuredCount = script.match(/\$RequiredToolCount\s*=\s*(\d+)/u);
    if (configuredCount) {
      assert.equal(
        Number(configuredCount[1]),
        toolCount,
        `${fileName} uses a stale required tool count`
      );
    }
  });
});

test('documented model fallbacks stay synchronized with source constants', () => {
  const modelTypes = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'Core', 'RadIA.Core.Types.pas'),
    'utf8'
  );
  const portuguese = fs.readFileSync(path.join(documentationRoot, 'settings_reference.md'), 'utf8');
  const english = fs.readFileSync(path.join(documentationRoot, 'settings_reference.en.md'), 'utf8');
  const fallbackModels = [...modelTypes.matchAll(/MODEL_[A-Z0-9_]+\s*=\s*'([^']+)'/gu)]
    .map(match => match[1]);

  assert.ok(fallbackModels.length >= 20);
  fallbackModels.forEach(model => {
    assert.ok(portuguese.includes('`' + model + '`'), `Portuguese fallbacks are missing ${model}`);
    assert.ok(english.includes('`' + model + '`'), `English fallbacks are missing ${model}`);
  });
});

test('feature catalog exposes every current experience-expansion milestone', () => {
  const portuguese = fs.readFileSync(path.join(documentationRoot, 'features.md'), 'utf8');
  const english = fs.readFileSync(path.join(documentationRoot, 'features.en.md'), 'utf8');
  const portugueseFeatures = [
    'Fila de Continuações', 'Alternativas de Ghost Text', 'Recursos Declarativos Empacotados',
    'Captura Visual Runtime', 'Consentimento Central entre Superfícies', 'Terminal Unicode e TUI'
  ];
  const englishFeatures = [
    'Follow-up Queue', 'Ghost Text Alternatives', 'Packaged Declarative Resources',
    'Runtime Visual Capture', 'Central Cross-surface Consent', 'Unicode and TUI Terminal'
  ];

  portugueseFeatures.forEach(feature => assert.ok(portuguese.includes(feature), feature));
  englishFeatures.forEach(feature => assert.ok(english.includes(feature), feature));
});

test('current backlog separates active work from historical deliveries', () => {
  const portuguese = fs.readFileSync(path.join(documentationRoot, 'backlog.md'), 'utf8');
  const english = fs.readFileSync(path.join(documentationRoot, 'backlog.en.md'), 'utf8');
  const rowPattern = /^\| \*\*/gmu;

  assert.match(portuguese, /## Backlog ativo canônico/u);
  assert.match(english, /## Canonical active backlog/u);
  assert.match(portuguese, /Contexto Semântico Compartilhado do Editor/u);
  assert.match(english, /Shared Semantic Editor Context/u);
  assert.doesNotMatch(portuguese, /M4 em execução|branch atual/u);
  assert.doesNotMatch(english, /M4 in progress|current branch/u);
  assert.equal([...portuguese.matchAll(rowPattern)].length, [...english.matchAll(rowPattern)].length);
});

test('current release audit matches the validated matrix', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, `release_audit_${packageVersion}.md`),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, `release_audit_${packageVersion}.en.md`),
    'utf8'
  );

  [portuguese, english].forEach(document => {
    assert.match(document, /1103/u);
    assert.match(document, /1111/u);
    assert.match(document, /106\/106/u);
    assert.match(document, /42\/42/u);
    assert.match(document, /148/u);
  });
});

test('completed historical goals do not claim to remain in progress', () => {
  const completedDocuments = [
    'experience_leadership_goal.md',
    'experience_leadership_goal.en.md',
    'runtime_debug_automation_m0.md',
    'runtime_debug_automation_m0.en.md',
    'runtime_debug_automation_m1.md',
    'runtime_debug_automation_m1.en.md',
    'runtime_debug_automation_m2.md',
    'runtime_debug_automation_m2.en.md',
    'runtime_debug_automation_m3.md',
    'runtime_debug_automation_m3.en.md'
  ];

  completedDocuments.forEach(fileName => {
    const document = fs.readFileSync(path.join(documentationRoot, fileName), 'utf8');
    assert.doesNotMatch(
      document,
      /planejado e em execução|planned and in progress|validação dentro da IDE pendente|in-IDE validation pending/u,
      fileName
    );
  });
});

test('declarative extensions document packaged resources end to end', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'declarative_extensions.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'declarative_extensions.en.md'),
    'utf8'
  );
  const catalogPortuguese = fs.readFileSync(
    path.join(documentationRoot, 'extension_catalog.md'),
    'utf8'
  );
  const catalogEnglish = fs.readFileSync(
    path.join(documentationRoot, 'extension_catalog.en.md'),
    'utf8'
  );
  const packager = fs.readFileSync(
    path.join(repositoryRoot, 'scripts', 'New-RadIA.DeclarativeExtensionPackage.ps1'),
    'utf8'
  );
  const requiredTerms = [
    'schema 6', 'contentFile', 'Resources folder', 'references/',
    'templates/', 'knowledge/', 'assets/', '128', '16 MiB', 'rollback'
  ];

  requiredTerms.forEach(term => {
    assert.ok(portuguese.includes(term), `Portuguese extension guide is missing ${term}`);
    assert.ok(english.includes(term), `English extension guide is missing ${term}`);
  });
  assert.ok(packager.includes('[string]$ResourcesPath'));
  assert.ok(packager.includes('$packageSchemaVersion = if ($hasResources) { 3 } else { 1 }'));
  [catalogPortuguese, catalogEnglish].forEach(document => {
    assert.match(document, /20 MiB/u);
    assert.match(document, /v2[^\n]+v3|version 2 or 3/iu);
  });
});

test('runtime guide separates structured evidence from consented visual capture', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'runtime_debug_automation.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'runtime_debug_automation.en.md'),
    'utf8'
  );
  [portuguese, english].forEach(document => {
    assert.match(document, /CaptureRuntimeEvidence/u);
    assert.match(document, /2 MiB/u);
    assert.match(document, /8 MiB/u);
    assert.match(document, /dez minutos|ten minutes/iu);
    assert.match(document, /CaptureRuntimeVisual/u);
    assert.match(document, /consentimento|consent/iu);
    assert.match(document, /antes e depois|before and after/iu);
  });
});

test('central consent is documented and wired consistently across surfaces', () => {
  const securityPortuguese = fs.readFileSync(
    path.join(documentationRoot, 'tool_security_model.md'),
    'utf8'
  );
  const securityEnglish = fs.readFileSync(
    path.join(documentationRoot, 'tool_security_model.en.md'),
    'utf8'
  );
  const consentSource = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.Consent.pas'),
    'utf8'
  );
  const terminalSource = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.TerminalFrame.pas'),
    'utf8'
  );
  [securityPortuguese, securityEnglish].forEach(document => {
    assert.match(document, /chat[\s\S]+MCP[\s\S]+terminal/iu);
    assert.match(document, /ConsentEveryTime/u);
    assert.match(document, /sanitiz|redact/iu);
    assert.match(document, /fila|queue/iu);
  });
  assert.match(consentSource, /FConsentGate/u);
  assert.match(consentSource, /TRadIAConsentPresentation\.Build/u);
  assert.match(consentSource, /FAllowOnceButton\.Hint/u);
  assert.match(terminalSource, /'terminal',\s+LSessionId,\s+LProjectId/um);
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
  const englishPolicy = fs.readFileSync(
    path.join(documentationRoot, 'documentation_policy.en.md'),
    'utf8'
  );
  const portugueseHub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');
  const englishHub = fs.readFileSync(path.join(documentationRoot, 'README.en.md'), 'utf8');

  assert.match(agentRules, /Documentação como parte do produto/u);
  assert.match(portuguesePolicy, /Toda mudança que adicione, remova, renomeie/u);
  assert.match(portuguesePolicy, /Afirmações sobre o comportamento atual devem ser verificadas/u);
  assert.match(englishPolicy, /Claims about current behavior must be verified/u);
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

test('terminal documentation defines Unicode, reflow, and TUI behavior', () => {
  const portuguese = fs.readFileSync(path.join(documentationRoot, 'terminal.md'), 'utf8');
  const english = fs.readFileSync(path.join(documentationRoot, 'terminal.en.md'), 'utf8');
  const manual = fs.readFileSync(path.join(documentationRoot, 'user_manual.en.md'), 'utf8');
  const capabilities = fs.readFileSync(path.join(documentationRoot, 'capabilities.en.md'), 'utf8');

  ['UTF-8', 'CJK', 'emoji', 'reflow', 'ICH', 'DCH', 'ECH']
    .forEach(term => assert.ok(portuguese.includes(term), `terminal.md is missing ${term}`));
  ['streaming decoding', 'combining marks', 'reflow', 'TUI']
    .forEach(term => assert.ok(english.includes(term), `terminal.en.md is missing ${term}`));
  assert.match(manual, /terminal reference/u);
  assert.match(capabilities, /CJK, emoji and combining-character widths/u);
});

test('chat documentation explains the bounded follow-up queue', () => {
  const portuguese = fs.readFileSync(
    path.join(documentationRoot, 'user_guide_chat_sessions.md'),
    'utf8'
  );
  const english = fs.readFileSync(
    path.join(documentationRoot, 'user_guide_chat_sessions.en.md'),
    'utf8'
  );

  assert.match(portuguese, /até cinco mensagens/u);
  assert.match(portuguese, /não entra no histórico antes do envio/u);
  assert.match(english, /up to five messages/u);
  assert.match(english, /does not enter history before sending/u);
});

test('source installation distinguishes build, test, and IDE registration', () => {
  const portugueseReadme = fs.readFileSync(path.join(repositoryRoot, 'README.md'), 'utf8');
  const englishReadme = fs.readFileSync(path.join(repositoryRoot, 'README.en.md'), 'utf8');
  const portugueseGuide = fs.readFileSync(
    path.join(documentationRoot, 'install_config.md'),
    'utf8'
  );
  const englishGuide = fs.readFileSync(
    path.join(documentationRoot, 'install_config.en.md'),
    'utf8'
  );

  [portugueseReadme, portugueseGuide].forEach(document => {
    assert.match(document, /"23\.0" -Release -Install/u);
    assert.match(document, /"37\.0" -Release -Install/u);
    assert.match(document, /"37\.0" -IDE64 -Release -Install/u);
    assert.match(document, /instala[\s\S]{0,100}sem\s+`-Install`/u);
  });
  [englishReadme, englishGuide].forEach(document => {
    assert.match(document, /"23\.0" -Release -Install/u);
    assert.match(document, /"37\.0" -Release -Install/u);
    assert.match(document, /"37\.0" -IDE64 -Release -Install/u);
    assert.match(document, /does not install[\s\S]{0,100}without\s+`-Install`/u);
  });
});

test('source installation deploys extension tooling and preserves shared Web assets', () => {
  const buildScript = fs.readFileSync(path.join(repositoryRoot, 'build.ps1'), 'utf8');

  assert.match(buildScript, /New-RadIA\.DeclarativeExtensionPackage\.ps1/u);
  assert.match(buildScript, /\$targetExtensionPackager/u);
  assert.match(buildScript, /\$win32Package/u);
  assert.match(buildScript, /\$win64Package/u);
});

test('current planning and update documentation match the released product', () => {
  const portugueseHub = fs.readFileSync(path.join(documentationRoot, 'README.md'), 'utf8');
  const englishHub = fs.readFileSync(path.join(documentationRoot, 'README.en.md'), 'utf8');
  const portugueseBacklog = fs.readFileSync(path.join(documentationRoot, 'backlog.md'), 'utf8');
  const englishBacklog = fs.readFileSync(path.join(documentationRoot, 'backlog.en.md'), 'utf8');
  const portugueseInstaller = fs.readFileSync(
    path.join(documentationRoot, 'visual_installer.md'),
    'utf8'
  );
  const englishInstaller = fs.readFileSync(
    path.join(documentationRoot, 'visual_installer.en.md'),
    'utf8'
  );
  const releaseWorkflow = fs.readFileSync(
    path.join(repositoryRoot, '.github', 'workflows', 'release.yml'),
    'utf8'
  );

  assert.doesNotMatch(portugueseHub, /Goal ativo da versão 2\.6\.0/u);
  assert.doesNotMatch(englishHub, /Active 2\.6\.0 goal/u);
  assert.match(portugueseHub, /goal ativo do motor semântico estrutural 2\.10\.0/u);
  assert.match(englishHub, /Active 2\.10\.0 structural semantic engine goal/u);
  assert.match(
    portugueseBacklog,
    /O goal ativo é o \*\*RadIA 2\.10\.0 — Motor Semântico Estrutural/u
  );
  assert.match(englishBacklog, /The active goal is \*\*RadIA 2\.10\.0 — Structural Semantic Engine/u);
  assert.match(
    portugueseInstaller,
    /não verifica, baixa ou instala novas versões automaticamente/u
  );
  assert.match(
    englishInstaller,
    /does not automatically check for, download, or install new versions/u
  );
  assert.doesNotMatch(releaseWorkflow, /Output\\Distribution\\stable\.json/u);
  assert.doesNotMatch(releaseWorkflow, /New-RadIA\.ReleaseChannel\.ps1/u);
});
