# Auditoria da release 2.1.0

Esta auditoria registra os gates executados para a versão 2.1.0. Os binários foram produzidos do
commit `cede55fdb6fd008316963d5dacef51367735a498`, sem assinatura, conforme a política atual do
projeto aberto.

## Resultado

| Gate | Resultado |
|---|---|
| Build Delphi 12 Win32 | Aprovado |
| Build Delphi 13 Win32 | Aprovado |
| Build Delphi 13 IDE64 | Aprovado |
| Testes DUnitX | 806/806 por target, zero falhas e zero leaks |
| Web, documentação e lint | Aprovados |
| SonarQube | Quality Gate `OK`, 82,9% de cobertura, 2,1% de duplicação e zero issues |
| Catálogo operacional | 111/111 ferramentas com finalidade e momento de acionamento |
| Diagnóstico runtime | Falha, correção, comparação `fixed` e regressão 10/10 nos três targets |
| Instalação real | `Uninstall`, `Install` e `Repair` aprovados nos três targets |
| Smoke na IDE | 2/2 ciclos por target, 6/6 no total |
| Superfícies | Docking, restauração, terminal, teclado e primeiro valor aprovados |
| Instalador visual | Integridade aprovada; Authenticode `NotSigned` |

## Artefatos

A proveniência e os hashes dos três ZIPs estão em
[`release_evidence_2.1.0.json`](release_evidence_2.1.0.json). O instalador único está registrado em
[`visual_installer_evidence_2.1.0.json`](visual_installer_evidence_2.1.0.json).

## Documentação

O [guia de diagnóstico runtime](runtime_debug_automation.md) explica o fluxo completo de reprodução,
captura, correção e regressão. A [referência operacional](internal_tools_reference.md) documenta
individualmente todas as 111 ferramentas, o que cada uma faz e quando pode ser acionada. Um teste
automatizado compara essa referência ao manifesto do runtime e bloqueia ferramentas sem
documentação.
