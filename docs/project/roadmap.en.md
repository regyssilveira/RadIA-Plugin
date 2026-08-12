# RadIA roadmap

The roadmap describes direction, not release history. Published deliveries are documented in
[GitHub Releases](https://github.com/regyssilveira/RadIA-Plugin/releases); executable work belongs in
the [backlog](backlog.en.md).

## Now — structural semantic engine

The current cycle turns the editor's bounded context into reproducible structural understanding for
Delphi 12 and 13:

1. supervised external process and effective compiler profile;
2. lexer, preprocessor, and parser tolerant of incomplete code;
3. incremental project, group, RTL, and VCL index;
4. navigation, agent context, and Ghost Text backed by the same index;
5. safe implementation of missing members;
6. resolved completion and `/doctor --deep` diagnostics.

The engine complements CodeInsight and keeps the current context as fallback. Delphi 11, C++,
Lazarus, and DCU reading are outside this cycle.

## Next — consolidate the complete experience

After the semantic engine is stable, priorities are:

- use structural resolution for Clean Uses, review on save, and mock generation;
- correlate stack traces across units and import MadExcept/EurekaLog evidence;
- extend guided, reversible modernization of existing applications;
- simplify cache operation, diagnostics, and installation maintenance.

New initiatives receive a version only after scope, evidence, and completion criteria are approved.
