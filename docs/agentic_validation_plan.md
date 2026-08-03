# Plano de Validação da Evolução Agentiva

## 1. Objetivo

Este documento define as evidências mínimas para considerar cada fase concluída. Uma fase não é
encerrada apenas porque o pacote compila.

## 2. Baseline

Antes de alterar código:

- Registrar `git status --short`.
- Executar build e testes na versão Delphi disponível.
- Registrar quantidade de testes.
- Executar ESLint quando houver mudança em `Source/UI/Web`.
- Registrar warnings novos.

### Baseline registrado em 2026-08-02

- Workspace inicialmente limpo.
- Delphi 12 Athens (`23.0`), Win32.
- Pacote `RadIA.dpk` compilado com sucesso: 22.259 linhas e zero erro reportado.
- A primeira compilação da suíte não iniciou porque a linha de comando do `dcc32.exe` excedeu o
  limite do Windows.
- `build.ps1` passou a usar um response file temporário para os parâmetros da suíte.
- A suíte compilou e encontrou 292 testes: 289 aprovados, três falharam e nenhum vazamento foi
  detectado.
- As três falhas estão em `RadIA.Tests.HttpClient` e dependem do SonarQube local. Duas falharam
  por timeout de rede e uma não conseguiu acessar o endpoint de versão.
- O pacote e a suíte compilam; o baseline não está totalmente verde enquanto os testes dependentes
  do SonarQube não forem isolados ou executados com o serviço disponível.

## 3. Fase 1: leitura e registry

Evidências:

- Registry recusa nomes duplicados.
- Schemas inválidos são recusados.
- Ferramentas read-only funcionam com facade fake.
- Respostas indicam truncamento.
- Cancelamento impede entrega tardia.
- Projeto fechado retorna erro estruturado.
- Build e DUnitX passam.
- Smoke test consulta editor e projeto vivos.

## 4. Fase 2: segurança

Evidências:

- Todas as chamadas atravessam a policy pipeline.
- Negação não altera estado.
- Permissão de sessão é limitada ao projeto e ferramenta.
- Secrets não aparecem em auditoria ou erros.
- Paths fora do workspace são recusados.
- Shutdown cancela consentimentos pendentes.

## 5. Fase 3: mutações e build

Evidências:

- Patch aplica quando precondições são válidas.
- Patch é recusado após edição concorrente.
- Encoding e line endings são preservados.
- Alteração pode ser revertida.
- Build retorna mensagens estruturadas.
- Iterações agentivas obedecem ao limite.
- Execução não ocorre implicitamente após build.

## 6. Fase 4: MCP

Evidências:

- `tools/list` corresponde ao registry.
- `tools/call` usa a policy pipeline.
- Named pipe aceita somente cliente local.
- HTTP escuta apenas em loopback.
- Token inválido é recusado.
- Payload acima do limite é recusado.
- Servidor encerra junto à IDE.
- Processos CLI filhos são canceláveis.

## 7. Fase 5: Designer, debugger e revisão

Evidências:

- Leitura usa o estado vivo do form.
- Mutações mantêm PAS e DFM consistentes.
- Event handler completo é atômico ou totalmente revertido.
- Debugger retorna estado estruturado.
- Ações de execução exigem consentimento.
- Revisão inline aceita e rejeita mudanças.
- Salvamento não deixa marcadores ou conteúdo inconsistente.
- Fallback Smart Diff permanece funcional.

## 8. Fase 6: conhecimento

Evidências:

- Parser identifica símbolos Delphi cobertos pelos fixtures.
- Indexação inicial e incremental produzem o mesmo estado final.
- Exclusões são respeitadas.
- Resultados citam origem e revisão.
- Índice corrompido pode ser reconstruído.
- Remoção apaga somente o índice do workspace alvo.
- Busca lexical funciona sem provider ou embeddings.

## 9. Gates de qualidade

Para qualquer fase:

