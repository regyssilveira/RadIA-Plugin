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

## Pelo chat, modo agente ou MCP

- `/tool GetMemoryDiagnosticsStatus {}` consulta a prontidão sem alterar configurações.
- `/tool ConfigureMemoryDiagnostics {"rootPath":"D:\\Delphi\\FastMM5","licenseAcknowledged":true}`
  prepara a alteração. Por ser uma escrita estrutural de configuração, a política de consentimento
  pode pedir aprovação antes da execução.

Depois da configuração, o agente chama `GetMemoryDiagnosticsStatus` antes de propor uma sessão de
diagnóstico. Nenhum projeto é instrumentado durante essa consulta.

## O que é armazenado

O RadIA guarda somente o caminho raiz, o aceite explícito da licença e os limites de execução. O
código-fonte e as DLLs permanecem na pasta do usuário. Os valores padrão limitam cada execução a
120 segundos, 50 MiB de log e 10 repetições.

## Estados de prontidão

- `ready`: fonte, versão, aceite e DLL da arquitetura estão válidos;
- `unavailable`: o caminho ainda não foi configurado;
- `invalid`: faltam arquivos ou o aceite da licença;
- `incompatible`: a versão não pôde ser identificada.

Consulte também o [plano completo de diagnóstico de memória](fastmm5_memory_diagnostics_plan.md).
