# Documentação do RadIA

Este é o ponto de entrada da documentação do RadIA 2.2.1. Escolha primeiro o que você deseja
fazer; cada assunto tem um guia principal para evitar informações duplicadas ou contraditórias.

> A referência mais precisa da instalação atual é o comando `/tools`, pois o catálogo pode variar
> conforme IDE, contexto e extensões instaladas.

## Quero começar a usar

| Objetivo | Comece por | Depois consulte |
|---|---|---|
| Instalar no Delphi 12 ou 13 | [Instalação e configuração](install_config.md) | [Primeiros passos](onboarding.md) |
| Conhecer tudo que está disponível | [Mapa de capacidades](capabilities.md) | [Manual do usuário](user_manual.md) |
| Configurar provider, agente ou CLI | [Instalação e configuração](install_config.md) | [Executores nativo e CLI](cli_executors.md) |
| Entender cada aba de configurações | [Mapa das configurações](user_manual.md#24-mapa-das-configurações) | [Modelo de segurança](tool_security_model.md) |
| Consultar um campo ou botão específico | [Referência completa das configurações](settings_reference.md) | [Solução de problemas](troubleshooting_agentic_platform.md) |
| Usar o chat no dia a dia | [Chat e sessões](user_guide_chat_sessions.md) | [Comandos de barra](slash_commands.md) |
| Resolver um problema | [Solução de problemas](troubleshooting_agentic_platform.md) | [Diagnóstico da instalação](capabilities.md#diagnóstico-da-instalação) |

## Quero realizar uma tarefa

| Tarefa | Guia principal |
|---|---|
| Explicar, revisar, refatorar ou gerar código | [Editor e geração](user_guide_editor_generation.md) |
| Criar um projeto Delphi | [New Project Wizard](project_wizard.md) |
| Adicionar ou remover units e forms | [Operações estruturais](project_file_operations.md) |
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
| Ver o estado configurado do RadIA | [Doctor, status, health e tools](slash_commands.md#qual-diagnóstico-usar) |
| Ver todas as ferramentas disponíveis | [Catálogo das 124 ferramentas](runtime_tool_catalog.md) |
| Entender cada ferramenta e quando ela é acionada | [Referência operacional](internal_tools_reference.md) |
| Entender consentimento, riscos e auditoria | [Modelo de segurança](tool_security_model.md) |
| Consultar custos e limites do agente | [Custos do agente](agent_pricing.md) |
| Usar as ferramentas por outro cliente | [Integração MCP](mcp_integration_guide.md) |

MCP, executor CLI e provider são configurações independentes. A exceção é um método de
autenticação que declare uma CLI como transporte, como o login ChatGPT via Codex. Consulte a
[matriz de executores](cli_executors.md) antes de diagnosticar dependências de CLI.

## Extender e integrar

| Objetivo | Guia |
|---|---|
| Criar comandos, aliases e workflows declarativos | [Extensões declarativas](declarative_extensions.md) |
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
- [auditorias de release](release_audit_2.2.0.md);
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