- Nenhuma literal Pascal acima de 255 caracteres.
- Nenhuma rotina com mais de sete parâmetros.
- Nenhuma linha de código acima de 120 caracteres.
- Nenhum trailing whitespace.
- Nenhum comentário de supressão do SonarQube.
- Objetos locais protegidos por `try..finally`.
- Nenhuma dependência circular entre interfaces de units.
- Complexidade cognitiva por rotina dentro do limite.
- Código, comentários e prompts em inglês.
- Documentação e comunicação em português.

## 10. Comandos padrão

Delphi 12:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
```

Delphi 11:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "22.0" -Test
```

Delphi 13:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "37.0" -Test
```

Frontend:

```powershell
npx eslint
```

Para validações rápidas sem relatório de cobertura, acrescentar `-NoCoverage`. O gate final de uma
entrega deve manter ao menos uma execução com cobertura.

## 11. Registro de evidências

Cada entrega deve informar:

- Arquivos alterados.
- Capacidades implementadas.
- Testes adicionados.
- Builds executados.
- IDEs realmente validadas.
- Riscos conhecidos.
- Fallbacks.
- Itens ainda não verificados.

### Evidência da Fase 1 em 2026-08-02

- Pacote compilado no Delphi 12 Athens (`23.0`), Win32.
- Registro interno e executor adicionados ao Core.
- Nove ferramentas read-only registradas.
- Fachada OTA read-only registrada no container.
- Suíte com 310 testes: 310 aprovados, nenhum ignorado e nenhum vazamento.
- Cobertura desativada explicitamente com `-NoCoverage` nesta execução.

### Baseline agentiva consolidada em 2026-08-02

- Delphi 11 Alexandria (`22.0`), Win32: 442/442 testes, sem falhas, erros ou vazamentos.
- Delphi 12 Athens (`23.0`), Win32: 442/442 testes, sem falhas, erros ou vazamentos.
- Delphi 13 Florence (`37.0`), Win32: 442/442 testes, sem falhas, erros ou vazamentos.
- Uma execução Delphi 11 anterior, com 370 testes, atingiu 78% das linhas selecionadas.
- O bridge MCP, o pacote e a suíte foram compilados nas três versões.
- Delphi 13 Win32 carregou o BPL automaticamente em três ciclos consecutivos e encerrou entre
  1,98 s e 2,63 s, sem crash, deadlock ou segunda chance no ciclo observado sob CDB.
- Delphi 11 Win32 carregou exatamente a BPL atual em três ciclos válidos e encerrou entre
  0,80 s e 0,86 s, sem crash ou deadlock.
- Delphi 12 Win32 carregou exatamente a BPL atual em três ciclos válidos e encerrou entre
  1,52 s e 1,99 s, sem crash ou deadlock.
- O bridge real confirmou handshake MCP, catálogo de tools, leitura do buffer vivo, consentimento
  nativo e auditoria. O timeout do bridge foi ampliado para dez minutos para acomodar consentimento
  humano.
- A revisão inline foi validada em projeto ativo no Delphi 13: decoração visual por severidade,
  preview com arquivo `.dpr`, aplicação na revisão prevista, reversão ao SHA original, remoção e
  limpeza auditadas. O arquivo em disco permaneceu byte a byte inalterado durante o ciclo.
- O smoke corrigiu duas falhas do adapter real: associação do conteúdo ao `.dproj` em vez do buffer
  `.dpr` e duplicação da quebra de linha terminal pelo writer OTA.
- O scheduler de conhecimento passou a usar relógio injetável, removendo dependência temporal dos
  testes de debounce. A matriz final voltou a 442/442 no Delphi 11, 12 e 13, sem vazamentos.
- Delphi 13 IDE64 compilou pacote, bridge e suíte nativamente; 442/442 testes passaram sem falhas
  ou vazamentos. A BPL Win64 carregou no `bin64\bds.exe` e respondeu ao MCP como plataforma Win64.
- O build usa o compilador, paths e executável de teste da plataforma selecionada. A cobertura
  propaga o exit code da suíte com `-tec`; IDE64 usa execução direta porque a ferramenta local de
  cobertura não suporta executáveis Win64.
- Em perfil IDE64 limpo, a BPL Win64 atual carregou em três ciclos consecutivos. O MCP confirmou
  projeto, editor `.dpr` e plataforma Win64. Os shutdowns normais concluíram entre 1,62 s e 1,88 s,
  sem crash, deadlock, descoberta MCP ou processo órfão.
- O protocolo MCP processou 1.000 requisições sequenciais, o servidor reiniciou 20 vezes removendo
  a descoberta a cada ciclo e o shutdown desconectou um cliente ocioso dentro do limite de três segundos.
- A descoberta por processo é criada e removida junto com o servidor; o shutdown preserva um
  `mcp.json` que tenha sido substituído por outra instância.
- Duas IDEs Delphi 13 atualizadas publicaram endpoints distintos e responderam `GetIDEState` e
  `GetActiveProject` pelo arquivo explícito de cada PID.
- A extensão de exemplo foi carregada em IDE real, elevou o catálogo de 57 para 58 tools e executou
  `SampleProjectInfo`; após desregistro, uma nova IDE voltou a 57 tools.
- O shutdown com a extensão carregada removeu o discovery da própria instância. O startup seguinte
  também eliminou discovery órfão de um processo morto sem afetar endpoints vivos.
- Delphi 13 Win32 concluiu dez ciclos consecutivos com handshake, `GetIDEState`, shutdown limpo e
  remoção do discovery por PID, entre 27,99 s e 31,48 s por ciclo.
- Delphi 11 concluiu dez ciclos consecutivos da revisão com watchdog entre 5,97 s e 9,51 s.
- Delphi 13 IDE64 concluiu dez ciclos consecutivos com MCP e cleanup entre 37,77 s e 74,08 s.
- Delphi 12 concluiu dez ciclos consecutivos com handshake, `GetIDEState`, shutdown limpo e
  remoção do discovery por PID, entre 45,76 s e 74,18 s por ciclo.
- Uma corrida observada no Delphi 11 motivou um watchdog externo na bridge. Ele valida PID e endpoint
  antes de remover discovery após o término do processo, independentemente da ordem de unload das BPLs.
- O registro IDE64 foi corrigido para `BDS\37.0\Known Packages x64`, conforme a separação oficial
  de packages da IDE de 64 bits.
- O transporte deixou de consultar `GetActiveProject` durante `initialize` e `tools/list`. Chamadas
  de tools durante o splash recebem `-32004`, evitando sincronização OTA prematura com a main thread.
- Consentimento `Allow once`, cancelamento e concessão destrutiva repetida possuem regressão; cada
  tentativa gera auditoria e cancelamento nunca executa a ferramenta.
- `notifications/cancelled` alcança tools cooperativas durante a execução pelo named pipe. Cada
  conexão aceita uma chamada em voo e responde `-32003` ao excesso de concorrência.
- `radia/metrics` expõe apenas contadores sanitizados da sessão: mensagens, chamadas concluídas,
  atividade atual e de pico, cancelamentos e rejeições.
- A execução instrumentada mais recente no Delphi 12 aprovou 442/442 testes e cobriu 9.390 de
  11.940 linhas selecionadas, mantendo 78% de cobertura.
- O smoke isolado `Test-RadIA.KnowledgeNotifierSmoke.ps1` abriu uma cópia do projeto no Delphi 12,
  indexou-a pelo MCP, aplicou uma edição revisável com consentimento, observou a atualização
  incremental do buffer vivo, salvou, renomeou e fechou a unit. A nova identidade apareceu no
  índice e o teardown não deixou processo ou discovery MCP órfão.
