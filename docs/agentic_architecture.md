# Arquitetura Agentiva do RadIA

## 1. Objetivo

Este documento define a arquitetura-alvo para evoluir o RadIA de um chat multi-provider para uma
plataforma agentiva segura e integrada à IDE Delphi.

A arquitetura deve permitir que o chat nativo e clientes externos utilizem as mesmas capacidades
do workspace, sem duplicar regras de acesso à Open Tools API (OTA), consentimento ou auditoria.

Esta especificação é uma implementação independente. Nenhum código, recurso, texto ou contrato
interno de produtos analisados como referência deve ser copiado.

## 2. Princípios

1. O registro interno de ferramentas é independente de MCP, UI e providers.
2. O MCP é um adaptador de transporte, não o núcleo do produto.
3. Toda dependência de `ToolsAPI`, `DesignIntf` ou interfaces internas da IDE fica em `Source/Integration`.
4. O Core trabalha apenas com contratos e tipos próprios do RadIA.
5. Leituras e mutações passam pela mesma cadeia de políticas.
6. Uma mutação deve possuir precondições, consentimento, auditoria e resultado verificável.
7. Operações OTA e VCL executam na main thread.
8. Rede, indexação, parsing pesado e processos externos executam em background.
9. Toda operação deve aceitar cancelamento e respeitar o ciclo de vida do wizard.
10. Recursos não suportados por determinada IDE devem falhar de forma explícita e previsível.

## 3. Visão de componentes

```text
Chat Presenter ----------------------+
                                      |
CLI Provider -> MCP Transport --------+--> Tool Registry
                                      |         |
Future Automation Adapter ------------+         v
                                           Policy Pipeline
                                               |
                             +-----------------+-----------------+
                             |                                   |
                             v                                   v
                      Workspace Facade                     Knowledge Search
                             |
                   Integration/OTA Adapters
                             |
                         Delphi IDE

Policy Pipeline --> Consent Service
Policy Pipeline --> Audit Log
Policy Pipeline --> Sensitive Data Redactor
```

## 4. Camadas

### 4.1 Core

Responsabilidades:

- Descritores e schemas das ferramentas.
- Registro e descoberta de ferramentas.
- Contexto de execução.
- Cadeia de políticas.
- Consentimento abstrato.
- Auditoria abstrata.
- Tipos da fachada de workspace.
- Representação de patches e precondições.
- Tipos de conhecimento e busca.

O Core não deve importar `ToolsAPI`, `Vcl.*`, WebView2 ou implementações de transporte.

### 4.2 Integration

Responsabilidades:

- Implementar a fachada de workspace usando OTA.
- Fazer marshalling para a main thread.
- Resolver projeto, module, source editor, edit view e form editor.
- Detectar capacidades disponíveis na versão atual da IDE.
- Integrar build, debugger, project group e designer.
- Preservar buffers vivos e alterações ainda não salvas.

### 4.3 UI

Responsabilidades:

- Mostrar chamadas de ferramentas.
- Solicitar consentimento.
- Exibir progresso, resultado, arquivos afetados e auditoria.
- Apresentar diff e permitir aceitar ou rejeitar.
- Nunca executar OTA diretamente.

### 4.4 Transport

Responsabilidades:

- Traduzir MCP para o registro interno.
- Autenticar a instância local.
- Aplicar limites de payload e timeout.
- Encerrar junto ao ciclo de vida do plugin.

Implementação atual:

- `TRadIAMcpProtocol` traduz JSON-RPC/MCP para o registry sem duplicar ferramentas.
- `TRadIANamedPipeMcpServer` mantém o transporte local fora do Core e cria uma sessão por cliente.
- O endpoint efêmero usa ACL do Windows limitada ao owner e ao sistema.
- `RadIAMcpBridge.exe` adapta o pipe privado ao transporte stdio padrão do MCP.
- Requisições externas passam pelo executor de políticas com origem, sessão e projeto.
- `notifications/cancelled` sinaliza tokens cooperativos enquanto a chamada continua em background.
- Cada conexão aceita uma chamada em voo; excesso de concorrência retorna erro JSON-RPC `-32003`.
- Durante o splash, negociação e catálogo continuam disponíveis, mas `tools/call` retorna `-32004`
  até existir uma janela principal `TAppBuilder` visível. O cliente deve aguardar e repetir.
- `radia/metrics` retorna somente contadores sanitizados e não inclui prompts, argumentos ou código.
- Cada processo publica descoberta própria por PID; o arquivo legado só é removido pela instância
  que ainda comprova ownership do endpoint.
- O shutdown interrompe o worker antes de liberar logger, container e integração OTA.

### 4.5 Knowledge

Responsabilidades:

- Extrair símbolos e chunks do projeto.
- Manter índice incremental por workspace.
- Executar busca lexical e, futuramente, vetorial.
- Retornar fontes rastreáveis.
- Não decidir por conta própria quais mutações executar.

## 5. Contratos iniciais

Os nomes abaixo são propostas. A declaração Pascal definitiva deve ser criada somente no primeiro
slice de implementação.

### 5.1 Ferramentas

- `IRadIATool`
- `IRadIAToolRegistry`
- `IRadIAToolPolicy`
- `IRadIAToolExecutor`
- `TRadIAToolDescriptor`
- `TRadIAToolRequest`
- `TRadIAToolResult`
- `TRadIAToolContext`
- `TRadIAToolError`

