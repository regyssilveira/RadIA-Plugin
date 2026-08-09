# Goal RadIA 2.0: liderança da experiência Delphi

> **Estado:** planejado e em execução.
> **Estado histórico:** goal concluído e publicado na versão 2.0.0.

## Objetivo

Entregar a experiência de desenvolvimento agentivo mais completa para Delphi, cobrindo continuamente
digitação, chat, edição revisável, Form Designer, terminal, build, testes, debug, conhecimento e
entrega, sem abandonar segurança, transparência ou compatibilidade.

O produto deve ser claramente superior pela jornada integrada, não pela quantidade isolada de
ferramentas. Cada capacidade precisa ser descobrível, observável, cancelável e comprovada em uma IDE
real.

## Princípios

1. Permanecer dentro do fluxo da IDE, do primeiro caractere ao commit.
2. Usar o buffer vivo e o estado real da IDE como fontes primárias.
3. Exigir preview, consentimento e rollback proporcionais ao risco.
4. Funcionar com agente nativo, providers por API, CLIs e modelos locais.
5. Tornar extensões simples sem reduzir o confinamento ou a auditabilidade.
6. Concentrar compatibilidade em Delphi 12 Win32 e Delphi 13 Win32/IDE64.
7. Não publicar a versão enquanto os gates objetivos permanecerem abertos.

## Resultados mensuráveis

| Resultado | Meta de aceite |
|---|---|
| Qualidade | Gate global do Sonar verde, zero vulnerabilidade e zero issue nova |
| Assistência inline | Primeira sugestão em até 700 ms no percentil 95 após o debounce |
| Aceite inline | Aceitar, rejeitar e alternar sugestões somente pelo teclado |
| Terminal | Shell interativo com ANSI, resize, stdin contínuo e encerramento da árvore |
| Jornada | Um único painel acompanha intenção, plano, tools, diffs, build, testes e debug |
| Extensibilidade | Instalar uma extensão declarativa sem recompilar ou reiniciar a IDE |
| Conhecimento | Busca lexical e semântica local, incremental, opt-in e reconstruível |
| Instalação | Instalar, diagnosticar e concluir o primeiro fluxo sem editar arquivos manualmente |
| Estabilidade | Dez ciclos consecutivos por combinação suportada, sem leak ou processo órfão |

## Placar de liderança

O RadIA só será considerado líder quando superar simultaneamente os seguintes eixos. Não basta
igualar uma capacidade isolada:

| Eixo | Evidência obrigatória para liderança |
|---|---|
| Jornada Delphi | Criar, editar, desenhar, compilar, testar, depurar, corrigir e entregar sem sair da IDE |
| Assistência contínua | Chat, Ghost Text e ações contextuais compartilham contexto, política e histórico |
| Controle da IDE | Buffer vivo, projeto, Form Designer, build, testes e debugger são observados por OTA |
| Execução híbrida | Agente nativo, providers, CLIs e modelos locais usam a mesma camada de tools e consentimento |
| Segurança | Toda mutação relevante possui preview, escopo, consentimento, auditoria e rollback proporcional |
| Transparência | Plano, tool, diff, custo, tokens, duração, resultado e falha permanecem visíveis |
| Extensibilidade | Comandos, skills, templates e tools podem ser instalados com permissões explícitas |
| Conhecimento | Recuperação incremental, lexical e semântica, privada, citável e isolada por workspace |
| Operação | Instalação, diagnóstico, atualização, reparo e remoção são guiados e reproduzíveis |
| Compatibilidade | A mesma experiência passa no Delphi 12 Win32 e Delphi 13 Win32/IDE64 |

Cada eixo recebe um dos estados `ausente`, `parcial`, `equivalente` ou `líder`. A decisão de release
exige `líder` em todos os eixos, acompanhada das evidências do M8.

## Estado de execução

| Marco | Estado | Gate para avançar |
|---|---|---|
| M0 — Qualidade | Concluído | Gate Sonar global verde e automatizado |
| M1 — Assistência inline | Concluído | Ghost Text OTA, atalhos, consentimento e matriz real aprovados |
| M2 — Terminal | Concluído | PTY, ANSI/CSI, abas, stdin, resize e encerramento de árvore validados |
| M3 — Central unificada | Concluído | Jornada observável, pausável, retomável e persistente |
| M4 — Extensões | Concluído | Instalação e workflows declarativos comprovados na matriz real |
| M5 — Conhecimento | Concluído | Busca híbrida privada comprovada na matriz real |
| M6 — Instalação | Concluído | Primeiro valor provado; instalador opcional e build reproduzível |
| M7 — Jornadas | Concluído | Receitas Delphi ponta a ponta aprovadas |
| M8 — Prova e release | Concluído | Matriz, dez ciclos e auditorias aprovados |

