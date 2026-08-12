# Migração para a plataforma agentiva

> **Documento histórico.** A compatibilidade descrita abaixo corresponde à linha 1.x; Delphi 11 não
> integra a matriz vigente da linha 2.0.

> A plataforma agentiva é promovida à versão pública `1.0.0` após a aprovação dos gates
> automatizados e dos smokes reais da matriz Delphi.

## Compatibilidade

A linha 1.x mantinha suporte ao Delphi 11, Delphi 12 e Delphi 13. No Delphi 13 eram produzidos pacotes
separados para IDE Win32 e IDE64. Não carregue uma BPL Win32 no `bin64\bds.exe`, nem uma BPL Win64
na IDE Win32.

As configurações existentes de providers permanecem válidas. O upgrade não remove API keys,
providers dinâmicos, sessões de chat ou preferências visuais.

## Novos dados locais

O RadIA passa a criar dados derivados em `%APPDATA%\RadIA`:

- `audit\tools.jsonl`: auditoria sanitizada de ferramentas;
- `Knowledge`: snapshots reconstruíveis do índice local;
- `mcp.json`: descoberta compatível da instância MCP mais recente;
- `mcp.<pid>.json`: descoberta específica de cada processo da IDE;
- `Web`: cópia local dos recursos da interface;
- `WebView2`: cache descartável do runtime.

O índice e o cache WebView2 podem ser removidos e reconstruídos. O arquivo de auditoria não deve ser
apagado automaticamente durante upgrade.

## MCP

A bridge `RadIA.MCP.Bridge.exe` passa a ser instalada ao lado da BPL. Sem argumentos, ela usa
`mcp.json`. Para selecionar uma IDE específica, informe o caminho completo do respectivo
`mcp.<pid>.json` como primeiro argumento.

Clientes devem executar `initialize` antes de `tools/list` ou `tools/call`. Operações mutáveis e de
execução continuam exigindo consentimento na IDE, mesmo quando originadas por MCP.

O transporte permanece local por named pipe. Nenhuma porta TCP é aberta por padrão.

## Ferramentas e consentimento

Ferramentas de leitura podem ser usadas diretamente. Escritas reversíveis, alterações estruturais,
build, debugger e operações destrutivas seguem a classificação de risco do descritor.

Permissões concedidas para a sessão não são globais: projeto, sessão, ferramenta e escopo fazem
parte da chave. Uma permissão destrutiva não é reutilizada silenciosamente.

## Extensões

Pacotes externos devem declarar `RadIA` em `requires`, implementar `IRadIAToolExtension` e manter o
token `IRadIAToolExtensionRegistration` até sua `finalization`. Extensões compiladas contra outra
arquitetura ou nível incompatível da API são recusadas.

Consulte `tool_extension_guide.md` antes de migrar uma integração interna baseada diretamente no
container ou no registry.

## Instalação

1. Salve o trabalho e feche todas as instâncias do Delphi.
2. Escolha o ZIP correspondente à versão e arquitetura da IDE.
3. Extraia todo o conteúdo.
4. Execute `Scripts\Install-RadIA.Package.ps1` com a versão correta.
5. Abra a IDE e confirme o painel RadIA.
6. Para MCP, execute a bridge instalada ao lado da BPL.

O instalador valida o manifesto SHA-256 antes de copiar arquivos e recusa pacote de outra versão ou
arquitetura.

## Rollback

Para voltar à versão anterior:

1. Feche todas as IDEs.
2. Reinstale a BPL, o DCP, a bridge e os recursos web do pacote anterior.
3. Preserve configurações e auditoria.
4. Remova `Knowledge` somente se a versão anterior não reconhecer o formato do snapshot.
5. Reabra a IDE e confirme que não restaram arquivos `mcp.<pid>.json` de processos encerrados.
