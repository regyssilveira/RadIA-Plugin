# Sessão completa de diagnóstico de memória

O RadIA pode combinar instrumentação FastMM5, build, depuração, automação visual e interpretação de
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
- inicia a aplicação pelo debugger do Delphi;
- aguarda a identidade segura do novo processo;
- executa aquecimento antes da medição;
- captura snapshots de memória do processo antes e depois das repetições medidas;
- encerra o processo pelo debugger;
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
debugger, cenário, parser ou cancelamento falham. Uma falha de restauração é relatada como erro e
nunca é ocultada por um resultado anterior.

Os snapshots representam memória privada e working set observados pelo Windows. A evidência
detalhada de blocos, classes e stacks vem do FastMM5.