O M1 já possui motor Fill-in-the-Middle, debounce, cancelamento, cache, limites, provider
desacoplado, captura contínua opt-in, controles de escopo e Ghost Text OTA. A captura usa o buffer
vivo, a posição do cursor e o símbolo vigente. Os cinco atalhos são bindings OTA configuráveis,
validados e recarregados sem reiniciar a IDE. Sugestões multilinha agora usam overlays virtuais por
linha, preservam quebras no aceite e mantêm continuações separadas do código real. O aceite visual
foi aprovado no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. A evidência registra separadamente
a preparação e a pintura OTA de duas linhas sem persistir conteúdo do editor.

O M2 possui buffer visual ANSI/CSI com cursor e sobrescrita, saída rica, stdin contínuo, execução
por ConPTY, resize em dimensões de caracteres, busca reversa por `Ctrl+R` e múltiplas sessões em
abas. Cada aba mantém processo, entrada, saída e ciclo de vida independentes. O estilo e o estado
do parser permanecem íntegros mesmo quando uma sequência chega dividida entre chunks.

## Regras de passagem entre marcos

1. Código, documentação e testes unitários formam uma única entrega.
2. Uma capacidade visual só termina depois de validação na IDE real.
3. Uma integração de provider ou CLI só termina depois de cancelamento, timeout e falha exercitados.
4. Uma mutação só termina depois de preview, consentimento, conflito concorrente e rollback testados.
5. Cada rodada consulta o Sonar; nenhum issue novo pode ser incorporado ao baseline.
6. Cada incremento concluído é commitado e enviado pela branch de trabalho.
7. Gates de release sempre usam Delphi 12 Win32 e Delphi 13 Win32/IDE64.

## Marcos

### M0 — Qualidade bloqueante

- Resolver os bugs e code smells ativos do Sonar pela causa raiz.
- Separar claramente baseline, código novo e dívida aceita no dashboard.
- Tornar lint, catálogo, matriz, integridade dos pacotes e Sonar gates automatizados.
- Rejeitar a preparação de release quando qualquer gate obrigatório falhar.

**Saída:** baseline global verde e pipeline local reproduzível.

O M0 foi concluído com evidência reproduzível em
[`sonar_quality_evidence_2.0.0.json`](sonar_quality_evidence_2.0.0.json): Quality Gate `OK`, zero
bugs, vulnerabilidades, hotspots de segurança, code smells e issues não resolvidas; cobertura global
de 82,3%, duplicação de 2,3% e ratings A para confiabilidade, segurança e manutenibilidade.

### M1 — Assistência inline e Ghost Text

- Criar um motor desacoplado de sugestões Fill-in-the-Middle.
- Capturar prefixo, sufixo, linguagem, símbolo e contexto limitado do projeto.
- Aplicar debounce, cancelamento de requisição anterior, cache e limite de contexto.
- Suportar providers remotos e modelos locais sem enviar contexto ocultamente.
- Renderizar Ghost Text sem alterar o buffer antes do aceite.
- Oferecer aceitar tudo, aceitar próxima palavra, rejeitar e solicitar alternativa.
- Desabilitar por projeto, arquivo, linguagem ou sessão.

**Saída:** sugestões contínuas, rápidas e reversíveis no editor Delphi.

A matriz `inline_completion_smoke_evidence_2.0.0.json` comprova Ghost Text multilinha preparado e
pintado pela OTA no Delphi 12 Win32 e no Delphi 13 Win32/IDE64, com o catálogo vigente de 95
ferramentas. A posição visual considera a primeira coluna visível após rolagem horizontal e o
cursor é reativado de forma inócua para iniciar o ciclo de pintura também na IDE64.

### M2 — Terminal interativo de primeira classe

- Substituir o executor de comando por uma camada de pseudo terminal compatível com Windows.
- Interpretar ANSI, cores, cursor, resize e entrada contínua.
- Manter múltiplas sessões, abas, perfis e diretórios por projeto.
- Oferecer histórico navegável, busca reversa, snippets e paleta de comandos.
- Conectar agentes iniciados no terminal ao mesmo MCP, consentimento, diff e auditoria do chat.
- Encerrar toda a árvore de processos sem bloquear o shutdown da IDE.

