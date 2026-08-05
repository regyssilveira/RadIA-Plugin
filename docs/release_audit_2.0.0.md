# Auditoria de release 2.0.0

Esta auditoria registra os gates reproduzíveis de segurança, privacidade, acessibilidade e
documentação do candidato RadIA 2.0.0. Ela complementa, mas não substitui, os ciclos reais na IDE.

| Área | Controle verificado | Evidência automatizada | Estado |
|---|---|---|---|
| Segurança | Consentimento, confinamento, sanitização, credenciais protegidas e extensões assinadas | Suíte DUnitX e SonarQube | Aprovado |
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

## Como reproduzir

```powershell
npm run test:web
npm run test:docs
npm run lint
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.SonarQualityGate.ps1
```

O aceite visual com teclado e tecnologia assistiva dentro de cada IDE suportada permanece parte dos
ciclos reais do M8 e só pode ser registrado depois que a BPL comprovada estiver instalada.
