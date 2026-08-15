# Goal de experiência e produtividade Delphi

## Objetivo

Permitir que um programador com conhecimento mínimo do RadIA descreva um objetivo comum em linguagem
natural e obtenha execução segura, progresso legível e evidência verificável no Delphi 12 e 13.

## Resultado observável

Ao final, o RadIA deve conduzir criação, compreensão, refatoração, build, testes, depuração,
performance, acesso a dados, dependências e localização sem exigir conhecimento de modos, jornadas
ou ferramentas internas.

## Estratégia

1. Reutilizar contratos atuais de tools, consentimento, transações, fingerprints e rollback.
2. Entregar fatias verticais demonstráveis, não infraestrutura isolada.
3. Tratar diferenças entre Delphi 12 e 13 como capacidades detectadas em runtime.
4. Manter o WebView atual e evoluir somente contratos e componentes necessários.
5. Não reservar versão antes de um marco possuir build, testes e documentação aprovados.

## Fundação transversal — automação de testes de uso

A cobertura integral será construída como uma matriz de capacidades, não como um único teste frágil
que controla toda a IDE. Cada cenário declara versão do Delphi, superfície, pré-condições, ações,
evidências e limpeza.

### Camada A — integração headless

- Exercitar contratos de providers, tools, consentimento, transações e adapters com doubles
  determinísticos.
- Executar sem Delphi e falhar rapidamente em regressões de contrato.

### Camada B — integração OTA

- Iniciar uma instância descartável do Delphi 12 ou 13 com perfil de Registro isolado quando a OTA
  permitir.
- Instalar o package produzido localmente, abrir projetos-fixture e acionar comandos reais da IDE.
- Consultar o estado por um canal de teste autenticado, compilado somente no harness.

### Camada C — jornadas ponta a ponta

- Automatizar instalação, onboarding, chat, consentimento e ações nas superfícies visuais.
- Validar criação de projeto, edição, Designer, build, DUnitX, debugger, runtime, terminal e
  recuperação de falhas.
- Coletar screenshot, log sanitizado, eventos, arquivos produzidos e resultado funcional.

### Isolamento e estabilidade

- Usar workspace, configuração, cache, credenciais falsas e projetos temporários por execução.
- Separar cenários offline determinísticos de smoke tests opcionais que exigem provider real.
- Proibir dependência de coordenadas absolutas, sleeps fixos ou estado pessoal da IDE.
- Encerrar processos filhos e restaurar Registro, arquivos e packages mesmo após timeout.
- Classificar testes em `smoke`, `critical`, `extended` e `provider-live`.

### Primeira matriz crítica

1. instalar e carregar o RadIA no Delphi 12 e 13;
2. abrir chat, executar `/doctor` e validar o diagnóstico sem provider;
3. configurar provider simulado e obter resposta streaming;
4. criar, abrir e compilar uma calculadora VCL;
5. executar DUnitX e interpretar uma falha controlada;
6. preparar, consentir, aplicar e reverter uma alteração;
7. iniciar o debugger, parar em breakpoint e consultar stack;
8. abrir terminal, executar comando e encerrar sessão;
9. fechar a IDE sem deadlock, AV ou processos órfãos.

Cada melhoria deste goal só termina quando adicionar ou atualizar um cenário nessa matriz.

## Marcos e dependências

### M1 — experiência universal

1. Definir taxonomia pequena de intenções e níveis de confiança.
2. Criar roteador determinístico com fallback explícito e telemetria somente local.
3. Unificar o modelo de achados das superfícies já existentes.
4. Entregar painel de problemas com filtros, navegação e ações seguras.
5. Validar prompts de criação, build, testes e diagnóstico com usuários iniciantes.

Dependências: jornadas, Agent Runtime, Tool Registry, Tool Views e Project Health.

### M2 — inteligência de código

1. Estender o índice com identidades e referências de símbolos.
2. Entregar Find All References somente leitura.
3. Entregar Rename Symbol transacional para Pascal e DFM.
4. Construir grafo de impacto entre diff, símbolos e testes DUnitX.
5. Selecionar, executar e explicar testes afetados.
6. Expandir refatorações somente após a base atingir os gates.

Dependências: Semantic Engine, DFM/PAS Audit, MultiFilePatch, DevelopmentTransaction, DUnitX e
Coverage.

### M3 — diagnóstico avançado

1. Criar matriz real das capacidades OTA de breakpoint por versão da IDE.
2. Entregar condições, hit count, exceções e logpoints somente onde forem confiáveis.
3. Projetar canal autenticado e limitado para o adaptador VCL no processo depurado.
4. Automatizar controles sem janela própria por identidade de componente.
5. Definir baseline e métricas limitadas de performance.
6. Comparar evidências antes e depois usando cenários versionados.

Dependências: Debugger, RuntimeScenario, RuntimeEvidence, VisualRuntimeSession e consentimento.

### M4 — ecossistema Delphi

1. Definir inventários somente leitura para FireDAC, dependências e localização.
2. Entregar diagnóstico de dependências antes de qualquer automação de instalação.
3. Entregar análise FireDAC sem armazenar credenciais ou executar SQL mutável por padrão.
4. Preparar extração transacional de textos para `resourcestring`.
5. Comparar layouts entre idiomas com snapshots existentes.

Dependências: DelphiEnvironment, ProjectKnowledge, DesignerVisualDiff e DevelopmentTransaction.

## Gates transversais

- Contrato de segurança e capacidade antes de cada adaptador OTA ou runtime.
- Nenhuma mutação sem preview, consentimento, fingerprint e reversão.
- Testes unitários, integração OTA e ponta a ponta no Delphi 12 e 13.
- Build Win32 e IDE64 quando aplicável.
- Documentação pt-BR/en-US, hints e testes documentais na mesma entrega.
- SonarQube aprovado, sem supressões.

## Primeira fatia executável

Implementar o roteador de intenção em modo de recomendação, sem execução automática. Ele deve
classificar prompts de criação, build, testes e diagnóstico, explicar a rota escolhida e permitir
confirmar, revisar ou manter o chat comum. Essa fatia valida a experiência antes de ampliar poder de
mutação.
