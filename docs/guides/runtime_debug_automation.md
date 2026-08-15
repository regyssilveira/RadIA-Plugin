# Diagnóstico Runtime Autônomo

O RadIA pode reproduzir uma falha visual em uma aplicação VCL iniciada pelo depurador, capturar
evidências, preparar uma correção revisável, recompilar, repetir o cenário e comprovar se a falha
foi removida.

> **Importante:** `CaptureRuntimeEvidence` continua significando evidência estruturada do debugger:
> exceção, call stack, estado, expressões e identidade da sessão. `CaptureRuntimeVisual` é a tool
> separada que captura uma janela autorizada e apresenta o PNG no chat.

## Sessão visual no chat

A sessão visual é vinculada à identidade completa criada pelo debugger. `CaptureRuntimeVisual`
recebe apenas o ID opaco devolvido por `GetRuntimeWindows`, revalida executável, instante de criação,
sessão e PID, e recusa janelas invisíveis, minimizadas, de outro processo ou maiores que 2560×1440.
Cada chamada exige consentimento porque a imagem pode conter dados da aplicação.

O resultado entregue ao agente contém somente metadados. O PNG segue por um canal local separado
para um card do chat que apresenta **Antes**, **Depois**, estado e timeline. As imagens ficam apenas
em memória: no máximo seis capturas, 2 MiB cada e 8 MiB no total, com expiração após dez minutos.
Outra sessão ou a expiração elimina o conteúdo anterior. O card é evidência visual complementar;
valores e sucesso continuam sendo confirmados pelas tools estruturadas e pelo debugger.

A timeline não é inferida pelo chat: o coordenador do cenário publica o início e o término de cada
ação, a repetição, o tipo da ação e o resultado final. Seletores, valores digitados e conteúdo dos
controles não entram nesses eventos. Uma falha no card é isolada e nunca interrompe o cenário.

## Quando usar

Use este fluxo quando o problema depende de uma sequência na interface, por exemplo:

- Access Violation ao abrir, fechar ou cancelar um formulário;
- erro que só aparece depois de preencher ou selecionar um controle;
- falha intermitente que precisa ser repetida com o mesmo roteiro;
- regressão visual que não pode ser isolada adequadamente em um teste unitário.

Se a causa puder ser isolada sem a interface, prefira também gerar um teste DUnitX. O cenário runtime
complementa testes unitários; ele não os substitui.

## Pré-requisitos

- Delphi 12 Win32 ou Delphi 13 Win32/IDE64;
- projeto ativo compilável para Win32 ou Win64;
- modo agente ativado pelo botão **Agent On/Off** ou por `/agent on`;
- consentimento habilitado para build, depurador, execução runtime e escrita;
- aplicação VCL com controles que possuam janela própria (`HWND`).

O fluxo também pode ser dirigido por um cliente MCP. As mesmas regras de consentimento e segurança
continuam válidas.

## Fluxo completo

1. Descreva o caminho exato até a falha e o resultado esperado.
2. O RadIA compila com `BuildProject`, enfileira a ação oficial da IDE com `StartDebugging` e usa
   `GetRuntimeDebugSession` para confirmar que o processo realmente iniciou.
3. `WaitForDebuggerEvent` observa parada ou exceção sem bloquear a thread principal da IDE.
4. A sessão correlaciona PID, instante de criação, executável, projeto e build.
5. `GetRuntimeWindows` e `GetRuntimeControlTree` localizam somente elementos do processo autorizado.
6. `CaptureRuntimeVisual` com `phase=before` registra a janela antes da interação.
7. `PrepareRuntimeScenario` cria um preview limitado e com fingerprint.
8. Após consentimento, `RunRuntimeScenario` executa o roteiro.
9. `CaptureRuntimeVisual` com `phase=after` completa o par visual no mesmo card.
10. Ao ocorrer a falha, `CaptureRuntimeEvidence` registra exceção, pilha, estado e expressões.
11. O RadIA prepara uma hipótese e um diff; nenhuma alteração é aplicada sem revisão.
12. Depois do aceite, o projeto é recompilado e uma nova sessão de debug é iniciada.
13. O mesmo cenário é repetido e uma evidência `verification` é capturada.
14. `CompareRuntimeEvidence` exige o mesmo projeto, mas sessões e builds distintos.
15. Com `outcome=fixed`, o cenário pode ser salvo como regressão e repetido em ciclos futuros.

### Observação confiável do depurador

`StartDebugging` retorna `starting` antes de a ação Run entrar no loop do depurador. Durante a
execução, use `GetRuntimeDebugSession` e `WaitForDebuggerEvent`; consultas OTA síncronas são
reservadas para antes da execução ou depois de uma parada. O evento de breakpoint é confirmado
pelo callback de disparo da própria OTA, inclusive quando o Delphi não publica uma mudança de
estado separada. Projetos criados pelo RadIA já incluem todos os símbolos exigidos por esse fluxo.

## Exemplo de pedido

```text
/agent run Reproduza a Access Violation que ocorre ao clicar em
"Fail when form cancels" e depois em "Cancel". Capture a pilha,
proponha uma correção, recompile, repita o cenário e deixe uma
regressão visual com 10 repetições.
```

O plano aparece antes da primeira execução. Cada tool com risco mantém seu próprio consentimento.

## Tools envolvidas

