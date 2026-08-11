# Guia de integração MCP

## Visão geral

O servidor MCP do RadIA expõe o catálogo agentivo da IDE para clientes locais. O transporte entre a
bridge e a IDE usa named pipe do Windows; nenhuma porta TCP é aberta por padrão.

O RadIA também possui o fluxo inverso: ele pode atuar como cliente de servidores MCP externos. Os
dois papéis são independentes:

- **RadIA como servidor:** disponibiliza as ferramentas da IDE por meio da bridge descrita neste guia;
- **RadIA como cliente:** descobre tools, resources e prompts de servidores locais e publica somente
  as tools que possuem concessão explícita no registry compartilhado do RadIA.

O runtime cliente é carregado junto com a IDE e pode trocar seu snapshot sem reiniciar o Delphi. Uma
falha de configuração, conexão ou descoberta preserva o catálogo interno e o último runtime válido.
`/status mcp` mostra somente contagens sanitizadas de servidores, concessões, tools, resources,
prompts e erros; `/doctor` inclui uma verificação separada quando o runtime externo está disponível.
Comando, argumentos, diretório de trabalho e paths concedidos não aparecem nesses diagnósticos.

Cadastre servidores em **Configurações > CLI & MCP > External MCP Servers**. Não edite
`external-mcp.settings`: o arquivo é um envelope DPAPI do usuário atual e não possui formato de
edição manual suportado.

### Consumir um servidor externo no RadIA

1. Abra **External MCP Servers** e preencha ID, nome, comando, argumentos, diretório e timeout; ou
   use **Import...** para carregar um JSON com `mcpServers`/`servers` no preview local.
2. Use **Add / Update** e confira a lista. Nenhum processo ou arquivo muda nessa etapa.
3. Clique **Test** para conectar e descobrir tools, resources e prompts sem publicar a tool.
4. Selecione uma tool descoberta e crie a concessão local com risco, consentimento e argumentos de
   path. Sem concessão, a tool permanece invisível ao agente.
5. Clique **Apply**, revise as quantidades e confirme. O snapshot é protegido por DPAPI e o runtime
   atualiza em background sem reiniciar o Delphi.
6. Confira `/status mcp`; em falha, execute `/doctor` e use **Refresh** depois da correção.

Remover um servidor também remove suas concessões do preview. Se **Apply**, **Refresh** ou a
descoberta falhar, o runtime anterior permanece ativo. Comandos, argumentos e paths nunca são
incluídos no diagnóstico sanitizado.

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
4. Verifique que `initialize` retorna RadIA `2.8.0`.
5. Execute `tools/list`.
6. Chame `GetIDEState` e `GetActiveProject`.
7. Para testar consentimento, use uma tool mutável somente em um projeto descartável.
8. Feche a IDE e confirme que discovery e conexão são encerrados.

## Diagnóstico rápido

- **Bridge encerra imediatamente:** confirme que a IDE está aberta e que o discovery existe.
- **Instância errada:** passe explicitamente `mcp.<pid>.json`.
- **Tool indisponível:** execute novamente `tools/list` e verifique o contexto exigido.
- **Solicitação pendente:** procure o diálogo de consentimento na IDE.
- O diálogo é o mesmo do chat, agente e terminal, identifica **MCP client** como origem e permanece
  acessível mesmo que o painel do chat esteja fechado. Chamadas concorrentes aguardam o slot único
  somente até o timeout configurado.
- **Pipe não encontrado:** confirme se o PID ainda existe e reinicie a bridge.
- **Discovery órfão:** feche a bridge, confirme que o PID não existe e reabra a IDE.
- **Sem resposta após tool mutável:** verifique o diálogo nativo de consentimento.
- **Schema inválido:** descarte o cache local do catálogo e execute novamente `tools/list`.
- **Projeto incorreto:** selecione explicitamente o discovery do PID correto.

Consulte também o [Manual Completo do RadIA](user_manual.md).

## Diagnóstico runtime por MCP

