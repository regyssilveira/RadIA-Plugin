# Configuração do FastMM5

O RadIA usa uma instalação fornecida pelo usuário e não redistribui arquivos do FastMM5. A integração
aceita Delphi 12/Win32, Delphi 13/Win32 e Delphi 13/IDE64.

## Pela tela de Configurações

1. Abra **RadIA > Settings > Memory Diagnostics**.
2. Informe a raiz do FastMM5, por exemplo `D:\Delphi\FastMM5`.
3. Marque o aceite de que a dependência é fornecida pelo usuário e possui licença própria.
4. Clique em **Validate installation**.
5. Salve as configurações.

O RadIA verifica `FastMM5.pas`, identifica a versão declarada e procura a DLL FullDebugMode adequada
à arquitetura atual. A tela mostra o motivo exato quando o backend não está pronto.

Para `D:\Delphi\FastMM5`, a instalação validada contém FastMM5 5.07,
`FullDebugMode DLL\Precompiled\FastMM_FullDebugMode.dll` e
`FullDebugMode DLL\Precompiled\FastMM_FullDebugMode64.dll`.

## Pelo chat, modo agente ou MCP

- `/tool GetMemoryDiagnosticsStatus {}` consulta a prontidão sem alterar configurações.
- `/tool ConfigureMemoryDiagnostics {"rootPath":"D:\\Delphi\\FastMM5","licenseAcknowledged":true}`
  prepara a alteração. Por ser uma escrita estrutural de configuração, a política de consentimento
  pode pedir aprovação antes da execução.

Depois da configuração, o agente chama `GetMemoryDiagnosticsStatus` antes de propor uma sessão de
diagnóstico. Nenhum projeto é instrumentado durante essa consulta.

## Como o usuário participa

- configurar e validar não altera nenhum projeto;
- preparar uma sessão apresenta DPR, cenário, repetições, limites e impacto do Full Debug Mode;
- executar exige consentimento explícito e nunca reutiliza silenciosamente uma aprovação anterior;
- o status pode ser consultado durante a execução;
- cancelar interrompe build, cenário e somente o processo iniciado pela sessão;
- a restauração do DPR ocorre mesmo quando build, cenário, parser ou cancelamento falham.

## O que é armazenado

O RadIA guarda somente o caminho raiz, o aceite explícito da licença e os limites de execução. O
código-fonte e as DLLs permanecem na pasta do usuário. Os valores padrão limitam cada execução a
120 segundos, 50 MiB de log e 10 repetições.

## Estados de prontidão

- `ready`: fonte, versão, aceite e DLL da arquitetura estão válidos;
- `unavailable`: o caminho ainda não foi configurado;
- `invalid`: faltam arquivos ou o aceite da licença;
- `incompatible`: a versão não pôde ser identificada.

## Solução rápida de problemas

- **`unavailable`**: informe o diretório que contém `FastMM5.pas`;
- **`invalid`**: confirme o aceite e as DLLs na subpasta `FullDebugMode DLL\Precompiled`;
- **target incorreto**: selecione Debug/Win32 ou Debug/Win64 no projeto ativo;
- **preview obsoleto**: salve ou revise as mudanças e prepare novamente;
- **conflito de recuperação**: o RadIA preserva a edição divergente e pede revisão manual, sem
  sobrescrevê-la.

Consulte também a [sessão guiada de diagnóstico](fastmm5_diagnostic_session.md).
