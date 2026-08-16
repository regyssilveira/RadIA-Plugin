# Safe local database access

RadIA can inspect project SQLite files and preview read-only queries without changing the database.
This journey supports local development and diagnostics; it is not a database administration tool
and does not connect to external servers.

## Supported use

- `.db`, `.sqlite`, and `.sqlite3` files inside the active project workspace;
- table, view, and column discovery;
- one read-only `SELECT`, `WITH`, or metadata `PRAGMA` statement per execution;
- up to 500 rows and 128 columns per result;
- a paginated chat grid and sanitized CSV copy.

## How to use it

Ask the agent to inspect the database or call the tools directly:

```text
/tool InspectLocalSQLiteDatabase {"path":"data/app.sqlite"}
/tool PreviewLocalSQLiteQuery {"path":"data/app.sqlite","sql":"SELECT id, name FROM customers","maxRows":100}
```

Schema inspection is read-only. Query preview always displays the consent dialog before execution.
Review the file, SQL, and limit, then choose **Allow once** to proceed.

## Enforced protections

- the path must remain inside the workspace and the file cannot exceed 512 MB;
- SQLite opens with `READONLY`, `query_only`, and disabled `trusted_schema`;
- DDL, DML, transactions, compound statements, comments, `ATTACH`, and extensions are rejected;
- the SQLite runtime must be the trusted copy distributed with Delphi 12 or 13;
- BLOB values are not materialized and appear as a placeholder;
- columns whose names suggest passwords, secrets, tokens, API keys, or credentials appear as
  `[redacted]` in both the grid and CSV;
- CSV copy uses only the sanitized result and never writes a file automatically.

If the database is outside the workspace, move a working copy into the project. Use a dedicated
external tool for mutations, remote servers, or migrations.

See [Internal tools](../reference/internal_tools_reference.en.md) and
[Security model](../reference/tool_security_model.en.md).
