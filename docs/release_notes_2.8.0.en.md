# Release notes - RadIA 2.8.0

> **Status:** validated candidate for publication on August 11, 2026.

RadIA 2.8.0 integrates bounded semantic assistance with the editor without replacing Delphi's native
provider. This version documents 133 built-in tools.

## Shared semantic context

- Ghost Text, contextual actions, and agent use the same context analyzer;
- unit, symbol at the cursor, imports, and nearby declarations come directly from the live buffer;
- **Show Semantic Editor Context** provides read-only inspection of the metadata;
- actions such as explain, generate tests, and find bugs receive the same editor context;
- `GetEditorSemanticContext` makes the context available to the agent with `readOnly` risk.

## Compatibility and safety

- Delphi's native CodeInsight remains responsible for the editor's default provider;
- context is bounded, observable, and does not change the buffer during inspection;
- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 remain the only supported targets;
- documentation, release gates, and evidence scripts are synchronized with 133 tools.

## Evidence

The [release audit](release_audit_2.8.0.en.md) records the publication gates.
