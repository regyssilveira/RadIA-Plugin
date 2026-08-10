# Notas de release — RadIA 2.5.0

## Experiência do chat

- Organiza os controles do compositor em duas linhas semânticas: execução e contexto da conversa.
- Reorganiza seletores, ações e estado efetivo conforme a largura disponível no painel acoplado.
- Mantém os mesmos comandos, atalhos e identificadores, sem alterar o fluxo existente do chat.
- Mantém o cartão de aprovação do plano como último conteúdo visível e oferece `/agent resume` como
  alternativa textual, evitando que uma mensagem duplicada esconda o botão **Approve plan**.
- Exibe no README e no `/help` uma tabela direta das combinações Chat, Agent, CLI e MCP.
- Reconhece pedidos naturais de criação de projetos sem exigir a escolha prévia do executor.
- Extrai caminhos Windows absolutos, deriva o nome pela pasta e usa Win32 quando a plataforma não
  foi informada, perguntando somente pelos dados realmente ausentes.
- Mostra atividade do CLI em tempo real e impede que links externos substituam a tela do chat.
- Mantém opções avançadas de executor, sessão, jornada e escopo atrás de **More**.

## Criação e consentimento

- Inclui composição determinística de uma calculadora VCL funcional.
- Abre, compila, executa e valida o cenário principal antes de concluir a jornada.
- Reutiliza **Allow session** entre tools compatíveis da mesma origem, projeto, escopo e categoria
  de risco, reduzindo confirmações repetidas sem ampliar permissões destrutivas.
- Mantém `/revoke-tools` e as preferências por categoria como revogação e opt-out imediatos.

## Instalação de CLIs

- Mantém npm como canal preferencial quando ele já está disponível.
- Usa os pacotes oficiais do WinGet para instalar Codex CLI e Claude Code quando npm não existe.
- Mantém GitHub Copilot CLI no canal WinGet e apresenta o comando antes de qualquer execução.
- Explica que o Gemini CLI ainda exige Node.js no Windows por seu canal oficial.
- Preserva a seleção de executável existente com **Browse**, consentimento por etapa e revalidação
  automática após a instalação.
- Permite conversar e criar um novo projeto VCL pelo modo Agent sem projeto aberto, usando um
  workspace privado até que o projeto seja criado ou aberto.

As CLIs não são incorporadas ao instalador do RadIA. O gerenciador utiliza os canais oficiais para
reduzir obsolescência, tamanho do instalador e riscos de redistribuição de software de terceiros.

## Compatibilidade

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

O instalador visual continua sendo o único artefato necessário para o usuário final.

## Validação

- 1.046 testes Delphi aprovados nos alvos Win32, sem falhas, erros ou vazamentos;
- 97 testes web, 36 testes documentais e ESLint aprovados;
- catálogo runtime validado com 132 ferramentas;
- SonarQube Quality Gate `OK`, sem issues.
