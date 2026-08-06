# Matriz de Compatibilidade Delphi

## Matriz vigente

| IDE | BDS | Arquitetura da IDE | Estado |
| :--- | :--- | :--- | :--- |
| Delphi 12 Athens | 23.0 | Win32 | Suportado |
| Delphi 13 | 37.0 | Win32 | Suportado |
| Delphi 13 | 37.0 | IDE64 | Suportado |

Delphi 11 e versões anteriores não fazem parte da matriz vigente. Não recebem novos pacotes,
correções, testes de regressão ou suporte operacional.

## Capacidades obrigatórias

| Capacidade | Delphi 12 Win32 | Delphi 13 Win32 | Delphi 13 IDE64 |
| :--- | :---: | :---: | :---: |
| Chat acoplável e WebView2 | Sim | Sim | Sim |
| Modo agente e registry de tools | Sim | Sim | Sim |
| MCP por bridge local | Sim | Sim | Sim |
| Terminal integrado | Sim | Sim | Sim |
| Ghost Text e revisão inline | Sim | Sim | Sim |
| Workspace e editor OTA | Sim | Sim | Sim |
| Form Designer | Sim | Sim | Sim |
| Build e testes DUnitX | Sim | Sim | Sim |
| Debugger e timeline | Sim | Sim | Sim |
| Conhecimento do projeto | Sim | Sim | Sim |
| Extensões declarativas | Sim | Sim | Sim |
| Instalação, reparo e remoção | Sim | Sim | Sim |

Uma funcionalidade compartilhada não pode ser declarada concluída enquanto houver regressão em
qualquer um dos três targets.

## Comandos de validação

Delphi 12 Win32:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "23.0" -Release -Test -NoCoverage
```

Delphi 13 Win32:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "37.0" -Release -Test -NoCoverage
```

Delphi 13 IDE64:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "37.0" -IDE64 -Release -Test -NoCoverage
```

## Gates de compatibilidade

1. O build rejeita versões diferentes de BDS 23.0 e BDS 37.0.
2. O instalador aceita somente os três targets da matriz.
3. O release contém três pacotes com manifesto, hash e commit de origem.
4. Cada target compila a BPL, a extensão de exemplo, a bridge MCP e a suíte DUnitX.
5. Os testes não podem apresentar falha, erro, ignore ou vazamento.
6. Os smokes em IDE real devem confirmar docking, catálogo de tools e shutdown sem processo órfão.

## Evidência histórica

Arquivos de evidência da versão 2.0 podem conter execuções do Delphi 11 realizadas antes da mudança
de suporte. Esses registros são imutáveis e demonstram o estado daquela revisão; não ampliam a
matriz atual. Geradores novos de evidência processam somente Delphi 12 e 13.
