# Matriz automatizada de testes de uso

A matriz de uso valida o RadIA como produto dentro do Delphi, complementando testes unitários e Web.
Ela possui níveis diferentes para não transformar toda entrega em uma certificação de várias horas.

## Camadas

| Camada | Finalidade | Execução |
|---|---|---|
| Integração headless | Contratos de serviços, tools, consentimento e adapters | DUnitX e Node.js, sem abrir a IDE |
| Integração OTA | Package, catálogo, comandos e estado real da IDE | Instância real e descartável do Delphi |
| Ponta a ponta | Jornada completa percebida pelo usuário | Projeto-fixture, UI, build, testes, debug e shutdown |

O manifesto versionado fica em `Tests/Usage/usage-matrix.json`. Cada cenário declara alvos,
quantidade de ciclos, timeout e evidências obrigatórias. O runner não usa coordenadas absolutas nem
provider real no perfil obrigatório.

Contratos `host` validam estrutura, mas não contam como prova de uma promessa pública. Somente cenários
`user-journey`, executados na IDE real e com resultados observáveis verdadeiros na evidência, podem cobrir
as promessas registradas em `Tests/Usage/release-promises.json`. Execute a auditoria com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePromises.ps1 `
  -Enforce
```

A criação VCL começa no campo real do chat, aceita a recomendação exibida ao usuário e exige evidência
estruturada de preview, criação, abertura, build e execução. A jornada reprova conclusão antecipada do CLI,
tool indisponível, ausência do arquivo de projeto ou qualquer etapa obrigatória não executada.

O isolamento de sessão também usa a WebView real: deixa uma recomendação pendente na conversa anterior,
cria outra conversa, confirma que o histórico foi limpo e exige a rejeição da aprovação antiga. A troca e
o rollback de projeto continuam sendo comprovados pela jornada da IDE. Nenhum resultado pode reutilizar o
booleano de consentimento como substituto para isolamento de chat ou de ação pendente.

Cada promessa também declara duração máxima, resultados esperados e resultados proibidos. A cobertura
obrigatória inclui conversa direta, criação VCL, correção de build, DUnitX, persistência da janela,
consentimento somente para mutações, orçamento de passos, cancelamento, recuperação de provedor/CLI,
instalação e atualização, isolamento de contexto e proteção de dados sensíveis.

## Consultar o plano sem abrir o Delphi

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup `
  -RequirePackageProvenance `
  -PlanOnly
```

`-PlanOnly` valida o manifesto e retorna JSON com todas as combinações que seriam executadas. Não
inicia, instala ou modifica a IDE.

## Níveis de execução

| Nível | Quando usar | Abrangência |
|---|---|---|
| `release` | Toda publicação corretiva ou menor | Suítes completas, templates, startup nos três alvos e jornadas críticas no Delphi 13 Win32 |
| `targeted` | Durante o desenvolvimento e após uma correção localizada | Somente cenários e alvos informados explicitamente |
| `regression` | Release maior, mudança transversal ou investigação de instabilidade | Todos os 49 fluxos em todos os alvos compatíveis |

Execute obrigatoriamente `regression` quando houver mudança no instalador, lifecycle da WebView2,
shutdown da IDE, isolamento de sessão, segurança/consentimento, orquestrador E2E ou matriz de targets.
Também execute antes de uma release maior, após uma falha que não possa ser isolada e quando a seleção
direcionada não representar com segurança a superfície alterada. A regressão completa é uma certificação
sob demanda; ela não bloqueia rotineiramente releases menores já cobertas pelo gate `release`.

## Executar durante o desenvolvimento

Feche todas as instâncias do Delphi e execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup
```

O resultado agregado fica em `Output/Validation/UsageMatrix/usage-matrix.json`. No perfil `release`, o
orquestrador executa as jornadas críticas no Delphi 13 Win32. Durante o
desenvolvimento, a evidência informa que a origem está suja e que a proveniência do pacote não foi
exigida; esse resultado não autoriza uma release.

Para executar somente a área alterada, informe cenário e alvo explicitamente:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile targeted `
  -ScenarioId calculator-history-fidelity `
  -TargetId delphi13-win32
