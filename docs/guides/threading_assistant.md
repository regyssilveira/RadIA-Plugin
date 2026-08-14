# Assistente de threads e PPL

Use `AnalyzeThreadingRisks` na unit Pascal ativa para localizar trabalho em `TTask.Run`,
`TParallel.For` ou `TThread.CreateAnonymousThread`. A análise aponta acesso VCL sem
`TThread.Queue`/`Synchronize`, ausência de cancelamento e ausência de um limite `try/except`.

Depois de revisar o diagnóstico, envie o bloco original e a substituição para
`PrepareThreadModernization`. A ferramenta rejeita propostas que ainda tenham riscos e, quando as
proteções estão presentes, cria somente um preview. A aplicação e a reversão usam as ferramentas
genéricas de patch e continuam sujeitas a consentimento.

O analisador é conservador e não comprova a correção funcional do algoritmo paralelo. Execute build,
testes e um cenário de runtime depois de aplicar o preview.
