# Auditoria da candidata 2.4.0

> **Estado:** auditoria corrente da release 2.4.0.

Esta auditoria registra o fechamento do goal de portabilidade de skills e terminal de alta
fidelidade, Doctor 2.0 e preflight do chat. O commit e os hashes exatos dos binários são registrados
nas evidências reproduzíveis geradas pelo pipeline. O instalador permanece sem assinatura, conforme
a política do projeto aberto.

## Resultado

| Gate | Resultado |
|---|---|
| Delphi 12 Win32 | 1.031/1.031 testes, zero falhas, erros, ignorados ou leaks |
| Delphi 13 Win32 | 1.031/1.031 testes, zero falhas, erros, ignorados ou leaks |
| Delphi 13 IDE64 | 1.031/1.031 testes, zero falhas, erros, ignorados ou leaks |
| Terminal real | ConPTY, streaming, entrada contínua, resize e oito contratos VT/TUI aprovados |
| Matriz visual instalada | Terminal aprovado nos três targets com 132 ferramentas |
| Portabilidade de skills | Codex, Claude Code, Gemini CLI e GitHub Copilot CLI aprovados |
| Web, documentação e lint | 88/88 testes e ESLint aprovados |
| SonarQube | `OK`, cobertura 82,8%, duplicação 1,7% e zero issues |
| Pacotes | Três ZIPs internos validados; não destinados ao fluxo público normal |
| Instalador visual | Integridade aprovada; Authenticode `NotSigned` por decisão do projeto |

## Evidências

- [matriz de alta fidelidade](terminal_high_fidelity_evidence_2.4.0.json);
- [matriz visual instalada](terminal_smoke_evidence_2.4.0.json);
- [pacotes e hashes](release_evidence_2.4.0.json);
- [instalador visual](visual_installer_evidence_2.4.0.json);
- [Quality Gate do SonarQube](sonar_quality_evidence_2.4.0.json).

Os hashes e o commit-fonte são lidos diretamente de `release_evidence_2.4.0.json` e
`visual_installer_evidence_2.4.0.json`, evitando duplicação sujeita a divergência.

O instalador é o artefato público recomendado. Os ZIPs existem para validação interna,
reprodutibilidade e diagnóstico; não precisam ser anexados ao release público.
