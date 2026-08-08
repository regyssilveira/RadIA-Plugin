# Auditoria de ideias do Free Claude Code aplicáveis ao RadIA

## Resumo executivo

Esta auditoria confronta o RadIA 2.2.1 com o Free Claude Code (FCC) 4.17.1, commit
`627c6d7417e764b7334e5b59643b6c7c872d5bbb`, consultado em 7 de agosto de 2026. Não é uma disputa
entre produtos. O RadIA é uma extensão nativa do RAD Studio, integrada à OTA, editor, compilador,
debugger e consentimento. O FCC é um proxy local que traduz protocolos e liga clientes de agentes a
providers. Por isso, uma feature só é recomendada quando melhora a jornada dentro do Delphi.

Os maiores ganhos encontrados são: taxonomia uniforme de falhas, recuperação segura de streaming,
catálogo declarativo de providers mais rico, cache observável de modelos e contratos de teste por
capability. Em seguida vêm normalização de reasoning, controle de concorrência, eventos internos
normalizados, correlação de diagnósticos e contrato único de resolução de CLI.

O RadIA já possui providers locais, provider OpenAI-compatible, registro extensível por JSON, agente
nativo, CLI e MCP independentes, consentimento, atualização de modelos sem reiniciar, `/doctor` e
`/status`. Portanto, não há benefício em importar a arquitetura de proxy, mensageria, tray app ou
uma lista indiscriminada de providers.

Esta entrega é pesquisa e priorização. Nenhum código do FCC foi copiado e nenhuma mudança estrutural
foi implementada.

## Método e evidências

Foram lidos código, testes, manifestos, instaladores e arquitetura dos dois projetos. No RadIA, a
análise começou pelos registries e percorreu providers, modelos, agente, CLI, MCP, contexto,
consentimento, streaming, diagnóstico, conhecimento e UI. No FCC, percorreu `application`, `api`,
`cli`, `config`, `core`, `providers`, `runtime`, `messaging`, testes e scripts.

Fontes externas principais:

