# Guia de integração MCP

## Visão geral

O servidor MCP do RadIA expõe o catálogo agentivo da IDE para clientes locais. O transporte entre a
bridge e a IDE usa named pipe do Windows; nenhuma porta TCP é aberta por padrão.

## Pré-requisitos

- RadIA instalado e carregado em uma IDE compatível.
- Um projeto aberto quando a ferramenta exigir contexto de workspace.
- `RadIA.MCP.Bridge.exe` instalado ao lado da BPL.
- Cliente com suporte a MCP por entrada e saída padrão.

## Descoberta da IDE

Cada processo publica `%APPDATA%\RadIA\mcp.<pid>.json`. O arquivo
`%APPDATA%\RadIA\mcp.json` aponta para a instância compatível mais recente.

Sem argumento, a bridge usa `mcp.json`:

```powershell
& "C:\caminho\RadIA.MCP.Bridge.exe"
```

Para selecionar uma IDE específica, informe o discovery correspondente:

```powershell
& "C:\caminho\RadIA.MCP.Bridge.exe" `
  "$env:APPDATA\RadIA\mcp.12345.json"
```

Não selecione um arquivo apenas pela data quando houver várias IDEs. Relacione o PID do nome ao
processo `bds.exe` desejado. O discovery é removido quando o processo termina normalmente.

## Sessão MCP

O cliente deve enviar `initialize` antes de `tools/list` ou `tools/call`. A bridge transporta as
mensagens MCP por stdio e encaminha as solicitações para o named pipe descoberto.

Sequência recomendada:

1. iniciar a bridge;
2. enviar `initialize`;
3. consultar `tools/list`;
4. chamar uma ferramenta com `tools/call`;
5. tratar resultados, erros e cancelamentos;
6. encerrar a bridge ao finalizar a sessão.

O catálogo retornado por `tools/list` é autoritativo para a instância. Não mantenha schemas
copiados indefinidamente, pois extensões locais podem adicionar ou remover ferramentas.

## Consentimento

Chamadas externas seguem exatamente as políticas do chat. Uma ferramenta mutável pode abrir um
diálogo nativo na IDE. O cliente deve aguardar a decisão; não há autorização implícita por usar MCP.

Consentimentos de sessão são limitados por cliente, sessão, projeto, ferramenta e escopo. Timeout,
negação ou shutdown da IDE encerram a solicitação com falha segura.

## Segurança e limites

- O transporte é local e usa ACL do usuário.
- Payloads, concorrência e tempo de execução possuem limites.
- O workspace boundary também se aplica a caminhos recebidos por MCP.
- Secrets são removidos da auditoria e de mensagens de erro conhecidas.
- O cliente deve suportar erro estruturado, timeout e cancelamento.

Consulte o [modelo de segurança](tool_security_model.md) e o
[catálogo de ferramentas](tool_catalog.md).

## Diagnóstico rápido

- **Bridge encerra imediatamente:** confirme que a IDE está aberta e que o discovery existe.
- **Instância errada:** passe explicitamente `mcp.<pid>.json`.
- **Tool indisponível:** execute novamente `tools/list` e verifique o contexto exigido.
- **Solicitação pendente:** procure o diálogo de consentimento na IDE.
- **Pipe não encontrado:** confirme se o PID ainda existe e reinicie a bridge.
- **Discovery órfão:** feche a bridge, confirme que o PID não existe e reabra a IDE.
