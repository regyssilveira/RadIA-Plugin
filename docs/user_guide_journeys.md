# Jornadas Delphi ponta a ponta

As jornadas transformam tools isoladas em fluxos completos executados pelo Agent Runtime. Toda
jornada apresenta um plano antes da primeira mutação, usa o consentimento central, registra
checkpoints e mantém diffs, build, testes, debugger e Git observáveis no chat.

Digite `/journey` para listar as receitas disponíveis.

Cada receita aceita contexto opcional depois do comando, por exemplo:

```text
/journey create aplicativo VCL de estoque com FireDAC e SQLite
/journey fix-build preserve a API pública da unit CustomerService
/journey debug Access Violation ao fechar o formulário de pedidos
/journey modernize reduzir acoplamento sem alterar as interfaces públicas
/journey migrate substituir uma camada ADO por FireDAC em lotes reversíveis
```

O contexto é limitado a 4.000 caracteres e anexado ao objetivo estruturado. Ele não altera as
regras de consentimento nem substitui a revisão do plano.

Cada receita possui quatro fases obrigatórias. Cada fase define o trabalho esperado e a evidência
que deve aparecer na timeline. A execução também recebe três critérios de conclusão; o agente não
deve declarar sucesso apenas porque produziu uma resposta textual.

| Comando | Objetivo |
|---|---|
| `/journey create [requisitos]` | Criar, organizar, documentar, compilar e explicar um projeto Delphi. |
| `/journey fix-build [restrições]` | Diagnosticar erros, aplicar correção mínima e recompilar. |
| `/journey tests [foco]` | Identificar lacunas, criar testes DUnitX e executar a validação. |
| `/journey debug [sintoma]` | Reproduzir uma falha, coletar evidências, corrigir e validar. |
| `/journey modernize [escopo]` | Modernizar units, forms, packages e dependências em lotes validados. |
| `/journey migrate [padrão legado]` | Migrar um padrão delimitado com baseline, transação e rollback. |
| `/journey release [escopo]` | Verificar gates, diff e preparar preview de commit. |

## Como a execução funciona

1. O comando ativa visualmente o modo agente quando necessário.
2. O RadIA converte a receita em um objetivo estruturado.
3. O modelo produz um plano revisável; nenhuma tool é executada antes da aprovação.
4. Cada operação passa por risco, consentimento, workspace boundary, sanitização e auditoria.
5. O usuário pode pausar, editar o plano, repetir uma etapa, retomar ou cancelar.
6. O resultado mostra evidências e riscos restantes, não apenas uma resposta textual.

O catálogo `/journey` informa a quantidade de fases e critérios. No início da execução, o objetivo
enviado ao Agent Runtime enumera as fases na ordem, a evidência exigida em cada uma e os critérios
finais. O contexto digitado pelo usuário aparece separado e não consegue remover esses gates.

Na jornada de criação, referências externas só são analisadas quando o usuário autoriza o path ou
URL. O plano registra licença e proveniência, justifica dependências, prefere recursos adequados da
RTL, organiza units reutilizáveis, atualiza o `.dproj`, produz documentação aplicável e usa os
diagnósticos reais do compilador como feedback para a próxima correção revisada.

As receitas não concedem permissões extras. A jornada de release prepara um preview local, mas não
faz push nem publica artefatos sem uma instrução explícita do usuário.

## Quando usar

- Use **create** quando a intenção inclui um projeto novo, estrutura, abertura e primeiro build.
- Use **fix-build** quando há mensagens reais do compilador e a correção precisa ser mínima.
- Use **tests** para ampliar cobertura sem misturar refatorações não relacionadas.
- Use **debug** quando a causa exige estado de execução, breakpoints, stack, watches ou avaliação.
- Use **modernize** para evoluir estrutura e práticas preservando comportamento e contratos públicos.
- Use **migrate** para substituir tecnologia legada em lotes independentes e reversíveis.
- Use **release** antes de uma entrega para reunir gates técnicos e revisar o escopo do commit.
