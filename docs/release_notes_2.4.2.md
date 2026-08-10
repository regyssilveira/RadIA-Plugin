# Notas de release — RadIA 2.4.2

## Correções

- Torna o compositor do chat responsivo em painéis estreitos e mantém o botão de envio acessível.
- Evita que seletores de executor, provider e modelo ultrapassem a largura disponível ao redimensionar
  ou acoplar o painel.
- Converte o erro bruto do Codex que exige uma versão mais recente em uma orientação clara e acionável.
- Explica que **RadIA native + ChatGPT Pro via Codex CLI** mantém a orquestração no RadIA, mas ainda
  utiliza o Codex CLI como transporte da conta Pro.
- Direciona o usuário para atualizar o canal ou escolher um executável mais recente, executar o
  diagnóstico e atualizar a lista de modelos.
- Faz o `/doctor --deep` reprovar versões do Codex incompatíveis com a família `gpt-5.6-*`, em vez
  de considerar suficiente qualquer resposta de `codex --version`.

## Compatibilidade

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

O instalador visual é o único artefato necessário para o usuário final. A atualização preserva
configurações, credenciais, servidores MCP e dados locais existentes.

## Validação

- 1.032 testes Delphi aprovados em cada alvo, sem falhas, erros ou vazamentos;
- 91 testes web, 36 testes documentais e ESLint aprovados;
- compilação aprovada nos três alvos suportados;
- catálogo runtime validado com 132 ferramentas;
- SonarQube Quality Gate `OK`, sem issues.
