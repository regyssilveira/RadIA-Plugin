# Plano de liderança técnica do RadIA 2.0

> **Estado:** planejado.
> **Escopo:** Delphi 12 Win32 e Delphi 13 Win32/IDE64.
> **Fora do escopo:** C++Builder, marketplace, assinatura Authenticode obrigatória e substituição do
> host WebView2 atual.

## Goal

Transformar a base híbrida já entregue em uma experiência contínua e comprovável: descobrir um
executor, autenticar, iniciar ou retomar uma conversa, usar o mesmo contexto no chat, terminal e
editor, revisar mudanças e concluir a jornada dentro da IDE.

O instalador continua sendo uma facilidade para um projeto aberto que também pode ser compilado
pelo usuário. A ausência de assinatura não bloqueia a versão 2.0. O canal deve publicar hash
SHA-256 e instruções reproduzíveis de build e instalação.

## Ideias aproveitadas da nova análise externa

A revisão de implementações atualizadas encontrou quatro ideias que trazem ganho real:

1. Capturar e persistir o identificador de conversa devolvido por cada CLI, permitindo continuar
   uma sessão em vez de reiniciá-la a cada mensagem.
2. Tratar gravações de configuração como transações para que duas telas ou serviços não apaguem
   campos um do outro.
3. Vincular pedidos de consentimento à execução e à sessão que os originaram, preservando ou
   cancelando o pedido de modo explícito quando o chat é fechado ou trocado.
4. Validar executores com contas reais em uma matriz ponta a ponta, incluindo streaming,
   cancelamento, retomada, MCP e encerramento.

A conclusão inline por CLI, o diagnóstico de instalação/autenticação, o Copilot CLI e o Ghost Text
já existem no RadIA. Esses itens entram somente no gate integrado, sem duplicação de implementação.

SQLite não é requisito inicial. A migração da persistência somente será considerada se medições
demonstrarem lentidão, crescimento excessivo ou necessidade de consultas que o armazenamento atual
não atende. O WebView2 permanece como está e não gera item futuro ou backlog.

## Plano de execução

### Fase 0 — Baseline e contratos

- Mapear o ciclo atual dos quatro executores: Codex, Claude, Gemini e GitHub Copilot.
- Definir um contrato comum de identidade de conversa, capacidade de retomada e diagnóstico.
- Registrar quais CLIs oferecem identificador estável e qual fallback seguro será usado.
- Criar testes de contrato para argumentos, parsing, timeout, cancelamento e saída parcial.

**Critério de aceite:** matriz de capacidades versionada, testes atuais verdes e Sonar sem issue
nova.

**Após a fase ainda faltará:** persistência real, compartilhamento entre superfícies, UX guiada e
prova autenticada.

### Fase 1 — Continuidade nativa por CLI

- Capturar o identificador de sessão ou conversa retornado por cada executor.
- Persistir executor, modelo, diretório de trabalho e identificador sem armazenar credenciais.
- Retomar a conversa quando o CLI suportar essa operação.
- Exibir claramente quando uma conversa foi retomada ou começou do zero.
- Impedir que uma resposta tardia seja anexada à sessão errada.

**Critério de aceite:** fechar e reabrir o painel, continuar uma conversa suportada e provar por
teste que mensagens não atravessam sessões.

**Após a fase ainda faltará:** contexto compartilhado entre chat, terminal e editor, configuração
transacional, consentimento de ciclo de vida e matriz real.

### Fase 2 — Contexto unificado no chat, terminal e editor

- Associar chat e terminal à mesma identidade de conversa quando o usuário escolher continuar.
- Permitir iniciar, escolher, retomar e desvincular uma sessão por botão e comando.
- Reutilizar a seleção de CLI, projeto, modelo e diagnóstico nas três superfícies.
- Manter ferramentas, MCP, consentimento, auditoria e workspace boundary sob a política do RadIA.
- Mostrar executor, estado de autenticação e estado da sessão sem abrir Configurações.

**Critério de aceite:** uma jornada inicia no chat, continua no terminal e solicita uma conclusão
no editor sem perder executor, projeto ou identidade de conversa.

**Após a fase ainda faltará:** hardening concorrente, consentimento resiliente e prova autenticada
nas IDEs suportadas.

### Fase 3 — Configuração e consentimento resilientes

- Centralizar atualização de configurações em operação de leitura, merge e gravação atômica.
- Testar dois escritores concorrentes e preservar campos desconhecidos.
- Vincular cada consentimento ao identificador da execução e da sessão.
- Definir comportamento determinístico para troca, fechamento e retomada do chat.
- Descartar cards, indicadores e callbacks obsoletos sem responder pelo usuário.

**Critério de aceite:** testes concorrentes não perdem configuração e nenhum consentimento fica
órfão, é aplicado à sessão errada ou recebe decisão implícita.

**Após a fase ainda faltará:** experiência CodeInsight avançada e validação autenticada completa.

### Fase 4 — Integração avançada com o editor

- Unificar a origem de contexto entre Ghost Text, ações contextuais, revisão inline e chat.
- Permitir navegar entre alternativas sem escrever no buffer antes do aceite.
- Mostrar origem, executor e estado da sugestão de forma acessível.
- Preservar atalhos configuráveis e devolver as teclas à IDE quando não houver sugestão válida.
- Cancelar sugestões obsoletas quando cursor, revisão ou buffer mudarem.

**Critério de aceite:** aceitar, rejeitar e alternar alternativas somente pelo teclado, com undo
único e sem alteração antecipada do buffer.

**Após a fase ainda faltará:** apenas a prova ponta a ponta e o fechamento dos gates da versão.

### Fase 5 — Matriz CLI autenticada e fechamento

Executar Codex, Claude, Gemini e GitHub Copilot nas três combinações suportadas:

- detecção, versão e orientação de autenticação;
- início e retomada de conversa;
- streaming e saída parcial;
- cancelamento, timeout e encerramento da árvore;
- chamada MCP somente leitura e mutação com consentimento;
- continuidade entre chat e terminal;
- conclusão inline e descarte de resposta obsoleta;
- fechamento da IDE sem processo órfão.

**Critério de aceite:** evidência versionada por CLI e target, build e testes verdes, Sonar verde e
dez ciclos consecutivos de instalação, uso, docking e encerramento.

**Após a fase ainda faltará:** nenhum item técnico obrigatório deste goal.

## Ordem e complexidade

| Ordem | Fase | Complexidade | Dependência |
|---:|---|---|---|
| 1 | Baseline e contratos | Baixa | Nenhuma |
| 2 | Continuidade nativa por CLI | Alta | Fase 0 |
| 3 | Contexto unificado | Alta | Fase 1 |
| 4 | Configuração e consentimento | Média | Fases 0 e 1 |
| 5 | Integração avançada com editor | Alta | Fases 2 e 3 |
| 6 | Matriz autenticada | Alta | Todas |

## Regras permanentes

- Consultar o Sonar em cada rodada e não aceitar issue nova.
- Commitar e enviar cada etapa fechada pela branch de trabalho.
- Informar ao final de cada etapa o que foi concluído, a evidência e o que ainda falta para o goal.
- Não ampliar o escopo para C++Builder, marketplace ou um novo host WebView2.
- Não bloquear a publicação por ausência de certificado de assinatura de código.