**Saída:** terminal completo, acoplável e adequado ao uso diário.

### M3 — Central unificada de execução

Entregue nesta etapa: o cartão vivo tornou-se uma timeline auditável com mensagem atual, limites,
tokens, custo, duração, correlação, argumentos, resultados, erros, mutações e indicadores de
build e testes. O botão **Runs** e `/agent history` pesquisam checkpoints por objetivo, estado ou
sessão sem expor payloads das tools.
O editor **Edit plan** e `/agent plan` permitem revisar de 1 a 50 etapas enquanto a execução aguarda
aprovação, preservando o checkpoint e bloqueando alterações após a primeira tool. A repetição
segura também foi entregue: **Replay step** e `/agent replay` repetem a chamada somente em uma
execução pausada, passam novamente por consentimento, registram a etapa de origem e permanecem
pausados para revisão.
Cada etapa agora apresenta a classificação formal de risco da ferramenta e agrega os arquivos
afetados informados em campos de caminho reconhecidos. O resumo não interpreta texto livre de
argumentos ou resultados, evitando expor conteúdo arbitrário como se fosse um caminho.
A evidência de validação também deixou de ser apenas binária: o checkpoint e o cartão mostram o
status e a duração do build, a quantidade de mensagens do compilador e o resumo DUnitX com total,
aprovados, falhas, erros e ignorados.
Etapas de `PreparePatch`, `ApplyPatch`, `RevertPatch` e suas variantes multiarquivo agora incluem
uma revisão visual por arquivo na própria timeline. O bloco mostra três linhas de contexto,
quantidade de linhas removidas e adicionadas e não oferece um atalho paralelo para mutação:
aplicar ou reverter continua passando pelo fluxo central de consentimento.
A jornada Git também está integrada: `GetGitStatus` mostra o estado textual do repositório,
`GetGitDiff` e `PreviewGitCommit` apresentam diff unificado colorido com arquivos e contagens,
e `CommitChanges` registra o SHA local criado. O preview mantém mensagem, caminhos e fingerprint
visíveis, sem oferecer push automático.
A jornada de debug também ganhou evidências próprias: estado do processo, localização, threads,
breakpoints, call stack, transições de execução, valores avaliados, watches e eventos da timeline
aparecem dentro da etapa correspondente. A camada visual consome somente o resultado auditado da
tool e limita listas extensas, sem criar polling ou controlar uma sessão por conta própria.

A jornada do runtime é comprovada no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. O smoke usa
um provider local determinístico, executa `GetIDEState` pelo registry e pela policy reais, pausa
após a etapa, persiste o checkpoint, destrói o runtime e retoma em outra instância até a conclusão.
A matriz versionada está em `agent_runtime_smoke_evidence_2.0.0.json` e vincula os três alvos ao
catálogo vigente de 95 ferramentas.

- Criar uma timeline única para intenção, plano, modelo, tools, consentimentos e resultados.
- Incorporar diffs por bloco, build, testes, cobertura, debug e Git na mesma jornada.
- Permitir pausar, cancelar, editar o plano, repetir uma etapa e retomar de checkpoint.
- Mostrar tokens, custo, tempo, arquivos alterados e riscos antes da conclusão.
- Persistir sessões de forma pesquisável sem registrar secrets.

**Saída:** o usuário entende o que aconteceu, o que está acontecendo e qual será o próximo passo.

### M4 — Plataforma de extensões acessível

- Definir manifesto versionado para comandos, prompts, skills, templates e tools.
- Oferecer extensões declarativas e scripts, preservando a API BPL para cenários avançados.
- Validar assinatura, versão, permissões, paths, dependências e integridade antes da ativação.
- Isolar execução, limitar recursos e passar toda mutação pela política central.
- Criar gerenciador visual para instalar, atualizar, desabilitar, diagnosticar e remover extensões.
- Publicar SDK, exemplos e validador de pacote.

