# Publish one skill to CLIs

RadIA keeps the declarative extension as the source of truth and publishes the same skill to the
project formats recognized by Codex, Claude Code, Gemini CLI, and GitHub Copilot CLI.

## How to open

1. Open or create a Delphi project.
2. Open **Tools > RadIA > Rad IA Extensions... > Addon Studio...**.
3. Select **Skill** and fill in ID, name, description, and instructions or a valid `contentFile`.
4. Click **Publish skill to CLIs...**.

The button appears only for skills. Its hint explains that paths are previewed and consent is
required before a write.

## Preview and destinations

| CLI | Project directory |
|---|---|
| Codex | `.agents/skills/<skill>/SKILL.md` |
| Claude Code | `.claude/skills/<skill>/SKILL.md` |
| Gemini CLI | `.gemini/skills/<skill>/SKILL.md` |
| GitHub Copilot CLI | `.github/skills/<skill>/SKILL.md` |

Check the desired destinations. The preview shows the absolute path and one state:

- `create`: new file;
- `update`: file still matches the last hash created by RadIA;
- `unchanged`: content already matches the expected output;
- `conflict`: file exists but does not match a replica controlled by RadIA.

A conflict blocks the complete publication. RadIA never silently overwrites content created or
modified by the user.

## Consent, synchronization, and removal

**Publish** requests central consent for the `PublishCliSkill` structural operation and identifies
the origin, project, and executors. Files use atomic replacement and rollback.
`.radia/skill-replicas.json` stores only extension ID, executor, path, and SHA-256; it does not store
prompts, credentials, or tokens.

To synchronize a change, open the skill again and publish the destinations. Changes are detected
without restarting Delphi. **Remove replicas** also requires consent and removes only files that
still match recorded hashes. Modified files are preserved.

## Recovery

| Message | Action |
|---|---|
| Open or create a project | Open a `.dproj`; destinations are relative to the active project. |
| Select at least one CLI destination | Check at least one executor. |
| conflict | Compare the file; rename it or merge the differences manually. |
| Publishing was not authorized | Retry and authorize the operation in the central dialog. |
| content file was not found | Correct **Resources folder** and **Content file**. |

For canonical creation and packaging, see [Declarative extensions](declarative_extensions.en.md).
