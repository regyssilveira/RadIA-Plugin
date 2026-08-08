# Goal 2.1 — Reprodução autônoma de falhas runtime

> **Estado:** concluído e aceito ponta a ponta nos três alvos suportados.
> **Versão-alvo:** 2.1.0.
> **Escopo:** Delphi 12 Win32 e Delphi 13 Win32/IDE64.
> **Estado:** concluído na versão 2.1.0. A execução atual está no
> [goal para eliminar as seis lacunas competitivas](competitive_leadership_plan.md).

## Goal

Permitir que o RadIA compile uma aplicação, inicie-a pelo depurador da IDE, execute um cenário visual
limitado, capture a falha e seu contexto, proponha uma correção, recompile e repita o cenário para
comprovar o resultado.

O caso de referência é uma Access Violation ao abrir ou cancelar um formulário sem causa aparente.
O fluxo completo deve produzir evidências reproduzíveis, preservar o consentimento do usuário e
interagir somente com o processo iniciado na sessão de depuração atual.

## Estado atual

O RadIA já consegue:

- compilar projetos e executar testes DUnitX;
- iniciar, pausar, continuar e encerrar uma sessão de depuração;
- avançar por instruções, gerenciar breakpoints e avaliar expressões;
- consultar estado, pilha de chamadas e linha do tempo do depurador;
- correlacionar sessão, processo, projeto, executável e build;
- descobrir janelas e controles autorizados da aplicação depurada;
- preparar, autorizar, executar e cancelar cenários visuais limitados;
- capturar e comparar evidências sanitizadas entre uma falha e sua verificação;
- preparar alterações revisáveis e recompilar após o consentimento.

O aceite da versão 2.1 comprovou:

- cenário visual persistido e versionado como prova de regressão;
- reprodução da Access Violation com pilha e linha de origem;
- correção, novo build, nova sessão e comparação com resultado `fixed`;
- dez repetições e trinta ações consecutivas em Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64;
- build e 806 testes aprovados em cada alvo, sem falhas ou vazamentos;
- SonarQube com Quality Gate `OK`, zero issues e ratings A.

A geração automática de DUnitX é usada quando a causa pode ser isolada sem o ciclo visual. Quando a
falha depende da interface, o cenário versionado é a regressão apropriada.

## Limites de segurança

- A automação só pode acessar o processo iniciado pelo depurador atual e seus descendentes.
- PID, instante de criação, executável, projeto e build devem ser correlacionados antes de agir.
- Nenhuma ferramenta aceitará um handle arbitrário ou coordenadas globais da área de trabalho.
- Seletores devem usar identidade estável: classe, nome, texto, Automation ID e hierarquia.
- Cada cenário terá prévia, consentimento, tempo máximo, limite de ações e cancelamento imediato.
- Campos de senha nunca serão lidos, persistidos ou incluídos em evidências.
- Logs e capturas devem aplicar a política existente de redação de dados sensíveis.
- Encerrar a IDE, o projeto ou o depurador deve cancelar a automação sem deixar processos órfãos.

## Fora do escopo

- automação genérica da área de trabalho ou de aplicações de terceiros;
- execução em processos de produção ou não iniciados pela sessão atual;
- contorno de UAC, isolamento de sessão ou outras proteções do Windows;
- uso de coordenadas de tela como mecanismo principal;
- substituição de testes unitários por testes visuais;
- injeção de código na aplicação como requisito inicial.

## Arquitetura implementada

O núcleo receberá uma fachada neutra, `IRadIARuntimeAutomationFacade`. A integração OTA correlacionará
projeto, build, sessão e processo. Um adaptador Windows combinará UI Automation e descoberta Win32
para controles VCL com janela própria. Controles VCL sem handle terão capacidade explícita como
indisponível; uma sonda de teste opcional somente será considerada após medição dessa lacuna.

As ferramentas de alto nível disponíveis são:

| Ferramenta | Responsabilidade |
|---|---|
| `GetRuntimeWindows` | Listar apenas as janelas pertencentes à sessão de depuração atual. |
| `GetRuntimeControlTree` | Obter a árvore sanitizada de controles e seletores estáveis. |
| `PrepareRuntimeScenario` | Validar ações, riscos, limites e consentimentos antes da execução. |
| `RunRuntimeScenario` | Executar um roteiro declarativo e limitado no processo autorizado. |
| `CancelRuntimeScenario` | Interromper imediatamente o roteiro em andamento. |
| `GetRuntimeScenarioStatus` | Consultar ações, esperas, falhas e evidências do roteiro. |
| `WaitForDebuggerEvent` | Aguardar exceção, breakpoint, término ou mudança de estado sem busy-wait. |
| `CaptureRuntimeEvidence` | Registrar resultado sanitizado para diagnóstico e regressão. |
| `CompareRuntimeEvidence` | Comparar a reprodução da falha com a verificação em nova sessão e build. |

## Marcos

