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

Afirmações sobre o comportamento atual devem ser verificadas contra o código, o catálogo runtime ou
o workflow vigente. Infraestrutura preparatória, planos e registros históricos devem ser rotulados
como tal e nunca descritos como capacidade disponível. Backlog e hubs devem declarar explicitamente
quando não existe goal ativo.

## Fonte única e navegação

- `docs/README.md` é a central de navegação por tarefa.
- `docs/getting-started/` contém instalação e primeiros passos.
- `docs/guides/` contém fluxos orientados a tarefas; `user_manual.md` é o roteiro completo de uso.
- `docs/reference/` contém fontes autoritativas, incluindo configurações, ferramentas e comandos.
- `docs/development/` contém arquitetura, contribuição e processo de release.
- `docs/project/` contém somente roadmap futuro e backlog aberto.
- Guias especializados aprofundam um assunto e devem apontar de volta para a fonte central.
- Notas de versão ficam exclusivamente no GitHub Releases.
- Evidências, auditorias, resultados de execução e planos internos não pertencem a `docs/`.
- Planos ativos de engenharia ficam em `.planning/` e não são manuais de uso.
- Links internos devem ser relativos ao repositório; nunca use caminhos locais `file:///`.
- Listas de modelos fallback devem permanecer sincronizadas com `RadIA.Core.Types.pas`.
- Contagens do catálogo devem ser derivadas de `runtime_tools.json`, não copiadas de evidências antigas.

Uma pendência registrada não pode simplesmente desaparecer. Sua remoção deve ocorrer no mesmo
trabalho que registre um dos destinos verificáveis: conclusão na documentação do produto, descarte
explícito com justificativa, substituição por outro item ou migração para um goal ativo. Uma
reorganização ou simplificação documental, isoladamente, não altera o estado do trabalho.

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

