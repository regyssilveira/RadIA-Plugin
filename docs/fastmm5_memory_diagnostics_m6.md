# Execução M6 — hardening do diagnóstico de memória

> **Versão:** 2.2.0
> **Backend:** FastMM5 5.07 fornecido pelo usuário
> **Escopo:** Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64

## Repetibilidade na IDE

O smoke `Test-RadIA.MemoryDiagnosticIDE.ps1` aceita `-Cycles 1..10`. Cada ciclo prepara nova
instrumentação, compila, inicia somente o processo supervisionado, reproduz o cenário visual,
aguarda a finalização do FastMM5, interpreta a evidência e restaura o DPR.

| Target | Ciclos | Resultado final | Restauração |
|---|---:|---|---|
| Delphi 12 Win32 | 10/10 | 4 grupos determinísticos | hash do DPR preservado |
| Delphi 13 Win32 | 10/10 | 4 grupos determinísticos | hash do DPR preservado |
| Delphi 13 IDE64 | 10/10 | 4 grupos determinísticos | hash do DPR preservado |
| Delphi 13 Win32, controle corrigido | 10/10 | 0 grupos | hash do DPR preservado |

As execuções completas, incluindo build/instalação da BPL, abertura e encerramento da IDE e dez
sessões, ficaram entre 100,4 e 117,5 segundos por target no ambiente de validação. A evidência JSON
do caso com leak ficou abaixo de 14 KiB; o limite configurado do parser continua em 50 MiB.

## Falhas e interrupções validadas

- cancelamento durante cenário ativo interrompe somente o PID supervisionado;
- cancelamento sempre passa pela restauração da instrumentação;
- o timeout global limita também a ação ativa e as repetições restantes;
- falha de build restaura o DPR;
- recuperação após interrupção restaura o conteúdo original conhecido;
- conteúdo divergente do usuário produz `memory_recovery_conflict` e não é sobrescrito;
- evidência JSON malformada é rejeitada sem Access Violation;
- uma execução limpa com marcador de prontidão e sem log retorna zero grupos, não backend ausente.

## Evidência comparável e correção

- baseline e verificação precisam ter builds distintos e o mesmo fingerprint de cenário;
- os resultados possíveis são `fixed`, `improved`, `unchanged`, `regressed` e `incomparable`;
- `PrepareMemoryDiagnosticFix` ignora frames de infraestrutura e escolhe o primeiro frame do projeto;
- o número da alocação pode ser usado por `PrepareMemoryInstrumentation` para configurar
  `FastMM_DebugBreakAllocationNumber`;
- o controle corrigido comprovou a transição de quatro grupos para zero sem falso positivo.

## Gates restantes

Esta página deve ser complementada pela auditoria final da release com:

- builds e testes finais Delphi 12 e Delphi 13;
- BPL Delphi 13 IDE64;
- lint e testes Web;
- SonarQube;
- smokes dos pacotes e instalador visual;
- instalação final nas três IDEs;
- hashes dos artefatos publicados.
