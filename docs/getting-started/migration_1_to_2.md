# Migração do RadIA 1.x para 2.0

O RadIA 2.0 mantém as configurações de provedores e sessões da versão 1.x. A atualização substitui
o pacote da IDE, a bridge MCP e os recursos Web; não altera projetos Delphi automaticamente.

## Antes de atualizar

1. Feche todas as instâncias do Delphi.
2. Faça backup de `%APPDATA%\RadIA` se precisar preservar sessões e auditorias fora da política
   normal de retenção.
3. Confirme que não há builds, testes, depuração ou execução agentiva em andamento.

## Atualização

Execute na raiz do repositório:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 `
  -DelphiVersion "37.0" -Release -Install
```

Use `23.0` para Delphi 12 ou `37.0` para Delphi 13. Para a IDE64 do Delphi
13, acrescente `-IDE64`.

## Mudanças relevantes

- O painel usa o host nativo `TOTADockForm`, com restauração pelo desktop da IDE.
- O modo agente possui controle visual, cancelamento, pausa, retomada e checkpoints persistentes.
- Tools mutáveis exigem preview e consentimento conforme a política configurada.
- Operações permanecem confinadas ao workspace e são registradas na auditoria local.
- A jornada inclui templates, código, Form Designer, build, DUnitX, debugger e commit Git revisável.
- O catálogo MCP público contém 95 tools e negocia a versão pública `2.0.0`.

## Verificação

1. Abra o Delphi e confirme `Tools > Rad IA Chat Panel`.
2. Confirme que o painel renderiza chat, status e controle do modo agente.
3. Execute `initialize` e `tools/list` na bridge MCP; a versão deve ser `2.0.0` e o catálogo deve
   conter 95 tools.
4. Faça um build e um teste simples antes de retomar uma execução agentiva antiga.

Checkpoints incompatíveis ou incompletos devem ser descartados e recriados. O RadIA nunca converte
nem executa automaticamente uma mutação pendente durante a migração.
