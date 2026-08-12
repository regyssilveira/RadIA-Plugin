# Delphi mentor

The Delphi mentor adapts explanations to the user's level without turning project code into retained
learning material. Select code in the editor and ask from chat, or run `ExplainSelectedDelphiCode` with
one of these profiles:

- `beginner`: introduces syntax, ownership, runtime behavior, and one safe next step;
- `cross-language`: compares the selection with managed-language concepts and highlights differences;
- `experienced`: focuses on contracts, lifetime, framework integration, compiler constraints, and tradeoffs.

The response detects ownership, VCL/FMX, DFM/FMX linkage, and packages, attaching curated rules with
stable citations. Selection is limited to 12,000 characters, used only for the current response, and
never stored by the mentor (`retained: false`).

Without a selection, the tool rejects execution instead of implicitly capturing the whole file. The
profile is supplied for every call and creates no hidden history or preference.
