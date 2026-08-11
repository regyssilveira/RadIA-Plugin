<div align="right">

[Português](README.md) | [English](README.en.md) | [Documentação](docs/README.md) | [Roadmap](docs/roadmap.md)

</div>

<p align="center">
  <img src="docs/images/radia_readme_banner-2.png" alt="RadIA - Assistente de IA para Delphi" width="100%" />
</p>

# RadIA — Assistente de IA integrado ao Delphi

O RadIA conecta chat, geração de código e um agente com ferramentas reais da IDE. Ele pode ler e
editar o projeto, compilar, executar testes, controlar o debugger, interagir com o Form Designer e
produzir evidências para validar uma correção — sempre com consentimento e limites de workspace.

## Comece aqui

1. [Instale e configure o RadIA](docs/install_config.md).
2. Siga os [primeiros passos](docs/onboarding.md).
3. Consulte o [manual completo do usuário](docs/user_manual.md).
4. Use o [centro de documentação](docs/README.md) para localizar qualquer assunto por tarefa.

Se você quer primeiro entender o alcance do produto, veja [tudo que o RadIA pode fazer](docs/capabilities.md).

No chat, digite `/help` para ver um resumo das capacidades, os comandos principais e links para a
documentação. Os links são abertos no navegador padrão do Windows.

## Qual modo usar?

| Combinação | Use para | Ferramentas da IDE | Precisa abrir um projeto? |
|---|---|---|---|
| **Chat + RadIA native** | Perguntas, explicações e ideias de código | Não | Não |
| **Agent + RadIA native** | Criar projetos, editar, compilar, testar e debugar | Sim, com consentimento | Não; somente a ferramenta específica pode exigir |
| **Chat + CLI externo** | Conversar diretamente pelo Codex, Claude, Gemini ou Copilot | Recursos do CLI | Não |
| **Agent + CLI externo** | Delegar um objetivo completo ao CLI escolhido | Recursos do CLI | Não |
| **MCP** | Expor ou consumir ferramentas registradas | Conforme a política da tool | Depende da tool |

**Provider** escolhe o modelo e a forma de autenticação; **modo** define se há execução agentiva;
**executor** define quem conduz a solicitação; **MCP** é uma ponte de ferramentas independente.
Quando um plano aguardar aprovação, clique em **Approve plan** ou digite `/agent resume`.
Veja a [explicação completa dos executores](docs/cli_executors.md).

Você não precisa escolher previamente a combinação correta para criar um projeto. Pedidos naturais
como **“crie uma calculadora VCL em D:\Projetos\Calculadora”** são reconhecidos como uma jornada de
criação: o RadIA infere nome e destino, usa Win32 quando a plataforma não é informada, pergunta apenas
o que realmente faltar, apresenta o plano e a aprovação no próprio chat e usa as ferramentas
nativas da IDE para criar, abrir, compilar, executar e validar o resultado. Os controles de executor
continuam disponíveis para uso avançado, mas não mudam esse roteamento seguro.

## Compatibilidade

| IDE | Arquitetura | Estado |
|---|---|---|
| Delphi 12 Athens | Win32 | Suportado e validado |
| Delphi 13 | Win32 | Suportado e validado |
| Delphi 13 | IDE64 | Suportado e validado |

Delphi 11 não faz parte da matriz atual.

## O que você pode fazer

