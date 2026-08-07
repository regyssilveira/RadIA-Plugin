# Execução M0 — baseline FastMM5 e laboratório de memória

> **Estado:** concluído e validado nos três targets.
> **Backend validado:** FastMM5 5.07 fornecido pelo usuário em `D:\Delphi\FastMM5`.

## Baseline confirmado

- `FastMM5.pas` declara `CFastMM_Version = 507`.
- A instalação contém `FastMM_FullDebugMode.dll` e `FastMM_FullDebugMode64.dll`.
- A origem local corresponde ao commit oficial
  `823ba351842a69977c509ff74d68acf08b3a1bc1`.
- O código ou os binários da dependência não foram copiados para o repositório RadIA.

## Contratos adicionados

`RadIA.Core.MemoryDiagnostics.pas` define:

- backend e estado de prontidão;
- limites de duração, log e repetições;
- sessão correlacionada a projeto, executável, PID, build, target e cenário;
- eventos de leak, double free, use-after-free, corrupção e crescimento;
- frames com endereço opaco e origem;
- grupos de alocações;
- snapshots;
- evidência e regras mínimas de comparabilidade;
- interface backend-neutral para coleta.

Os schemas públicos estão em:

- [`memory_diagnostic_evidence_schema_v1.json`](memory_diagnostic_evidence_schema_v1.json);
- [`memory_diagnostic_comparison_schema_v1.json`](memory_diagnostic_comparison_schema_v1.json).

## Laboratório

`Tests/MemoryLab` possui quatro modos:

| Modo | Resultado esperado |
|---|---|
| `clean` | encerramento sem arquivo de leak |
| `leak` | `TStringList` e suas alocações aparecem no relatório |
| `transient` | crescimento temporário sem leak no encerramento |
| `double-free` | evento de acesso a bloco ou objeto já liberado |
| `use-after-free` | chamada virtual em objeto liberado |

O script `Build-RadIA.MemoryLab.ps1` exige caminho explícito do FastMM5, escolhe compilador e
arquitetura, compila com símbolos e copia somente a DLL para a saída descartável em `Output`.

## Evidência inicial

| Target | Clean | Leak | Origem resolvida |
|---|---|---|---|
| Delphi 12 Win32 | sem relatório | detectado | `RunLeakCase`, linhas 32–33 |
| Delphi 13 Win32 | sem relatório | detectado | `RunLeakCase`, linhas 32–33 |
| Delphi 13 Win64/IDE64 | sem relatório | detectado | `RunLeakCase`, linhas 32–33 |

No Delphi 13 Win32, os modos `double-free` e `use-after-free` encerraram com código diferente de
zero e produziram evento de chamada virtual em objeto liberado, sem message box.

## O que ainda falta para o goal

- M1: detector, configuração persistida e doctor;
- M2: instrumentação transacional de projetos reais;
- M3: parser que converta esses relatórios em evidência;
- M4: integração com cenários e snapshots;
- M5: correção, comparação e regressão;
- M6: hardening, documentação completa, instalação e release 2.2.0.
