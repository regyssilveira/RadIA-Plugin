# Transações compostas de desenvolvimento

Uma mudança completa costuma envolver mais de uma superfície da IDE: código, estrutura do projeto e
Form Designer. O RadIA pode agrupar previews já revisados em uma única transação compensável.

## Operações aceitas

`PrepareDevelopmentTransaction` recebe uma lista ordenada com `kind`, `previewId` e um `label`
opcional de até 120 caracteres. O resultado é um plano visual: cada etapa contém índice, rótulo,
tipo, preview de origem e estado (`pending`, `rejected`, `applied` ou `reverted`). Os kinds aceitos
são:

- `multiFilePatch`;
- `projectFile`;
- `designerComponent`;
- `designerLayout`;
- `designerProperty`;
- `designerEvent`.

Cada `previewId` deve ter sido produzido anteriormente pela tool específica. A transação superior não
substitui os previews detalhados; ela preserva a decisão revisada em cada domínio.

## Aplicação

Antes da aplicação, `RejectDevelopmentTransactionStep` permite rejeitar uma etapa específica. O
plano precisa manter pelo menos uma etapa pendente, e uma etapa rejeitada nunca é executada.

`ApplyDevelopmentTransaction` executa as operações na ordem informada. Se uma etapa falhar, todas as
etapas anteriores são revertidas em ordem inversa. O resultado só é `applied` quando a lista inteira
foi aplicada.

## Reversão

`RevertDevelopmentTransaction` desfaz as operações da última para a primeira. Se uma reversão falhar,
as etapas que já tinham sido desfeitas são reaplicadas, evitando um estado parcialmente revertido.

`RevertDevelopmentTransactionStep` permite reversão gradual. Para preservar dependências, somente a
última etapa ainda aplicada pode ser revertida; etapas anteriores ficam disponíveis depois que as
posteriores forem desfeitas. O plano passa a `partiallyReverted` e continua mostrando cada estado.

Durante a jornada, `NavigateToDevelopmentSurface` ativa explicitamente o editor de código ou o Form
Designer vivo para um arquivo do projeto. A tool recusa arquivos externos e falha quando a
superfície solicitada não existe.

Depois da última mutação, a timeline reúne as evidências de `BuildProject`, `RunDUnitXTests`,
`GetCoverageSummary`, `StartDebugging`, `GetDebuggerState` e `GetDebugTimeline`. O card da jornada
mostra estados separados para mudanças, build, testes, cobertura, execução e debug, além de duração,
contagens e última sequência observada. Uma nova mutação invalida essas evidências e inicia outro
ciclo de validação.

## Segurança

- máximo de 32 operações e 16 previews compostos ativos;
- IDs duplicados do mesmo domínio são recusados;
- expiração local do preview;
- consentimento de escrita estrutural antes do apply;
- auditoria de cada tool específica e da transação superior;
- falha explícita `compensation_failed` quando a IDE impede recuperar integralmente o estado.
