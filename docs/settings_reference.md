# Referência completa das configurações

Este é o catálogo central das opções exibidas em **Tools > Options > Rad IA**. Use `Ctrl+F` para
procurar o texto de uma aba, campo ou botão exatamente como aparece na IDE. Para um roteiro inicial,
consulte o [manual do usuário](user_manual.md); para problemas, consulte a
[solução de problemas](troubleshooting_agentic_platform.md).

## Como usar esta referência

- **Quando alterar** explica a situação prática que justifica a opção.
- **Efeito e cuidados** explica o comportamento, dependências e impacto de segurança.
- Campos de segredo são protegidos localmente com Windows DPAPI e nunca devem ser colocados em logs,
  prompts, templates ou capturas de tela.
- Alterações de provider e modelo são recarregadas ao salvar; não é necessário reiniciar o Delphi.

## Providers

### Opções comuns a providers de IA

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| API Key | Ao conectar uma conta por chave | Autentica chamadas ao provider. É armazenada com DPAPI. A cobrança e os limites pertencem à conta do provider. |
| Obter API Key | Quando ainda não possui uma chave | Abre a página oficial do provider. O RadIA não cria, lê ou transmite a chave até o usuário inseri-la. |
| Temperature (0.0 - 1.0) | Para respostas mais determinísticas ou criativas | Valores baixos reduzem variação; valores altos ampliam variação. **Auto (Smart Parameters)** pode assumir esse ajuste. |
| Max Output Tokens | Para limitar o tamanho máximo de uma resposta | Não representa a janela total de contexto nem um limite de cobrança. Valores altos podem elevar tempo e custo. |
| Timeout (seconds) | Quando o provider ou a rede exige mais tempo | Cancela a espera local após o limite; não altera limites do serviço remoto. |

### Gemini

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Connection Method | Para escolher **API Key (BYOK)** ou **Web Login** | A chave usa a API do Google; o login usa a sessão autorizada pelo fluxo do provider. |
| Sign In with Google / Sign Out | Para iniciar ou encerrar a sessão web | Abre o login oficial e atualiza a sessão local. Salve a configuração depois de trocar o método. |

### OpenAI

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Connection Method | Para escolher API key ou **Sign in with ChatGPT** | API key funciona sem CLI. ChatGPT OAuth usa Codex CLI como transporte, mesmo com orquestração nativa. |
| Custom Base URL (optional) | Somente para endpoint compatível com OpenAI | Vazio usa o endpoint oficial. Informe a URL base completa, incluindo `/v1` quando o serviço exigir. |
| Sign In with ChatGPT / Sign Out | Para autorizar ou encerrar o transporte OAuth | Exige um Codex CLI resolvido em **CLI & MCP**. Não instala npm automaticamente sem confirmação. |

### Claude, DeepSeek, Groq, OpenRouter, Alibaba Qwen e Mistral AI

Essas abas usam **API Key** e as três opções avançadas comuns. Selecione o provider somente depois de
salvar uma chave válida. O link **Obter API Key** abre a página oficial correspondente.

### Ollama e LM Studio

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Server URL | Ao usar um servidor local ou de rede | Informe esquema, host e porta, por exemplo `http://localhost:11434`. HTTP deve ser usado somente em loopback ou rede confiável. |

Esses providers não exigem CLI nem chave de nuvem. O catálogo de modelos vem do servidor configurado;
se ele não responder, verifique processo, porta, firewall e URL.

### GitHub Copilot

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| GitHub User Token | Quando já possui um token compatível | O token é protegido com DPAPI. Use apenas tokens da própria conta. |
| Conectar Conta do GitHub | Para autorizar pelo device flow | Exibe o código e abre o fluxo oficial do GitHub; o RadIA salva o token após autorização. |
| Importar do VS Code | Quando o VS Code já possui uma sessão válida | Importa as credenciais locais compatíveis. Não modifica a configuração do VS Code. |

### Azure OpenAI

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| API Key | Ao conectar o recurso Azure | Chave do recurso, protegida com DPAPI. |
| Endpoint Base URL | Sempre que configurar o Azure | URL completa do recurso, como `https://recurso.openai.azure.com`. |
| Deployment Name | Sempre que configurar o modelo | Nome do deployment criado no Azure, não necessariamente o nome do modelo base. |
| API Version | Quando exigido pelo deployment | Versão enviada no parâmetro `api-version`; use uma versão aceita pelo recurso. |

