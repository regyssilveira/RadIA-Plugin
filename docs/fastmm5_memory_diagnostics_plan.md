# Goal 2.2 — Diagnóstico dinâmico de memória com FastMM5

> **Estado:** planejado, pronto para execução.
> **Versão-alvo:** 2.2.0.
> **Escopo:** Delphi 12 Win32 e Delphi 13 Win32/IDE64, diagnosticando aplicações Win32 e Win64.
> **Dependência:** FastMM5 opcional, fornecido e licenciado pelo usuário.

## Decisão de versionamento

A próxima versão será `2.2.0`. A integração acrescenta uma capacidade compatível sem remover ou
alterar contratos públicos existentes. Pela versão semântica, isso exige incremento `MINOR`.

## Goal

Permitir que o RadIA instrumente uma configuração Debug de forma reversível, execute um cenário
runtime, capture e interprete eventos do FastMM5, localize stacks de alocação, prepare uma correção
e repita o mesmo cenário para comprovar que o vazamento ou erro de memória foi removido.

O fluxo deve diferenciar:

- crescimento transitório e estabilização esperada;
- vazamento confirmado no encerramento;
- crescimento recorrente entre snapshots;
- corrupção de heap, double free e uso após liberação;
- recursos não gerenciados pelo heap, que exigem outro backend.

## Estado atual e lacuna

O RadIA já possui análise estática, execução DUnitX, debugger orientado a eventos, cenários visuais,
evidências comparáveis e regressões versionadas. Ele ainda não registra a origem de cada alocação
nem interpreta relatórios detalhados de heap de uma aplicação real.

O FastMM5 oferece modo de depuração, eventos para arquivo e debugger, stacks de alocação, snapshots,
break por número de alocação e suporte Windows Win32/Win64. A integração reutilizará essas
capacidades sem copiar sua implementação.

## Modelo de dependência e licença

- O RadIA não distribuirá FastMM5, suas DLLs ou seu código-fonte.
- O usuário indicará uma instalação local ou uma dependência já pertencente ao projeto.
- A tela de configuração exibirá versão detectada, caminhos, arquiteturas e confirmação de licença.
- Nenhuma aceitação de licença será presumida ou registrada em nome do usuário.
- A integração aceitará apenas caminhos locais explícitos e arquivos com identidade validada.
- O projeto continuará compilando e funcionando normalmente sem FastMM5.
- A documentação explicará que FastMM5 usa GPLv3 ou licença comercial, conforme escolha do usuário.

## Experiência do usuário

1. O usuário descreve um vazamento ou crescimento de memória.
2. O RadIA executa `GetMemoryDiagnosticsStatus`.
3. Se FastMM5 não estiver configurado, a interface orienta a localização da instalação.
4. `PrepareFastMMInstrumentation` mostra todos os arquivos, defines e configurações afetados.
5. O usuário escolhe sessão temporária ou configuração Debug persistente e concede consentimento.
6. `ApplyFastMMInstrumentation` aplica a instrumentação transacional e reversível.
7. O RadIA compila, inicia o debugger e executa o cenário aprovado.
8. Snapshots opcionais medem o estado antes e depois de cada repetição.
9. O encerramento controlado produz o relatório de leaks e erros.
10. `CaptureMemoryLeakEvidence` normaliza stacks, classes, tamanhos e números de alocação.
11. O chat apresenta grupos ordenados por impacto e permite navegar até a origem.
12. O RadIA prepara a correção, recompila e repete o cenário.
13. `CompareMemoryLeakEvidence` classifica o resultado como `fixed`, `improved`, `unchanged`,
    `regressed` ou `incomparable`.
14. A instrumentação temporária é revertida e a regressão fica versionada.

## Ferramentas planejadas

