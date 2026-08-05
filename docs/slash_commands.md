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
| `/terminal` | Abre o terminal integrado acoplável. | Projeto e desktop atuais da IDE. |
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

## Customização e Backups de Comandos

O Rad IA permite que você edite, exclua ou adicione novos comandos e templates de prompts diretamente nas opções do plugin na IDE (`Tools -> Options -> Rad IA -> Templates`).

Os comandos da família `/agent`, além de `/terminal`, `/tools`, `/tool`, `/revoke-tools` e
`/extensions reload`, são
internos e não podem ser substituídos por templates. Consulte o [Manual Completo do RadIA](user_manual.md) para
exemplos.

Extensões declarativas podem acrescentar comandos próprios sem recompilar ou reiniciar a IDE.
Consulte [Extensões declarativas](declarative_extensions.md).

Os demais comandos são fornecidos pelos templates instalados. Como esses templates podem ser
editados, restaurados, importados ou removidos, digitar `/` no chat é a fonte de verdade para a
lista disponível no perfil atual.

Cada template cadastrado pode especificar:
- **Slash Command**: O comando que acionará o template diretamente no chat (ex: `/explain`).
- **Is Project Generator**: Um indicador se aquele template gera um projeto físico compilável no disco.
- **Importação/Exportação**: Você pode exportar seus templates para arquivos JSON e importá-los em outras máquinas de forma transacional, mesclando com os existentes ou substituindo-os.

