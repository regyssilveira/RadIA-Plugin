# Comandos de Barra (Slash Commands) do Rad IA

O Rad IA suporta atalhos rápidos de comandos diretamente no chat, facilitando a execução de tarefas comuns sem a necessidade de digitar prompts extensos ou usar o mouse.

---

## Como Utilizar

Basta digitar o caractere `/` na caixa de entrada do chat. Um menu flutuante surgirá abaixo do campo de digitação, permitindo selecionar o comando desejado com as setas `↑`/`↓` do teclado e pressionar `Enter` para inseri-lo.

---

## Tabela de Comandos Disponíveis

| Comando | Descrição | Contexto Automático da IDE |
| :--- | :--- | :--- |
| `/agent [on\|off]` | Alterna ou define o modo agente e sincroniza o botão visual. | Chat ativo. |
| `/agent run <objetivo>` | Inicia um loop agentivo observável usando o catálogo atual. | Sessão e workspace ativos. |
| `/agent plan <JSON>` | Substitui o plano pendente por um array JSON validado. | Plano aguardando aprovação. |
| `/agent replay <etapa>` | Repete a chamada auditada de uma etapa. | Execução agentiva pausada. |
| `/agent pause` | Pausa o loop após interromper com segurança a decisão atual. | Execução agentiva ativa. |
| `/agent resume` | Retoma o último checkpoint da sessão. | Execução agentiva pausada. |
| `/agent cancel` | Cancela a decisão e a execução agentiva atuais. | Execução agentiva ativa. |
| `/agent history [filtro]` | Pesquisa execuções por objetivo, estado ou ID. | Checkpoints locais. |
| `/help` | Resume as capacidades do RadIA e oferece links para a documentação. | Catálogos e guias públicos. |
| `/terminal` | Abre o terminal integrado acoplável; equivale ao botão `>_` do chat. | Projeto e desktop atuais da IDE. |
| `/settings` | Abre as configurações do RadIA; equivale ao botão de engrenagem do chat. | Configuração local do usuário. |
| `/extensions` | Abre o gerenciador visual de extensões. | Extensões e publicadores locais. |
| `/health` | Resume a saúde do projeto e prioriza riscos atuais. | IDE, compilador, build, testes e conhecimento local. |
| `/doctor` | Diagnostica a instalação e recomenda a próxima ação. | Provider, executor, ponte MCP condicional, terminal, chat, primeira tool e runtime MCP externo quando disponível. |
| `/status [filtro\|--json]` | Mostra um inventário sanitizado do estado do RadIA. | Provider, agente, CLI, MCP, segurança, editor, projeto, tools e logs. |
| `/status settings` | Mostra provider, modelo, executor e limites efetivos com a origem de cada valor. | Projeto, sessão e próxima solicitação. |
| `/scope` | Mostra configurações efetivas e a precedência aplicada. | Equivale ao botão **Settings > Scope**. |
| `/scope <nível> <campo> <valor>` | Cria um override em `project`, `session` ou `request`. | Nunca altera credenciais. |
| `/scope <nível> inherit <campo>` | Remove o override de um campo e restaura sua herança. | Mantém os demais campos. |
| `/scope <nível> clear` | Remove todos os overrides do nível. | Mantém a configuração global. |
| `/cli session` | Mostra se a conversa atual está vinculada a uma sessão de CLI retomável. | Conversa, executor e projeto atuais. |
| `/cli new` | Desvincula a sessão externa; a próxima solicitação inicia uma conversa nova no CLI. | Conversa ativa; não apaga dados no fornecedor. |
| `/context` | Mostra ou vincula a jornada compartilhada por chat, terminal e editor. | Conversa e projeto ativos. |
| `/context new` | Cria uma identidade de jornada nova para a conversa e projeto atuais. | Descarta somente o vínculo transitório anterior. |
| `/context detach` | Desvincula a conversa da jornada compartilhada. | Não apaga conversa, histórico ou sessão CLI. |
| `/context switch <id>` | Abre a conversa vinculada à jornada informada. | Aceita somente jornadas do projeto ativo. |
| `/journey` | Lista receitas Delphi ponta a ponta. | Catálogo nativo de jornadas. |
| `/journey cancel` | Abandona a coleta de dados da jornada ativa. | Contexto ainda não executado. |
| `/journey create` | Cria, abre, compila e explica um projeto novo. | Agent Runtime e tools de projeto. |
| `/journey dext-minimal` | Cria e valida um servidor DEXT com rotas diretas. | Templates DEXT, build e runtime. |
| `/journey dext-controllers` | Cria e valida um servidor DEXT com controllers. | Templates DEXT, build, Swagger e runtime. |
| `/journey fix-build` | Diagnostica e corrige um build com alterações mínimas. | Compilador, patches e build. |
| `/journey tests` | Amplia testes DUnitX e executa validação. | Projeto, patches e DUnitX. |
| `/journey debug` | Conduz reprodução, diagnóstico, correção e validação. | Debugger, patches e build. |
| `/journey modernize` | Moderniza estrutura e práticas em lotes revisáveis. | Grafo, Designer, transações, build e testes. |
| `/journey migrate` | Migra um padrão legado com baseline e rollback. | Grafo, transações, diff, build e testes. |
| `/journey release` | Reúne gates e prepara preview de commit local. | Saúde, build, testes e Git. |
| `/tools` | Mostra o catálogo de tools da instância atual. | Estado e extensões da IDE. |
| `/tool <nome> {JSON}` | Executa uma tool com argumentos JSON opcionais. | Workspace e sessão. |
| `/revoke-tools` | Revoga permissões concedidas na sessão. | Sessão de chat ativa. |
| `/extensions reload` | Recarrega extensões declarativas e mostra diagnósticos. | Diretório local de extensões. |
| `/explain` | Analisa e explica didaticamente a lógica do código selecionado no editor. | Envia o trecho de código selecionado. |
| `/refactor` | Otimiza a performance, legibilidade e aplica boas práticas (Clean Code/SOLID) no código selecionado. | Envia o trecho de código selecionado. |
| `/optimize` | Alias de otimização e refatoração de código. | Envia o trecho de código selecionado. |
| `/performance` | Analisa gargalos e oportunidades de desempenho. | Envia o código selecionado. |
| `/test` | Gera testes unitários DUnitX para o código selecionado. | Envia o trecho de código selecionado. |
| `/bugs` | Varre o código selecionado em busca de memory leaks, tratamento incorreto de exceções e erros de lógica. | Envia o trecho de código selecionado. |
| `/doc` | Gera comentários de documentação no formato XML (`/// <summary>`) compatível com o Delphi Help Insight. | Envia a assinatura do método selecionado. |
| `/template` | Abre o menu flutuante de biblioteca de templates para escolha de prompts reutilizáveis. | — |
| `/stacktrace` | Analisa logs de erro ou exceções (MadExcept, EurekaLog ou RTL) e aponta a causa raiz na unit ativa. | Envia o texto da unit aberta no editor como referência de código para a linha do erro. |
| `/review` | Executa uma análise estática abrangente de toda a unit ativa em busca de memory leaks (falta de try..finally) e anti-padrões. | Envia o código completo do arquivo ativo no editor. |
| `/sqloptimize` | Analisa e otimiza a consulta SQL selecionada, sugerindo índices, correções de sintaxe e melhorias de performance. | Envia a string ou trecho de consulta SQL selecionado. |
| `/scanwarnings` | Varre o código em busca de warnings do compilador Delphi, problemas de thread-safety e vazamentos de recursos (handles GDI). | Envia o trecho de código selecionado ou a unit ativa. |
| `/createproject` | Cria um projeto Delphi vanilla completo no disco e o carrega na IDE com base em uma especificação textual. | — |
| `/createprojectarch` | Cria um projeto Delphi baseado em arquitetura limpa (SOLID) no disco e o carrega na IDE com base em especificação. | — |

