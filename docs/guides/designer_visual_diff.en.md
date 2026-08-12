# Form Designer visual diff

RadIA captures local structural snapshots of the active form and compares a previous state with a
proposed state. The comparison is designed to appear as a single before and after step in the agent
timeline without persisting project content or changing the Designer when the review is accepted or
rejected.

## Workflow

1. With the form open, run `CaptureDesignerVisualSnapshot` before the proposal.
2. Make or prepare the authorized change through the Designer tools.
3. Run `CaptureDesignerVisualSnapshot` again.
4. Pass both identifiers to `CompareDesignerVisualSnapshots`.
5. Review `changes` and decide with `DecideDesignerVisualDiff`.
6. When finished, run `ClearDesignerVisualDiffArtifacts`.

The comparison reports created and removed components, class or parent changes, movement, resizing,
selection, and changes to the allowlisted `Caption`, `Text`, `Align`, `Visible`, `Enabled`, and
`TabOrder` properties. Each change contains `before` and `after` objects ready for side-by-side timeline
rendering.

## Retention and privacy

- snapshots and comparisons remain only in IDE process memory;
- at most 20 snapshots and 20 comparisons are retained, with oldest-first eviction;
- each capture contains at most 1,000 components;
- file paths, Pascal code, DFM content, and properties outside the allowlist are not copied;
- this version does not write raster captures to disk or automatically send images to providers.

The OTA facade reads the Form Designer on the main thread. Calls started in the background are
synchronized before components and properties are read.

## Decisions and conflicts

A comparison starts as `prepared` and accepts only one decision: `accepted` or `rejected`. Repeating a
decision produces a conflict and does not change the Designer. The decision records
`designerMutated=false`: applying or reverting the actual change remains the responsibility of the
transactional tools that originated the proposal. Rejecting the comparison alone therefore never writes
to the form.

If a snapshot has expired due to retention, belongs to another form, or has been cleared, create two new
captures from the current state.
