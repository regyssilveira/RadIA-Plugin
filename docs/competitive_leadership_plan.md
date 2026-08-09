# Goal — eliminar as seis lacunas competitivas do RadIA

> **Estado:** ativo, planejado a partir do RadIA 2.3.0.
> **Escopo:** Delphi 12 Win32 e Delphi 13 Win32/IDE64.
> **Versão de entrega:** será definida pela mudança pública efetivamente entregue; números herdados
> de backlogs anteriores não são compromisso.
> **Fora do escopo:** C++Builder, marketplace, assinatura Authenticode obrigatória e substituição do
> host WebView2 atual.

## Objetivo

Eliminar, com evidência reproduzível, as seis lacunas funcionais restantes:

1. continuidade nativa das sessões CLI;
2. contexto único entre chat, terminal e editor;
3. revisão por bloco diretamente no gutter;
4. completion especializada em Fill-In-the-Middle (FIM);
5. cliente e federação de servidores MCP externos;
6. configurações por projeto, sessão e solicitação.

O goal termina somente quando os seis contratos estiverem implementados, documentados e aprovados
na matriz Delphi suportada. Entregar apenas a interface, um provider ou um target não fecha uma fase.

## Baseline que deve ser preservada

- Agente nativo independente de CLI e executores externos opcionais.
- Um registry de tools compartilhado por chat, agente, MCP e extensões.
- Consentimento por risco, auditoria sanitizada, workspace boundary, checkpoints e rollback.
- Terminal ConPTY, Ghost Text, revisão inline, debugger, Designer, build, DUnitX e FastMM5.
- Descoberta e troca de provider/modelo sem reiniciar a IDE.
- Documentação central, `/doctor`, `/status` e `/tools` coerentes com o runtime.

## Contratos transversais

Todas as fases obedecem aos seguintes contratos:

- nenhuma credencial, token ou conteúdo sensível é persistido em texto aberto;
- callbacks tardios nunca atravessam sessão, projeto, revisão ou instância da IDE;
- tools internas e externas usam a mesma classificação de risco e consentimento;
- alterações no editor são preview-first, atômicas, auditáveis e reversíveis;
- a UI informa origem efetiva de executor, modelo, configuração e tool;
- recursos indisponíveis degradam de forma explícita, sem fallback silencioso;
- toda capacidade visível atualiza referência central, guia, hints, tradução e testes documentais;
- cada fase fecha com testes, Sonar e evidência na matriz suportada.

## Plano de execução

### Fase 0 — Baseline, contratos e telemetria local

- Versionar uma matriz de capacidades dos executores Codex, Claude, Gemini e GitHub Copilot.
- Definir records/interfaces para identidade de jornada, conversa, sessão, projeto e solicitação.
- Definir contratos de capability discovery para retomada, FIM e seleção de modelo.
- Medir localmente latência, cancelamento, respostas obsoletas e retomadas, sem telemetria remota.
- Criar fixtures e testes de contrato antes das mudanças de persistência e UI.

**Aceite:** matriz versionada, contratos revisados, baseline de testes verde e Sonar sem issue nova.

**Estado:** concluída. O catálogo tipado, as cinco fronteiras de identidade, a matriz bilíngue e os
quatro testes contratuais foram aprovados com 898/898 testes nos três targets. Consulte a
[evidência da Fase 0](competitive_gap_phase_0_evidence_2.3.1.json).

**Ainda faltará:** implementar os seis pontos funcionais.

### Fase 1 — Continuidade nativa das sessões CLI

- Capturar o identificador de conversa devolvido por cada CLI e validar seu formato.
- Persistir somente metadados não secretos: executor, modelo declarado, workspace e identificador.
- Implementar criar, retomar, duplicar, desvincular e encerrar conversa.
- Definir fallback explícito para CLIs sem retomada estável; nunca simular continuidade.
- Correlacionar processo, streaming, consentimento e resposta com a sessão que os originou.
- Expor estado e ações por botão, comando e `/status`.

**Aceite:** após fechar o painel e reiniciar a IDE, cada CLI suportada retoma a conversa correta ou
informa claramente que iniciou uma nova; testes provam isolamento e descarte de saída tardia.

**Estado:** concluída. Codex, Claude, Gemini e Copilot retomam por identificador, com metadados
sanitizados por conversa, isolamento de respostas tardias e ações equivalentes no compositor e por
comando. A matriz Delphi passou com 904/904 testes por alvo. Consulte a
[evidência da Fase 1](competitive_gap_phase_1_evidence_2.3.1.json).

**Ainda faltará:** contexto entre superfícies, configuração hierárquica, FIM, gutter e MCP externo.

### Fase 2 — Contexto único entre chat, terminal e editor