| Etapa | Tools principais |
|---|---|
| Build | `BuildProject`, `GetBuildStatus`, `CancelBuild` |
| Sessão | `StartDebugging`, `GetDebuggerState`, `GetRuntimeDebugSession`, `StopDebugging` |
| Descoberta | `GetRuntimeWindows`, `GetRuntimeControlTree` |
| Visual | `CaptureRuntimeVisual` antes e depois do cenário |
| Cenário | `PrepareRuntimeScenario`, `RunRuntimeScenario`, `GetRuntimeScenarioStatus`, `CancelRuntimeScenario` |
| Evidência | `WaitForDebuggerEvent`, `CaptureRuntimeEvidence`, `CompareRuntimeEvidence` |
| Correção | `PreparePatch`, `ApplyPatch`, `RevertPatch` |
| Regressão | `PrepareRuntimeRegression`, `SaveRuntimeRegression`, `ListRuntimeRegressions`, `PrepareSavedRuntimeScenario` |

Consulte [O que faz e quando usar cada ferramenta](../reference/internal_tools_reference.md) para os contratos
operacionais e [Catálogo gerado](../reference/runtime_tool_catalog.md) para a lista registrada na build.

## Cenários e seletores

Um cenário define nome, limites e ações. As ações disponíveis são `invoke`, `setValue`, `select`,
`close`, `cancel`, `wait` e `assert`. Cada alvo usa identidade estável, como classe, texto,
Automation ID e caminho hierárquico.

Controles que só aparecem depois de uma ação anterior são resolvidos durante a execução. No Delphi
13 IDE64 controlando uma aplicação Win32, o Windows pode não devolver o texto de um controle. Nesse
caso, o RadIA usa classe e caminho somente dentro da janela raiz visível e habilitada, evitando
confundir o formulário modal com o formulário proprietário desabilitado.

Não são aceitos handles arbitrários, coordenadas globais ou janelas de outros processos.

## Evidências e comparação

Uma evidência contém:

- fase `failure` ou `verification`;
- identidade da sessão, projeto, executável e build;
- resultado e quantidade de ações do cenário;
- último evento do depurador;
- pilha acessível e até dez expressões sanitizadas;
- fingerprint do conteúdo.

Uma comparação só é válida quando:

- a primeira evidência é `failure` e contém uma exceção;
- a segunda é `verification`;
- ambas pertencem ao mesmo projeto;
- os IDs de sessão são distintos;
- os IDs de build são distintos.

O resultado `fixed` significa que a falha foi reproduzida, a verificação terminou e a nova evidência
não contém a mesma condição de exceção.

## Regressão versionada

`SaveRuntimeRegression` grava
`.radia/runtime-scenarios/<regressionId>.json` com schema, fingerprint e escrita atômica. O arquivo
não guarda IDs transitórios da sessão. Em uma execução futura:

1. inicie uma nova sessão de debug;
2. chame `PrepareSavedRuntimeScenario`;
3. revise o preview e autorize `RunRuntimeScenario`;
4. confirme `state=succeeded`, a repetição final e o total de ações.

O artefato deve ser incluído no controle de versão pelo usuário.

## Segurança e consentimento

- A automação fica confinada ao processo depurado e seus descendentes.
- Campos de senha são redigidos e não entram em evidências.
- A captura visual é `sensitive`, exige consentimento em toda chamada e pode conter qualquer texto
  visível dentro da janela autorizada.
- Build, debug, cenário e escrita preservam o diálogo de consentimento.
- O usuário pode cancelar o cenário sem novo consentimento.
- Troca de projeto, término do processo ou shutdown invalida a sessão.
- Cada novo processo depurado recebe uma nova identidade de sessão.

## Limitações

- Controles VCL sem janela própria não podem ser automatizados por este mecanismo.
- Aplicações elevadas em outro nível de integridade podem ser inacessíveis.
- Janelas minimizadas, invisíveis ou acima de 2560×1440 não são capturadas.
- A execução usa identidade semântica e não visão computacional ou coordenadas.
- Uma execução visual bem-sucedida não prova sozinha ausência de vazamento ou correção lógica geral.
- Compilação, DUnitX, análise estática e revisão humana continuam fazendo parte do gate.

## Solução de problemas

- **Nenhuma janela encontrada:** aguarde a aplicação entrar em `running` e confirme
  `GetRuntimeDebugSession.complete=true`.
- **`runtime_target_not_found`:** atualize a descoberta e verifique classe, texto e caminho.
- **`runtime_capture_unavailable`:** restaure e deixe visível a janela, confirme o PID e repita
  `GetRuntimeWindows` antes de gerar um novo ID opaco.
- **Sessão incomparável:** pare, recompile e inicie uma nova sessão antes da verificação.
- **Exceção de software de segurança no startup:** confirme a pilha; continue apenas quando ela não
  pertencer ao código do projeto.
- **Cenário excedeu o tempo:** reduza repetições na reprodução e use o cenário versionado completo
  após a correção.
- **Artefato recusado:** o fingerprint não corresponde ao conteúdo; gere e revise um novo preview.

## Evidência histórica de aceite inicial

### Matriz automatizada atual da captura visual

A implementação atual abre uma janela VCL real, obtém seu ID opaco pelo facade de descoberta,
captura o mesmo `HWND` pelo facade de produção e valida dimensões e assinatura PNG. O teste passou
no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64. A renderização segura do card, incluindo o
par anterior/posterior e a timeline, é coberta adicionalmente pelos testes web locais.

O caso-laboratório de Access Violation ao cancelar um formulário foi comprovado em Delphi 12 Win32,
Delphi 13 Win32 e Delphi 13 IDE64. Em cada alvo houve reprodução, captura, correção, novo build,
nova sessão, comparação `fixed` e regressão com 10 repetições. A matriz de build executou 806 testes
por alvo sem falhas ou vazamentos, e o SonarQube permaneceu com Quality Gate `OK`.
