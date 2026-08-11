# M1 — Correlação e espera do depurador

> **Estado histórico:** implementação e validação na IDE concluídas para a versão 2.1.0.
> **Goal:** [Reprodução autônoma de falhas runtime](runtime_debug_automation_plan.md).

## Entregas

- coordenador thread-safe para sessão, processo e eventos runtime;
- identidade por sessão, PID real do Windows, instante de criação, projeto, executável e build;
- fingerprint do build formado pelo tamanho e pela data UTC do executável iniciado;
- invalidação imediata de esperas quando uma nova sessão começa;
- espera por condição sem polling, com timeout máximo de cinco minutos;
- cancelamento imediato por comando, agente ou pedido MCP;
- captura estruturada da pilha em eventos de parada e exceção;
- integração com `IOTADebuggerNotifier`;
- retenção limitada aos 500 eventos runtime mais recentes.

## Ferramentas

| Ferramenta | Uso |
|---|---|
| `GetRuntimeDebugSession` | Confirma a identidade correlacionada e a última sequência. |
| `WaitForDebuggerEvent` | Aguarda execução, parada, exceção, término ou janela. |
| `CancelDebuggerWait` | Cancela uma espera ativa explicitamente. |

`WaitForDebuggerEvent` também recebe o token de cancelamento comum. Portanto, cancelar o agente ou
um pedido MCP acorda a espera imediatamente, sem depender de uma segunda chamada.

## Estados observados

| Estado OTA | Evento runtime |
|---|---|
| `psRunning` | `running` |
| `psStopped` | `stopped` |
| `psException`, `psFault`, `psResFault` | `exception` |
| `psTerminated`, `psNoProcess` | `processExited` |

Uma parada não é classificada automaticamente como breakpoint porque a OTA não oferece uma origem
confiável nesse callback. A pilha e o estado são retornados sem inventar essa distinção.

## Evidências automatizadas

- sessão incompleta não pode ser usada;
- sessão antiga não pode anexar um processo;
- troca de sessão invalida a espera;
- timeout usa condição, sem busy-wait;
- cancelamento direto acorda a espera;
- cancelamento do contrato comum interrompe a ferramenta;
- exceção retorna PID, detalhes e pilha estruturada;
- catálogo verificável contém 98 ferramentas.

## Evidência ainda pendente

O aceite final de M1 exige iniciar a aplicação-laboratório nos três hosts e comprovar que a Access
Violation retorna evento `exception` e pilha estruturada. Essa verificação permanece junto da
pendência visual do M0.

## O que falta para o goal

- evidência M0/M1 dentro dos três hosts;
- M2: descoberta segura de janelas e controles;
- M3: execução declarativa limitada;
- M4: ciclo de diagnóstico, correção e repetição;
- M5: regressão, evidências e hardening.
