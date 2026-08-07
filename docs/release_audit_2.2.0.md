# Auditoria da release 2.2.0

Esta auditoria registra os gates executados para a versão 2.2.0. Os binários foram produzidos do
commit `42a7f0b8be34521c628fbab012bbfced7533006c`, sem assinatura, conforme a política do projeto
aberto.

## Resultado

| Gate | Resultado |
|---|---|
| Build Delphi 12 Win32 | Aprovado |
| Build Delphi 13 Win32 | Aprovado |
| Build Delphi 13 IDE64 | Aprovado |
| Testes Delphi 12/13 Win32 | 832 unitários + 6 externos, zero falhas e zero leaks |
| Testes Delphi 13 IDE64 | 838/838, zero falhas e zero leaks |
| Web, documentação e lint | 15/15 Web, 3/3 documentação e ESLint aprovado |
| SonarQube | Quality Gate `OK`, 83,2% de cobertura global, 2,0% de duplicação e zero issues |
| Catálogo operacional | 123/123 ferramentas com finalidade e momento de acionamento |
| Diagnóstico FastMM5 | Leak localizado nos três targets e controle corrigido com zero grupos |
| Repetibilidade FastMM5 | 10/10 ciclos nos três targets e 10/10 no controle sem leak |
| Interrupções | Cancelamento, timeout, recuperação e conflito de edição aprovados |
| Pacotes | Três ZIPs Release e testes adversariais aprovados |
| Instalação real | BPL 2.2.0.0, hash e registro aprovados nos três targets |
| Smoke final na IDE | 1/1 por target, 123 ferramentas em cada IDE |
| Instalador visual | Integridade aprovada; Authenticode `NotSigned` |

## Artefatos

A proveniência e os hashes dos três ZIPs estão em
[`release_evidence_2.2.0.json`](release_evidence_2.2.0.json). O instalador único está registrado em
[`visual_installer_evidence_2.2.0.json`](visual_installer_evidence_2.2.0.json).

| Artefato | SHA-256 |
|---|---|
| Delphi 12 Win32 ZIP | `BDF599EEF04D1AA3ADCA5E5AEA7C193821E0CF1146A02B94C75F4AF4622B3176` |
| Delphi 13 Win32 ZIP | `0706231C1995B0BEC4117C7256301D1AA872F2C9DC79D11C5924F574581F48AB` |
| Delphi 13 IDE64 ZIP | `1DCD250322839706E8BF92A091524C4A898D1960E6CA07960C8A1290FD7DF9D6` |
| Instalador visual | `9A7C10C368759207C89B9FB3F6A95362231389016712665FACDA017DE23D42EA` |

## Diagnóstico de memória

O [guia da sessão FastMM5](fastmm5_diagnostic_session.md) explica configuração, consentimento,
instrumentação reversível, processo supervisionado, cenários, evidência, correção, breakpoint por
alocação e comparação. O [hardening M6](fastmm5_memory_diagnostics_m6.md) registra repetibilidade,
cancelamento, timeout, recuperação e limites.

O RadIA não redistribui o FastMM5. A instalação validada foi fornecida pelo usuário e permaneceu em
`D:\Delphi\FastMM5`.
