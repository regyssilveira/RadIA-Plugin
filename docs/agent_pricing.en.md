# Agent Runtime local pricing catalog

RadIA does not hardcode provider prices because rates and models change independently from plugin
releases. Agent Runtime uses a local, auditable, editable catalog:

```text
%USERPROFILE%\RadIA\agent-pricing.json
```

The file is created automatically on the first `/agent run`. Until a valid rate exists for the
active provider and model, the card reports `cost pricing not configured`. Token and time limits
remain active, but RadIA does not present a fabricated monetary estimate.

## Format

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

Replace the provider, model, and rates with the official values for your contract. Do not treat the
example rates as current prices.

`model` accepts `*` as a provider fallback. An exact match takes precedence over the wildcard.
Values are expressed in US dollars per million tokens.

## Calculation and enforcement

The estimated cost is:

```text
(input tokens × input rate + output tokens × output rate) / 1,000,000
```

Snapshots persist the amount in micro-USD to avoid floating-point errors while enforcing the
limit. When `estimatedCostMicros` reaches `maxEstimatedCostMicros`, the runtime stops before the
next decision or tool. The estimate depends on usage counters returned by the provider and excludes
taxes, credits, discounted cache rates, and external commercial rules.

Start a new agent run after changing the catalog to load the new rates.
