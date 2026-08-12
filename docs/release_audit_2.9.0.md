# Auditoria da release 2.9.0

> **Estado:** aprovada e liberada em 12 de agosto de 2026.

## Baseline funcional

- [x] Perfil sanitizado do ambiente Delphi e orientação curada.
- [x] Auditoria DFM/PAS e diff visual do Designer.
- [x] Contrato de execução autônoma e retomada segura.
- [x] Migração reversível de acesso a dados legado para FireDAC.
- [x] Mentor Delphi, ficha de segurança e benchmark reproduzível.
- [x] Catálogo gerado com 148 ferramentas documentadas e sincronizadas.

## Gates finais

- [x] Delphi 12 Win32: 1103 testes instrumentados e 8 externos, sem vazamentos.
- [x] Delphi 13 Win32: 1103 testes instrumentados e 8 externos, sem vazamentos.
- [x] Delphi 13 IDE64: 1111 testes, sem vazamentos.
- [x] Web 106/106, ESLint e documentação 42/42.
- [x] SonarQube: gate aprovado, cobertura global 83,6%, duplicação 1,8% e zero issues.
- [x] Pacotes, instalador, evidências, merge, tag e publicação.

## Evidências finais

Os artefatos foram produzidos do commit `2d10e90917c27d9440d3a7040fc8e2b1afd19ff8`. O instalador
`RadIA-v2.9.0-Setup.exe` não é assinado por decisão do projeto e possui SHA-256
`C84414D4494FF4F2F30206404827014CEA373F647DF83F01815C54536225BCB6`.
