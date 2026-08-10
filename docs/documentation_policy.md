# Política de documentação

Documentação é parte do produto e deve permanecer correta, encontrável e verificável.

Todo documento Markdown mantido em `docs` deve possuir duas versões completas e equivalentes: o
arquivo-base em português do Brasil e o arquivo correspondente com sufixo `.en.md` em inglês.

## Regra obrigatória

Toda mudança que adicione, remova, renomeie ou altere comportamento visível deve atualizar, no mesmo
commit ou pull request:

1. a referência central da superfície afetada;
2. o guia de tarefa ou manual, quando o fluxo do usuário mudar;
3. os hints da interface, quando houver campo, botão, comando ou estado novo;
4. a versão em inglês do documento, quando existir;
5. testes documentais que protejam contratos importantes e links.

Uma funcionalidade não está concluída quando o usuário precisa ler código-fonte, histórico de commits
ou roadmap para descobrir como utilizá-la.

## Fonte única e navegação

- `docs/README.md` é a central de navegação por tarefa.
- `docs/user_manual.md` é o roteiro completo de uso.
- `docs/settings_reference.md` é a fonte única para opções de configuração.
- `docs/internal_tools_reference.md` é a fonte única para ferramentas internas.
- `docs/slash_commands.md` é a fonte única para comandos do chat.
- Guias especializados aprofundam um assunto e devem apontar de volta para a fonte central.
- Roadmaps, evidências e históricos não devem ser usados como instrução principal para usuários.
- Links internos devem ser relativos ao repositório; nunca use caminhos locais `file:///`.
- Listas de modelos fallback devem permanecer sincronizadas com `RadIA.Core.Types.pas`.
- Contagens do catálogo devem ser derivadas de `runtime_tools.json`, não copiadas de evidências antigas.

## Critérios de qualidade

Cada opção documentada deve informar:

- nome visível e localização;
- finalidade e momento adequado de uso;
- efeito, dependências e valores válidos;
- impacto de segurança, rede, custo ou arquivos quando aplicável;
- comportamento padrão e forma de recuperação;
- link para aprofundamento ou solução de problemas.

Antes do commit, execute `npm run test:docs`. Mudanças na interface também devem executar os testes
web e Delphi correspondentes. Links quebrados, mojibake, versões obsoletas e opções sem referência
central são defeitos de produto.

