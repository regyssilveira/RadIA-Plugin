# DFM/PAS consistency audit

RadIA compares the active form with its Pascal unit without loading components or modifying files. The
audit identifies mismatches that commonly cause streaming errors, disconnected handlers, or incompatible
fields in the Form Designer.

## Run the audit

Open the form in the Designer and run:

```text
/tool AuditActiveDfmPasConsistency
```

Each finding contains a stable code, severity, file (`dfm` or `pas`), line, name, and message. The
current version detects:

- a different root class between DFM and Pascal;
- a component without a Pascal field or a field with a different class;
- a component field without a corresponding DFM object;
- an event that references a missing method;
- an incompatible signature for common notification events;
- a method that looks like a component handler but is not assigned in the DFM.

The parser is deliberately bounded: it reads at most 2 MiB per file and produces at most 500 findings.
It does not instantiate the form, run code, or interpret arbitrary properties.

## Prepare a fix

Automatic fixes are restricted to the deterministic `missing_event_handler` and
`missing_component_field` cases. To prepare a preview, run:

```text
/tool PrepareDfmPasAuditFix
```

Provide the `findingCode` and `name` exactly as returned by the audit. The tool creates a preview in the
patch service but does not modify the file. Review and apply it with `ApplyPatch`; revert it with
`RevertPatch`.

If the buffer changes after the preview, application fails with `precondition_failed` and makes no
change. Root class mismatches, incompatible handlers, and orphan items require human judgment and do
not receive automatic fixes.

## Recovery

- `form_unavailable`: open a form in the Designer.
- `resource_limit`: reduce the DFM or unit below 2 MiB.
- `fix_unavailable`: rerun the audit and check the code and name; the finding might not support an
  automatic fix.
- `precondition_failed`: the buffer changed; discard the preview and prepare another from current state.
