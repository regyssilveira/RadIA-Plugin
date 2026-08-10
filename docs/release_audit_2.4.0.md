# Auditoria da candidata 2.4.0

> **Estado:** evidência histórica da candidata anterior às correções do executor Codex e Doctor 2.0.
> Novos artefatos precisam ser gerados antes da publicação.

Esta auditoria registra o fechamento do goal de portabilidade de skills e terminal de alta
fidelidade. Os binários foram produzidos do commit
`7dce5ca5254243f843f43a1addc46f55fb231472`, sem assinatura, conforme a política do projeto aberto.

## Resultado

| Gate | Resultado |
|---|---|
| Delphi 12 Win32 | 1.024/1.024 testes, zero falhas, erros, ignorados ou leaks |
| Delphi 13 Win32 | 1.024/1.024 testes, zero falhas, erros, ignorados ou leaks |
| Delphi 13 IDE64 | 1.024/1.024 testes, zero falhas, erros, ignorados ou leaks |
| Terminal real | ConPTY, streaming, entrada contínua, resize e oito contratos VT/TUI aprovados |
| Matriz visual instalada | Terminal aprovado nos três targets com 131 ferramentas |
| Portabilidade de skills | Codex, Claude Code, Gemini CLI e GitHub Copilot CLI aprovados |
| Web, documentação e lint | 83/83 testes e ESLint aprovados |
| SonarQube | `OK`, cobertura 82,8%, duplicação 1,7% e zero issues |
| Pacotes | Três ZIPs internos validados; não destinados ao fluxo público normal |
| Instalador visual | Integridade aprovada; Authenticode `NotSigned` por decisão do projeto |

## Evidências

- [matriz de alta fidelidade](terminal_high_fidelity_evidence_2.4.0.json);
- [matriz visual instalada](terminal_smoke_evidence_2.4.0.json);
- [pacotes e hashes](release_evidence_2.4.0.json);
- [instalador visual](visual_installer_evidence_2.4.0.json);
- [Quality Gate do SonarQube](sonar_quality_evidence_2.4.0.json).

## Artefatos preparados

| Artefato | SHA-256 |
|---|---|
| Delphi 12 Win32 ZIP | `7DD07F8DA6A01858EB584B5E2670F37E69F143E815DAF2D3B0E2CB3242FF834E` |
| Delphi 13 Win32 ZIP | `27946654F34DCE0881CE12B1130A8380E5B297317FA0D93201331C48FB843ABC` |
| Delphi 13 IDE64 ZIP | `33810DB5FF15942BBDC0A64BE6F955B0695DEF783333C7294D5162468DD9AF0A` |
| Instalador visual | `C7FA1D9EA4ECAA4B1F03E8EBA8309D0850E6D7AF0C5594D317821450165FD9C6` |

O instalador é o artefato público recomendado. Os ZIPs existem para validação interna,
reprodutibilidade e diagnóstico; não precisam ser anexados ao release público.
