# Clean Uses

Ask the agent to clean imports in the active unit. `PrepareCleanUses` queries the indexed public project API and
prepares a preview; this step changes nothing. The analyzer preserves conditional clauses, qualified references,
external units or units without verifiable source, and units with `initialization`/`finalization`.

Review the candidates and proposed content. Application uses `ApplyPatch`, requires consent, validates the buffer
revision, and can be undone with `RevertPatch`. Run the build after application.
