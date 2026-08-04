# Transações compostas de desenvolvimento

Uma mudança completa costuma envolver mais de uma superfície da IDE: código, estrutura do projeto e
Form Designer. O RadIA pode agrupar previews já revisados em uma única transação compensável.

## Operações aceitas

`PrepareDevelopmentTransaction` recebe uma lista ordenada com `kind` e `previewId`. Os kinds aceitos são:

- `multiFilePatch`;
- `projectFile`;
- `designerComponent`;
- `designerLayout`;
- `designerProperty`;
- `designerEvent`.

Cada `previewId` deve ter sido produzido anteriormente pela tool específica. A transação superior não
substitui os previews detalhados; ela preserva a decisão revisada em cada domínio.

## Aplicação

`ApplyDevelopmentTransaction` executa as operações na ordem informada. Se uma etapa falhar, todas as
etapas anteriores são revertidas em ordem inversa. O resultado só é `applied` quando a lista inteira
foi aplicada.

## Reversão

`RevertDevelopmentTransaction` desfaz as operações da última para a primeira. Se uma reversão falhar,
as etapas que já tinham sido desfeitas são reaplicadas, evitando um estado parcialmente revertido.

## Segurança

- máximo de 32 operações e 16 previews compostos ativos;
- IDs duplicados do mesmo domínio são recusados;
- expiração local do preview;
- consentimento de escrita estrutural antes do apply;
- auditoria de cada tool específica e da transação superior;
- falha explícita `compensation_failed` quando a IDE impede recuperar integralmente o estado.