**Entregue até aqui:** manifestos de comandos com hot reload, instalação transacional, pacote
fechado com limites e SHA-256, assinatura RSA-SHA256 via Windows CNG, fingerprint, consentimento no
primeiro uso, trust store local e revogação visual de publicadores. O catálogo remoto já possui
navegador visual assíncrono, busca, URL persistente, schema, HTTPS, limites, download transacional
e vínculo ao pacote assinado. O schema 2 entrega commands, templates e skills de prompt com hot
reload. O schema 3 adiciona aliases de tools internas com namespace próprio, permissão
`tool.alias`, metadados de risco herdados, registro comum ao chat e MCP e rollback do catálogo em
falhas. O schema 5 substitui scripts arbitrários por workflows de 1–16 tools internas: risco,
timeout e idempotência são derivados, e cada etapa atravessa novamente consentimento e auditoria.

**Saída:** uma capacidade simples pode ser adicionada sem recompilar o RadIA ou reiniciar a IDE.

### M5 — Conhecimento semântico privado

- Manter a busca lexical atual como fallback determinístico.
- Adicionar embeddings opcionais e armazenamento vetorial local.
- Permitir provider local ou remoto com consentimento explícito e exclusões configuráveis.
- Indexar incrementalmente código, DFM/FMX, projetos, documentação, símbolos e histórico aprovado.
- Explicar a origem de cada trecho recuperado e permitir abrir o arquivo correspondente.
- Medir relevância, latência, tamanho, reconstrução e isolamento entre workspaces.

**Saída:** contexto relevante de grandes soluções sem perder privacidade ou rastreabilidade.

**Entregue:** busca híbrida com fallback lexical determinístico, contrato opcional de embeddings,
provider vetorial local sem rede, persistência versionada por workspace e explicação dos
componentes lexical e vetorial de cada resultado.

O consentimento visual local agora está disponível em **Settings > Security & Consent**, desativado
por padrão e aplicado imediatamente sem reiniciar a IDE. Exclusões configuráveis por arquivo e
projeto bloqueiam consultas imediatamente e removem o conteúdo persistido na atualização seguinte.
O provider remoto OpenAI-compatible é opcional e permanece inativo até autorização explícita.

A integração remota inclui transporte OpenAI-compatible injetável, endpoint HTTPS ou loopback,
redirects desabilitados, timeout, limites de entrada e resposta, dimensões validadas e API key fora
do JSON. Falhas continuam retornando à busca lexical. A ativação exige consentimento remoto
separado e configuração visual explícita.

O seletor de embeddings remotos agora falha de forma fechada: busca semântica e autorização de rede
são decisões independentes. Sem habilitação remota, consentimento separado e provider válido, o
índice continua usando apenas o provider local. A tela expõe endpoint, modelo, credencial protegida,
dimensões, timeout e limite de entrada e aplica as alterações sem reiniciar a IDE.

Busca e reconstrução agora publicam latência local em milissegundos, o status informa o tamanho
estimado do índice e todas as respostas preservam a identidade do projeto. Com scores explicados,
navegação direta e testes independentes por workspace, relevância, latência, tamanho, reconstrução
e isolamento passaram a possuir evidência observável sem telemetria.

A indexação incremental agora cobre Pascal, companions DFM/FMX textuais, arquivos DPROJ/GROUPPROJ
e documentação Markdown, texto, AsciiDoc e reStructuredText. A descoberta documental é confinada
à raiz e às pastas `docs/doc`, com limites de quantidade, tamanho e workspace boundary; o notifier
OTA usa a mesma política central de formatos.

O histórico aprovado está integrado ao índice mediante consentimento explícito, desligado por
padrão. Somente execuções concluídas, com plano aprovado e do projeto atual viram documentos
virtuais. Argumentos e resultados de tools não são copiados, e a revogação bloqueia consultas
imediatamente antes da remoção física na atualização seguinte.

A jornada semântica real é aprovada no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. A prova
indexa o projeto de testes, pesquisa semanticamente com `local-hash-v1`, valida origem, navegação,
métricas, leitura do documento e isolamento do workspace. A matriz versionada está em
`knowledge_smoke_evidence_2.0.0.json`.
Os três targets publicam 95 ferramentas e reconstruíram automaticamente o índice persistido ao
detectar a transição do modo lexical para o provider semântico. Assim, ativar ou trocar embeddings
não exige que o usuário descubra e execute uma limpeza manual.

### M6 — Instalação e primeiro valor