Um cliente MCP pode conduzir o mesmo ciclo disponível no modo agente:

1. `BuildProject` e `StartDebugging`;
2. `GetRuntimeDebugSession`, `GetRuntimeWindows` e `GetRuntimeControlTree`;
3. `PrepareRuntimeScenario` e, após consentimento na IDE, `RunRuntimeScenario`;
4. `CaptureRuntimeEvidence` com `phase=failure`;
5. aplicação revisada da correção, novo build e nova sessão;
6. repetição do cenário, captura com `phase=verification` e `CompareRuntimeEvidence`;
7. `PrepareRuntimeRegression`, `SaveRuntimeRegression` e posterior
   `PrepareSavedRuntimeScenario`.

O cliente nunca recebe autorização implícita. Builds, ações do depurador, execução visual e escritas
continuam exibindo o consentimento na IDE. Para detalhes, consulte
[Diagnóstico Runtime Autônomo](runtime_debug_automation.md).

## Provisionamento seguro dos clientes CLI

O RadIA 2.2 possui um mecanismo visual de provisionamento para Codex CLI, Claude Code, Gemini CLI e
GitHub Copilot CLI. O contrato central garante que o processo siga estas etapas:

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
Antes de provisionar ou remover pela interface, o Rad IA apresenta a prévia e solicita
consentimento explícito.

### Uso pela tela de configurações

Abra **RadIA > Settings > CLI & MCP** e siga este fluxo:

1. selecione Codex, Claude, Gemini ou GitHub Copilot;
2. use **Install** ou **Update** para revisar e executar opcionalmente o canal oficial, ou informe
   um executável CLI fora do `PATH`;
3. revise os caminhos sugeridos da configuração do cliente e da bridge;
4. clique em **Diagnose** para conferir a detecção do CLI e o estado MCP;
5. clique em **Preview** para revisar exatamente o conteúdo proposto;
6. use **Connect / Repair** e confirme o arquivo e o backup exibidos;
7. use **Test Handshake** para validar a bridge contra a instância atual da IDE;
8. use **Disconnect** para remover somente a entrada gerenciada pelo RadIA.

Os três caminhos são persistidos separadamente para cada cliente e restaurados quando a tela é
reaberta. Um campo vazio de executável mantém a detecção automática pelo `PATH`.

O botão de conexão fica desabilitado quando a bridge não existe, a configuração é inválida ou o
cliente já está configurado corretamente. Instalação de CLI e alteração MCP são operações
independentes e nenhuma delas ocorre sem confirmação visual.

### Diagnóstico de handshake

**Test Handshake** usa o discovery específico `mcp.<pid>.json` da IDE atual, e não o alias global
`mcp.json`. A bridge é iniciada em background e recebe por stdin a sequência:

1. `initialize` com a versão de protocolo suportada;
2. `notifications/initialized`;
3. `ping`;
4. `tools/list`.

O diagnóstico só fica verde quando a bridge encerra normalmente, as três respostas JSON-RPC são
válidas, a negociação retorna uma versão de protocolo e `tools/list` contém um array de
ferramentas. O painel mostra a quantidade real de tools registradas na instância. O processo possui
timeout de 30 segundos e sua árvore é encerrada se a tela for fechada.

## Smoke opt-in com servidor externo real

Mantenedores podem reproduzir a matriz com o servidor oficial de filesystem fixado na versão
`2026.7.10`. O fluxo exige Node.js com `npx`, baixa somente para o cache do `npx`, não usa
credenciais e cria um workspace temporário diferente em cada execução.

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ExternalMcpRealServer.ps1 `
  -Consent `
  -EvidencePath Output\Validation\ExternalMcp\real-server.json
```

Sem `-Consent`, o script encerra antes de qualquer download ou execução. Ele exige que os binários
de teste dos três targets já tenham sido compilados, executa somente a categoria opt-in, verifica a
limpeza dos artefatos temporários e gera evidência sem caminhos locais nem conteúdo de arquivos.
