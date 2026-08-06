# Estratégia Delphi 12/13 e Liderança de Experiência

## Decisão de produto

A partir da linha 2.0, o RadIA é desenvolvido, validado e distribuído para:

- Delphi 12 com IDE Win32;
- Delphi 13 com IDE Win32;
- Delphi 13 com IDE64.

Delphi 11 deixa de receber novos pacotes, correções, testes de regressão e suporte operacional.
Evidências antigas permanecem no repositório apenas como histórico e não representam a matriz
vigente.

Essa decisão permite aprofundar a integração com editor, Form Designer, debugger, terminal e Open
Tools API, preservando uma base instalada relevante sem carregar a geração mais antiga.

## Objetivo

Entregar a experiência de desenvolvimento Delphi mais completa: iniciar um projeto, gerar e
revisar código, desenhar formulários, compilar, testar, depurar, operar o terminal e concluir a
jornada Git sem sair do contexto controlado pelo RadIA.

## Princípios

1. Uma intenção do usuário deve produzir uma jornada compreensível, revisável e reversível.
2. Chat, terminal, MCP e modo agente devem compartilhar ferramentas, consentimento e auditoria.
3. Operações sobre código e Designer devem apresentar preview antes da mutação.
4. Cada automação deve possuir evidência observável de resultado.
5. Recursos externos devem ser detectados e configurados sem capturar credenciais.
6. Novas capacidades devem passar no Delphi 12 Win32, Delphi 13 Win32 e IDE64 antes de serem
   consideradas prontas.

## Plano de execução

### Fase 0 — Consolidar Delphi 12/13 como plataforma

- Remover Delphi 11 dos parâmetros aceitos pelo build.
- Produzir pacotes Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
- Remover targets antigos do instalador, CI e geradores de evidência.
- Atualizar requisitos, onboarding, matriz de compatibilidade e release.
- Preservar evidências antigas com marcação explícita de histórico.
- Criar um gate que rejeite novos targets ativos diferentes de BDS 23.0 e BDS 37.0.

**Critério de conclusão:** build, testes, instalador e release rejeitam BDS 22.0 e aceitam somente
BDS 23.0 e BDS 37.0 nas arquiteturas suportadas.

### Fase 1 — Templates e criação de projetos

- Consolidar templates para Console, VCL, FMX, Library, Package e DUnitX.
- Adicionar serviços Windows e aplicações multicamadas.
- Mostrar arquivos, plataformas e dependências antes da criação.
- Criar o projeto em transação reversível.
- Abrir o projeto, compilar e apresentar a primeira ação recomendada.
- Permitir templates declarativos instalados pelo catálogo.

**Critério de conclusão:** um usuário cria, abre, compila e executa cada tipo de projeto suportado
sem editar arquivos manualmente.

### Fase 2 — CLI Manager

- Detectar Codex, Claude, Gemini, GitHub Copilot e executores locais.
- Exibir instalação, versão, autenticação, disponibilidade e atualização.
- Direcionar instalações aos canais oficiais mediante consentimento.
- Provisionar MCP e validar o handshake automaticamente.
- Permitir escolher API, CLI ou modelo local por sessão e por projeto.
- Criar diagnóstico e reparo para configurações inconsistentes.

**Critério de conclusão:** cada executor pode ser preparado e validado pela interface, sem edição
manual de JSON, TOML ou variáveis globais.

### Fase 3 — Addon Studio

- Criar assistentes para commands, skills, aliases, workflows e journeys.
- Validar schema, permissões, riscos, limites e assinatura em tempo real.
- Oferecer execução isolada de teste e inspeção da auditoria.
- Empacotar, instalar e atualizar pelo gerenciador visual.
- Publicar SDK, exemplos e diagnóstico de compatibilidade.

**Critério de conclusão:** uma extensão funcional pode ser criada, testada e instalada sem
recompilar a BPL.

### Fase 4 — Jornada unificada Code/Design

- Transformar pedidos de interface em um plano visual.
- Apresentar preview de componentes, propriedades, eventos e arquivos.
- Aplicar mudanças no Designer vivo e no editor dentro da mesma transação.
- Navegar automaticamente entre Design e Code conforme a etapa.
- Incorporar build, testes, execução e debug à timeline.
- Permitir rejeição e reversão por etapa.

**Critério de conclusão:** a criação de uma tela completa percorre Designer, código, build e
execução em uma única jornada auditada.

### Fase 5 — Terminal 2.0

- Adicionar múltiplas sessões e abas.
- Criar perfis para PowerShell, CMD, Git Bash e CLIs de IA.
- Entregar busca, histórico, snippets e paleta de comandos.
- Tornar todos os atalhos configuráveis.
- Compartilhar diretório, contexto do projeto, MCP e consentimento com o chat.
- Garantir resize, ANSI, Unicode e encerramento completo da árvore de processos.

**Critério de conclusão:** o terminal integrado atende ao uso diário sem exigir uma janela externa.

### Fase 6 — Revisão inline

- Mostrar alterações pequenas diretamente no editor sem modificar o buffer.
- Permitir aceitar ou rejeitar cada bloco por teclado ou mouse.
- Reposicionar marcadores após rolagem e edição concorrente.
- Invalidar previews quando o hash-base mudar.
- Encaminhar mudanças grandes ou multiarquivo ao Smart Diff.
- Validar estabilidade, acessibilidade e desempenho no Delphi 12 Win32 e Delphi 13 Win32/IDE64.

**Critério de conclusão:** alterações pequenas são revisadas no editor e alterações complexas
continuam protegidas pelo Smart Diff.

### Fase 7 — Prova de liderança

- Medir tempo da instalação até a primeira alteração revisada.
- Executar jornadas completas no Delphi 12 Win32 e Delphi 13 Win32/IDE64.
- Validar teclado, leitor de tela, temas e escalas de DPI.
- Executar ciclos repetidos de instalação, reparo, upgrade, uso e shutdown.
- Publicar hashes e evidências reproduzíveis dos dois pacotes.
- Manter Sonar, lint, testes e auditorias sem regressão.

**Critério de conclusão:** todas as jornadas críticas possuem evidência automatizada e aprovação em
IDE real nos três targets.

## Ordem por complexidade

1. Templates e criação de projetos.
2. CLI Manager.
3. Addon Studio.
4. Jornada unificada Code/Design.
5. Terminal 2.0.
6. Revisão inline.

As três primeiras fases ampliam rapidamente o primeiro valor. As três últimas concentram o maior
risco de integração com a IDE e devem reutilizar consentimento, transações e auditoria já
consolidados.

## Indicadores

| Indicador | Meta |
| :--- | :--- |
| Targets ativos | Delphi 12 Win32 e Delphi 13 Win32/IDE64 |
| Configuração manual para executores | Zero arquivos obrigatórios |
| Criação de projeto até primeiro build | Uma jornada guiada |
| Mutação sem preview ou consentimento | Zero |
| Processo órfão após shutdown | Zero |
| Ferramentas fora da política central | Zero |
| Quality Gate | Aprovado |
| Testes das jornadas críticas | 100% aprovados |
