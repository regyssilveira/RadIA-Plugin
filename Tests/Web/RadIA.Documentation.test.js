const assert = require('node:assert/strict');
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
  assert.equal(registeredTools.length, 123);
  assert.equal(documentedTools.size, registeredTools.length);
  registeredTools.forEach(toolName => {
    const documentation = documentedTools.get(toolName);
    assert.ok(documentation, `Missing operational documentation for ${toolName}`);
    assert.ok(documentation.purpose.length >= 20, `Purpose is too short for ${toolName}`);
    assert.ok(documentation.activation.length >= 20, `Activation guidance is too short for ${toolName}`);
  });
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
  assert.match(englishManual, /tool_security_model\.md/u);
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
    'continuous inline completion',
    'RadIA shortcuts',
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
