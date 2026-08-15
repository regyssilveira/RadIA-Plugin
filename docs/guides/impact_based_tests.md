# Testes DUnitX selecionados por impacto

Durante o desenvolvimento, o RadIA pode calcular e executar o menor conjunto de fixtures DUnitX que
consegue justificar com segurança. Essa seleção reduz o tempo de feedback sem enfraquecer o gate de
release, que continua executando todas as suítes, a calculadora e a abertura de projetos.

## Como a seleção funciona

`PlanImpactedDUnitXTests` recebe os arquivos alterados, símbolos opcionais e um relatório de cobertura
opcional. A ferramenta monta o grafo transitivo de `uses`, identifica as fixtures registradas com
`RegisterTestFixture` e explica por que cada fixture foi selecionada.

O resultado informa:

- `runMode: selected` quando existe evidência suficiente para filtrar fixtures;
- `runMode: full` quando a opção segura é executar toda a suíte;
- `confidence: high` quando grafo e cobertura confirmam as units alteradas;
- `confidence: medium` quando o grafo é conclusivo, mas não existe cobertura;
- `confidence: fallback-full-suite` quando algum sinal é incompleto ou ambíguo.

`RunImpactedDUnitXTests` produz o mesmo plano e entrega as fixtures ao runner DUnitX existente. Uma
lista vazia representa a suíte completa, nunca a ausência de testes.

Exemplo de planejamento:

```json
{
  "changedFiles": ["Source/Orders/OrderService.pas"],
  "changedSymbols": ["TOrderService.CreateOrder"],
  "coverageReport": "Output/Coverage/CodeCoverage_Summary.xml"
}
```

Exemplo de execução:

```json
{
  "changedFiles": ["Source/Orders/OrderService.pas"],
  "executablePath": "Output/Win32/Debug/MyProjectTests.exe",
  "timeoutMs": 120000
}
```

## Fallbacks de segurança

O RadIA executa a suíte completa quando encontra arquivo de tipo desconhecido, mudança sem unit
correspondente, ausência de fixture relacionada, cobertura presente sem a unit alterada, mais de 100
filtros ou mais de 2.000 arquivos Pascal no projeto. Arquivos e relatórios fora do workspace são
recusados. O relatório de cobertura apenas confirma que a unit participou da medição; o grafo de
dependências continua sendo responsável pela seleção das fixtures.

## Quando usar

Use a seleção por impacto para feedback rápido após mudanças localizadas. Use `RunDUnitXTests` sem
filtros quando quiser solicitar explicitamente toda a suíte. Em qualquer release, o processo oficial
ignora otimizações de impacto e executa obrigatoriamente as suítes completas no Delphi 12 e 13, os
testes funcionais e DUnitX da calculadora e a criação, abertura e navegação de projetos.
