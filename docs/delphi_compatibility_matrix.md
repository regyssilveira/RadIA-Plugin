# Matriz de Compatibilidade Agentiva

## 1. Versões-alvo

| IDE | BDS | IDE principal | Estado atual do RadIA |
|---|---:|---|---|
| Delphi 11 Alexandria | 22.0 | Win32 | Build e DUnitX locais aprovados |
| Delphi 12 Athens | 23.0 | Win32 | Build e DUnitX locais aprovados |
| Delphi 13 Florence | 37.0 | Win32 e Win64 | Build e DUnitX aprovados em ambas as IDEs |

O suporte de uma ferramenta deve ser determinado por capacidade, não apenas por número de versão.

## 2. Níveis de suporte

- `Supported`: implementação e testes disponíveis.
- `Fallback`: comportamento alternativo seguro.
- `Unavailable`: capacidade não exposta nessa configuração.
- `Experimental`: requer opt-in e pode usar interfaces menos estáveis.

## 3. Matriz inicial planejada

| Capacidade | D11 | D12 | D13 Win32 | D13 Win64 |
|---|---|---|---|---|
| Estado da IDE | Automatizado | Automatizado | Automatizado | Automatizado |
| Projeto ativo | Automatizado | Automatizado | Automatizado | Automatizado |
| Leitura do editor | Automatizado | Automatizado | Automatizado | Automatizado |
| Seleção e cursor | Automatizado | Automatizado | Automatizado | Automatizado |
| Mensagens do compilador | Automatizado | Automatizado | Automatizado | Automatizado |
| Busca no projeto | Automatizado | Automatizado | Automatizado | Automatizado |
| Patches revisáveis | Automatizado | Automatizado | Automatizado | Automatizado |
| Build controlado | Automatizado | Automatizado | Automatizado | Automatizado |
| MCP named pipe | Automatizado | Automatizado | Automatizado | Automatizado |
| MCP HTTP loopback | Planejado | Planejado | Planejado | Planejado |
| Form Designer vivo | Automatizado | Automatizado | Automatizado | Automatizado |
| Captura do form | A validar | A validar | A validar | A validar |
| Debugger read-only | Automatizado | Automatizado | Automatizado | Automatizado |
| Controle do debugger | A validar | A validar | A validar | A validar |
| Revisão no gutter | Automatizado | Automatizado | Automatizado | Automatizado |
| Conhecimento local | Automatizado | Automatizado | Automatizado | A validar |

Nenhuma célula `Planejado` representa funcionalidade concluída.

## 4. Regras de implementação

1. Não usar condicionais de versão espalhadas pelo Core.
2. Centralizar detecção em um serviço de capacidades.
3. Usar `Supports` antes de acessar interfaces opcionais.
4. Não manter referências OTA além da operação.
5. Oferecer fallback documentado quando possível.
6. Retornar `Unsupported` quando não houver caminho seguro.
7. Isolar integrações experimentais em units próprias.

## 5. Capacidades propostas

- `EditorRead`
- `EditorWrite`
- `ProjectRead`
- `ProjectWrite`
- `CompilerMessages`
- `BuildControl`
- `RunControl`
- `DebuggerRead`
- `DebuggerControl`
- `LiveFormRead`
- `LiveFormWrite`
- `EditorGutterReview`
- `MCPNamedPipe`
- `MCPHttpLoopback`

## 6. Gates por versão

Cada capacidade deve passar por:

1. Compilação do pacote.
2. Compilação da suíte DUnitX.
3. Testes unitários.
4. Smoke test dentro da IDE.
5. Teste de projeto aberto e fechado.
6. Teste de shutdown.
7. Teste com buffer modificado e não salvo.
8. Teste de erro controlado quando a capacidade não estiver disponível.

## 7. Atenções conhecidas

### Delphi 11 e 12

- IDE predominantemente Win32.
- Validar limites de memória para indexação e respostas grandes.
- Evitar pressupor interfaces introduzidas no Delphi 13.

### Delphi 13

- Validar separadamente Win32 e Win64.
- Preservar as correções existentes de elision e criação de views.
- Validar tamanho de ponteiros e interop com WebView2.
- Não assumir equivalência comportamental entre as duas IDEs.

### Todas as versões

- Leitura de `IOTAEditReader` deve continuar em blocos.
- Notifiers não devem interferir com a criação de editor views.
- Operações WebView2 respeitam `GIsShuttingDown`.
- Toda UI proveniente de background usa `TThread.Queue` ou `TThread.Synchronize`.

## 8. Evidência de suporte

Uma célula só poderá mudar para `Supported` quando houver:

- Unit de implementação identificada.
- Teste automatizado aplicável.
- Comando de build registrado.
- Resultado do smoke test.
- Ausência de regressão no shutdown.

### Baseline local de 2026-08-02

| BDS | Plataforma validada | Resultado |
|---:|---|---|
| 22.0 | Win32 | Pacote compilado; 442/442 testes aprovados; zero vazamentos |
| 23.0 | Win32 | Pacote compilado; 442/442 testes aprovados; zero vazamentos |
| 37.0 | Win32 | Pacote compilado; 442/442 testes aprovados; zero vazamentos |

Comando reproduzível:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "<BDS>" -Test -NoCoverage
```

Essa baseline comprova compatibilidade de compilação e testes automatizados. A BPL atual foi
carregada automaticamente em três ciclos válidos por versão: Delphi 11 encerrou entre 0,80 s e
0,86 s; Delphi 12, entre 1,52 s e 1,99 s; e Delphi 13, entre 1,98 s e 2,63 s. Não houve crash ou
deadlock. O Delphi 13 também respondeu ao bridge MCP nas IDEs Win32 e Win64.

No Delphi 13 Win32, a revisão inline também foi validada visualmente em projeto ativo. O ciclo real
publicou uma decoração, preparou e aplicou uma sugestão no buffer, reverteu ao SHA original, removeu
e limpou as revisões com consentimento e auditoria. O arquivo em disco permaneceu inalterado. A
validação visual completa do fluxo de revisão deixa de ser gate.

No Delphi 13 IDE64, pacote, bridge e suíte foram compilados nativamente e 442/442 testes passaram
sem falhas ou vazamentos. Em perfil limpo, a BPL Win64 carregou em três ciclos consecutivos no
`bin64\bds.exe`; projeto, editor `.dpr` e plataforma Win64 foram confirmados pelo MCP. Após a
confirmação de descarte do `.dproj` ajustado pela IDE64, os shutdowns concluíram entre 1,62 s e
1,88 s, sem crash, deadlock, descoberta MCP ou processo órfão.
