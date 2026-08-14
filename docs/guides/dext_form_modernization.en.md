# DEXT adoption and form decomposition

Start from the legacy migration report: every batch must be `validated`. Record behavioral parity
evidence for the existing flow before preparing any change.

`PrepareDextFormModernization` receives the report, evidence, and proposed contents. The batch must
contain the form DFM/Pascal pair, an explicit DEXT boundary, and at least one responsibility extracted
into a Presenter, Service, or Controller. DFM/Pascal audit must pass before the reversible multi-file
preview is created.

After consented application, build and test the batch. Send evidence to
`RecordDextFormModernizationGate`. A failed build or test reverts the preview; both must pass to record
the `validated` state.