- Introduzir uma identidade de jornada que referencia conversa, projeto e execução sem duplicá-los.
- Permitir iniciar no chat, continuar no terminal e solicitar completion/revisão no editor.
- Compartilhar executor, projeto, diagnóstico e artefatos selecionados, não histórico irrestrito.
- Permitir vincular, desvincular e trocar jornada por interface visual e comando.
- Mostrar em cada superfície a jornada ativa e impedir mistura entre projetos.
- Preservar consentimento, auditoria, checkpoints e limites do agente nativo.

**Aceite:** uma jornada autenticada atravessa chat, terminal e editor sem perder identidade nem
copiar contexto de outro workspace; cancelamento em uma superfície produz estado coerente nas demais.

**Estado:** concluída. Chat, terminal e editor usam a mesma identidade por conversa e projeto, com
atividade compartilhada, isolamento entre workspaces, botão visual e comandos para vincular,
desvincular, renovar e trocar a jornada. Nenhum histórico ou saída de processo é copiado. A matriz
Delphi passou com 916/916 testes por alvo. Consulte a
[evidência da Fase 2](competitive_gap_phase_2_evidence_2.3.1.json).

**Ainda faltará:** configuração hierárquica, FIM, gutter e MCP externo.

### Fase 3 — Configuração por projeto, sessão e solicitação

- Implementar precedência explícita: solicitação > sessão > projeto > global > padrão seguro.
- Cobrir provider, modelo, executor e limites compatíveis; credenciais permanecem globais e seguras.
- Armazenar configuração de projeto fora de arquivos versionados por padrão, com exportação opt-in.
- Mostrar valor efetivo, origem, override e ação para restaurar herança.
- Aplicar gravação read-merge-write atômica e preservar campos desconhecidos.
- Atualizar modelo e capacidades ao trocar escopo, sem reiniciar o Delphi.

**Aceite:** dois projetos e duas sessões usam configurações distintas simultaneamente; concorrência
não perde campos e a UI, `/status` e a execução real concordam sobre cada valor efetivo.

**Estado:** concluída. Provider, modelo, executor e limites usam a precedência solicitação > sessão >
projeto > global > padrão seguro no chat nativo, agente e CLI externo. O botão **Settings > Scope**,
`/scope`, `/status settings` e a rota do compositor mostram o mesmo valor efetivo e sua origem,
permitem restaurar herança e atualizam modelos sem reiniciar a IDE. Projeto e sessão persistem fora
do repositório; a próxima solicitação fica em memória e não atravessa conversa ou workspace. A
exportação sanitizada é explícita e nunca inclui credenciais ou o caminho do projeto. A matriz
Delphi passou com 937/937 testes por target. Consulte a
[evidência final da Fase 3](competitive_gap_phase_3_evidence_2.3.1.json).
Consulte a [evidência do fundamento da Fase 3](competitive_gap_phase_3_foundation_evidence_2.3.1.json).
Consulte também a
[evidência da persistência da Fase 3](competitive_gap_phase_3_persistence_evidence_2.3.1.json).

**Ainda faltará:** gutter por bloco e MCP externo.

### Fase 4 — Completion especializada em FIM

- Adicionar um contrato de completion separado do contrato de chat.
- Detectar suporte a FIM por capability, sem inferir apenas pelo nome do modelo.
- Enviar prefixo, sufixo, linguagem, posição do cursor e orçamento dentro dos limites configurados.
- Manter fallback explícito para completion tradicional quando FIM não estiver disponível.
- Cancelar respostas obsoletas ao mudar cursor, buffer, arquivo, projeto ou jornada.
- Expor latência local, origem do modelo e motivo do fallback para diagnóstico.

**Concluída:** contrato FIM separado, discovery por capability, rotas dedicadas Ollama/LM Studio,
fallback, cancelamento por contexto e diagnóstico visual estão implementados. Fixtures de provider e
o smoke no editor real comprovaram preview limpo, aceite, undo único, restauração e rejeição limpa
no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
Consulte a
[evidência do fundamento da Fase 4](competitive_gap_phase_4_foundation_evidence_2.3.1.json).
Consulte também a
[evidência final da matriz FIM](inline_completion_smoke_evidence_2.3.1.json).

**Aceite:** fixtures provam montagem correta de prefixo/sufixo e um smoke real por target aceita e
rejeita Ghost Text sem alterar antecipadamente o buffer, com undo único e nenhum vazamento de código.

**Ainda faltará:** gutter por bloco e MCP externo.

### Fase 5 — Revisão por bloco diretamente no gutter

- Projetar marcadores acessíveis para aceitar, rejeitar, editar e explicar cada bloco.
- Vincular cada bloco ao hash da revisão e invalidá-lo quando o buffer divergir.
- Aplicar decisões parciais como transações coerentes com checkpoint e rollback.
- Oferecer equivalentes por teclado e comando para todas as ações visuais.
- Suportar múltiplos arquivos sem perder navegação, foco ou estado de revisão.
- Integrar o resultado à timeline e à auditoria, sem duplicar a fonte do diff.