- Manter um instalador visual opcional e instruções reproduzíveis para compilação pelo usuário.
- Detectar Delphi, arquitetura, WebView2, CLIs, autenticação e configurações incompatíveis.
- Manter CLIs de terceiros fora do pacote e delegar instalação aos canais oficiais com consentimento.
- Guiar login sem capturar tokens ou credenciais.
- Executar diagnóstico pós-instalação de chat, provider, terminal, MCP e primeira tool.
- Oferecer reparação e desinstalação completas, preservando dados escolhidos pelo usuário.

**Saída:** da instalação à primeira alteração revisada sem configuração manual de arquivos.

O onboarding versão 2 executa `/doctor` por um botão próprio. O diagnóstico retorna checks
estruturados, score e próxima ação, confirma `GetIDEState` como primeira tool somente leitura e não
exige MCP quando o executor nativo está selecionado.

O pacote de release agora usa o mesmo instalador validado para `Install`, `Repair` e `Uninstall`,
possui plano somente leitura, preserva dados e componentes compartilhados por padrão e exige
`-RemoveUserData` para apagar configurações, auditoria, sessões e conhecimento.

O instalador visual único foi implementado com detecção e seleção de Delphi 12 Win32 e Delphi 13
Win32/IDE64. A geração valida os três pacotes antes de compilar e registra SHA-256 e o estado
Authenticode. Como o RadIA é aberto e pode ser compilado pelo usuário, assinatura de código e
marketplace não são gates da versão 2.0. A distribuição deve manter hash verificável, origem
versionada e instruções reproduzíveis de build e instalação.

O diagnóstico pós-instalação é aprovado no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. A
prova consulta o doctor pelo bridge instalado, exige chat, terminal, catálogo de 95 tools e
`GetIDEState`, e preserva uma próxima ação útil quando o provider ainda não está configurado.
A matriz versionada está em `first_value_smoke_evidence_2.0.0.json`.

### M7 — Jornadas especializadas

- [x] Entregar receitas auditáveis para criar aplicação, corrigir build, ampliar testes e depurar.
- [x] Adicionar modernização orientada a Delphi, incluindo units, forms, packages e dependências.
- [x] Integrar migração segura de padrões legados com preview e gates de compilação.
- [x] Criar cartão de saúde do projeto com score, riscos e jornadas priorizadas revisáveis.
- [x] Permitir compartilhar receitas e políticas entre equipes sem compartilhar credenciais.

**Saída:** o RadIA resolve fluxos completos de Delphi, não apenas solicitações isoladas.

As sete receitas nativas agora possuem quatro fases ordenadas, evidência obrigatória por fase e
três critérios de conclusão incorporados ao objetivo do Agent Runtime. O contexto do usuário é
mantido separado e não substitui consentimento, revisão de plano nem gates de conclusão.

O catálogo agora possui sete receitas. `/journey modernize` inventaria units, forms, packages,
dependências e targets antes de aplicar lotes coerentes. `/journey migrate` exige baseline, escopo
fechado, transação reversível e comparação de build, testes e saúde antes de aceitar cada lote.

O schema declarativo 4 publica jornadas e políticas com hot reload. Jornadas compartilhadas entram
no Agent Runtime com gates obrigatórios acrescentados pelo RadIA; políticas só expandem mediante
comando explícito. Campos de credenciais são rejeitados recursivamente e não entram nos pacotes.
A matriz real validou os três targets suportados com 95 ferramentas: o manifesto foi carregado,
registrado e executado por hot reload. O workflow `RadIADiagnosticInspection`, classificado como
`readOnly`, concluiu suas duas etapas em Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

### M8 — Prova de liderança e release

- [x] Executar a matriz completa de build e 100% dos testes.
- [x] Validar Ghost Text, terminal, central, extensões e conhecimento em IDE real.
- [x] Aprovar navegação completa por teclado e tecnologia assistiva nas três combinações.
- [x] Executar dez ciclos de desinstalação, instalação, reparo, uso e shutdown por combinação.
- [x] Validar upgrade real entre versões diferentes do pacote em cada combinação suportada.
- [x] Aprovar a jornada contínua: criar, editar, desenhar, testar, depurar, corrigir e commitar.
- [x] Regenerar os três pacotes do mesmo commit e publicar hashes independentes.
- [x] Vincular o smoke real ao pacote, commit e BPL instalada com evidência JSON fail-closed.
- [x] Automatizar a auditoria final de segurança, privacidade, acessibilidade e documentação.

**Saída:** candidato 2.0.0 comprovado, reproduzível e pronto para decisão de publicação.

