# Instrumentação reversível de memória

O RadIA nunca instrumenta silenciosamente um projeto. O fluxo usa as mesmas garantias transacionais
das alterações de código:

1. `PrepareMemoryInstrumentation` valida projeto, configuração, plataforma e FastMM5;
2. o RadIA abre o DPR pela IDE e lê o buffer vivo, incluindo alterações ainda não salvas;
3. o preview recebe um fingerprint e mostra o arquivo que será modificado;
4. `ApplyMemoryInstrumentation` revalida o fingerprint e solicita consentimento estrutural;
5. `RevertMemoryInstrumentation` restaura exatamente o conteúdo capturado.

## Alteração proposta

Somente o DPR é alterado. O preview:

- exige a configuração **Debug**;
- aceita apenas Win32 e Win64;
- insere o define `FastMM_EnableMemoryLeakReporting`;
- coloca `FastMM5` como primeira unit, requisito do gerenciador de memória;
- referencia o `FastMM5.pas` da pasta configurada pelo usuário;
- configura explicitamente a DLL FullDebugMode correspondente à plataforma;
- direciona o log para `.radia/memory/latest-fastmm5.log`;
- cria um marcador local de prontidão para diferenciar uma execução limpa de backend ausente;
- pode configurar `FastMM_DebugBreakAllocationNumber` quando a evidência identifica a alocação;
- entra no modo de diagnóstico no início do bloco principal do projeto, sem depender do diretório
  atual do processo.

Release não é instrumentado e configurações não relacionadas não são alteradas. O escritor da IDE
mantém o buffer, participa do Undo e recusa previews obsoletos.

## Modos

- `session`: a próxima execução diagnóstica usa a instrumentação e a restaura em um bloco de
  finalização mesmo em cancelamento ou falha;
- `persistentDebug`: a instrumentação permanece em Debug até o usuário executar a reversão.

O modo persistente não afeta Release. Antes de iniciar uma sessão, consulte
`GetMemoryDiagnosticsStatus`.

## Recuperação após interrupção

Antes de alterar o DPR, a sessão grava em `.radia/memory/recovery` o conteúdo original, o conteúdo
instrumentado e um manifesto. Na próxima preparação:

- se o DPR ainda corresponde ao original ou ao instrumentado, o original é restaurado;
- se o usuário editou o arquivo para um terceiro conteúdo, a recuperação falha fechada com
  `memory_recovery_conflict`;
- nenhum conteúdo divergente é sobrescrito automaticamente;
- após restauração normal, o journal é removido.
