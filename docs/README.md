# Centro de documentação do RadIA

Este índice reúne a documentação funcional, operacional e técnica do RadIA 2.0.

## Comece aqui

1. [Tudo que o RadIA pode fazer](capabilities.md)
2. [Manual completo do usuário](user_manual.md)
3. [Instalação e configuração](install_config.md)
4. [Onboarding guiado](onboarding.md)
5. [Recursos e funcionalidades](features.md)
6. [Solução de problemas](troubleshooting_agentic_platform.md)

## Uso diário

| Tema | Documento |
|---|---|
| Chat, sessões, histórico e templates | [Chat e sessões](user_guide_chat_sessions.md) |
| Editor, Smart Diff e geração | [Editor e geração](user_guide_editor_generation.md) |
| Diagnóstico e análise | [Diagnóstico](user_guide_diagnostics_analysis.md) |
| Slash commands | [Comandos de barra](slash_commands.md) |
| Providers | [Instalação e configuração](install_config.md) |
| Novo provider | [Guia de providers](new_provider_guide.md) |

## Plataforma agentiva

| Tema | Documento |
|---|---|
| Ativação e execução de tools | [Ferramentas agentivas](user_guide_agentic_tools.md) |
| Tarifas e orçamento monetário | [Catálogo local de custos](agent_pricing.md) |
| Criação determinística de projetos | [New Project Wizard](project_wizard.md) |
| Criação e remoção de units/forms | [Operações estruturais](project_file_operations.md) |
| Transações código, projeto e Designer | [Transações compostas](development_transactions.md) |
| Execução e análise de testes DUnitX | [Runner DUnitX](dunitx_runner.md) |
| Commit Git local e revisável | [Fluxo Git](git_workflow.md) |
| O que faz e quando usar cada ferramenta | [Referência operacional](internal_tools_reference.md) |
| Todas as 95 ferramentas internas | [Catálogo gerado](runtime_tool_catalog.md) |
| Arquitetura alvo e contratos | [Catálogo arquitetural](tool_catalog.md) |
| Consentimento, risco e auditoria | [Modelo de segurança](tool_security_model.md) |
| MCP e clientes externos | [Integração MCP](mcp_integration_guide.md) |
| Seleção de executores CLI | [Executores CLI](cli_executors.md) |
| Terminal acoplável | [Terminal](terminal.md) |
| Primeira execução e jornada guiada | [Onboarding](onboarding.md) |
| Conhecimento local | [Conhecimento do projeto](user_guide_project_knowledge.md) |
| Jornadas Delphi | [Jornadas ponta a ponta](user_guide_journeys.md) |
| Form Designer e debugger | [Designer e debugger](user_guide_designer_debugger.md) |
| Extensões de ferramentas | [Extensões](tool_extension_guide.md) |
| Extensões declarativas | [Comandos sem recompilar](declarative_extensions.md) |
| Migração para 1.0 | [Guia de migração](agentic_migration_0_1.md) |

## Arquitetura e desenvolvimento

| Tema | Documento |
|---|---|
| Arquitetura geral | [Guia de arquitetura](architecture_guide.md) |
| Arquitetura agentiva | [Arquitetura agentiva](agentic_architecture.md) |
| Mapa do código-fonte | [Guia de fontes](source_code_guide.md) |
| Compatibilidade Delphi | [Matriz de compatibilidade](delphi_compatibility_matrix.md) |
| Extensão por BPL | [Guia de extensões](tool_extension_guide.md) |
| Novo provider | [Guia de providers](new_provider_guide.md) |
| Convenção de commits | [Commits](commit_convention.md) |
| Convenção de branches | [Branches](branch_convention.md) |

## Qualidade e release

| Tema | Documento |
|---|---|
| Processo de release | [Finalização de release](release_process.md) |
| Instalador visual e canal | [Distribuição assinável](visual_installer.md) |
| Migração 1.x para 2.0 | [Migração para RadIA 2.0](migration_1_to_2.md) |
| Checklist agentivo | [Checklist](agentic_release_checklist.md) |
| Plano e evidências | [Validação](agentic_validation_plan.md) |
| Auditoria de conclusão | [Auditoria](agentic_completion_audit.md) |
| Roadmap agentivo | [Roadmap agentivo](agentic_roadmap.md) |
| Roadmap do produto | [Roadmap](roadmap.md) |
| Backlog | [Backlog](backlog.md) |
| Goal RadIA 2.0 | [Jornada completa](radia_2_goal.md) |
| Goal de liderança | [Experiência Delphi completa](experience_leadership_goal.md) |
| Goal prioritário pós-2.0 | [Reprodução autônoma de falhas runtime](runtime_debug_automation_plan.md) |
| Plano congelado para retomada | [Continuidade CLI e integração avançada](competitive_leadership_plan.md) |
| Estratégia Delphi 12/13 | [Plataforma e plano de liderança](delphi_12_13_strategy.md) |

## Segurança e compliance

- [Termos, privacidade e compliance](compliance.md)
- [Modelo de segurança das tools](tool_security_model.md)

## Cobertura da plataforma RadIA 2.0

| Capacidade | Manual de uso | Referência técnica |
|---|---|---|
| Registry compartilhado | [Tools](user_guide_agentic_tools.md) | [Arquitetura](agentic_architecture.md) |
| Workspace OTA | [Manual completo](user_manual.md) | [ADR 0002](adr/0002-workspace-facade.md) |
| Consentimento e auditoria | [Tools](user_guide_agentic_tools.md) | [Segurança](tool_security_model.md) |
| Patches reversíveis | [Tools](user_guide_agentic_tools.md) | [Catálogo](tool_catalog.md) |
| Build controlado | [Manual completo](user_manual.md) | [Catálogo](tool_catalog.md) |
| Testes DUnitX estruturados | [Runner DUnitX](dunitx_runner.md) | [Catálogo](runtime_tool_catalog.md) |
| MCP | [Guia MCP](mcp_integration_guide.md) | [Arquitetura](agentic_architecture.md) |
| Form Designer | [Designer](user_guide_designer_debugger.md) | [Catálogo](tool_catalog.md) |
| Debugger | [Debugger](user_guide_designer_debugger.md) | [Catálogo](tool_catalog.md) |
| Revisão inline | [Manual completo](user_manual.md) | [Catálogo](tool_catalog.md) |
| Conhecimento local | [Conhecimento](user_guide_project_knowledge.md) | [Arquitetura](agentic_architecture.md) |
| Extensões | [Extensões](tool_extension_guide.md) | [ADR 0001](adr/0001-internal-tool-registry.md) |
| Shutdown seguro | [Troubleshooting](troubleshooting_agentic_platform.md) | [Arquitetura](agentic_architecture.md) |
