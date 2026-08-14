# Thread and PPL assistant

Run `AnalyzeThreadingRisks` on the active Pascal unit to locate work using `TTask.Run`,
`TParallel.For`, or `TThread.CreateAnonymousThread`. It reports VCL access without
`TThread.Queue`/`Synchronize`, missing cancellation, and a missing `try/except` boundary.

After reviewing the findings, send the original and replacement blocks to
`PrepareThreadModernization`. The tool rejects proposals that retain risks and otherwise creates a
preview only. Generic patch tools apply or revert it under the existing consent policy.

The analyzer is conservative and does not prove the functional correctness of a parallel algorithm.
Run the build, tests, and a runtime scenario after applying the preview.
