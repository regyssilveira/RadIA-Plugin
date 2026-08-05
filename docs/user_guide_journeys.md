# Jornadas Delphi ponta a ponta

As jornadas transformam tools isoladas em fluxos completos executados pelo Agent Runtime. Toda
jornada apresenta um plano antes da primeira mutação, usa o consentimento central, registra
checkpoints e mantém diffs, build, testes, debugger e Git observáveis no chat.

Digite `/journey` para listar as receitas disponíveis.

| Comando | Objetivo |
|---|---|
| `/journey create` | Criar, abrir, compilar e explicar um novo projeto Delphi. |
| `/journey fix-build` | Diagnosticar erros do compilador, aplicar correção mínima e recompilar. |
| `/journey tests` | Identificar lacunas, criar testes DUnitX e executar a validação relevante. |
| `/journey debug` | Reproduzir uma falha, coletar evidências do debugger, corrigir e validar. |
| `/journey release` | Verificar saúde, build, testes, diff e preparar preview de commit. |

## Como a execução funciona

1. O comando ativa visualmente o modo agente quando necessário.
2. O RadIA converte a receita em um objetivo estruturado.
3. O modelo produz um plano revisável; nenhuma tool é executada antes da aprovação.
4. Cada operação passa por risco, consentimento, workspace boundary, sanitização e auditoria.
5. O usuário pode pausar, editar o plano, repetir uma etapa, retomar ou cancelar.
6. O resultado mostra evidências e riscos restantes, não apenas uma resposta textual.

As receitas não concedem permissões extras. A jornada de release prepara um preview local, mas não
faz push nem publica artefatos sem uma instrução explícita do usuário.

## Quando usar

- Use **create** quando a intenção inclui um projeto novo, estrutura, abertura e primeiro build.
- Use **fix-build** quando há mensagens reais do compilador e a correção precisa ser mínima.
- Use **tests** para ampliar cobertura sem misturar refatorações não relacionadas.
- Use **debug** quando a causa exige estado de execução, breakpoints, stack, watches ou avaliação.
- Use **release** antes de uma entrega para reunir gates técnicos e revisar o escopo do commit.

