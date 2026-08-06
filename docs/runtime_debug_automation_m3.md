# M3 — Execução declarativa limitada

> **Estado:** implementação e testes automatizados concluídos; validação dentro da IDE pendente.
> **Goal:** [Reprodução autônoma de falhas runtime](runtime_debug_automation_plan.md).

## Entregas

- preparação separada da execução, com preview identificado e fingerprint imutável;
- validação de todas as ações e capacidades antes de criar o preview;
- consentimento de execução obrigatório em cada chamada, sem permissão lembrada para a sessão;
- revalidação da sessão e do alvo imediatamente antes de cada ação;
- execução sequencial limitada por número de ações, duração e repetições;
- suporte a invocar, preencher, selecionar, fechar, cancelar, aguardar e verificar texto;
- status estruturado com repetição, ação corrente, ações concluídas e falha;
- cancelamento imediato de esperas pelo agente, MCP ou ferramenta de parada;
- mensagens Windows limitadas a um segundo para manter a parada responsiva;
- recusa de controles de senha, IDs desconhecidos, janelas externas e capacidades ausentes.

## Ferramentas

| Ferramenta | Risco | Uso |
|---|---|---|
| `PrepareRuntimeScenario` | Somente leitura | Valida e registra o roteiro sem executar ações. |
| `RunRuntimeScenario` | Execução | Solicita consentimento e executa exatamente o preview informado. |
| `CancelRuntimeScenario` | Somente leitura | Aciona a parada de emergência sem abrir diálogo de consentimento. |
| `GetRuntimeScenarioStatus` | Somente leitura | Consulta progresso, resultado ou motivo da interrupção. |

`RunRuntimeScenario` usa a política `ConsentEveryTime`. Mesmo que o usuário permita lembrar outras
ações de execução durante a sessão, cada cenário runtime volta a exigir uma decisão explícita.

## Formato do cenário

```json
{
  "name": "Abrir e cancelar o formulário-alvo",
  "limits": {
    "maxActions": 2,
    "maxDurationMs": 10000,
    "maxRepetitions": 1
  },
  "actions": [
    {
      "kind": "invoke",
      "targetId": "<controlId retornado pela descoberta>",
      "timeoutMs": 1000
    },
    {
      "kind": "cancel",
      "targetId": "<windowId ou controlId autorizado>",
      "timeoutMs": 1000
    }
  ]
}
```

Os tipos aceitos são `invoke`, `setValue`, `select`, `close`, `cancel`, `wait` e `assert`. A ação
`wait` não recebe alvo. `setValue`, `select` e `assert` recebem `value`. Coordenadas, PID, caminho de
executável e handles não fazem parte do contrato.

## Evidências automatizadas

- cenário inválido ou alvo sem capacidade é rejeitado na preparação;
- troca de sessão invalida o preview;
- repetições executam a sequência esperada;
- falha interrompe as ações posteriores;
- cancelamento acorda uma espera de cinco segundos em menos de dois segundos;
- botão autorizado é invocado e editor autorizado é alterado;
- campo de senha é recusado;
- ferramenta `Run` exige consentimento a cada execução;
- ferramenta `Cancel` permanece disponível sem consentimento;
- catálogo verificável contém 104 ferramentas;
- 794 testes passam sem vazamentos no primeiro alvo validado.

## Evidência ainda pendente

O aceite final de M3 exige executar a aplicação-laboratório dentro dos três hosts, preparar o roteiro
com os controles descobertos, revisar o preview, autorizar a execução e reproduzir a falha ao abrir
ou cancelar o formulário-alvo sem tocar em uma janela externa.

## O que falta para o goal

- evidência M0–M3 dentro dos três hosts;
- M4: ciclo de diagnóstico, correção e repetição;
- M5: regressão, evidências e hardening.
