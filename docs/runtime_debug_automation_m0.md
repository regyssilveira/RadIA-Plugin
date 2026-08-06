# M0 — Baseline e contratos da automação runtime

> **Estado:** em andamento.
> **Goal:** [Reprodução autônoma de falhas runtime](runtime_debug_automation_plan.md).

## Entregas implementadas

- fachada neutra `IRadIARuntimeAutomationFacade`;
- identidade obrigatória de sessão, processo, projeto, executável e build;
- contratos de seletor, ação, limites, cenário e resultado;
- validação de seletores estáveis e cenários limitados;
- aplicação-laboratório VCL com falha determinística ao abrir ou cancelar um formulário;
- script reproduzível para compilar o laboratório com Delphi 12 ou 13;
- testes unitários dos contratos de segurança.

Esses contratos ainda não registram ferramentas no agente. Eles delimitam a futura implementação
para impedir que os adaptadores de M1–M3 ampliem silenciosamente o acesso à área de trabalho.

## Aplicação-laboratório

O projeto está em `Tests/RuntimeLab/RadIARuntimeLab.dproj` e oferece dois caminhos:

1. `btnFailOnOpen` abre o formulário-alvo e provoca uma Access Violation em `FormShow`;
2. `btnFailOnCancel` abre o formulário-alvo e `btnCancel` provoca a mesma falha no clique.

Os dois caminhos convergem em `TriggerDeterministicAccessViolation`, mantendo a origem e a pilha
previsíveis. A falha é intencional e existe somente nessa aplicação de teste.

Para compilar:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Build-RadIA.RuntimeLab.ps1 `
  -DelphiVersion "23.0"
```

Use `37.0` para o Delphi 13.

## Matriz de aceite M0

| Host da IDE | Aplicação | Build | Abrir | Cancelar | Depuração manual |
|---|---|---|---|---|---|
| Delphi 12 Win32 | Win32 | Aprovado | Pendente | Pendente | Pendente |
| Delphi 13 Win32 | Win32 | Aprovado | Pendente | Pendente | Pendente |
| Delphi 13 IDE64 | Win32 | Aprovado | Pendente | Pendente | Pendente |

O M0 só será concluído depois que as duas ações pararem na linha intencional, com pilha legível, em
cada host. A compilação isolada não substitui essa evidência.

## Modelo de ameaças

| Ameaça | Limite definido no contrato | Evidência exigida nas próximas fases |
|---|---|---|
| Atingir outra aplicação | Identidade completa da sessão é obrigatória | Teste negativo com janela externa |
| Reutilizar PID antigo | PID e instante de criação são inseparáveis | Teste de reciclagem de PID |
| Executar roteiro ilimitado | Limites de ações, duração e repetição | Testes de timeout e cancelamento |
| Selecionar controle ambíguo | Seletor exige identidade estável | Teste de ambiguidade |
| Expor segredo visual | Evidência será sanitizada | Teste com controle de senha |
| Deixar processo órfão | Sessão pertence ao depurador atual | Testes de stop e shutdown |
| Mutar código sem autorização | Fachada não altera arquivos | Integração com consentimento existente |

## Decisões arquiteturais

- O núcleo não dependerá de UI Automation, Win32 ou OTA.
- A correlação de sessão será implementada antes da descoberta de janelas.
- A primeira versão não aceitará handles fornecidos pelo modelo.
- Coordenadas não farão parte do contrato de ações.
- Controles VCL sem handle serão reportados como capacidade indisponível.
- Uma sonda dentro da aplicação somente será avaliada após medir a cobertura real da descoberta.

## O que falta após esta etapa

- concluir a reprodução manual nas três combinações da matriz;
- M1: correlação e espera cancelável do depurador;
- M2: descoberta segura de janelas e controles;
- M3: execução declarativa limitada;
- M4: ciclo de diagnóstico, correção e repetição;
- M5: regressão, evidências e hardening.
