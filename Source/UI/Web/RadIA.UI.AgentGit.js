function radIAGitDiffLineKind(line) {
  if (line.startsWith('diff --git ') ||
      line.startsWith('index ') ||
      line.startsWith('--- ') ||
      line.startsWith('+++ ') ||
      line.startsWith('@@')) {
    return 'header';
  }
  if (line.startsWith('+')) {
    return 'addition';
  }
  if (line.startsWith('-')) {
    return 'removal';
  }
  return 'context';
}

function radIAGitDiffPath(line) {
  const match = /^diff --git a\/(.+) b\/(.+)$/.exec(line);
  return match ? match[2] : '';
}

function radIASummarizeGitDiff(diff) {
  const lines = diff.split(/\r?\n/);
  const files = [];
  let additions = 0;
  let removals = 0;
  const tokens = lines.map(line => {
    const kind = radIAGitDiffLineKind(line);
    const path = radIAGitDiffPath(line);
    if (path && !files.includes(path)) {
      files.push(path);
    }
    if (kind === 'addition') {
      additions += 1;
    } else if (kind === 'removal') {
      removals += 1;
    }
    return { kind, text: line };
  });
  return { additions, files, removals, tokens };
}

(function initializeRadIAAgentGit(root) {
  const api = { summarizeDiff: radIASummarizeGitDiff };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.RadIAAgentGit = api;
  }
})(typeof globalThis === 'undefined' ? this : globalThis);
