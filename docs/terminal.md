# Terminal acoplável

O RadIA 2.0 inclui um terminal nativo acoplável à IDE. Abra-o pelo botão **>_** do chat, digitando
`/terminal`, pelo atalho configurado ou em **Tools/Ferramentas > Rad IA Terminal**. A janela usa o
mesmo mecanismo de docking do chat, portanto posição, tamanho e visibilidade acompanham o desktop
do Delphi.

## Recursos

- perfis para Windows PowerShell e Command Prompt;
- diretório de trabalho automático na pasta do projeto Delphi ativo;
- captura incremental e simultânea de stdout e stderr;
- interpretação incremental de ANSI SGR, inclusive quando a sequência é dividida entre chunks;
- cores ANSI normais e brilhantes, texto em negrito e reset de estilo em uma saída rica;
- buffer de tela com sobrescrita por retorno de carro, posição e movimento de cursor CSI;
- limpeza ANSI de linha ou tela e save/restore da posição do cursor;
- múltiplas sessões simultâneas em abas, cada uma com processo, entrada e saída independentes;
- fechamento isolado de aba com cancelamento seguro apenas da árvore de processos correspondente;
- entrada contínua para responder prompts enquanto o processo permanece ativo;
- sessão Windows ConPTY com canais UTF-8 e fallback para pipes em sistemas sem a API;
- resize automático da pseudo-console em colunas e linhas quando o painel muda de tamanho;
- botão **Stop** que encerra toda a árvore de processos;
- timeout máximo de 30 minutos por comando;
- histórico persistente dos últimos 200 comandos;
- reutilização de comandos pelo seletor de histórico;
- busca reversa incremental por `Ctrl+R`; pressione novamente para encontrar a ocorrência anterior;
- snippets para build do Delphi 13, testes, `git status` e `git diff --check`;
- saída monoespaçada com código de saída e estado final.

Sequências ANSI de estilo (`0`, `1`, `22`, `30–37`, `39` e `90–97`) são interpretadas e não
aparecem como texto bruto. O buffer visual aplica movimentação relativa e absoluta de cursor,
retorno de carro, backspace, tabulação, limpeza de linha/tela e save/restore de posição. Isso permite
que barras de progresso e ferramentas interativas atualizem o conteúdo existente sem produzir
linhas duplicadas. Em Windows 10 1809 ou superior, a execução usa ConPTY, mantém entrada contínua e
atualiza as dimensões do console conforme o painel.

## Fluxo de uso

1. Abra um projeto na IDE.
2. Abra **Rad IA Terminal**.
3. Use **New terminal** quando precisar de outra sessão simultânea.
4. Escolha PowerShell ou Command Prompt na aba ativa.
5. Digite um comando ou selecione um snippet.
6. Clique em **Run**.
7. Se o processo solicitar entrada, digite a resposta e clique em **Send**.
8. Use **Stop** para cancelar o processo e seus subprocessos.
9. Use **Close terminal** para cancelar e remover somente a aba ativa.

Para recuperar um comando sem usar o mouse, digite parte dele e pressione `Ctrl+R`. Cada novo
acionamento percorre os resultados anteriores, do mais recente para o mais antigo. Alterar
manualmente o texto reinicia a busca.

O terminal executa exatamente o comando informado pelo usuário. Ele não habilita automaticamente
permissões de agente ou opções autônomas dos CLIs. O histórico é salvo localmente em
`%APPDATA%\RadIA\terminal-history.json` e não contém stdout, stderr, tokens ou credenciais — apenas
perfil, comando, horário e código de saída.

## Encerramento seguro

Cada execução recebe um Job Object do Windows com encerramento em cascata. Ao cancelar, fechar o
painel, descarregar o plugin ou encerrar a IDE, o RadIA finaliza o processo principal e todos os
filhos. Atualizações da interface são enfileiradas na thread principal e descartadas se o painel já
tiver sido destruído.

A camada ConPTY carrega as APIs do Windows dinamicamente. Em versões antigas do sistema, o terminal
continua funcional pelo executor de pipes, mas sem resize ou semântica completa de pseudo-console.
