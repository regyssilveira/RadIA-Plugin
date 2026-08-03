# Checklist da release agentiva

A avaliação requisito por requisito está em `agentic_completion_audit.md`.

## Escopo técnico

- [x] Registry interno compartilhado entre chat e MCP.
- [x] Fachada de workspace e adapters OTA isolados do Core.
- [x] Pipeline central de política, consentimento, sanitização e auditoria.
- [x] Patches reversíveis com preview e precondições de revisão.
- [x] Build controlado, cancelável e sem execução implícita.
- [x] Named pipe local com ACL, limite de payload, cancelamento, quota e métricas.
- [x] Descoberta MCP independente por processo.
- [x] Form Designer vivo, debugger e revisão inline.
- [x] Conhecimento local incremental, persistente e reconstruível.
- [x] Status e leitura limitada de documentos do índice.
- [x] API versionada para extensões e pacote externo de exemplo.
- [x] ADR clean-room registra fronteiras e controles de independência do AEFOS.

## Compatibilidade automatizada

- [x] Delphi 11 Win32: pacote, bridge, extensão e 442 testes.
- [x] Delphi 12 Win32: pacote, bridge, extensão e 442 testes.
- [x] Delphi 13 Win32: pacote, bridge, extensão e 442 testes.
- [x] Delphi 13 IDE64: pacote, bridge, extensão e 442 testes.
- [x] Zero teste ignorado, falha, erro ou vazamento.
- [x] Cobertura instrumentada: 78% no Delphi 12.
- [x] ESLint aprovado.
- [x] Limite de linha, trailing whitespace e `NOSONAR` verificados.

## Distribuição

- [x] Build Release reproduzível por versão e plataforma.
- [x] Pacote ZIP inclui BPL, DCP, bridge, recursos web e WebView2Loader.
- [x] Manifesto registra versão, Delphi, plataforma, configuração, tamanho e SHA-256.
- [x] `SHA256SUMS.txt` é atualizado automaticamente a cada pacote gerado.
- [x] Instalador valida manifesto, versão e arquitetura.
- [x] Instalador recusa traversal, paths absolutos, duplicidades e arquivos não manifestados.
- [x] O próprio build executa `-ValidateOnly` antes de comprimir o staging.
- [x] Modo `-ValidateOnly` verifica o pacote sem alterar o sistema.
- [x] Testes negativos do pacote cobrem corrupção, versão, plataforma, traversal, duplicidade e arquivo extra.
- [x] Instalador recusa execução enquanto existir uma IDE aberta.
- [x] `build.ps1 -Install` instala também a bridge MCP.
- [x] Versão pública centralizada e validada contra `package.json` e `RadIA.rc`.
- [x] Notas preparatórias de migração publicadas.
- [x] Gerar os quatro pacotes finais a partir do commit de release.
- [x] Publicar `SHA256SUMS.txt` junto dos pacotes finais.

## Validações manuais restantes

- [x] Confirmar edição, save, rename e fechamento reais acionando o notifier do conhecimento.
- [x] Completar dez ciclos consecutivos de instalação, uso e shutdown no Delphi 11.
- [x] Completar dez ciclos consecutivos de instalação, uso e shutdown no Delphi 12.
- [x] Completar dez ciclos consecutivos de instalação, uso e shutdown no Delphi 13 Win32.
- [x] Completar dez ciclos consecutivos de instalação, uso e shutdown no Delphi 13 IDE64.
- [x] Carregar e descarregar `RadIASampleExtension` em uma IDE real.
- [x] Validar duas IDEs atualizadas simultaneamente e selecionar cada arquivo `mcp.<pid>.json`.

## Gate de publicação

A versão pública, tag e notas de release somente devem ser criadas depois que todos os itens manuais
estiverem aprovados e os pacotes forem regenerados a partir do mesmo commit. Não reutilizar artefatos
produzidos antes do commit final.
