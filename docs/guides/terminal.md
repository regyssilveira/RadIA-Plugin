# Terminal acoplável

Quando uma jornada está vinculada no chat, o cabeçalho do terminal mostra o mesmo identificador,
projeto e estado de atividade. A autorização do comando usa essa identidade sem enviar o histórico
do chat ou a saída anterior. Veja [Contexto compartilhado](shared_journey_context.md).

O RadIA 2.0 inclui um terminal nativo acoplável à IDE. Ele está disponível nos três targets
oficiais: Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

## Como abrir

Existem quatro formas equivalentes:

1. Clique no botão **>_ Terminal** no cabeçalho do chat.
2. Digite `/terminal` no chat e envie o comando.
3. Use **Ferramentas > RadIA > Rad IA Terminal**.
4. Pressione o atalho configurado. O padrão é `Ctrl+Alt+T`.

O botão e o comando chamam a mesma ação nativa. O terminal não é inserido dentro do WebView2:
ele usa um painel VCL próprio, registrado pela Open Tools API como janela acoplável.

Internamente, transporte ConPTY, emulação VT e renderer VCL são camadas independentes. A UI usa
`IRadIATerminalEmulator`, sem conhecer o parser ou tipos de terceiros. O núcleo nativo atual fica
atrás dessa interface, permitindo evolução e fallback sem alterar sessões, consentimento ou docking.

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
- ANSI SGR com cores normais, brilhantes, 256 cores e true color para texto e fundo;
- negrito, itálico, sublinhado, vídeo inverso e reset seletivo de atributos;
- alternate screen com restauração do conteúdo e cursor da tela principal;
- bracketed paste negociado pelo processo;
- cliques de mouse em aplicações que habilitam rastreamento SGR;
- hyperlinks OSC 8 identificáveis, abertos por duplo clique após consentimento;
- movimentação de cursor, retorno de carro, limpeza de linha e tela;
- redimensionamento automático da pseudo-console;
- Unicode por canais UTF-8 com decodificação contínua entre blocos de leitura;
- largura visual correta para CJK, emoji e marcas combinantes;
- reflow ao redimensionar, preservando quebras de linha explícitas;
- operações TUI de inserir, excluir e apagar caracteres, inclusive com sequências VT fragmentadas;
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

## Unicode, resize e aplicações TUI

O transporte ConPTY mantém bytes UTF-8 incompletos até a próxima leitura. Assim, um emoji ou
ideograma dividido pelo Windows entre dois blocos não vira o caractere de substituição. A tela
trabalha com a largura exibida: CJK e emoji ocupam duas colunas; uma marca combinante é anexada ao
caractere anterior sem avançar o cursor.

Ao estreitar ou ampliar o painel, linhas quebradas automaticamente são reorganizadas para a nova
largura. Quebras enviadas pelo processo continuam sendo quebras reais. O emulador também mantém
estado entre blocos para CSI e OSC e atende movimentação/salvamento do cursor, limpeza de tela e
linha, SGR, inserção (`ICH`), exclusão (`DCH`) e apagamento (`ECH`) de caracteres. Cores de 256
posições e true color preservam texto e fundo. Negrito, itálico, sublinhado e vídeo inverso são
renderizados de forma independente.

Aplicações TUI podem ativar a alternate screen com `1047` ou `1049`; ao sair, conteúdo e cursor da
tela principal são restaurados. O terminal envolve a entrada com bracketed paste apenas após o
processo habilitar `2004`. Cliques são enviados no protocolo SGR somente quando o processo habilita
um modo de rastreamento (`1000`, `1002` ou `1003`) e o protocolo `1006`.

Links OSC 8 aparecem sublinhados. Dê duplo clique para solicitar autorização e abrir somente URI
`http`, `https` ou `mailto`; outros esquemas são recusados. A autorização é solicitada em toda
abertura e utiliza a mesma política central do restante do RadIA.

Aplicações que exigem recursos ainda não emulados, como gráficos sixel, imagens inline ou protocolos
de mouse diferentes de SGR, continuam executando, mas podem apresentar saída simplificada. Nesse
caso, abra a aplicação em seu terminal externo preferido; o RadIA não altera nem bloqueia o processo.

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

O pedido identifica **Terminal** como origem, preserva a jornada e o projeto nos campos corretos e
usa o diálogo nativo independente do painel. Os argumentos são sanitizados antes de aparecerem.

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

A matriz automatizada é executada no pipeline de validação. O smoke exige geometria
útil, entrada e saída, os controles **New terminal**, **Close terminal**, **Run**, **Stop** e
**Clear**, os cinco rótulos acessíveis, pelo menos 11 pontos navegáveis por Tab, dois perfis e uma
paleta não vazia. A matriz vigente cobre exclusivamente Delphi 12 Win32, Delphi 13 Win32 e Delphi
13 IDE64, todos com o catálogo atual de 185 ferramentas. Evidências detalhadas ficam fora de `docs`
somente como registro histórico.