---

## Qual diagnóstico usar

| Necessidade | Comando | Resultado |
|---|---|---|
| Descobrir por que o RadIA não está pronto | `/doctor` | Seis verificações básicas, runtime MCP externo quando disponível, problemas, recomendações e próxima ação. |
| Conferir o que está configurado e disponível | `/status` | Todas as áreas, sem chaves, tokens ou payloads sensíveis. |
| Investigar somente uma área | `/status cli`, `/status mcp`, `/status provider` | Apenas a seção solicitada. `mcp` separa a ponte de CLI das contagens sanitizadas do runtime externo. Também aceita `agent`, `security`, `editor`, `project`, `tools`, `logging` e `settings`. |
| Copiar ou analisar a estrutura completa | `/status --json` | Estado completo no formato estruturado retornado pela tool. |
| Avaliar o projeto Delphi aberto | `/health` | Score e riscos do projeto, build, testes, compilador e conhecimento local. |
| Descobrir ferramentas executáveis | `/tools` | Catálogo efetivo da instância atual da IDE. |

Comece com `/doctor` quando algo não funciona. Use `/status` quando a pergunta for “o que está
configurado agora?”. Caminhos de executáveis podem aparecer, mas credenciais nunca são incluídas.

## Customização e Backups de Comandos

O Rad IA permite que você edite, exclua ou adicione novos comandos e templates de prompts diretamente nas opções do plugin na IDE (`Tools -> Options -> Rad IA -> Templates`).

Os comandos da família `/agent`, além de `/terminal`, `/settings`, `/extensions`, `/health`,
`/doctor`, `/status`, `/scope`, `/tools`,
`/tool`, `/revoke-tools` e
`/extensions reload`, são
internos e não podem ser substituídos por templates. Consulte o [Manual Completo do RadIA](user_manual.md) para
exemplos.

Consulte [Configurações por projeto, sessão e solicitação](hierarchical_settings.md) para a
precedência completa, os campos aceitos, a persistência e os exemplos de recuperação.

Extensões declarativas podem acrescentar comandos próprios sem recompilar ou reiniciar a IDE.
Consulte [Extensões declarativas](declarative_extensions.md).

Os demais comandos são fornecidos pelos templates instalados. Como esses templates podem ser
editados, restaurados, importados ou removidos, digitar `/` no chat é a fonte de verdade para a
lista disponível no perfil atual.

Cada template cadastrado pode especificar:
- **Slash Command**: O comando que acionará o template diretamente no chat (ex: `/explain`).
- **Is Project Generator**: Um indicador se aquele template gera um projeto físico compilável no disco.
- **Importação/Exportação**: Você pode exportar seus templates para arquivos JSON e importá-los em outras máquinas de forma transacional, mesclando com os existentes ou substituindo-os.

