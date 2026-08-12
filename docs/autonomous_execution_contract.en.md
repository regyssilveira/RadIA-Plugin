# Autonomous execution contract

Every native run started with `/agent run` receives a local contract that is immutable for that session.
The contract complements the existing step, repetition, duration, token, cost, and context limits.

## Additional limits

The default contract limits a run to 32 affected files and 20 mutating operations and produces a summary
every five steps. The runtime checks operations and known paths before calling a tool; if a response
reveals additional files beyond the limit, the run also pauses immediately.

The periodic summary records step count, mutating operations, affected files, and the latest tool. It is
stored in the checkpoint and returns after `/agent resume`.

## Criteria and gates

The contract contains explicit completion criteria and required build and test flags. Under the default
contract, any mutation requires a successful `BuildProject` after the latest change. Journeys that enable
the test gate also require a later DUnitX run. A test run that fails always blocks completion.

An early completion attempt returns to the loop with recovery guidance. Three consecutive attempts that
ignore the gates fail the run.

## Safe pauses

The runtime pauses without expanding permissions when:

- the next known operation or file would exceed the contract;
- a tool returns ambiguity, an invalid request, a conflict, or a concurrent precondition failure;
- the user requests a pause.

Resume loads limits, criteria, gates, accumulated usage, summary, and steps directly from the checkpoint.
Older checkpoints without the new block receive the default contract; missing values are never converted
into broader limits.

## Final report

Completed, cancelled, or failed runs include `finalReport` in the snapshot. The report summarizes status,
message, steps, operations, affected files, build outcome, DUnitX counts, and pending items. This evidence
uses only already authorized tool results and does not run additional validation.