| Ferramenta | Responsabilidade | Risco |
|---|---|---|
| `GetMemoryDiagnosticsStatus` | Detectar backend, configuração, target e prontidão. | Leitura |
| `PrepareFastMMInstrumentation` | Criar preview transacional sem alterar o projeto. | Leitura |
| `ApplyFastMMInstrumentation` | Aplicar somente o preview aprovado à configuração Debug. | Mutação |
| `RevertFastMMInstrumentation` | Restaurar DPR, opções e artefatos alterados. | Mutação |
| `PrepareMemoryDiagnosticScenario` | Associar cenário, snapshots, limites e encerramento. | Leitura |
| `RunMemoryDiagnosticScenario` | Executar o cenário limitado sob o backend configurado. | Execução |
| `CancelMemoryDiagnosticScenario` | Cancelar cenário e coleta imediatamente. | Controle |
| `GetMemoryDiagnosticStatus` | Informar fase, repetição, memória e eventos coletados. | Leitura |
| `CaptureMemoryLeakEvidence` | Normalizar relatório, stacks, blocos e métricas. | Leitura |
| `GetMemoryLeakReport` | Consultar grupos, alocações e origem navegável. | Leitura |
| `CompareMemoryLeakEvidence` | Comparar baseline e verificação de builds distintos. | Leitura |
| `NavigateToLeakAllocation` | Abrir arquivo e linha da stack selecionada. | Navegação |
| `SetAllocationBreakpoint` | Preparar break em número de alocação validado. | Debug |
| `SaveMemoryRegression` | Versionar cenário e expectativas de memória. | Mutação |
| `RunMemoryRegression` | Reexecutar a regressão com limites aprovados. | Execução |

Os nomes definitivos dependerão do baseline para evitar duplicação com ferramentas atuais. Cada
ferramenta nova deverá aparecer automaticamente no catálogo das ferramentas internas.

## Arquitetura

### Núcleo independente

Criar contratos que não dependam de FastMM5:

- `IRadIAMemoryDiagnosticsFacade`;
- `IRadIAMemoryDiagnosticsBackend`;
- `TRadIAMemoryDiagnosticSession`;
- `TRadIAMemoryEvidence`;
- `TRadIAMemoryEvidenceComparison`;
- `TRadIAMemoryRegression`.

O primeiro backend será `TRadIAFastMM5Backend`. Backends futuros poderão interpretar outros
coletores sem alterar o runtime agentivo.

### Instrumentação transacional

A instrumentação deverá:

- modificar apenas configuração Debug selecionada;
- inserir `FastMM5` na posição válida do DPR usando parser, nunca substituição textual cega;
- configurar saída em diretório confinado dentro de `.radia`;
- validar DLL Win32 ou Win64 conforme o target da aplicação;
- preservar encoding, line endings e buffers não salvos;
- produzir fingerprint e preview;
- impedir apply quando DPR, `.dproj` ou dependência mudar;
- reverter integralmente arquivos e opções;
- não persistir caminhos absolutos pessoais em arquivos versionados.

### Coleta

O backend combinará:

- arquivo de eventos em encoding detectado;
- mensagens `OutputDebugString` correlacionadas ao PID;
- snapshots antes/depois, quando suportados pela versão configurada;
- encerramento normal e encerramento excepcional identificados separadamente;
- MAP, símbolos e stack do debugger para resolução de origem.

Nenhum parser dependerá de texto localizado sem fallback. O relatório bruto será preservado como
artefato local, e a evidência estruturada será sanitizada antes de chegar ao chat ou MCP.

### Comparação

Uma comparação só será válida quando coincidir:

- projeto e executável;
- target e arquitetura;
- cenário e parâmetros;
- backend e versão;
- política de snapshot;
- encerramento controlado;
- builds diferentes para falha e verificação.

Além de leaks finais, a comparação considerará bytes e blocos vivos após aquecimento, inclinação de
crescimento entre repetições e grupos de stacks equivalentes.

## Segurança e consentimento

- Nenhuma instrumentação automática sem preview e consentimento.
- Somente o processo correlacionado à sessão atual poderá ser observado.
- Logs serão confinados ao workspace e sujeitos à política de retenção.
- Strings, buffers e conteúdo de blocos não serão enviados ao modelo por padrão.
- Endereços serão representados por IDs opacos fora da camada local.
- Caminhos pessoais e argumentos sensíveis serão sanitizados.
- Limites de duração, repetições, tamanho de log e uso de disco serão obrigatórios.
- Full Debug Mode terá aviso de impacto de desempenho e memória.
- O usuário poderá cancelar e reverter a instrumentação a qualquer momento.

## Marcos de execução

### M0 — Baseline, licença e laboratório

- congelar contratos oficiais da versão FastMM5 validada;
- mapear DPR, `.dproj`, MAP e diferenças Win32/Win64;
- criar aplicação-laboratório com leak determinístico, crescimento transitório, double free e
  cenário sem leak;
