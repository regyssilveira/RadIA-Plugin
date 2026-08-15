# Documentação do RadIA

Este é o ponto de entrada da documentação do RadIA. Escolha o objetivo; os documentos são
organizados por tarefa, e não por versão.

As pastas separam primeiros passos, guias de uso, referências, desenvolvimento e direção do
projeto. Planos internos, auditorias, resultados de testes e notas de versão não pertencem a esta
árvore.

> Para saber exatamente quais ferramentas estão disponíveis na instalação atual, use `/tools`.
> Para verificar configuração e pré-requisitos, use `/doctor --deep`.

## Começar

[Abra o roteiro de primeiros passos](getting-started/README.md).

| Objetivo | Documento |
|---|---|
| Instalar no Delphi 12 ou 13 | [Instalação e configuração](getting-started/install_config.md) |
| Fazer a primeira configuração | [Primeiros passos](getting-started/onboarding.md) |
| Usar o instalador visual | [Instalador visual](getting-started/visual_installer.md) |

## Usar o RadIA

[Veja todos os guias de uso](guides/README.md).

| Quero... | Documento |
|---|---|
| Entender modos, chat, agente e consentimento | [Manual do usuário](guides/user_manual.md) |
| Entender precedência por solicitação, sessão e projeto | [Configurações por escopo](guides/hierarchical_settings.md) |
| Criar, editar, compilar e testar projetos | [Jornadas ponta a ponta](guides/user_guide_journeys.md) |
| Executar somente testes DUnitX afetados | [Testes por impacto](guides/impact_based_tests.md) |
| Criar um projeto pelo chat | [New Project Wizard](guides/project_wizard.md) |
| Usar chat e sessões | [Chat e sessões](guides/user_guide_chat_sessions.md) |
| Usar o editor e gerar código | [Editor e geração](guides/user_guide_editor_generation.md) |
| Trabalhar com Designer e debugger | [Designer e debugger](guides/user_guide_designer_debugger.md) |
| Diagnosticar problemas e stack traces | [Diagnóstico e análise](guides/user_guide_diagnostics_analysis.md) |
| Reunir e navegar pelos achados das ferramentas | [Painel de problemas](reference/problems_panel.md) |
| Reproduzir falhas em execução | [Automação de diagnóstico runtime](guides/runtime_debug_automation.md) |
| Diagnosticar vazamentos com FastMM5 | [Diagnóstico de memória](guides/fastmm5_diagnostic_session.md) |
| Usar o terminal integrado | [Terminal](guides/terminal.md) |
| Configurar e usar CLI | [Executores nativo e CLI](guides/cli_executors.md) |
| Configurar e usar MCP | [Integração MCP](guides/mcp_integration_guide.md) |
| Resolver um problema de instalação ou uso | [Solução de problemas](guides/troubleshooting_agentic_platform.md) |

## Consultar

[Abra o índice completo de referências](reference/README.md).

| Informação | Referência |
|---|---|
| Tudo que o RadIA pode fazer | [Mapa de capacidades](reference/capabilities.md) |
| Consultar cada recurso, sua categoria e seu status | [Inventário detalhado](reference/features.md) |
| Campos e botões de configuração | [Configurações](reference/settings_reference.md) |
| Entender as abas de configuração | [Mapa das configurações](guides/user_manual.md#24-mapa-das-configurações) |
| Comandos de barra e diagnóstico | [Comandos](reference/slash_commands.md#qual-diagnóstico-usar) |
| Estado e diagnóstico completo | [Doctor](reference/doctor.md) |
| Achados de build, testes, memória e revisão | [Painel de problemas](reference/problems_panel.md) |
| Ferramentas disponíveis e quando são usadas | [Ferramentas internas](reference/internal_tools_reference.md) |
| Catálogo gerado da versão atual | [Catálogo runtime](reference/runtime_tool_catalog.md) |
| Compatibilidade Delphi | [Matriz de compatibilidade](reference/delphi_compatibility_matrix.md) |
| Providers, modelos e rotas CLI | [Matriz de capacidades CLI](reference/cli_capability_matrix.md) |
| Segurança e consentimento | [Modelo de segurança](reference/tool_security_model.md) |

## Desenvolver e contribuir

[Abra o índice de desenvolvimento](development/README.md).

| Assunto | Documento |
|---|---|
| Arquitetura | [Guia de arquitetura](development/architecture_guide.md) |
| Units e responsabilidades | [Guia do código-fonte](development/source_code_guide.md) |
| Build, testes e contribuição | [Instalação e configuração](getting-started/install_config.md) |
| Criar providers | [Guia de providers](development/new_provider_guide.md) |
| Criar extensões de ferramentas | [API de extensões](development/tool_extension_guide.md) |
| Convenções | [Branches](development/branch_convention.md) · [Commits](development/commit_convention.md) |
| Trabalhar com Git | [Fluxo Git](guides/git_workflow.md) |
| Política de documentação | [Documentação como produto](development/documentation_policy.md) |
| Processo de release | [Release](development/release_process.md) |

## Direção do projeto

- [Índice de direção do projeto](project/README.md).
- [Roadmap](project/roadmap.md): direção e resultados futuros.
- [Backlog](project/backlog.md): somente trabalho aberto e verificável.

Notas de versão, downloads e evidências de publicação ficam no
[GitHub Releases](https://github.com/regyssilveira/RadIA-Plugin/releases). O histórico removido desta
árvore continua disponível no histórico Git.

Documentação em inglês: [Documentation hub](README.en.md).