**Implementação concluída:** `TRadIABlockReviewEngine` separa mudanças independentes, vincula cada
bloco ao arquivo e à revisão-base, atribui identidade estável e recompõe o arquivo com decisões
individuais de aceitar, rejeitar ou editar. O motor preserva CRLF e limita a matriz de comparação;
arquivos acima do limite continuam seguros por meio de um bloco agregado.
Consulte a
[evidência do fundamento da Fase 5](competitive_gap_phase_5_foundation_evidence_2.3.1.json).

Previews simples e multiarquivo publicam automaticamente uma sessão de blocos. Marcadores OTA no
gutter mostram os estados pendente, aceito, rejeitado e editado. O menu do marcador permite aceitar,
rejeitar, editar, explicar, aplicar ou descartar; comandos e atalhos configuráveis oferecem as mesmas
ações e navegação entre blocos e arquivos. As decisões não escrevem no editor até a aplicação.
`ApplyBlockReviews` exige todos os blocos resolvidos e usa a transação multiarquivo existente, com
preflight de SHA e compensação. `ListBlockReviews`, `DecideBlockReview`, `ApplyBlockReviews` e
`ClearBlockReviews` estão no catálogo de 130 ferramentas. Consulte a
[evidência transacional da Fase 5](competitive_gap_phase_5_transaction_evidence_2.3.1.json).

**Aceite comprovado:** 953 testes passam sem falhas ou vazamentos em cada target. Smokes reais no
Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 publicam revisões, pintam linha e gutter pela OTA,
aceitam pelo teclado, rejeitam pelo mouse e protegem contra revisão obsoleta.

**Ainda faltará:** cliente e federação MCP externa.

### Fase 6 — Cliente e federação de servidores MCP externos

- Implementar cliente MCP separado do servidor já existente, com lifecycle e cancelamento.
- Cadastrar servidores locais por fluxo guiado e importar configuração somente após preview.
- Descobrir tools, recursos e prompts com namespace estável e indicação clara de origem.
- Resolver colisões sem renomear silenciosamente e manter catálogo interno disponível em falhas.
- Aplicar allowlist, workspace boundary, consentimento, timeout, auditoria e sanitização.
- Isolar processos, segredos e configuração por servidor; suportar desabilitar e remover com segurança.
- Refletir saúde e próxima ação em Configurações, `/doctor` e `/status` sem exigir restart.

**Aceite:** um servidor fixture e um servidor real autorizado são descobertos, executam leitura e
mutação consentida, cancelam corretamente e não contornam nenhuma política do RadIA.

**Ainda faltará:** somente o gate integrado de encerramento.

### Fase 7 — Jornada integrada e encerramento do goal

Executar nas três combinações suportadas:

1. abrir dois projetos com configurações diferentes;
2. iniciar e retomar uma conversa CLI;
3. continuar a mesma jornada no terminal;
4. pedir completion FIM no editor;
5. revisar uma mudança multiarquivo por bloco no gutter;
6. chamar uma tool de MCP externo com consentimento;
7. compilar, testar, depurar e revisar as evidências;
8. reiniciar a IDE, retomar a jornada e encerrar sem processo órfão.

**Aceite:** evidência versionada para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64; builds,
testes Delphi, testes web, testes documentais e Sonar verdes; dez ciclos consecutivos de uso e
shutdown; documentação navegável validada contra UI, comandos e catálogo runtime.

**Ainda faltará:** nenhum dos seis pontos deste goal.

## Ordem, dependências e complexidade

| Ordem | Fase | Ponto principal | Complexidade | Dependência |
|---:|---|---|---|---|
| 1 | Fase 0 | Contratos | Média | Nenhuma |
| 2 | Fase 1 | Continuidade CLI | Alta | Fase 0 |
| 3 | Fase 2 | Contexto único | Alta | Fase 1 |
| 4 | Fase 3 | Configuração hierárquica | Alta | Fases 0–2 |
| 5 | Fase 4 | FIM | Alta | Fases 0 e 3 |
| 6 | Fase 5 | Gutter por bloco | Alta | Fases 2 e 4 |
| 7 | Fase 6 | MCP externo | Muito alta | Fases 0, 2 e 3 |
| 8 | Fase 7 | Gate integrado | Muito alta | Todas |

## Evidência obrigatória por etapa

Cada etapa fechada deve publicar:

- requisitos e contratos cobertos;
- arquivos e superfícies alterados;
- testes unitários, de integração e smokes executados;
- resultado do Sonar pela API/script oficial do projeto;
- evidência separada por target quando houver OTA ou UI;
- documentação e hints atualizados;
- resumo objetivo do que ainda falta para o goal;
- commit e push da branch de trabalho.

## Definição de conclusão

O goal não está concluído enquanto qualquer uma das seis lacunas estiver apenas prototipada,
documentada, disponível em um único executor ou validada em somente parte da matriz. A auditoria
final deve mapear cada requisito deste documento a código, teste, evidência runtime e documentação.
