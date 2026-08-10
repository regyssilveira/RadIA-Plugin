# Documentação do RadIA

Este é o ponto de entrada da documentação do RadIA 2.4.1. Escolha primeiro o que você deseja
fazer; cada assunto tem um guia principal para evitar informações duplicadas ou contraditórias.

> A referência mais precisa da instalação atual é o comando `/tools`, pois o catálogo pode variar
> conforme IDE, contexto e extensões instaladas.

## Quero começar a usar

| Objetivo | Comece por | Depois consulte |
|---|---|---|
| Instalar no Delphi 12 ou 13 | [Instalação e configuração](install_config.md) | [Primeiros passos](onboarding.md) |
| Conhecer tudo que está disponível | [Mapa de capacidades](capabilities.md) | [Manual do usuário](user_manual.md) |
| Configurar provider, agente ou CLI | [Instalação e configuração](install_config.md) | [Executores nativo e CLI](cli_executors.md) |
| Usar configurações diferentes por projeto ou conversa | [Configurações por escopo](hierarchical_settings.md) | [Comandos de barra](slash_commands.md) |
| Entender cada aba de configurações | [Mapa das configurações](user_manual.md#24-mapa-das-configurações) | [Modelo de segurança](tool_security_model.md) |
| Consultar um campo ou botão específico | [Referência completa das configurações](settings_reference.md) | [Solução de problemas](troubleshooting_agentic_platform.md) |
| Usar o chat no dia a dia | [Chat e sessões](user_guide_chat_sessions.md) | [Comandos de barra](slash_commands.md) |
| Continuar uma tarefa entre chat, terminal e editor | [Contexto compartilhado](shared_journey_context.md) | [Chat e sessões](user_guide_chat_sessions.md) |
| Resolver um problema | [Solução de problemas](troubleshooting_agentic_platform.md) | [Diagnóstico da instalação](capabilities.md#diagnóstico-da-instalação) |

## Quero realizar uma tarefa

| Tarefa | Guia principal |
|---|---|
| Explicar, revisar, refatorar ou gerar código | [Editor e geração](user_guide_editor_generation.md) |
| Diagnosticar código, warnings, SQL ou stack trace | [Diagnóstico e análise](user_guide_diagnostics_analysis.md) |
| Receber e diagnosticar sugestões Ghost Text/FIM | [Assistência inline e FIM](inline_completion.md) |
| Revisar alterações por bloco no gutter | [Revisão por bloco](block_reviews.md) |
| Criar um projeto Delphi | [New Project Wizard](project_wizard.md) |
| Adicionar ou remover units e forms | [Operações estruturais](project_file_operations.md) |
| Coordenar alterações de código, projeto e Designer | [Transações de desenvolvimento](development_transactions.md) |
| Compilar, corrigir erros e executar testes | [Jornadas ponta a ponta](user_guide_journeys.md) |
| Criar um servidor DEXT a partir de endpoints | [Jornadas de servidores DEXT](user_guide_dext_journeys.md) |
| Executar e interpretar testes DUnitX | [Runner DUnitX](dunitx_runner.md) |
| Trabalhar com Form Designer ou debugger | [Designer e debugger](user_guide_designer_debugger.md) |
| Reproduzir uma falha visual automaticamente | [Diagnóstico runtime](runtime_debug_automation.md) |
| Diagnosticar vazamentos com FastMM5 | [Diagnóstico de memória](fastmm5_diagnostic_session.md) |
| Usar o terminal integrado | [Terminal](terminal.md) |
| Pesquisar no conhecimento local do projeto | [Conhecimento do projeto](user_guide_project_knowledge.md) |
| Revisar e criar um commit Git local | [Fluxo Git](git_workflow.md) |

## Agente, ferramentas e segurança

| Assunto | Documento autoritativo |
|---|---|
| Ativar e operar o modo agente | [Manual do usuário](user_manual.md#3-como-ativar-o-modo-agente) |
| Entender o agente nativo e executores externos | [Executores nativo e CLI](cli_executors.md) |
| Consultar capacidades e retomada dos CLIs | [Matriz contratual dos CLIs](cli_capability_matrix.md) |
| Diagnosticar a instalação e a rota efetiva | [RadIA Doctor](doctor.md) |
| Ver o estado configurado do RadIA | [Doctor, status, health e tools](slash_commands.md#qual-diagnóstico-usar) |
| Entender valor efetivo, origem e herança | [Configurações por projeto, sessão e solicitação](hierarchical_settings.md) |
| Ver todas as ferramentas disponíveis | [Catálogo das 132 ferramentas](runtime_tool_catalog.md) |
| Entender cada ferramenta e quando ela é acionada | [Referência operacional](internal_tools_reference.md) |
| Entender consentimento, riscos e auditoria | [Modelo de segurança](tool_security_model.md) |
| Consultar custos e limites do agente | [Custos do agente](agent_pricing.md) |
| Planejar a evolução do compactador interno | [Plano de execução do RTK](rtk_execution_plan.md) |
| Usar e diagnosticar o RTK interno | [Compactação e recuperação de resultados](agent_result_compaction.md) |
| Revisar a release 2.4.1 | [Notas de release](release_notes_2.4.1.md) |
| Revisar a release 2.4.0 | [Notas de release](release_notes_2.4.0.md) |
| Revisar a versão 2.3.1 | [Notas de release](release_notes_2.3.1.md) |
| Revisar o RTK da 2.3.0 | [Notas de release](release_notes_2.3.0.md) e [auditoria](result_compaction_release_audit_2.3.0.md) |
| Usar as ferramentas por outro cliente | [Integração MCP](mcp_integration_guide.md) |

MCP, executor CLI e provider são configurações independentes. A exceção é um método de
autenticação que declare uma CLI como transporte, como o login ChatGPT via Codex. Consulte a
[matriz de executores](cli_executors.md) antes de diagnosticar dependências de CLI.

## Extender e integrar

| Objetivo | Guia |
|---|---|
| Compartilhar comandos, skills, conhecimento, templates, aliases e workflows | [Extensões declarativas](declarative_extensions.md) |
| Publicar uma skill nos CLIs suportados | [Portabilidade de skills](skill_portability.md) |
| Registrar tools por package | [API de extensões](tool_extension_guide.md) |
| Adicionar um provider | [Guia de providers](new_provider_guide.md) |
| Integrar um cliente MCP | [Integração MCP](mcp_integration_guide.md) |
| Consultar contratos futuros de tools | [Catálogo arquitetural](tool_catalog.md) |

O [catálogo arquitetural](tool_catalog.md) inclui contratos e propostas. Para saber o que existe na
versão instalada, use `/tools` ou o [catálogo gerado](runtime_tool_catalog.md).

## Desenvolver e contribuir

- [Política obrigatória de documentação](documentation_policy.md)

| Assunto | Documento |
|---|---|
| Arquitetura geral | [Guia de arquitetura](architecture_guide.md) |
| Arquitetura agentiva | [Arquitetura do agente](agentic_architecture.md) |
| Mapa das units e responsabilidades | [Guia do código-fonte](source_code_guide.md) |
| Compatibilidade suportada | [Matriz Delphi](delphi_compatibility_matrix.md) |
| Build e testes | [Instalação e configuração](install_config.md) |
| Convenções de branch e commit | [Branches](branch_convention.md) · [Commits](commit_convention.md) |
| Processo de release | [Release](release_process.md) |
| Privacidade e licenças | [Compliance](compliance.md) |

## Planejamento e histórico

Estes documentos registram decisões, versões e execução do projeto; não são manuais de uso nem
descrevem necessariamente o comportamento atual:

- [Roadmap](roadmap.md) e [backlog](backlog.md);
- [goal concluído das seis lacunas de experiência](competitive_leadership_plan.md);
- [goal concluído de expansão da experiência completa](experience_expansion_goal.md);
- [goal concluído de portabilidade de skills e terminal](terminal_skill_portability_goal.md);
- [auditoria da release 2.4.1](release_audit_2.4.1.md) e auditorias anteriores;
- [goal da jornada 2.0](radia_2_goal.md) e [goal de experiência 2.0](experience_leadership_goal.md);
- [planos e marcos do diagnóstico runtime](runtime_debug_automation_plan.md);
- [planos e marcos do diagnóstico de memória](fastmm5_memory_diagnostics_plan.md);
- [auditoria de ideias do Free Claude Code aplicáveis ao RadIA](research/free-claude-code-radia-analysis.md);
- arquivos `*_evidence_*.json`, que são evidências imutáveis de releases anteriores.

Se uma informação histórica divergir de um guia principal, prevalecem o código da versão atual,
o catálogo retornado por `/tools` e os documentos listados nas seções anteriores.

## Compatibilidade atual

| IDE | Arquitetura | Suporte |
|---|---|---|
| Delphi 12 Athens | Win32 | Suportado e validado |
| Delphi 13 | Win32 | Suportado e validado |
| Delphi 13 | IDE64 | Suportado e validado |

Delphi 11 aparece apenas em registros históricos e não integra a matriz atual.

Documentação em inglês: [Documentation hub](README.en.md).