- [revisão analisada](https://github.com/Alishahryar1/free-claude-code/tree/627c6d7417e764b7334e5b59643b6c7c872d5bbb);
- [`ARCHITECTURE.md`](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/ARCHITECTURE.md);
- [catálogo de providers](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/src/free_claude_code/config/provider_catalog.py);
- [política de falhas](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/src/free_claude_code/providers/failure_policy.py);
- [recuperação de streaming](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/src/free_claude_code/providers/stream_recovery.py).

As conclusões retratam esses commits, não versões futuras.

## Arquiteturas

### RadIA

O RadIA roda no `bds.exe`: UI VCL/WebView2, OTA para editor/projeto/build/teste/designer/debugger,
providers nativos e compatíveis com OpenAI, agente nativo com tools/consentimento/auditoria e bridge
MCP externa. A vantagem é agir com contexto real da IDE; o custo é cuidar de UI thread, WebView2,
shutdown e isolamento de processos.

### FCC

O FCC roda separado. FastAPI recebe Anthropic Messages ou OpenAI Responses, converte o protocolo,
roteia um provider e devolve streaming no contrato do cliente. Launchers configuram Claude Code,
Codex e Pi. Uma UI administrativa gerencia provider, modelo, auth e diagnóstico; Telegram/Discord
podem acionar sessões gerenciadas.

### Direção arquitetural

O RadIA deve transportar os padrões para interfaces Delphi pequenas — catálogo, roteamento, falhas,
recovery, discovery e observabilidade — sem hospedar um proxy HTTP. A bridge MCP já cumpre a
fronteira externa necessária.

## Análise por domínio

### Features e experiência

O FCC centraliza configuração e apresenta status e falhas consistentes. O RadIA já cobre uma jornada
mais profunda: criar e alterar projetos, compilar, testar, depurar, diagnosticar memória, usar Git e
terminal. O ganho é mostrar no chat, `/doctor` e `/status` a origem do modelo, saúde do provider,
próxima ação e recuperação aplicada — não criar mais telas.

### Providers, modelos e roteamento

O catálogo do FCC descreve nome, endpoint, URL de credencial, campos obrigatórios, proxy, discovery
e fábrica. O RadIA possui `TProviderRegistry`, providers nativos, genérico OpenAI-compatible, defaults
e extensões JSON. Quantidade não é o gap. `TProviderMetadata` pode evoluir para declarar auth,
discovery, reasoning, tools, streaming, capabilities e ajuda, servindo UI, doctor e runtime.

O RadIA já recarrega modelos sem reiniciar e possui fallback. Falta tornar explícitos: origem
`live/cache/fallback`, instante da descoberta, idade, erro anterior e validade.

### Autenticação

O FCC especializa OpenAI/Codex e Vertex, além de chaves. O RadIA já separa API key, login ChatGPT via
Codex CLI, executável portátil e auth externa. Deve manter provider, executor CLI e MCP independentes.
Cada auth deveria declarar pré-requisitos, verificação, renovação, expiração e recuperação.

### CLI e MCP

Launchers do FCC concentram preparação e saneamento do ambiente. O RadIA já descobre, permite
override, instala com consentimento, autentica, revalida e registra reparos. A ideia aplicável é um
contrato único de resolução do executável, consumido por diagnóstico, instalação, login e execução.
MCP deve continuar independente do executor.

### Agentes e contexto

O FCC gerencia clientes e árvores de conversa, mas delega a agência. O RadIA possui compositor nativo
com plano, aprovação, pausa, retomada, histórico e tools da IDE. Substituí-lo por sessões CLI seria
regressão. É útil, porém, normalizar eventos de provider, CLI, tool, debugger, build e teste antes de
renderizá-los.

### IA local

O FCC suporta LM Studio e gateways OpenAI-compatible; o RadIA já suporta Ollama, LM Studio e genérico.
A prioridade deve ser diagnosticar endpoint, modelos carregados, tools, contexto e streaming. Adotar
mais nomes sem contrato e teste real cria manutenção, não valor.

### Instalação e diagnóstico

O FCC separa instalação, atualização, remoção, health e status. O RadIA já oferece instalador,
onboarding, instalação consentida de CLI, `/doctor`, `/status` e handshake MCP. Pode adotar resultados
tipados: código estável, resumo, evidência sanitizada, ação automática e alternativa manual completa.

### Segurança, privacidade e observabilidade

São aplicáveis: logs mínimos por padrão, payload detalhado por opt-in, redação de chaves, request ID,
retenção limitada e bloqueio de rede privada em web fetch. O RadIA já é mais forte no consentimento
por risco. Deve preservar esse modelo e acrescentar correlação e falhas uniformes, sem registrar
prompts, tokens, argumentos sensíveis ou respostas por padrão.

## Matriz de oportunidades

| Ideia | Existe no FCC | Existe no RADIA | Gap | Impacto | Esforço | Prioridade |
|---|---|---|---|---|---|---|
| Taxonomia canônica de falhas | Sim | Parcial | Mensagens/retry variam | Alto | Médio | P0 |
| Recovery seguro de streaming | Sim | Parcial | Resposta pode ficar truncada | Alto | Alto | P0 |
| Catálogo declarativo rico | Sim | Parcial | Faltam capabilities/auth | Alto | Médio | P0 |
| Cache de modelos observável | Sim | Parcial | Origem e idade não são claras | Alto | Médio | P0 |
| Contratos por capability | Sim | Parcial | Sem matriz uniforme | Alto | Médio | P0 |
| Normalização de reasoning | Sim | Parcial | Vocabulário varia | Médio | Médio | P1 |
| Admission control por provider | Sim | Não central | Sem política única | Médio | Médio | P1 |
| Eventos de execução normalizados | Sim | Parcial | UI conhece formatos distintos | Médio | Alto | P1 |
| Request/correlation ID | Sim | Parcial | Correlação incompleta | Médio | Médio | P1 |
| Contrato único de CLI | Sim | Parcial | Fluxos podem divergir | Alto | Médio | P1 |
| Probing de IA local | Sim | Parcial | Capability nem sempre testada | Médio | Médio | P1 |
| URL de credencial no catálogo | Sim | Parcial | Ajuda dispersa | Médio | Baixo | P1 |
| Proxy Anthropic/Responses | Central | Não | Fora da jornada IDE | Baixo | Alto | P3 |
| Launchers Claude/Codex/Pi | Sim | Outro desenho | Duplicaria gestão | Baixo | Alto | P3 |
| Telegram/Discord | Sim | Não | Fora do foco Delphi | Baixo | Alto | P3 |
| Aplicativo de tray | Sim | Não | IDE já é o host | Baixo | Médio | P3 |
| Transcrição de voz | Sim | Não | Sem caso validado | Baixo | Alto | P3 |

## Decisão por grupo

### Implementar agora

- taxonomia canônica de falhas;
- catálogo com metadados operacionais;
- origem, idade e fallback dos modelos;
- matriz mínima de contratos por provider/capability.

### Planejar

- recovery transacional de streaming;
- reasoning por provider/modelo;
- concorrência, backoff e circuit breaker;
- eventos normalizados e correlação ponta a ponta;
- contrato único de CLI.

### Experimentar

- probing de capabilities de servidores locais;
- holdback curto no início do streaming;
- adaptação de reasoning e tool schema por modelo;
- visão de saúde por provider dentro das superfícies existentes.

### Não implementar

- proxy multiprotocolo obrigatório;
- Telegram/Discord, tray app e voz;
- cliente Pi e launchers paralelos;
- importação em massa de providers sem testes e manutenção definida.

## Top 10 priorizado

### 1. Taxonomia canônica de falhas — P0

1. **Problema:** adapters traduzem timeout, auth, limite e indisponibilidade de formas distintas.
2. **Ideia:** `TRadIAProviderFailure` com categoria, retry, código, mensagem e ação.
3. **FCC:** `ExecutionFailure` e `failure_policy.py` estabilizam a semântica após retries.
4. **Adaptação:** converter exceções na fronteira do serviço, mantendo detalhe sanitizado.
5. **Impacto:** alto.
6. **Dificuldade:** média.
7. **Componentes:** providers, streaming, service, chat, doctor, logger e testes.
8. **Risco:** esconder detalhe; preservar causa segura e correlation ID.
9. **Estratégia:** migrar um provider remoto e um local, depois os demais.
10. **Aceite:** a mesma falha gera categoria e próxima ação idênticas em todos os adapters.

### 2. Recovery transacional de streaming — P0

1. **Problema:** conexão interrompida pode deixar texto ou tool call incompletos.
2. **Ideia:** distinguir falha antes do commit visual, após texto e após tool completa.
3. **FCC:** buffer curto permite retry invisível e política específica no meio do stream.
4. **Adaptação:** buffer de eventos sem repetir tool nem conteúdo confirmado.
5. **Impacto:** alto.
6. **Dificuldade:** alta.
7. **Componentes:** streaming, service, presenter e parser de tools.
8. **Risco:** duplicar texto/ação e aumentar latência.
9. **Estratégia:** máquina de estados, idempotência, limite pequeno e feature flag.
10. **Aceite:** cortes precoce/intermediário/tool não duplicam conteúdo nem efeitos.

### 3. Catálogo declarativo como fonte única — P0

1. **Problema:** registro, UI, doctor e ajuda podem conhecer dados diferentes.
2. **Ideia:** metadados para auth, capabilities, discovery e documentação.
3. **FCC:** `ProviderDescriptor` orienta configuração, status e construção.
4. **Adaptação:** ampliar `TProviderMetadata` e schema JSON, mantendo fábricas Delphi.
5. **Impacto:** alto.
6. **Dificuldade:** média.
7. **Componentes:** ProviderRegistry, ConfigFrame, factories, doctor e docs geradas.
8. **Risco:** incompatibilidade com JSON existente.
9. **Estratégia:** campos opcionais, versão e defaults compatíveis.
10. **Aceite:** UI, doctor e runtime leem a mesma descrição; teste detecta divergência.

### 4. Descoberta de modelos observável — P0

1. **Problema:** usuário não sabe se a lista veio da API, cache ou fallback.
2. **Ideia:** expor origem, instante, validade, erro e refresh.
3. **FCC:** discovery e cache possuem estado explícito.
4. **Adaptação:** estado imutável e refresh assíncrono sem reinício.
5. **Impacto:** alto.
6. **Dificuldade:** média.
7. **Componentes:** providers, config, chat, doctor/status e testes.
8. **Risco:** refresh concorrente ou UI obsoleta.
9. **Estratégia:** geração monotônica, cancelamento no shutdown e publicação na UI thread.
10. **Aceite:** troca de provider atualiza e mostra `live/cache/fallback`, horário e erro.

### 5. Matriz de contratos de provider — P0

1. **Problema:** testes não demonstram uniformemente streaming, tools e falhas.
2. **Ideia:** suíte compartilhada por adapter e perfil.
3. **FCC:** contratos cobrem protocolos, catálogos, boundaries e streaming.
4. **Adaptação:** fixtures DUnitX e smoke tests reais opt-in.
5. **Impacto:** alto.
6. **Dificuldade:** média.
7. **Componentes:** testes, mocks HTTP e CI.
8. **Risco:** instabilidade live; separar da suíte determinística.
9. **Estratégia:** OpenAI, Claude, Gemini, Ollama e Generic primeiro.
10. **Aceite:** toda capability declarada possui contrato determinístico correspondente.

### 6. Normalização de reasoning — P1

1. **Problema:** nomes e níveis não são universais.
2. **Ideia:** negociar opção por provider/modelo com fallback claro.
3. **FCC:** perfis traduzem vocabulários e detalhes de reasoning.
4. **Adaptação:** capability no catálogo e normalizador separado do payload.
5. **Impacto:** médio.
6. **Dificuldade:** média.
7. **Componentes:** config, providers, metadata e UI.
8. **Risco:** custo/latência inesperados.
9. **Estratégia:** opt-in, default conservador e diagnóstico do valor efetivo.
10. **Aceite:** provider não recebe parâmetro incompatível e usuário vê o nível efetivo.

### 7. Admission control e backoff — P1

1. **Problema:** tarefas concorrentes podem pressionar endpoint limitado.
2. **Ideia:** limite, fila curta, backoff com jitter e circuit breaker por provider.
3. **FCC:** admissão e retry são responsabilidades explícitas.
4. **Adaptação:** serviço compartilhado preservando cancelamento.
5. **Impacto:** médio.
6. **Dificuldade:** média.
7. **Componentes:** provider service, agent, chat e status.
8. **Risco:** fila escondida e aparência de travamento.
9. **Estratégia:** estado visível, timeout de fila e cancelamento imediato.
10. **Aceite:** teste concorrente prova limite, cancelamento e reabertura.

### 8. Eventos normalizados — P1

1. **Problema:** provider, CLI e tools entregam formatos distintos à apresentação.
2. **Ideia:** eventos `started/delta/reasoning/tool/usage/failed/completed`.
3. **FCC:** conversões e pipelines isolam protocolos da renderização.
4. **Adaptação:** records Delphi internos, sem servidor HTTP.
5. **Impacto:** médio.
6. **Dificuldade:** alta.
7. **Componentes:** service, agent, CLI adapters, presenter e chat.js.
8. **Risco:** refatoração transversal.
9. **Estratégia:** adapter paralelo e migração incremental.
10. **Aceite:** UI não interpreta payload específico de provider/CLI.

### 9. Correlação estruturada — P1

1. **Problema:** falha entre UI, provider, tool e processo exige cruzar logs.
2. **Ideia:** correlation ID por turno/execução sem payload sensível.
3. **FCC:** request IDs e traces unem as camadas.
4. **Adaptação:** propagar ID no logger, auditoria, tool run e diagnóstico.
5. **Impacto:** médio.
6. **Dificuldade:** média.
7. **Componentes:** logger, service, runtime, security audit e doctor.
8. **Risco:** exposição; ID não pode conter dado do usuário.
9. **Estratégia:** GUID aleatório e allowlist de metadados.
10. **Aceite:** um ID recupera a sequência sanitizada sem prompt, token ou credencial.

### 10. Contrato único de executável CLI — P1

1. **Problema:** discovery, login e execução podem voltar a divergir.
2. **Ideia:** resolver uma vez caminho, origem, versão, auth e ambiente.
3. **FCC:** launchers concentram preparação e removem credenciais conflitantes.
4. **Adaptação:** interface única sobre o mecanismo já corrigido no RadIA.
5. **Impacto:** alto.
6. **Dificuldade:** média.
7. **Componentes:** CLI manager, config, agent executors, doctor e MCP provisioning.
8. **Risco:** quebrar overrides portáteis e WSL.
9. **Estratégia:** testes com PATH, override, espaços, ausente e WSL.
10. **Aceite:** diagnóstico e execução exibem e usam o mesmo caminho efetivo.

## Quick wins

1. Exibir `live`, `cache` ou `fallback` junto ao modelo e no `/status`.
2. Incluir URL oficial de credencial/ajuda nos metadados.
3. Padronizar categoria de erro e próxima ação no chat.
4. Acrescentar correlation ID sanitizado às falhas.
5. Gerar tabela provider × capability e protegê-la por teste.
6. Mostrar no doctor o executável CLI efetivamente usado.

## Melhorias estruturais

- separar metadata, factory, discovery e health sem multiplicar registries;
- manter payload específico fora do presenter e JavaScript;
- definir commit e idempotência antes de implementar recovery;
- falhar teste quando uma capability declarada não possuir contrato;
- estruturar diagnósticos antes de renderizá-los como texto;
- preservar provider, agente nativo, CLI e MCP como eixos independentes.

## Roadmap sugerido

1. **Confiabilidade básica:** falhas canônicas, diagnóstico estruturado, catálogo e origem dos modelos.
2. **Contratos:** matriz de capabilities, testes compartilhados e reasoning normalizado.
3. **Resiliência:** admission control, retry/backoff e experimento de holdback.
4. **Unificação:** eventos normalizados, correlation ID e contrato CLI único.

As etapas 1 e 2 cabem em um release minor. Recovery só deve sair de feature flag após testes de
idempotência de tools.

## Licença, segurança e privacidade

O FCC usa licença MIT. Ela permite uso e modificação, mas exige preservar copyright e licença em
cópias ou porções substanciais. Esta auditoria usa ideias e padrões abstratos. Se houver adaptação
substancial futura, ela deverá ser isolada, revisada e registrada em `THIRD_PARTY_NOTICES` ou
equivalente antes do merge.

Não devem ser copiados automaticamente: código Python sem redesenho de lifecycle/threading, fluxos
OAuth sem threat model, proxy/admin/web fetch sem auth/loopback/SSRF, logs de payload e retries que
possam repetir escrita, debug ou tool calls. Consentimento, allowlists, redação de segredos, limites
de workspace e auditoria do RadIA continuam obrigatórios.

## Riscos

- catálogo excessivamente complexo;
- latência no holdback;
- duplicação de tool calls;
- providers demais para manter;
- vazamento de payload em observabilidade;
- threads/timers sobrevivendo ao shutdown;
- nova confusão entre provider, auth, CLI e MCP.

Mitigações: schema pequeno e versionado, limites conservadores, idempotência, contratos, logs por
allowlist e cancelamento integrado ao shutdown.

## Próximos passos

1. Criar ADR de `TRadIAProviderFailure` e do estado de descoberta.
2. Inventariar capabilities reais e seus testes.
3. Prototipar falhas canônicas em um provider remoto e um local.
4. Expor origem/idade em `/status` e `/doctor`.
5. Definir “commit visual” e “ação idempotente” antes do recovery.
6. Medir falhas sanitizadas para escolher retry, concorrência e cache.
7. Converter etapas 1 e 2 em goal de release com critérios verificáveis.

## Conclusão

O FCC não revela uma lacuna que exija transformar o RadIA em proxy ou agregador universal. Ele
oferece referências maduras para deixar a infraestrutura atual previsível, observável e testável.
O investimento correto é aprofundar a experiência no Delphi e usar catálogo, falhas, discovery,
recovery e contratos como multiplicadores dessa experiência.
