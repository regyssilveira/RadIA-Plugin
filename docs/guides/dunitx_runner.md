# Runner DUnitX estruturado

O RadIA executa testes DUnitX sem depender da interpretação do texto exibido no console. O runner
gera XML no formato NUnit, que é convertido para JSON antes de retornar ao chat, modo agente ou MCP.

## Tools

- `RunDUnitXTests`: recebe `executablePath`, `timeoutMs` opcional e uma lista opcional `tests`.
- `GetDUnitXStatus`: consulta o estado da execução.
- `CancelDUnitXTests`: cancela o processo ativo.

Exemplo:

```json
{
  "executablePath": "Output\\Win32\\Debug\\MyProjectTests.exe",
  "timeoutMs": 120000,
  "tests": [
    "TOrderServiceTests.CreatesOrder"
  ]
}
```

O resultado contém status da execução, exit code, duração, saída capturada e relatório com totais,
fixtures, casos, status, duração, mensagem de falha e stack trace.

## Contrato do executável

O projeto de testes deve processar as opções do DUnitX e registrar o logger NUnit:

```pascal
TDUnitX.CheckCommandLine;
Runner := TDUnitX.CreateRunner;
Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
Runner.AddLogger(
  TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile)
);
```

O template DUnitX do RadIA já gera esse contrato.

## Segurança e ciclo de vida

- O projeto ativo determina a raiz autorizada.
- O executável precisa estar dentro dessa raiz e ter extensão `.exe`.
- Caminhos contendo reparse points são recusados.
- Apenas uma execução pode permanecer ativa por instância da IDE.
- Timeout e cancelamento encerram o processo de teste.
- XML e log são preservados em `.radia/test-results`.
- Executar testes exige consentimento de risco de execução.

## Compatibilidade validada

O parser, as tools e o executor compilam e passam pela suíte do RadIA no Delphi 12 e 13. O
package e os testes também foram validados para a IDE Win64 do Delphi 13.