```

Use `-PlanOnly` antes da execução para conferir o custo e as combinações sem abrir o Delphi. Exemplos de
seleção: UI usa `chat-window-state-persistence`; agente usa `agent-step-budget` e
`request-cancellation-recovery`; geração usa `natural-vcl-project-creation` e
`calculator-history-fidelity`; testes e reparo usam `build-failure-repair` e
`dunitx-create-run-repair`.

`natural-vcl-project-creation` começa deliberadamente com uma pasta já existente. O cenário só passa
quando o usuário simulado informa outro destino, os requisitos originais permanecem no objetivo, a
execução continua no orquestrador nativo e o projeto é criado, aberto e compilado sem iniciar o aplicativo.
Esse é o gate representativo da experiência padrão. `calculator-history-fidelity` e
`vcl-project-creation-lifecycle` pedem e validam execução funcional em ambiente controlado.

O perfil `targeted` usa o build já instalado e nunca troca silenciosamente a IDE do desenvolvedor. Instale
explicitamente a revisão desejada com `build.ps1 -Install` antes de executá-lo. Os perfis `startup`,
`release` e `regression` geram e instalam seus próprios pacotes por alvo.

## Gate obrigatório de release

Depois dos builds da mesma revisão limpa e antes de gerar os packages oficiais, execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleaseUsage.ps1
```

Antes de ocupar a máquina, acrescente `-PlanOnly` para obter o plano agregado sem compilar, instalar ou
abrir o Delphi.

Esse comando compõe o gate rápido e obrigatório:

1. suítes DUnitX completas do RadIA no Delphi 12 e 13;
2. smoke de inicialização e encerramento nos três alvos suportados;
3. geração e build de todos os templates suportados no Delphi 12 e 13;
4. operação visual `2 + 3 = 5` na calculadora VCL;
   o cenário também comprova que o pedido de histórico gera `2 + 3 = 5` na lista e que a ação de
   limpeza deixa a lista vazia;
5. execução dos cinco testes DUnitX da calculadora;
6. criação, abertura e navegação imediata no Delphi 13 Win32 representativo;
7. instalação limpa e atualização no alvo representativo;
8. roteamento real de pedidos iniciantes para criação, build, testes e diagnóstico, com fallback
   educativo e contadores locais sanitizados.

O perfil `regression` continua contendo todos os cenários registrados exatamente uma vez e os distribui
pelos alvos compatíveis. Execute a certificação completa com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile regression `
  -EvidencePath Output\Validation\UsageMatrix\regression.json
```

A proveniência dos packages e do instalador é validada depois, no gate de empacotamento, porque esses
artefatos ainda não existem durante `Test-RadIA.ReleaseUsage.ps1`. Usar `-RequirePackageProvenance`
antes de `New-RadIA.ReleaseEvidence.ps1` é inválido. A matriz compara a BPL instalada com o build local
da mesma revisão; o runner instala esse build nos três alvos antes da matriz, e a etapa seguinte vincula
a revisão aos packages e ao instalador.

Antes do primeiro build e de cada instalação, o gate encerra somente processos auxiliares conhecidos do RadIA
(`RadIA.Semantic.Engine` e `RadIA.MCP.Bridge`) quando nenhuma IDE está aberta. Isso impede que um processo órfão
de uma sessão anterior bloqueie a substituição dos binários, sem encerrar terminais ou processos do projeto.

Uma falha exata de prontidão na inicialização da IDE permite uma única retentativa limitada do mesmo alvo.
A primeira saída é preservada na evidência com `attemptCount: 2` e `startupRetryUsed: true`. Qualquer falha
funcional, de build, teste, navegação, debug ou encerramento bloqueia imediatamente sem retentativa.
A saída padrão e o stderr do processo filho são capturados junto com o exit code; stderr não pode interromper
o orquestrador antes que ele registre a tentativa e aplique essa política.

Se `DEXT_ROOT` não estiver configurado, somente os templates DEXT são registrados como
`not-required`; os demais templates e gates continuam obrigatórios. Quando `DEXT_ROOT` existe, os
servidores e endpoints DEXT também são compilados e executados.

## Evidência e falhas

Artefatos ficam em `Output/Validation/ReleaseUsage` e nunca são publicados como assets da release.
Cada resultado registra alvo, arquitetura, duração, status e cauda sanitizada da saída. Uma falha
preserva evidência parcial e bloqueia a publicação; repetir um cenário não converte a primeira falha
em sucesso.

O perfil `startup` comprova package carregado, contrato de tools válido, shutdown limpo e ausência de
processos órfãos. O perfil `release` executa contratos críticos independentes da IDE e jornadas
representativas. O perfil `targeted` exige `-ScenarioId`; o perfil `regression` impede que um cenário
registrado fique fora da certificação completa. O
primeiro comprova confirmação explícita da rota por intenção, revisão do comando, continuação no chat
e validação do comando pendente pelo host. A suíte DUnitX executa dezesseis prompts naturais contra
o classificador Pascal real; o contrato host-neutral confirma que a telemetria não aceita conteúdo
do prompt. Novos comportamentos devem acrescentar cenários ao
manifesto e testes de contrato em `Tests/Web/RadIA.UsageMatrix.test.js`.
