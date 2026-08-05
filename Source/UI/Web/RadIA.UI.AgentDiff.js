const RADIA_PATCH_TOOLS = new Set([
  'PreparePatch',
  'ApplyPatch',
  'RevertPatch'
]);

const RADIA_MULTI_FILE_PATCH_TOOLS = new Set([
  'PrepareMultiFilePatch',
  'ApplyMultiFilePatch',
  'RevertMultiFilePatch'
]);

function radIAHasReviewableContent(file) {
  return file &&
    typeof file.originalContent === 'string' &&
    typeof file.proposedContent === 'string';
}

function radIAExtractPatchFiles(toolName, result) {
  if (RADIA_PATCH_TOOLS.has(toolName) && radIAHasReviewableContent(result)) {
    return [result];
  }
  if (RADIA_MULTI_FILE_PATCH_TOOLS.has(toolName) &&
      result &&
      Array.isArray(result.files)) {
    return result.files.filter(radIAHasReviewableContent);
  }
  return [];
}

function radIABuildDiffHunk(
  originalContent,
  proposedContent,
  contextLineCount = 3
) {
  const originalLines = originalContent.split(/\r?\n/);
  const proposedLines = proposedContent.split(/\r?\n/);
  let prefix = 0;
  while (prefix < originalLines.length &&
         prefix < proposedLines.length &&
         originalLines[prefix] === proposedLines[prefix]) {
    prefix += 1;
  }
  let suffix = 0;
  while (suffix < originalLines.length - prefix &&
         suffix < proposedLines.length - prefix &&
         originalLines[originalLines.length - suffix - 1] ===
           proposedLines[proposedLines.length - suffix - 1]) {
    suffix += 1;
  }
  const contextStart = Math.max(0, prefix - contextLineCount);
  const originalEnd = Math.min(
    originalLines.length,
    originalLines.length - suffix + contextLineCount
  );
  const proposedEnd = Math.min(
    proposedLines.length,
    proposedLines.length - suffix + contextLineCount
  );
  return {
    original: originalLines.slice(contextStart, originalEnd).join('\n'),
    proposed: proposedLines.slice(contextStart, proposedEnd).join('\n'),
    originalStartLine: contextStart + 1,
    originalChangedLines: Math.max(
      0,
      originalLines.length - prefix - suffix
    ),
    proposedChangedLines: Math.max(
      0,
      proposedLines.length - prefix - suffix
    )
  };
}

(function initializeRadIAAgentDiff(root) {
  const api = {
    buildHunk: radIABuildDiffHunk,
    extractFiles: radIAExtractPatchFiles
  };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.RadIAAgentDiff = api;
  }
})(typeof globalThis === 'undefined' ? this : globalThis);