Um descritor deve conter:

- Nome estável.
- Versão do contrato.
- Descrição em inglês para consumo por modelos.
- Schema de entrada.
- Schema de saída.
- Nível de risco.
- Capacidade exigida da IDE.
- Timeout padrão.
- Indicação de idempotência.

### 5.2 Workspace

- `IRadIAWorkspaceFacade`
- `IRadIAEditorReadService`
- `IRadIAEditorWriteService`
- `IRadIAProjectReadService`
- `IRadIAProjectWriteService`
- `IRadIABuildService`
- `IRadIADebugService`
- `IRadIALiveFormService`
- `IRadIAIDEStateService`

A fachada coordena os serviços, mas não deve se tornar uma classe monolítica. Cada serviço possui
responsabilidade única e pode ser substituído por fake nos testes.

### 5.3 Segurança

- `IRadIAConsentService`
- `IRadIAAuditLog`
- `IRadIASensitiveDataRedactor`
- `IRadIAWorkspaceBoundary`
- `TRadIAToolRisk`
- `TRadIAConsentDecision`
- `TRadIAAuditEvent`

### 5.4 Extensões

- `IRadIAToolExtension`
- `IRadIAToolExtensionRegistrar`
- `IRadIAToolExtensionHost`
- `IRadIAToolExtensionRegistration`
- `TRadIAToolExtensionDescriptor`

A API versionada fornece a extensões confiáveis somente um registrar limitado. As ferramentas são
validadas e publicadas atomicamente no registry compartilhado, portanto continuam sujeitas às mesmas
políticas, ao consentimento, à auditoria e aos limites do MCP. Cada extensão declara um prefixo de
ownership e mantém um token que remove suas ferramentas antes do descarregamento da BPL.

## 6. Fluxo de execução

### 6.1 Leitura

1. Consumidor cria uma requisição com identificador de correlação.
2. Registry resolve a ferramenta.
3. Executor valida schema, capacidade e ciclo de vida.
4. Policy classifica a ação.
5. Ferramenta consulta a fachada.
6. Resultado é limitado e sanitizado.
7. Auditoria registra metadados, sem conteúdo sensível.

### 6.2 Mutação

1. Ferramenta lê o estado vivo e calcula precondições.
2. Ferramenta produz um plano ou patch, sem alterar a IDE.
3. UI apresenta resumo e diff.
4. Consentimento é solicitado.
5. Precondições são verificadas novamente.
6. Mutação é aplicada na main thread.
7. Estado final é relido e comparado ao esperado.
8. Auditoria registra resultado e artefatos afetados.
9. Um identificador de reversão é devolvido quando aplicável.

### 6.3 Build agentivo

1. Alteração aprovada é aplicada.
2. Build é solicitado separadamente.
3. Mensagens são coletadas estruturadamente.
4. Erros podem alimentar nova proposta.
5. Cada nova mutação exige revisão conforme a política.
6. O número de iterações é limitado.
7. Executar a aplicação exige consentimento distinto do build.

## 7. Thread safety

- Chamadas OTA e VCL devem usar uma abstração única de dispatcher da main thread.
- A ferramenta nunca deve manter referências OTA após o término da chamada.
- Callbacks enfileirados verificam `IRadIALifecycleGuard`.
- Cancelamento impede novas etapas, mas não interrompe uma operação OTA no meio de uma escrita.
- Escritas devem ser pequenas, determinísticas e verificadas.
- Nenhum diálogo deve ser criado por uma thread secundária.

## 8. Shutdown

O encerramento seguro é requisito arquitetural:

1. Invalidar o lifecycle guard.
2. Recusar novas chamadas.
3. Cancelar operações de rede, indexação e processos filhos.
4. Encerrar listeners MCP.
5. Drenar apenas callbacks seguros.
6. Desassociar WebView2 conforme a política já existente.
7. Não liberar ativamente WebView2 quando `GIsShuttingDown` estiver ativo.
8. Evitar unload da BPL enquanto callbacks ainda possam executar.

## 9. Persistência

Na primeira fase, o registro de ferramentas não requer persistência.

Auditoria e conhecimento devem utilizar stores abstratos. SQLite pode ser adotado posteriormente,
desde que:

- Possua migrações versionadas.
- Use transações.
- Não armazene credenciais.
- Permita exportar dados portáveis.
- Tenha política clara de retenção e exclusão.

## 10. Fronteiras de implementação

### Incluído

- Chat nativo consumindo ferramentas internas.
- MCP consumindo o mesmo registry.
- Ferramentas OTA read-only e mutáveis.
- Consentimento e auditoria.
- Patches, build, designer, debugger e conhecimento.
- Pacotes locais de extensão usando a API pública versionada.

### Não incluído inicialmente

- Automação genérica do desktop.
- Terminal completo.
- Execução automática sem consentimento.
- Catálogo remoto de extensões.
- Banco vetorial obrigatório.
- Dependência obrigatória de Python.

## 11. Critérios arquiteturais

A arquitetura estará implementada quando:

- O chat não chamar OTA diretamente para executar ferramentas.
- MCP puder ser removido sem afetar o chat ou o registry.
- Ferramentas puderem ser testadas com uma fachada fake.
- Toda mutação passar por política, consentimento e auditoria.
- Capacidades não suportadas falharem sem crash.
- Shutdown encerrar transports e tarefas sem deadlock.
- A matriz Delphi aplicável estiver verde.