A prova reproduzível em `release_evidence_2.0.0.json` contém os três ZIPs da matriz vigente, todos
gerados do commit `20a9f996c10c76ecfc925bb80029debb307cd117`, com validação interna,
SHA-256 independente e árvore rastreada limpa.

A matriz em `ide_smoke_evidence_2.0.0.json` comprova Delphi 12 Win32 e Delphi 13 Win32/IDE64 com
10/10 ciclos por target, 30/30 no total, e o catálogo vigente de 95 tools. Cada target exercitou o docking nativo
`TOTADockForm`, restaurou o estado do desktop e terminou sem
processos órfãos. Cada ciclo executou `Uninstall`, instalou a versão 1.0.0, atualizou para 2.0.0 e
executou `Repair`, preservando dados do usuário e revalidando manifesto, hashes, registro e arquivos
instalados antes de abrir a IDE. O consolidador fail-closed deriva a prova oficial dos três JSONs
de execução e rejeita divergências de target, ciclo, upgrade, lifecycle, hash, commit, docking, BPL
ou catálogo.

A jornada contínua completa está comprovada em
`New-RadIA.LeadershipClosureEvidence.ps1`. No mesmo fluxo e pelo mesmo commit, cada combinação
criou e compilou um projeto VCL, alterou e reverteu o Form Designer, editou e salvou o buffer vivo,
observou uma falha intencional do compilador, reverteu a correção, recompilou, aprovou 761 testes,
parou em breakpoint com call stack e timeline, criou um commit Git revisado e encerrou sem processo
órfão. Delphi 12 Win32 e Delphi 13 Win32/IDE64 passaram autonomamente. O consolidador rejeita
fonte suja, SHA divergente, hash de BPL inválido, fase ausente, testes incompletos, debug sem
evidência ou commit sem diff revisado.

A matriz `generated_project_templates_evidence_2.0.0.json` comprova a criação e a compilação
individuais dos sete templates nativos do RadIA nos compiladores do Delphi 12 e 13: Console, VCL,
FMX, Library, Package, DUnitX e Service. A prova está vinculada ao commit de origem, registra a
versão efetiva de cada compilador e rejeita template ausente, duplicado, não compilado ou executado
fora de Win32/Debug. Assim, a promessa de iniciar projetos do zero não depende apenas da jornada VCL.

A validação funcional das cinco superfícies em IDE real também está completa. O terminal possui
prova dedicada em `terminal_smoke_evidence_2.0.0.json`: a janela nativa, controles essenciais,
entrada, saída, geometria útil, cinco rótulos associados e 11 pontos navegáveis por Tab passaram
no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. A árvore UI Automation do Delphi 13 IDE64
confirmou nomes, estados e descrições do chat, inclusive Agent Mode, terminal, histórico,
configurações, conversa e prompt. Ghost Text, central agentiva, extensões e conhecimento
permanecem vinculados às suas respectivas matrizes versionadas e aos controles nativos ou à
semântica Web compartilhada entre os targets.

A auditoria reproduzível está em `release_audit_2.0.0.md`. Ela removeu a única conexão Web
silenciosa no startup, adicionou semântica e teclado às superfícies Web, criou um gate para links e
mojibake e consolidou o aceite com tecnologia assistiva.

## Ordem de execução

```text
M0 Qualidade
  ├── M1 Assistência inline
  ├── M2 Terminal interativo
  └── M3 Central unificada
        ├── M4 Extensões
        ├── M5 Conhecimento
        └── M6 Instalação
              └── M7 Jornadas especializadas
                    └── M8 Prova e release
```

M1, M2 e a fundação visual de M3 podem avançar em paralelo após M0. M4 e M5 dependem da política,
auditoria e observabilidade consolidadas em M3. A publicação depende de todos os marcos.

## Definition of Done

- O usuário recebe ajuda antes, durante e depois de escrever código.
- Chat e terminal possuem o mesmo alcance, segurança e revisão.
- Toda sugestão ou mutação pode ser entendida, recusada, cancelada ou revertida.
- Extensões não contornam consentimento, workspace boundary ou auditoria.
- Conhecimento semântico é opcional, privado e rastreável.
- Instalação, atualização, reparação e remoção são guiadas.
- Não há secret em logs, telemetria, prompts persistidos ou artefatos.
- Sonar, lint, testes, packages e matriz de IDE permanecem verdes.
- A jornada completa é aprovada no Delphi 12 Win32 e Delphi 13 Win32/IDE64.
