# Auditoria de release 2.0.0

Esta auditoria registra os gates reproduzíveis de segurança, privacidade, acessibilidade e
documentação do candidato RadIA 2.0.0. Ela complementa, mas não substitui, os ciclos reais na IDE.

| Área | Controle verificado | Evidência automatizada | Estado |
|---|---|---|---|
| Segurança | Consentimento, confinamento, sanitização, credenciais protegidas e extensões assinadas | Suíte DUnitX e [evidência Sonar](sonar_quality_evidence_2.0.0.json) | Aprovado |
| Privacidade | Nenhuma conexão externa iniciada pelas superfícies Web; provider remoto continua explícito | `npm run test:web` | Aprovado |
| Acessibilidade | Nomes acessíveis, regiões vivas, estado ARIA, foco visível e ativação por teclado | `npm run test:web` | Aprovado |
| Documentação | Links locais existentes e ausência de marcadores comuns de mojibake | `npm run test:docs` | Aprovado |

## Correções da auditoria

- Removido o carregamento automático da fonte Inter pelo Google no startup do chat.
- Chat e diff ganharam regiões semânticas para conversa, status, erros e seleção.
- Botões somente com ícone ganharam nomes acessíveis.
- Agent Mode, sessões, provider, modelo e diff mantêm estados ARIA sincronizados.
- Seletores customizados aceitam teclado, Escape e foco visível.
- A auditoria de documentação percorre o README e todos os Markdown em `docs` e falha para links locais
  ausentes ou marcadores comuns de mojibake.
- O gate global do Sonar falha para qualquer issue, rating diferente de A, cobertura abaixo de 80%
  ou duplicação acima de 3%. A evidência atual registra zero issues, 82,3% de cobertura e 2,3% de
  duplicação.
- O terminal nativo abriu com controles, entrada, saída e nove pontos de navegação por Tab nas
  quatro combinações, conforme
  [`terminal_smoke_evidence_2.0.0.json`](terminal_smoke_evidence_2.0.0.json).
- Os seletores, histórico, entrada e saída do terminal possuem cinco rótulos VCL associados. A
  árvore UI Automation do Delphi 13 IDE64 confirmou os nomes, estados e descrições das superfícies
  Web carregadas pela mesma BPL distribuída.

## Como reproduzir

```powershell
npm run test:web
npm run test:docs
npm run lint
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.SonarQualityGate.ps1
```

A navegação visual, por Tab e com tecnologia assistiva está comprovada. O contrato Web é validado
automaticamente e inspecionado por UI Automation na IDE64; o terminal nativo é validado nas quatro
combinações e exige rótulos associados e nove pontos navegáveis.
