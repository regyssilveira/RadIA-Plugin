# Reversible memory instrumentation

RadIA never instruments a project silently. The workflow uses the same transactional guarantees as
code changes:

1. `PrepareMemoryInstrumentation` validates project, configuration, platform, and FastMM5;
2. RadIA opens the DPR through the IDE and reads the live buffer;
3. the preview receives a fingerprint;
4. `ApplyMemoryInstrumentation` revalidates it and requests structural consent;
5. `RevertMemoryInstrumentation` restores the exact captured content.

Only the DPR is changed. Debug is required, only Win32 and Win64 are accepted, FastMM5 is placed
first in the uses list, and bounded diagnostic defines are enabled. Release and unrelated project
settings are not changed. Session mode is reverted after the diagnostic even on cancellation;
persistent Debug mode remains until explicit reversion.
