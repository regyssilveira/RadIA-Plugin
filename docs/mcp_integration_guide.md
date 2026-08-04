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

## Configuração de um cliente

Clientes que aceitam servidores MCP por comando podem usar uma configuração equivalente a:

```json
{
  "mcpServers": {
    "radia-delphi": {
      "command": "C:\\caminho\\RadIA.MCP.Bridge.exe",
      "args": [
        "C:\\Users\\usuario\\AppData\\Roaming\\RadIA\\mcp.12345.json"
      ]
    }
  }
}
```

Remova `args` para usar automaticamente `mcp.json`. O nome do campo raiz varia entre clientes;
consulte a documentação do cliente, mas preserve `command` e o argumento de discovery.

O executável instalado normalmente fica em:

```text
C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\RadIA.MCP.Bridge.exe
C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\Win64\RadIA.MCP.Bridge.exe
```

Use a bridge da mesma arquitetura do package carregado. Não copie apenas o executável: ele depende
do discovery publicado pela IDE.

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

### Métodos implementados

- `initialize`
- `notifications/initialized`
- `ping`
- `tools/list`
- `tools/call`

O protocolo negociado pela versão 1.0 é `2025-06-18`.

Exemplo conceitual de inicialização:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {},
    "clientInfo": {
      "name": "my-client",
      "version": "1.0"
    }
  }
}
```

Depois da resposta, o cliente pode enviar `notifications/initialized` e consultar `tools/list`.

Exemplo de chamada:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "GetActiveProject",
    "arguments": {}
  }
}
```

Não escreva JSON-RPC manualmente quando o cliente já implementa MCP. Esses exemplos servem para
diagnóstico e desenvolvimento de integrações.

## Capacidades expostas

O MCP publica o mesmo registry do chat, incluindo tools disponíveis para:

- IDE, projeto, units, arquivos e editor;
- patches revisáveis;
- build e mensagens do compilador;
- Form Designer;
- debugger, breakpoints e watches;
- revisão inline;
- conhecimento local;
- extensões carregadas na IDE.

Execute `tools/list` em cada conexão. O [catálogo técnico](tool_catalog.md) contém a visão de
arquitetura, mas somente o resultado runtime confirma o que está registrado naquela IDE.

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

## Várias IDEs simultâneas

Cada `mcp.<pid>.json` representa somente um processo:

1. identifique o PID da IDE desejada;
2. associe o projeto aberto nessa IDE;
3. configure uma instância da bridge para aquele discovery;
4. use nomes distintos no cliente, como `radia-project-a` e `radia-project-b`;
5. não compartilhe consentimento entre as conexões.

O arquivo `mcp.json` é conveniente para uma única IDE, mas pode mudar quando outra instância inicia.
Para automação reproduzível, prefira sempre `mcp.<pid>.json`.

## Verificação operacional

1. Abra o Delphi e um projeto.
2. Confirme que `mcp.<pid>.json` foi criado.
3. Inicie ou recarregue o servidor no cliente MCP.
4. Verifique que `initialize` retorna RadIA `2.0.0`.
5. Execute `tools/list`.
6. Chame `GetIDEState` e `GetActiveProject`.
7. Para testar consentimento, use uma tool mutável somente em um projeto descartável.
8. Feche a IDE e confirme que discovery e conexão são encerrados.

## Diagnóstico rápido

- **Bridge encerra imediatamente:** confirme que a IDE está aberta e que o discovery existe.
- **Instância errada:** passe explicitamente `mcp.<pid>.json`.
- **Tool indisponível:** execute novamente `tools/list` e verifique o contexto exigido.
- **Solicitação pendente:** procure o diálogo de consentimento na IDE.
- **Pipe não encontrado:** confirme se o PID ainda existe e reinicie a bridge.
- **Discovery órfão:** feche a bridge, confirme que o PID não existe e reabra a IDE.
- **Sem resposta após tool mutável:** verifique o diálogo nativo de consentimento.
- **Schema inválido:** descarte o cache local do catálogo e execute novamente `tools/list`.
- **Projeto incorreto:** selecione explicitamente o discovery do PID correto.

Consulte também o [Manual Completo do RadIA](user_manual.md).

## Provisionamento seguro dos clientes CLI

O RadIA 2.0 possui um mecanismo de provisionamento para Codex CLI, Claude Code, Gemini CLI e
GitHub Copilot CLI. A integração visual ainda será ligada à tela de configurações, mas o contrato
central já garante que o processo siga estas etapas:

1. detectar se a configuração está ausente, válida, divergente ou inválida;
2. gerar uma prévia sem alterar o arquivo;
3. confirmar que `RadIA.MCP.Bridge.exe` existe;
4. preservar servidores MCP e preferências que não pertencem ao RadIA;
5. criar `<configuração>.radia.bak` antes de qualquer alteração;
6. inserir ou reparar somente a entrada `radia`;
7. reler e validar o arquivo gravado;
8. restaurar o backup automaticamente se a validação falhar;
9. remover somente a entrada gerenciada quando o usuário desconectar o cliente.

Arquivos JSON são mesclados como objetos, preservando as demais propriedades. No `config.toml` do
Codex, o RadIA controla apenas o bloco delimitado por `BEGIN/END RadIA managed MCP server`; todo o
conteúdo externo ao bloco permanece intacto. Configurações inválidas nunca são sobrescritas.

O backup é deliberadamente estável e representa o estado imediatamente anterior à última mutação.
Antes de provisionar ou remover pela interface, o RadIA sempre deverá apresentar a prévia e solicitar
consentimento explícito.
