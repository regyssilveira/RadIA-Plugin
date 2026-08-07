# M5 — Regressão, evidências e hardening

## Objetivo

Transformar a reprodução visual aprovada em uma regressão executável depois de recompilar ou abrir
outra sessão do Delphi, sem persistir handles, IDs opacos, coordenadas ou segredos.

## Artefato versionado

Cada regressão fica em:

```text
.radia/runtime-scenarios/<id>.json
```

O schema 1 registra ID, data, fingerprint SHA-256 e a definição do cenário. O arquivo deve ser
versionado com o projeto quando fizer parte de sua suíte de regressão. A referência formal está em
[`runtime_regression_schema_v1.json`](runtime_regression_schema_v1.json).

IDs opacos retornados por `GetRuntimeWindows` e `GetRuntimeControlTree` pertencem somente à sessão
atual e são recusados na persistência. Cada ação usa um seletor repetível:

```json
{
  "className": "TButton",
  "text": "Cancel",
  "parentPath": "TTargetForm[0]"
}
```

Para uma janela raiz, `parentPath` deve ser `$root`. A resolução é refeita apenas dentro do processo
autorizado. Nenhum alvo ou mais de um alvo produz falha segura; o RadIA não escolhe por coordenadas.

## Fluxo

1. Execute e confirme a correção com `/journey debug`.
2. Se a causa puder ser isolada, crie um teste DUnitX focado com as tools de projeto e patch.
3. Se a falha depender do ciclo visual, chame `PrepareRuntimeRegression`.
4. Revise caminho, fingerprint e possível sobrescrita.
5. Autorize `SaveRuntimeRegression` e faça o commit do artefato quando desejar.
6. Em uma nova sessão de debug, use `PrepareSavedRuntimeScenario`.
7. Autorize `RunRuntimeScenario`; a regressão pode definir até dez repetições.

`ListRuntimeRegressions` descobre os artefatos. `RevertRuntimeRegression` desfaz somente a gravação
rastreada e recusa sobrescrever alterações feitas depois do save.

## Proteções

- escrita confinada ao projeto ativo e à pasta fixa `.radia/runtime-scenarios`;
- IDs aceitam somente letras, números e hífen;
- limite de 1 MiB por artefato;
- escrita temporária e troca atômica;
- preview invalidado quando projeto ou arquivo muda;
- schema, ID e fingerprint revalidados antes da repetição;
- dados reconhecidos pelo redator de segredos são recusados;
- execução continua exigindo consentimento novo em toda tentativa;
- fechamento, cancelamento e troca de sessão continuam interrompendo o cenário pelo mecanismo M3.

## Aplicação-laboratório

O exemplo versionado
[`cancel-access-violation.json`](../Tests/RuntimeLab/.radia/runtime-scenarios/cancel-access-violation.json)
abre o formulário modal, cancela-o e permite até dez repetições após a correção. O cenário de falha
deve ser executado uma vez para capturar a exceção; as dez repetições pertencem à verificação
corrigida.

## Solução de problemas

| Resultado | Significado | Ação |
|---|---|---|
| `runtime_regression_not_replayable` | O cenário ainda usa ID opaco ou não tem seletor estável. | Obtenha classe, texto e caminho na árvore atual e remova `targetId`. |
| `runtime_regression_unavailable` | Projeto, arquivo, schema ou fingerprint mudou. | Reabra o projeto correto e prepare novamente; não edite o fingerprint manualmente. |
| `runtime_target_not_found` | O seletor não existe na sessão atual. | Compare a árvore atual com o artefato e atualize por preview. |
| `runtime_scenario_timeout` | A janela ou controle não surgiu dentro do limite. | Confirme o caminho reproduzível e ajuste uma espera limitada. |
| `sensitive_runtime_target` | O alvo é um campo de senha. | Remova a ação; segredos não fazem parte de regressões runtime. |

## Evidência pendente para aceite

Evidência automatizada desta entrega:

- catálogo verificável com 111 ferramentas;
- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64: 802/802 testes por alvo, sem falhas,
  erros, ignorados ou vazamentos;
- o teste do executor conclui dez repetições e vinte ações sem flutuação em cada suíte da matriz;
- SonarQube aprovado com cobertura nova de 82,5%, duplicação nova de 0,97826% e zero issues;
- métricas globais: cobertura de 82,9%, duplicação de 2,1%, zero bugs, vulnerabilidades, hotspots
  ou smells e todos os ratings A.

O aceite operacional final ainda exige execução real do laboratório nos três hosts, incluindo dez
ciclos corrigidos sem flutuação, processo órfão ou falha de shutdown.
