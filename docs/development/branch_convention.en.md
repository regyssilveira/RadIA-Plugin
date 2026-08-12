# Branch Naming Convention

**Rad IA** branches should follow a simple, predictable structure compatible with widely adopted conventions such as Conventional Branch.

Recommended format:

```text
<type>/<short-description>
```

Examples:

```text
feat/chat-welcome-actions
fix/editor-selection-bug
docs/release-process
refactor/provider-session-handling
```

---

## General Rules

* Use lowercase letters.
* Use short English words.
* Separate words with hyphens (`-`).
* Use a slash (`/`) only between the type and the description.
* Avoid accents, spaces, underscores, and special characters.
* Keep the description objective and related to the main branch goal.

---

## Allowed Prefixes

| Prefix | Use | Example |
| :--- | :--- | :--- |
| `feat/` or `feature/` | New features. | `feat/user-authentication` |
| `fix/` or `bugfix/` | Bug or failure fixes. | `fix/login-error` |
| `hotfix/` | Urgent fixes applied directly to production. | `hotfix/payment-failure` |
| `refactor/` | Code improvements that do not add features or fix bugs. | `refactor/search-optimization` |
| `docs/` | Documentation-only changes. | `docs/update-readme` |
| `test/` | Test additions or fixes. | `test/api-coverage` |
| `chore/` | Maintenance or configuration tasks. | `chore/update-dependencies` |

---

## Best Practices

* Choose the prefix based on the main branch goal.
* Prefer one branch per work intention.
* Avoid generic names such as `fix/adjustments`, `feat/new-stuff`, or `chore/misc`.
* When there is a tracked issue or task, the identifier may be appended at the end: `fix/editor-selection-bug-123`.
* The branch prefix does not force every commit to use the same prefix, but history is clearer when both are aligned.
