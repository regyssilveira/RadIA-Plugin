# Reviewable Git commits

RadIA creates local commits only and never pushes automatically. `GetGitStatus` and `GetGitDiff`
inspect the active project; `PreviewGitCommit` freezes explicitly selected paths, their diff,
message, and content fingerprint without touching the index; `CommitChanges` accepts only the
resulting `previewId`, requires consent, and creates the local commit.

An active Delphi project inside a Git work tree is required. Every path must remain inside its
workspace, the message must be a single line, and no previously staged changes may exist anywhere
in the repository. Tracked, untracked, and deleted files participate in the fingerprint. Concurrent
changes invalidate the preview.

RadIA exposes no destructive reset, file discard, force push, or push operation. If `git commit`
fails, only the paths staged by that transaction are removed from the index; working-tree content
is preserved. `CommitChanges` is a structural-write tool covered by consent and audit policies.