### AWS Bedrock

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| AWS Access Key ID / Secret Access Key | Ao usar credenciais explícitas | Use uma identidade com o menor conjunto de permissões necessário. Os valores sensíveis são protegidos localmente. |
| AWS Session Token | Para credenciais temporárias | Obrigatório quando a credencial STS inclui token; deixe vazio para chave duradoura. |
| AWS Region | Sempre que configurar Bedrock | Região que disponibiliza o modelo e na qual a conta possui acesso, por exemplo `us-east-1`. |
| IAM Console | Para criar ou revisar permissões | Abre o console oficial. O RadIA não altera políticas IAM. |

## General / Logs

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Auto (Smart Parameters) | Recomendado para a maioria dos usuários | Permite ao RadIA escolher parâmetros não definidos explicitamente conforme provider e tarefa. |
| Inject Delphi version in prompt | Recomendado em projetos dependentes da versão | Inclui a versão ativa para reduzir sugestões incompatíveis com Delphi 12 ou 13. |
| Prefer concise AI responses | Quando deseja respostas menores | Solicita concisão por padrão; um pedido explícito ainda pode exigir detalhes. |
| Enable logging | Ao investigar problemas | Registra diagnósticos locais sanitizados. Desative quando não precisar de investigação prolongada. |
| Log Folder Path / `...` | Para mudar ou escolher a pasta de logs | Use uma pasta gravável. Não selecione pastas compartilhadas com usuários não confiáveis. |
| Max Log File Size (KB) | Para controlar uso de disco | Limita a rotação/tamanho dos logs locais, não a resposta do modelo. |
| Enable local token quota | Para impor um aviso/limite local mensal | Desligado, o agente não aplica orçamento local de tokens por execução. Não substitui limites do provider. |
| Monthly Token Limit | Ao definir o orçamento local | Quantidade mensal aceita pelo controle do RadIA. |
| Monthly Used Tokens | Para acompanhar consumo estimado | Contador local; pode divergir da contabilização oficial do provider. |
| Reset Usage | Ao iniciar deliberadamente um novo acompanhamento | Zera somente o contador local, sem alterar cobrança externa. |

## Security & Consent

### Execução de ferramentas

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Consent dialog timeout | Para aumentar ou reduzir o tempo de decisão | Aceita 15–600 segundos. Ao expirar, a operação é cancelada; nunca é aprovada automaticamente. |
| Show tool arguments | Recomendado para revisão detalhada | Mostra JSON sanitizado antes da aprovação. Segredos continuam removidos. |
| Allow session permission for reversible writes | Para reduzir confirmações em edições reversíveis | Habilita a opção **Allow session** somente no escopo compatível da sessão. |
| Allow session permission for structural writes | Somente em sessão confiável | Pode abranger criação/remoção estrutural; vem desabilitada por segurança. |
| Allow session permission for build, tests, and execution | Somente quando o plano exigir execução repetida | Não autoriza ações destrutivas e não substitui limites, auditoria ou workspace boundary. |
| Revoke session permissions | Ao terminar uma tarefa ou suspeitar de escopo excessivo | Revoga imediatamente todas as permissões lembradas na sessão atual da IDE. |

## Knowledge & Embeddings

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Enable local semantic project knowledge | Para pesquisas semânticas no projeto | Cria índice reconstruível local, sem rede. Vem desabilitado por padrão. |
| Include approved agent run summaries | Para recuperar decisões de execuções anteriores | Indexa somente resumos concluídos com plano aprovado; argumentos e resultados de tools não entram. |
| Knowledge excluded file fragments | Para excluir arquivos sensíveis ou gerados | Fragmentos separados por `;`; qualquer caminho correspondente fica fora do índice. |
| Knowledge excluded project fragments | Para excluir projetos por nome ou caminho | Use para testes, terceiros, artefatos ou áreas confidenciais. |
| Use a remote embedding provider | Quando o índice local precisar de embeddings remotos | Não envia conteúdo enquanto o consentimento remoto separado não estiver marcado e válido. |
| I consent to sending bounded project text | Somente após revisar endpoint e política de dados | Autoriza envio limitado ao endpoint configurado; pode ser revogado desmarcando a opção. |
| Remote embeddings endpoint | Ao habilitar embeddings remotos | Aceita HTTPS ou HTTP em loopback. Não use HTTP remoto. |
| Embedding model / API key | Conforme o endpoint | Modelo deve existir no serviço; chave fica protegida com DPAPI. |
| Dimensions / timeout / maximum input | Para compatibilidade e limites | Dimensão deve corresponder ao modelo; timeout limita espera; input limita texto enviado por requisição. |

