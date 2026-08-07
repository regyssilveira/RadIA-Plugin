# Sessão completa de diagnóstico de memória

O RadIA pode combinar instrumentação FastMM5, build, processo supervisionado, automação visual e interpretação de
evidências em uma única sessão reversível. O fluxo funciona no chat, no modo agente e via MCP porque
usa o mesmo catálogo interno de ferramentas.

## Fluxo recomendado

1. Configure o FastMM5 em **Tools > Options > Rad IA > Memory Diagnostics**.
2. Confirme que o projeto ativo usa **Debug** e Win32 ou Win64.
3. Prepare um cenário runtime com `PrepareMemoryDiagnosticSession`.
4. Revise o DPR, as ações, o aquecimento, as repetições e os limites apresentados.
5. Autorize `RunMemoryDiagnosticSession`.
6. Acompanhe com `GetMemoryDiagnosticSessionStatus` ou interrompa com
   `CancelMemoryDiagnosticSession`.

A execução aprovada:

- aplica temporariamente o FastMM5 ao DPR;
- compila o projeto ativo;
- inicia uma nova instância da aplicação como processo supervisionado;
- aguarda a identidade segura do novo processo;
- executa aquecimento antes da medição;
- captura snapshots de memória do processo antes e depois das repetições medidas;
- aguarda o encerramento natural para que o FastMM5 finalize o relatório e força a parada somente
  após timeout ou cancelamento;
- interpreta `.radia/memory/latest-fastmm5.log`;
- devolve grupos de leaks ou erros, stacks, linhas, fingerprints e snapshots;
- restaura o conteúdo original do DPR em um bloco de finalização.

## Exemplo pelo chat

```text
/tool PrepareMemoryDiagnosticSession {
  "warmupRepetitions": 1,
  "scenario": {
    "name": "Abrir e cancelar cadastro",
    "limits": {
      "maxActions": 4,
      "maxDurationMs": 60000,
      "maxRepetitions": 5
    },
    "actions": [
      {
        "kind": "invoke",
        "selector": {"controlName": "OpenCustomerButton"},
        "timeoutMs": 5000
      },
      {
        "kind": "cancel",
        "selector": {"controlName": "CustomerForm"},
        "timeoutMs": 5000
      }
    ]
  }
}
```

O preview retorna um `previewId`. Depois da revisão:

```text
/tool RunMemoryDiagnosticSession {"previewId":"<id retornado>"}
```

## Consentimento e recuperação

Preparar é somente leitura. Executar sempre exige consentimento porque modifica temporariamente o
DPR, compila e inicia um processo. No modo de sessão, a reversão é obrigatória mesmo quando build,
processo, cenário, parser ou cancelamento falham. Uma falha de restauração é relatada como erro e
nunca é ocultada por um resultado anterior.

Os snapshots representam memória privada e working set observados pelo Windows. A evidência
detalhada de blocos, classes e stacks vem do FastMM5.

Se a IDE for encerrada abruptamente durante a instrumentação, o journal local permite restauração
segura na próxima preparação. Uma edição divergente do usuário sempre vence e produz um conflito
explícito, em vez de ser sobrescrita.

## Da evidência à correção

1. Selecione um grupo retornado pela sessão.
2. Execute `PrepareMemoryDiagnosticFix` com a evidência e o fingerprint do grupo.
3. O RadIA ignora frames do RTL, VCL e FastMM5 e retorna o primeiro frame do projeto com arquivo,
   linha, rotina e número da alocação.
4. Revise a alteração sugerida pelo `PreparePatch`.
5. Para parar exatamente na origem, prepare nova instrumentação com `allocationNumber`.
6. Faça novo build e repita o mesmo cenário em uma nova sessão.
7. Use `CompareMemoryDiagnosticEvidence` para obter `fixed`, `improved`, `unchanged`, `regressed`
   ou `incomparable`.

A comparação só é válida para builds distintos com o mesmo fingerprint de cenário. Isso evita
declarar uma correção quando o fluxo executado mudou.

## Limites e interpretação

- o tempo global limita também a ação que estiver em execução;
- cada sessão aceita no máximo 10 repetições;
- o log padrão é limitado a 50 MiB;
- conteúdo bruto de blocos não é enviado ao modelo;
- snapshots do Windows ajudam a observar tendência, mas grupos e stacks do FastMM5 são a evidência
  usada para localizar leaks e erros de heap;
- GDI, handles, COM e GPU precisam de coletores próprios e não são classificados como heap FastMM5.
