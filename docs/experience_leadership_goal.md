# Goal RadIA 2.0: liderança da experiência Delphi

> **Estado:** planejado e em execução.
> **Versão alvo:** 2.0.0, ainda não publicada.

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
6. Preservar Delphi 11, 12, 13 Win32 e Delphi 13 IDE64.
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

## Marcos

### M0 — Qualidade bloqueante

- Resolver os bugs e code smells ativos do Sonar pela causa raiz.
- Separar claramente baseline, código novo e dívida aceita no dashboard.
- Tornar lint, catálogo, matriz, integridade dos pacotes e Sonar gates automatizados.
- Rejeitar a preparação de release quando qualquer gate obrigatório falhar.

**Saída:** baseline global verde e pipeline local reproduzível.

### M1 — Assistência inline e Ghost Text

- Criar um motor desacoplado de sugestões Fill-in-the-Middle.
- Capturar prefixo, sufixo, linguagem, símbolo e contexto limitado do projeto.
- Aplicar debounce, cancelamento de requisição anterior, cache e limite de contexto.
- Suportar providers remotos e modelos locais sem enviar contexto ocultamente.
- Renderizar Ghost Text sem alterar o buffer antes do aceite.
- Oferecer aceitar tudo, aceitar próxima palavra, rejeitar e solicitar alternativa.
- Desabilitar por projeto, arquivo, linguagem ou sessão.

**Saída:** sugestões contínuas, rápidas e reversíveis no editor Delphi.

### M2 — Terminal interativo de primeira classe

- Substituir o executor de comando por uma camada de pseudo terminal compatível com Windows.
- Interpretar ANSI, cores, cursor, resize e entrada contínua.
- Manter múltiplas sessões, abas, perfis e diretórios por projeto.
- Oferecer histórico navegável, busca reversa, snippets e paleta de comandos.
- Conectar agentes iniciados no terminal ao mesmo MCP, consentimento, diff e auditoria do chat.
- Encerrar toda a árvore de processos sem bloquear o shutdown da IDE.

**Saída:** terminal completo, acoplável e adequado ao uso diário.

### M3 — Central unificada de execução

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

**Saída:** uma capacidade simples pode ser adicionada sem recompilar o RadIA ou reiniciar a IDE.

### M5 — Conhecimento semântico privado

- Manter a busca lexical atual como fallback determinístico.
- Adicionar embeddings opcionais e armazenamento vetorial local.
- Permitir provider local ou remoto com consentimento explícito e exclusões configuráveis.
- Indexar incrementalmente código, DFM/FMX, projetos, documentação, símbolos e histórico aprovado.
- Explicar a origem de cada trecho recuperado e permitir abrir o arquivo correspondente.
- Medir relevância, latência, tamanho, reconstrução e isolamento entre workspaces.

**Saída:** contexto relevante de grandes soluções sem perder privacidade ou rastreabilidade.

### M6 — Instalação e primeiro valor

- Criar instalador visual assinado e preparar um canal compatível com o gerenciador da IDE.
- Detectar Delphi, arquitetura, WebView2, CLIs, autenticação e configurações incompatíveis.
- Manter CLIs de terceiros fora do pacote e delegar instalação aos canais oficiais com consentimento.
- Guiar login sem capturar tokens ou credenciais.
- Executar diagnóstico pós-instalação de chat, provider, terminal, MCP e primeira tool.
- Oferecer reparação e desinstalação completas, preservando dados escolhidos pelo usuário.

**Saída:** da instalação à primeira alteração revisada sem configuração manual de arquivos.

### M7 — Jornadas especializadas

- Entregar receitas auditáveis para criar aplicação, corrigir build, ampliar testes e depurar.
- Adicionar modernização orientada a Delphi, incluindo units, forms, packages e dependências.
- Integrar migração segura de padrões legados com preview e gates de compilação.
- Criar painel de saúde do projeto com riscos, testes, dívida e sugestões priorizadas.
- Permitir compartilhar receitas e políticas entre equipes sem compartilhar credenciais.

**Saída:** o RadIA resolve fluxos completos de Delphi, não apenas solicitações isoladas.

### M8 — Prova de liderança e release

- Executar a matriz completa de build e 100% dos testes.
- Validar Ghost Text, terminal, central, extensões e conhecimento em IDE real.
- Executar dez ciclos de instalação, uso, atualização e shutdown por combinação suportada.
- Aprovar a jornada contínua: criar, editar, desenhar, testar, depurar, corrigir e commitar.
- Regenerar os quatro pacotes do mesmo commit e publicar hashes independentes.
- Realizar auditoria final de segurança, privacidade, acessibilidade e documentação.

**Saída:** candidato 2.0.0 comprovado, reproduzível e pronto para decisão de publicação.

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
- A jornada completa é aprovada no Delphi 11, 12, 13 Win32 e Delphi 13 IDE64.
