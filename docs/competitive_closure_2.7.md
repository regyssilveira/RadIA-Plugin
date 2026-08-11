# Fechamento competitivo determinístico 2.7

Este documento congela a régua usada para concluir as diferenças funcionais da linha 2.7. Uma
capacidade aprovada não pode ser reaberta por opinião, mudança de nome ou nova comparação. Para
reabrir um item, é necessária uma regressão reproduzível no RadIA ou uma nova baseline formal.

## Baseline congelada

- RadIA: versão 2.6.2, commit `1b2dd78`;
- referência CLI/IDE: commit `9e4416f`;
- referência de extensões: commit `26698ff`;
- referência de conhecimento: commit `f8b8f5d`;
- referência integrada à IDE: documentação pública capturada em 11 de agosto de 2026.

Os nomes das referências externas são deliberadamente omitidos da documentação do produto. Os
commits e a data tornam a comparação reproduzível sem transformar concorrentes em dependências ou
conteúdo operacional do RadIA.

## Exclusões permanentes

- C++ e Lazarus;
- marketplace, assinatura e instalação comercial;
- substituição do WebView atual;
- empacotamento obrigatório de CLIs;
- funcionalidades exclusivas do fabricante da IDE.

Esses pontos são decisões explícitas de produto e nunca devem voltar como lacunas desta baseline.

## Matriz fechada

| ID | Requisito | Estado | Evidência obrigatória |
|---|---|---|---|
| CC-01 | Projetos gerados | Aprovado | Delphi 12/13, 11 projetos e 5/5 testes |
| CC-02 | Prompt por template | Aprovado | Matriz PT/EN pela conversa real |
| CC-03 | Intenção e visão da IDE | Aprovado | Smoke de Design, Code, erro e cancelamento |
| CC-04 | Comentário na revisão | Aberto | Feedback sem mutação e com auditoria |

## Regra de aprovação

Um item somente muda para **Aprovado** quando possui, no mesmo escopo:

1. implementação atual;
2. teste unitário;
3. teste de integração;
4. smoke na IDE real quando envolve OTA ou interface;
5. evidência vinculada a commit rastreado limpo;
6. documentação em português e inglês;
7. Quality Gate aprovado.

O fechamento da versão exige `open=0`, `failed=0` e `unverified=0` no manifesto
`competitive_closure_baseline_2.7.json`.

## Evidência de CC-01

A matriz
[generated_project_templates_evidence_2.6.2.json](generated_project_templates_evidence_2.6.2.json)
foi produzida pelo commit `58faee7`, com `sourceDirty=false`. Delphi 12 e Delphi 13 compilaram os 11
projetos, executaram a calculadora e aprovaram os cinco testes DUnitX sem falhas, erros, itens
ignorados ou vazamentos.

## Evidência de CC-02

A matriz [natural_project_prompts_evidence_2.7.0.json](natural_project_prompts_evidence_2.7.0.json)
foi produzida pelo commit `5d217aa`, com `sourceDirty=false`. Os sete templates foram solicitados por
prompts naturais em português e inglês pela conversa real, totalizando 14 cenários aprovados no
Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

## Evidência de CC-03

A matriz [ide_intent_navigation_evidence_2.7.0.json](ide_intent_navigation_evidence_2.7.0.json) foi
produzida pelo commit `4604508`, com `sourceDirty=false`. Em uma IDE real, os três alvos mapearam
intenções para Design e Code, recusaram intenção inválida, cancelaram sem executar e encerraram a IDE
sem deixar a descoberta MCP ativa.