## Editor Assistance

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Enable ghost text (inline completion) | Para receber sugestões enquanto edita | Envia contexto limitado do editor ao provider ativo; respeita exclusões e consentimentos aplicáveis. |
| Idle delay (250–5000 ms) | Para equilibrar rapidez e quantidade de chamadas | Valor menor solicita mais cedo e pode aumentar chamadas; valor maior reduz interrupções. |
| Excluded languages | Para impedir completação em linguagens específicas | Lista separada por `;`, por exemplo `sql;markdown`. |
| Excluded file fragments | Para impedir completação em arquivos específicos | Fragmentos de nome ou caminho separados por `;`. |
| Excluded project fragments | Para impedir completação em projetos específicos | Fragmentos de nome ou caminho separados por `;`. |
| RadIA shortcuts | Para personalizar atalhos | Pares `ação=atalho` separados por `;`: `request`, `accept`, `nextWord`, `alternative`, `reject` e `terminal`. Conflitos são validados ao salvar. |

## CLI & MCP

CLI e MCP são independentes. O agente nativo não exige CLI para providers por API key ou locais. MCP
permite que um cliente externo acesse as ferramentas protegidas do RadIA.
No menu lateral, **External CLI clients** agrupa cada CLI suportado e abre apenas a configuração
do cliente escolhido. **MCP Connection** abre somente a conexão MCP. O nó pai distingue o modo
de orquestração nativo do modo por CLI externo.

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| Chat executor | Para escolher orquestração nativa ou externa | **RadIA native agent** usa o runtime interno; **External CLI** entrega o objetivo ao cliente selecionado. |
| CLI client | Ao diagnosticar, instalar ou usar uma CLI externa | Seleciona Codex, Claude, Gemini ou Copilot e também o perfil de configuração MCP correspondente. |
| CLI executable override | Quando a CLI é portátil ou não está no PATH | Informe o caminho completo de `.exe`, `.cmd` ou `.bat`. O mesmo resolver é usado por diagnóstico e execução. |
| Browse... | Para localizar uma CLI existente | Seleciona o arquivo sem exigir Node.js/npm. |
| Diagnose | Depois de instalar, trocar caminho ou autenticar | Resolve o caminho efetivo, lê versão e verifica autenticação quando o cliente oferece esse comando. |
| Install/Update channel | Quando não há executável utilizável | Mostra pacote, comando e pré-requisitos; só executa o canal oficial após confirmação. A alternativa é cancelar e selecionar um executável portátil. |
| Manual steps | Quando a automação não é desejada ou falhou | Copia URL oficial, comando completo, nomes esperados e alternativa portátil; pode abrir a documentação oficial. |
| Start login | Depois de detectar a CLI e antes do primeiro uso autenticado | Abre o login em terminal visível e repete o diagnóstico quando o terminal é fechado. |
| MCP client configuration | Somente para override ou diagnóstico avançado | Caminho completo do JSON/TOML do cliente. O padrão é detectado por cliente. |
| RadIA MCP bridge | Somente se a instalação foi movida ou reparada | Caminho da bridge fornecida pelo instalador junto à BPL. Não requer download separado. |
| Preview | Antes de conectar ou reparar | Mostra o conteúdo proposto sem gravar arquivos. |
| Connect / Repair | Para adicionar ou corrigir a entrada `radia` | Pede confirmação, cria `.radia.bak`, grava, verifica e restaura o original se a verificação falhar. |
| Disconnect | Para remover a integração | Remove somente a entrada gerenciada pelo RadIA e mantém as demais configurações do cliente. |
| Test Handshake | Depois de conectar e com a IDE ativa | Executa `initialize`, `ping` e `tools/list`; não modifica projeto nem configurações. |

O bloco **MCP connection** é explicitamente independente do executor do chat. O histórico sanitizado
de instalação e reparo fica em `%USERPROFILE%\RadIA\cli-mcp-setup-history.jsonl`.

