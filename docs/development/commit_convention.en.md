# Commit Message Convention

**Rad IA** commit messages must always be written in **English** and follow a semantic prefix that indicates the main type of change.

Recommended format:

```text
<type>: <short description in English>
```

Examples:

```text
feat: Add chat welcome quick actions
fix: Prevent chat switching while processing
docs: Document release finalization process
refactor: Simplify provider session handling
```

---

## Allowed Prefixes

| Prefix | Use |
| :--- | :--- |
| `feat` | Adds a new feature. |
| `fix` | Fixes a bug or error. |
| `docs` | Changes documentation only. |
| `style` | Adjusts formatting without changing logic, such as spaces, line breaks, or punctuation. |
| `refactor` | Improves code structure without adding a feature or fixing a bug. |
| `perf` | Improves performance. |
| `test` | Adds or fixes tests. |
| `build` | Changes the build system, packaging, or external dependencies. |
| `chore` | Performs maintenance tasks with no production-code impact. |

---

## Best Practices

* Use short phrases in natural English imperative style.
* Prefer describing the outcome of the change, not the process.
* Use one prefix per commit.
* Split commits by intent when a change mixes documentation, code, and build work.
* Avoid generic messages like `fix: adjustments`, `chore: changes`, or `update files`.

When a change is broad, the commit body may detail context and impact, but the title should still follow the format above.
