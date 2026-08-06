# Terminal acoplável

O RadIA 2.0 inclui um terminal nativo acoplável à IDE. Ele está disponível nos três targets
oficiais: Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

## Como abrir

Existem quatro formas equivalentes:

1. Clique no botão **>_ Terminal** no cabeçalho do chat.
2. Digite `/terminal` no chat e envie o comando.
3. Use **Tools/Ferramentas > Rad IA Terminal**.
4. Pressione o atalho configurado. O padrão é `Ctrl+Alt+T`.

O botão e o comando chamam a mesma ação nativa. O terminal não é inserido dentro do WebView2:
ele usa um painel VCL próprio, registrado pela Open Tools API como janela acoplável.

## Configuração do atalho

Abra **Rad IA > Settings > Security & Privacy** e localize **RadIA shortcuts**. O perfil contém
pares `ação=atalho` separados por ponto e vírgula:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right; nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+T
```

Altere somente o valor de `terminal` para escolher outro binding. Os atalhos precisam ser válidos
e únicos dentro do perfil. A configuração é validada antes de ser salva, evitando que o terminal
conflite com aceitar, rejeitar ou solicitar uma sugestão inline.

Perfis salvos por versões anteriores, ainda sem a entrada `terminal`, continuam válidos e recebem
automaticamente o padrão `Ctrl+Alt+T`.

## Recursos

- sessões simultâneas em abas independentes;
- perfis fixos para Windows PowerShell e Command Prompt;
- perfil para Git Bash quando a instalação do Git for Windows estiver no `PATH`;
- perfis para Codex, Claude, Gemini e GitHub Copilot somente quando o executável for detectado;
- diretório de trabalho baseado na pasta do projeto Delphi ativo;
- execução interativa por ConPTY, com fallback para pipes;
- entrada contínua para responder prompts de processos ativos;
- captura incremental de stdout e stderr;
- ANSI SGR, cores normais e brilhantes, negrito e reset;
- movimentação de cursor, retorno de carro, limpeza de linha e tela;
- redimensionamento automático da pseudo-console;
- Unicode por canais UTF-8;
- histórico persistente dos últimos 200 comandos;
- busca reversa incremental com `Ctrl+R`;
- snippets para build, testes e Git;
- paleta pesquisável e deduplicada sobre snippets e histórico, aberta com `Ctrl+P`;
- cancelamento da árvore completa de processos;
- timeout máximo de 30 minutos por comando;
- encerramento isolado de cada aba.

## Fluxo de uso

1. Abra um projeto na IDE.
2. Abra o terminal por botão, `/terminal`, menu ou atalho.
3. Use **New terminal** para criar outra sessão.
4. Escolha o shell da aba ativa.
5. Digite um comando ou selecione um snippet.
6. Clique em **Run** ou pressione Enter.
7. Quando o processo solicitar entrada, digite a resposta e use **Send**.
8. Use **Stop** para cancelar o processo e seus subprocessos.
9. Use **Close terminal** para remover somente a aba ativa.

Para recuperar um comando sem usar o mouse, digite parte dele e pressione `Ctrl+R`. Pressione
novamente para percorrer ocorrências mais antigas. Uma edição manual reinicia a busca.

Para procurar por finalidade ou pelo próprio texto do comando, pressione `Ctrl+P` no campo de
comando. Digite na caixa **Command palette** e selecione um resultado identificado como
`[snippet]` ou `[history]`. A paleta elimina duplicidades: quando um snippet e o histórico possuem
o mesmo comando, a versão documentada do snippet aparece uma única vez.

## Segurança e privacidade

O terminal executa exatamente o comando informado pelo usuário. Ele não ativa modo agente nem
adiciona opções autônomas aos CLIs. O histórico é salvo em
`%APPDATA%\RadIA\terminal-history.json` e contém somente perfil, comando, horário e código de saída.
Stdout, stderr, tokens e credenciais não são persistidos pelo histórico.

Antes de iniciar um processo, o terminal solicita autorização à mesma política de execução usada
pelo chat, MCP e modo agente. **Allow once**, **Allow for session**, **Deny** e **Cancel** possuem a
mesma semântica em todas essas superfícies. Uma permissão de sessão é limitada ao projeto e pode
ser removida em **Security & Consent > Revoke session permissions**. Autorizações são registradas
no mesmo log auditável das ferramentas, com remoção de segredos antes da persistência.

O diretório de trabalho e o identificador do projeto ativo compõem o escopo da autorização. Em um
perfil de IA, os caminhos MCP configurados para aquele cliente também entram no contexto auditado;
o terminal não lê nem grava o conteúdo dos arquivos MCP durante essa etapa.

Os perfis de IA reutilizam o catálogo do CLI Manager. Assim, o terminal não mantém uma segunda
lista de nomes ou caminhos: somente CLIs realmente detectados são apresentados. Executáveis
`.cmd` e `.bat` são iniciados com segurança pelo Command Prompt; executáveis nativos são chamados
diretamente. O texto digitado torna-se o prompt ou comando inicial do CLI selecionado.

Cada execução recebe um Job Object do Windows. Cancelar a execução, fechar a aba, descarregar o
plugin ou encerrar a IDE finaliza o processo principal e seus filhos. Atualizações visuais são
enfileiradas na thread principal e ignoradas quando o painel já não existe.

## Docking e foco

O host nativo cria o frame e conecta toda a hierarquia de parents antes de solicitar foco. Isso
evita o erro `Control TEdit has no parent window` observado ao abrir o terminal durante a criação
do painel no Delphi 13. O foco é aplicado de forma adiada apenas quando:

- o formulário está visível e possui handle;
- o campo de comando possui parent e handle válidos;
- a janela do campo está visível e habilitada.

A própria IDE persiste posição, tamanho, visibilidade e estado acoplado.

## Evidência

A matriz automatizada está em
[`terminal_smoke_evidence_2.0.0.json`](terminal_smoke_evidence_2.0.0.json). O smoke exige geometria
útil, entrada e saída, os controles **New terminal**, **Close terminal**, **Run**, **Stop** e
**Clear**, os cinco rótulos acessíveis e pelo menos nove pontos navegáveis por Tab.

Evidências de versões antigas do Delphi presentes no arquivo são históricas. A matriz vigente e
obrigatória do RadIA é exclusivamente Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