### Fluxo guiado e recuperação

| Situação | O que o RadIA faz | Como continuar |
|---|---|---|
| Tudo já configurado | Detecta caminho, versão e autenticação disponível; não instala nada. | Use o executor ou teste o handshake MCP. |
| CLI ausente | Oferece o canal oficial após mostrar comando, origem e pré-requisitos. | Autorize ou use **Browse...** para um executável existente. |
| Node.js/npm ausente | Oferece Node.js LTS via WinGet em uma confirmação separada. | Após sucesso, revalida e oferece instalar a CLI. |
| Usuário recusa | Nenhuma alteração é feita. | Use **Manual steps**, **Browse...** ou mantenha o agente nativo. |
| Instalação falha | Mostra erro acionável, preserva saída visível e registra metadados sanitizados. | Corrija a causa indicada, execute **Diagnose** e retome. |
| Instalação manual | Procura override, `PATH`, npm, Node.js e links do WinGet. | Clique **Diagnose**; não é necessário reiniciar o Delphi. |
| Configuração MCP inválida | Não sobrescreve o arquivo e desabilita a gravação. | Corrija o arquivo indicado e gere novo **Preview**. |
| Primeiro MCP | Mostra preview, pede consentimento, cria backup, verifica e permite handshake. | Execute **Connect / Repair** e depois **Test Handshake**. |

Cancelar ou recusar mantém o ambiente inalterado e deixa uma alternativa visível.

Para requisitos, autenticação e limitações de WSL, consulte
[Orquestração nativa e executores por CLI](cli_executors.md). Para formatos e descoberta, consulte
[Integração MCP](mcp_integration_guide.md).

## Memory Diagnostics

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| FastMM5 root | Ao habilitar investigação dinâmica de memória | Pasta fornecida pelo usuário que contém `FastMM5.pas`; o RadIA não baixa nem redistribui FastMM5. |
| Browse... | Para selecionar a raiz instalada | Escolhe a pasta sem alterar o projeto. |
| License confirmation | Antes de usar FastMM5 | Confirma que a cópia foi fornecida pelo usuário e permanece sob a licença própria. |
| Validate installation | Depois de selecionar a raiz | Verifica layout e disponibilidade sem modificar o projeto ativo. |

Consulte o [plano e guia do diagnóstico de memória](fastmm5_memory_diagnostics_plan.md) antes da
primeira sessão.

## System

O campo **System Prompt** define instruções permanentes para novas conversas. Use-o para convenções
estáveis, idioma ou restrições arquiteturais. Não coloque credenciais, dados pessoais ou instruções
temporárias; para tarefas pontuais, use a mensagem do chat ou um template.

## Templates

| Opção | Quando alterar | Efeito e cuidados |
|---|---|---|
| New | Para criar um prompt reutilizável | Cria uma entrada editável sem afetar templates existentes. |
| Delete | Para remover uma entrada personalizada | Solicita confirmação; templates padrão podem ser restaurados. |
| Template Name / Description | Ao identificar e explicar o template | Use nomes únicos e descrições que indiquem entrada e resultado esperados. |
| Slash Command | Para chamar o template pelo chat | Deve começar com `/` e ser único. Evite nomes dos comandos internos. |
| Template | Ao definir o prompt reutilizado | Pode conter instruções e placeholders, mas nunca segredos. |
| Gera Projeto Completo | Quando a resposta representa múltiplos arquivos | Ativa o tratamento de geração de projeto e a revisão correspondente. |
| Save Template | Depois de revisar campos e conteúdo | Valida e persiste a entrada. |
| Exportar / Importar | Para backup ou compartilhamento controlado | Revise conteúdo importado; merge preserva entradas existentes e substituição troca a biblioteca. |
| Restore Defaults | Para recuperar templates distribuídos | Sobrescreve alterações dos templates padrão após confirmação. |

## Onde buscar ajuda

| Necessidade | Documento |
|---|---|
| Primeiros passos | [Manual do usuário](user_manual.md) |
| Todas as capacidades | [Mapa de capacidades](capabilities.md) |
| Ferramentas e consentimento | [Guia das ferramentas agentivas](user_guide_agentic_tools.md) |
| Comandos do chat | [Comandos de barra](slash_commands.md) |
| Erros e recuperação | [Solução de problemas](troubleshooting_agentic_platform.md) |
