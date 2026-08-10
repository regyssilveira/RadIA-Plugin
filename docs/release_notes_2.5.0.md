# Notas de release — RadIA 2.5.0

## Experiência do chat

- Organiza os controles do compositor em duas linhas semânticas: execução e contexto da conversa.
- Reorganiza seletores, ações e estado efetivo conforme a largura disponível no painel acoplado.
- Mantém os mesmos comandos, atalhos e identificadores, sem alterar o fluxo existente do chat.
- Mantém o cartão de aprovação do plano como último conteúdo visível e oferece `/agent resume` como
  alternativa textual, evitando que uma mensagem duplicada esconda o botão **Approve plan**.
- Exibe no README e no `/help` uma tabela direta das combinações Chat, Agent, CLI e MCP.

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

- 1.037 testes Delphi aprovados nos alvos Win32, sem falhas, erros ou vazamentos;
- 93 testes web, 36 testes documentais e ESLint aprovados;
- catálogo runtime validado com 132 ferramentas;
- SonarQube Quality Gate `OK`, sem issues.