| Área | Capacidades principais | Guia |
|---|---|---|
| Chat | Providers, streaming, sessões, fila de continuações, templates, histórico e comandos | [Chat e sessões](docs/user_guide_chat_sessions.md) |
| Configurações por escopo | Provider, modelo, executor e limites por projeto, sessão ou próxima solicitação | [Configurações por escopo](docs/hierarchical_settings.md) |
| Contexto compartilhado | Continuar a mesma jornada no chat, terminal e editor sem copiar histórico | [Contexto compartilhado](docs/shared_journey_context.md) |
| Editor | Explicar, revisar, refatorar, gerar código, testes, DTOs e documentação | [Editor e geração](docs/user_guide_editor_generation.md) |
| Ghost Text/FIM | Completar no cursor, comparar até três alternativas e usar fallback diagnosticável | [Assistência inline e FIM](docs/inline_completion.md) |
| Revisão por bloco | Aceitar, rejeitar, editar e aplicar mudanças pelo gutter | [Revisão por bloco](docs/block_reviews.md) |
| Projetos | Criar projetos, units e forms com preview e validação | [Criação de projetos](docs/project_wizard.md) |
| DEXT | Criar APIs minimalistas ou com controllers por jornadas guiadas | [Jornadas DEXT](docs/user_guide_dext_journeys.md) |
| Build e testes | Compilar, estruturar erros, executar DUnitX e usar resultados como gate | [Jornadas](docs/user_guide_journeys.md) |
| Designer | Consultar e alterar componentes, propriedades, eventos e layout | [Designer e debugger](docs/user_guide_designer_debugger.md) |
| Debugger | Iniciar, pausar, continuar, executar passos, breakpoints, watches e call stack | [Designer e debugger](docs/user_guide_designer_debugger.md) |
| Diagnóstico runtime | Reproduzir uma falha visual, corrigir e repetir o mesmo cenário | [Diagnóstico runtime](docs/runtime_debug_automation.md) |
| Memória | Instrumentar Debug com FastMM5, analisar leaks e comparar a correção | [Diagnóstico FastMM5](docs/fastmm5_diagnostic_session.md) |
| Agente | Planejar, executar tools, pausar, retomar, cancelar e restaurar checkpoints | [Modo agente](docs/user_manual.md#3-como-ativar-o-modo-agente) |
| MCP | Expor as mesmas tools da IDE a clientes locais autorizados | [Integração MCP](docs/mcp_integration_guide.md) |
| Terminal | Usar ConPTY com Unicode, true color, alternate screen, paste protegido, mouse SGR e OSC 8 | [Terminal](docs/terminal.md) |
| Conhecimento | Indexar e pesquisar o projeto localmente | [Conhecimento do projeto](docs/user_guide_project_knowledge.md) |

## Agente nativo, CLI, provider e MCP

Essas escolhas têm responsabilidades diferentes:

- **provider** conecta o chat a um modelo por API, endpoint local ou transporte declarado;
- **agente nativo** executa o loop de ferramentas, consentimentos e checkpoints dentro do RadIA;
- **executor CLI externo** entrega o objetivo ao Codex, Claude, Gemini ou Copilot instalado pelo usuário;
- **MCP** permite que outro cliente autorizado use as tools publicadas pela IDE.

O OpenAI API via API Key usa transporte HTTP e cobrança da plataforma API. O ChatGPT Pro usa a
sessão e a cota do Codex CLI. Nesse segundo caso, **RadIA native** mantém a orquestração dentro do
RadIA, enquanto **Codex CLI direto** entrega a execução completa ao CLI. Veja a
[matriz completa de executores](docs/cli_executors.md).

## Ferramentas e comandos

- `/tools` mostra as ferramentas disponíveis na instalação e no contexto atuais.
- `/help` resume o produto e aponta para a documentação aplicável.
- `/journey` lista jornadas que coletam dados ausentes sem perder o contexto da conversa.
- `/scope` mostra valores efetivos e permite sobrescrever ou restaurar herança sem reiniciar a IDE.
- [Catálogo das 133 ferramentas](docs/runtime_tool_catalog.md) lista o catálogo interno gerado.
- [Referência operacional](docs/internal_tools_reference.md) explica o que cada ferramenta faz e
  quando pode ser acionada.
- [Comandos de barra](docs/slash_commands.md) documenta comandos, argumentos e exemplos.
- [Modelo de segurança](docs/tool_security_model.md) explica riscos, consentimento e auditoria.
- [Extensões declarativas](docs/declarative_extensions.md) ensina a compartilhar comandos, skills,
  conhecimento, referências, templates, aliases e workflows em pacotes `.radiaext`.
- [Portabilidade de skills](docs/skill_portability.md) publica uma definição nos quatro CLIs com
  preview, consentimento, rollback e preservação de conflitos.

O catálogo retornado por `/tools` é a fonte mais precisa em runtime. Documentos de roadmap e
catálogos arquiteturais podem incluir propostas ainda não disponíveis.

## Instalação

Para usar o Rad IA, baixe somente `RadIA-v<versão>-Setup.exe` na
[release mais recente](https://github.com/regyssilveira/RadIA-Plugin/releases/latest). Feche o
Delphi, execute o instalador e selecione as IDEs desejadas. Não é necessário baixar ZIP, instalar
PowerShell/npm ou compilar o projeto.

O instalador verifica os binários, o registro do pacote, o loader e todos os recursos Web do
manifesto. O reparo reaplica esses componentes preservando configurações, e a desinstalação mantém
os dados do usuário por padrão.

## Compilar e instalar do código-fonte

Para instalar sem usar o instalador visual, clone o repositório, abra o PowerShell na raiz, feche
todas as instâncias do Delphi e execute o comando correspondente. Use uma sessão elevada caso o
Windows precise autorizar a cópia do `WebView2Loader.dll`:

```powershell
# Delphi 12 Win32
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "23.0" -Release -Install

# Delphi 13 Win32
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "37.0" -Release -Install

# Delphi 13 IDE64
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "37.0" -IDE64 -Release -Install
```

`-Test` compila e executa os testes, mas não instala sem `-Install`. Depois da instalação, abra a IDE
e execute `/doctor`. O procedimento completo, incluindo build, teste, instalação por pacote e
solução de problemas, está no
[guia de instalação e configuração](docs/install_config.md).

Para localizar e entender qualquer campo ou botão de configuração, consulte a
[referência completa das configurações](docs/settings_reference.md).

## Segurança e privacidade

- Credenciais compatíveis são protegidas localmente com Windows DPAPI.
- Tools são classificadas por risco e mutações exigem consentimento.
- Paths são confinados ao workspace autorizado.
- Patches usam preview, hash-base e precondições para evitar sobrescrever conteúdo alterado.
- MCP reutiliza as mesmas políticas do chat.
- O RadIA não envia código a um provider sem uma ação iniciada pelo usuário.

Consulte [segurança das ferramentas](docs/tool_security_model.md) e
[privacidade e compliance](docs/compliance.md).

## Desenvolvimento e contribuição

- [Arquitetura](docs/architecture_guide.md)
- [Mapa do código-fonte](docs/source_code_guide.md)
- [Matriz de compatibilidade](docs/delphi_compatibility_matrix.md)
- [Convenção de branches](docs/branch_convention.md)
- [Convenção de commits](docs/commit_convention.md)
- [Processo de release](docs/release_process.md)
- [Backlog](docs/backlog.md)

O código, identificadores, comentários e commits são escritos em inglês. Discussões e documentação
principal são mantidas em português do Brasil, com versões em inglês quando disponíveis.

## Licença

Consulte o arquivo [LICENSE](LICENSE) e o [guia de compliance](docs/compliance.md).