- definir schemas de sessão, evento, stack, grupo, evidência e comparação;
- comprovar manualmente os casos nos três targets.

**Aceite:** relatórios reproduzíveis e fixtures anonimizadas para todas as classes de evento.

### M1 — Detecção e configuração

- implementar backend abstrato e detector FastMM5;
- adicionar configurações de caminho, versão, DLLs e política de licença;
- validar compatibilidade por target;
- expor doctor e `GetMemoryDiagnosticsStatus`;
- documentar instalação sem redistribuição.

**Aceite:** prontidão correta para ausente, inválido, incompatível e configurado.

### M2 — Instrumentação reversível

- implementar prepare/apply/revert transacional;
- preservar buffers, encoding e configurações não relacionadas;
- suportar sessão temporária e Debug persistente;
- validar fingerprint antes do apply;
- restaurar o projeto mesmo após build ou execução interrompidos.

**Aceite:** round-trip sem diff residual nos três targets e rejeição de preview obsoleto.

### M3 — Coleta e parser

- capturar arquivo e `OutputDebugString`;
- interpretar leak summary/detail, stacks, classes, bytes e números de alocação;
- reconhecer corrupção, double free e use-after-free;
- resolver endereço para unit/linha quando símbolos estiverem disponíveis;
- limitar e sanitizar artefatos.

**Aceite:** fixtures e aplicações reais geram o mesmo modelo estruturado.

### M4 — Cenário, snapshots e evidência

- integrar com os cenários runtime da v2.1;
- adicionar aquecimento, baseline, repetições e snapshots;
- executar encerramento controlado;
- gerar evidência com fingerprint;
- mostrar relatório navegável no chat e via MCP.

**Aceite:** o leak determinístico é reproduzido e localizado nos três targets.

### M5 — Correção, comparação e regressão

- preparar correção revisável a partir da stack de alocação;
- repetir cenário em build e sessão novos;
- classificar `fixed`, `improved`, `unchanged`, `regressed` ou `incomparable`;
- adicionar break por número de alocação;
- salvar e executar regressões versionadas.

**Aceite:** o caso-laboratório passa de leak confirmado para `fixed`, sem falsos positivos no caso
controle.

### M6 — Hardening e release 2.2.0

- executar dez ciclos por target;
- validar cancelamento, timeout, shutdown e restauração do projeto;
- medir overhead e tamanho máximo de logs;
- concluir documentação das ferramentas, configuração e troubleshooting;
- executar builds, testes, Web, lint, Sonar e smokes de instalação;
- gerar, instalar e validar os três pacotes e o instalador visual;
- publicar release somente após todos os gates.

**Aceite:** Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 aprovados, sem regressões no fluxo
runtime existente.

## Ordem por complexidade

| Ordem | Entrega | Complexidade |
|---:|---|---|
| 1 | M0 — baseline e laboratório | Média |
| 2 | M1 — detecção e configuração | Média |
| 3 | M3 — parser de relatórios | Alta |
| 4 | M2 — instrumentação transacional | Alta |
| 5 | M4 — cenários e snapshots | Alta |
| 6 | M5 — correção e regressão | Muito alta |
| 7 | M6 — hardening e release | Alta |

O parser será desenvolvido antes do apply para permitir testes com fixtures sem modificar projetos.

## Definição de pronto

O goal estará concluído quando o usuário puder:

1. configurar uma instalação FastMM5 própria;
2. revisar e aplicar instrumentação somente em Debug;
3. reproduzir um leak por cenário visual ou fluxo de teste;
4. receber grupos de alocações com stack, arquivo e linha;
5. navegar para a origem e preparar uma correção;
6. repetir o mesmo cenário em outro build;
7. comprovar a remoção do leak por evidência comparável;
8. manter uma regressão executável;
9. reverter a instrumentação sem alteração residual;
10. executar tudo nos três targets suportados.

## Fora do escopo da 2.2.0

- redistribuir ou sublicenciar FastMM5;
- instrumentar builds Release por padrão;
- anexar a processos que não foram iniciados pela sessão autorizada;
- substituir análise de recursos GDI, handles, COM ou GPU por análise de heap;
- suportar FastMM4, madExcept, EurekaLog ou outros backends nesta versão;
- enviar conteúdo bruto de blocos de memória a providers.
