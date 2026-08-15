# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

O backlog não registra versões, entregas concluídas, evidências ou planos internos.

## Goal ativo: experiência Delphi completa e determinística

Transformar objetivos comuns do programador Delphi em fluxos simples, seguros e verificáveis,
aproveitando as ferramentas existentes antes de ampliar o catálogo.

A ordem abaixo é obrigatória; itens de um marco podem ser desenvolvidos em paralelo somente quando
não compartilham contratos ou superfícies da IDE. Planos internos de engenharia permanecem
separados da documentação pública.

## Fundação transversal — testes automatizados de uso

- [ ] **Plataforma de integração e ponta a ponta:** automatizar instalação isolada, abertura do
  Delphi, configuração sanitizada, chat, tools, editor, Designer, build, testes, debugger, terminal,
  consentimento e recuperação de falhas nos alvos Delphi 12 e 13.

A plataforma deve possuir três camadas:

1. integração de serviços e adapters sem abrir a IDE;
2. integração OTA carregada em uma instância descartável do Delphi;
3. jornadas de usuário ponta a ponta com projetos-fixture, ações reais e evidências verificáveis.

Gate: uma execução limpa deve instalar o RadIA em ambiente isolado, abrir cada IDE suportada,
executar a matriz crítica, coletar logs, screenshots e resultados estruturados e restaurar o ambiente
sem depender de intervenção humana. Falhas precisam identificar etapa, versão da IDE e artefato de
diagnóstico, sem expor credenciais.

Esse gate integra obrigatoriamente toda release junto com a criação e teste funcional da calculadora
e com a criação, abertura e navegação imediata de projetos.

## Marco 2 — inteligência de código

- [ ] **Refatoração semântica segura:** entregar primeiro Rename Symbol e Find All References com
  preview, consistência Pascal/DFM, transação multiarquivo e rollback; expandir depois para
  hierarquias, Extract Method, Move Type e Change Signature.
- [ ] **Testes selecionados por impacto:** relacionar diff, símbolos, dependências, fixtures e
  cobertura para executar e justificar o menor conjunto seguro de testes DUnitX.

Gate: renomear um símbolo usado por várias units e pelo DFM, executar somente os testes afetados e
reverter toda a operação sem perda de código.

## Marco 3 — diagnóstico avançado

- [ ] **Debugger avançado:** breakpoints condicionais, hit count, exceções e logpoints, respeitando
  as capacidades efetivas do Delphi 12 e 13.
- [ ] **Automação de controles sem janela própria:** adicionar um adaptador VCL autorizado para
  `TGraphicControl`, frames e controles customizados sem usar coordenadas globais.
- [ ] **Diagnóstico de performance:** medir cenários, bloqueio da thread principal, CPU, memória e
  duração, comparando evidência anterior e posterior à correção.

Gate: reproduzir um problema condicionado, interagir com um controle sem `HWND` e comprovar uma
melhoria de desempenho em execuções comparáveis.

## Marco 4 — ecossistema Delphi

- [ ] **Assistente FireDAC e banco de dados:** inventariar conexões, queries, parâmetros,
  transações e datasets; operar em modo somente leitura por padrão.
- [ ] **Saúde de dependências Delphi:** detectar bibliotecas, packages, GetIt, Boss, paths e versões
  ausentes ou incompatíveis e produzir orientação acionável.
- [ ] **Auditoria de localização e recursos:** inventariar textos Pascal/DFM, preparar extração para
  `resourcestring` e verificar idiomas e layout visual.

Gate: diagnosticar uma aplicação de dados em uma máquina limpa e produzir correções revisáveis para
dependências, acesso a dados e localização.

## Definição de concluído

Cada item precisa de:

- contrato e ameaça documentados antes da implementação;
- suporte comprovado no Delphi 12 e 13, com capacidade indisponível reportada explicitamente;
- testes unitários, integração OTA e cenário ponta a ponta proporcional ao risco;
- cenário automatizado de uso incluído na matriz de regressão para cada comportamento novo;
- preview, consentimento, fingerprint e rollback para qualquer mutação;
- atualização simultânea do manual, referências, hints, traduções e testes documentais;
- build local, DUnitX, lint aplicável e SonarQube aprovados;
- evidência observável do resultado, não apenas existência de classes ou tools.