### M0 — Baseline, contratos e aplicação-laboratório

Detalhes e matriz: [Baseline M0](runtime_debug_automation_m0.md).

- mapear o ciclo atual de build, depuração, consentimento e cancelamento;
- criar uma aplicação VCL de teste com falha determinística ao abrir e cancelar um formulário;
- definir contratos de seletor, ação, asserção, resultado, capacidade e evidência;
- documentar modelo de ameaças e matriz Delphi 12/13.

**Aceite:** reprodução manual determinística nos três alvos e contratos aprovados por testes.

**Ainda faltará:** correlação de eventos, descoberta visual, execução, correção e repetição.

### M1 — Correlação e espera do depurador

Implementação e evidências: [Correlação M1](runtime_debug_automation_m1.md).

- atribuir identidade estável à sessão e ao processo depurado;
- correlacionar exceção, pilha, módulo, projeto, build e cenário;
- implementar espera cancelável para exceção, breakpoint, término e janela;
- respeitar timeout, encerramento da IDE e troca de projeto.

**Aceite:** a falha da aplicação-laboratório retorna exceção e pilha estruturadas nos três alvos.

**Ainda faltará:** localizar controles, interagir com a interface e repetir o cenário.

### M2 — Descoberta runtime segura

Implementação e evidências: [Descoberta segura M2](runtime_debug_automation_m2.md).

- listar somente janelas do processo autorizado e seus descendentes;
- expor hierarquia, modal, proprietário, classe, nome, texto e capacidades do controle;
- produzir seletores estáveis e indicar ambiguidades;
- rejeitar qualquer processo ou janela fora da sessão.

**Aceite:** localizar formulário principal, formulário-alvo e ações de abrir e cancelar, além de
comprovar a rejeição de uma janela externa.

**Ainda faltará:** executar ações, integrar a correção e gerar regressão.

### M3 — Execução declarativa limitada

Implementação e evidências: [Execução declarativa M3](runtime_debug_automation_m3.md).

- suportar invocar, clicar, preencher, selecionar, fechar, cancelar, aguardar e verificar;
- exigir prévia e consentimento antes de executar o cenário;
- aplicar limites de ações, tempo, repetição e uma parada de emergência visível;
- proibir coordenadas por padrão e falhar com diagnóstico quando o controle não for automatizável.

**Aceite:** abrir e cancelar o formulário-alvo, provocar a falha determinística e não tocar em
nenhuma janela externa.

**Ainda faltará:** fechar o ciclo de correção e transformar a reprodução em regressão.

### M4 — Diagnóstico, correção e repetição

Implementação e evidências: [Ciclo de correção M4](runtime_debug_automation_m4.md).

- integrar o cenário ao `/journey debug`;
- compilar, iniciar, executar, aguardar a exceção e coletar estado, pilha e expressões;
- preparar diff com hipótese e evidência, mantendo consentimento para cada mutação;
- recompilar, repetir o mesmo cenário e comparar os resultados.

**Aceite:** uma correção remove a Access Violation e o mesmo cenário termina sem exceção nos três
alvos, com trilha completa de consentimento.

**Ainda faltará:** endurecimento, regressão versionada e gate de entrega.

### M5 — Regressão, evidências e gate

Implementação e evidências: [Regressão e hardening M5](runtime_debug_automation_m5.md).

- gerar teste DUnitX quando a causa puder ser isolada;
- preservar cenário runtime quando a falha depender do ciclo visual;
- executar dez ciclos consecutivos por alvo sem flutuação ou processo órfão;
- validar acessibilidade, cancelamento, shutdown, auditoria, testes e SonarQube;
- documentar uso, limitações, solução de problemas e exemplos completos.

**Aceite:** matriz Delphi 12/13 verde, cenário versionado, evidência reproduzível e quality gate
aprovado.

**Ainda faltará:** nada deste goal; o plano congelado poderá ser retomado pela Fase 0.

## Ordem de implementação por complexidade

| Ordem | Entrega | Complexidade |
|---:|---|---|
| 1 | M0 — contratos e laboratório | Baixa |
| 2 | M1 — correlação e espera | Média |
| 3 | M2 — descoberta runtime | Alta |
| 4 | M3 — execução segura | Alta |
| 5 | M4 — ciclo autônomo completo | Muito alta |
| 6 | M5 — regressão e hardening | Alta |

## Definição de pronto

O goal foi concluído quando ficou comprovado que um usuário pode descrever o caminho até a falha, revisar o
roteiro e autorizar o RadIA a:

1. compilar e iniciar a aplicação no depurador;
2. reproduzir o problema sem interagir com outras aplicações;
3. capturar exceção, pilha, estado e evidências suficientes;
4. propor uma alteração revisável;
5. recompilar e repetir exatamente o mesmo cenário;
6. comprovar a ausência da falha e deixar uma regressão executável.

O plano de continuidade CLI pode ser retomado pela Fase 0, sem alterar seu escopo congelado.
