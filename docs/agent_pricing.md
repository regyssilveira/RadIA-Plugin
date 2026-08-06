# Catálogo local de custos do Agent Runtime

O RadIA não embute preços de providers no código, pois tarifas e modelos mudam sem acompanhar uma
release do plugin. O Agent Runtime usa um catálogo local, auditável e editável:

```text
%USERPROFILE%\RadIA\agent-pricing.json
```

O arquivo é criado automaticamente na primeira execução de `/agent run`. Enquanto não houver uma
tarifa válida para o provider e modelo ativos, o cartão informa `cost pricing not configured`. Os
limites de tokens e tempo continuam ativos, mas o RadIA não apresenta uma estimativa monetária
inventada.

## Formato

```json
{
  "schemaVersion": 1,
  "currency": "USD",
  "defaultRunBudgetUsd": 5.0,
  "prices": [
    {
      "provider": "ExampleProvider",
      "model": "example-model",
      "inputUsdPerMillionTokens": 1.0,
      "outputUsdPerMillionTokens": 2.0
    }
  ]
}
```

Substitua o provider, modelo e tarifas pelos valores oficiais do seu contrato. Não copie as tarifas
do exemplo como se fossem preços reais.

`model` aceita `*` para definir uma tarifa padrão do provider. Uma correspondência exata deve ser
preferida à curinga. Os valores são expressos em dólares americanos por milhão de tokens.

## Cálculo e bloqueio

O custo estimado é:

```text
(tokens de entrada × tarifa de entrada + tokens de saída × tarifa de saída) / 1.000.000
```

O snapshot persiste o custo em micro-USD para evitar erros de ponto flutuante na aplicação do
limite. Quando `estimatedCostMicros` alcança `maxEstimatedCostMicros`, o runtime termina antes da
próxima decisão ou tool. A estimativa depende dos contadores retornados pelo provider e não inclui
impostos, créditos, cache com desconto ou regras comerciais externas.

Após alterar o catálogo, inicie uma nova execução agentiva para carregar as novas tarifas.
