# Onboarding do Rad IA

O onboarding do Rad IA leva o usuário ao primeiro resultado útil sem exigir que ele aprenda antes
os conceitos de provider, modelo, executor, CLI ou MCP. A experiência continua apresentando a
plataforma completa e mantém todos os controles acessíveis no compositor e nas configurações.

Ele aparece automaticamente uma vez para cada versão do fluxo e pode ser reaberto em
**Ferramentas > RadIA > Rad IA Getting Started**. Fechar a janela interrompe o roteiro sem alterar configurações.
Ao reabrir pelo menu, a jornada continua da última etapa visitada.

## Princípio da experiência

O fluxo segue três ideias:

1. **Começar pelo objetivo:** o usuário descreve o que quer entender, modificar, validar, depurar
   ou criar.
2. **Manter a potência visível:** o chat apresenta modo, provider, modelo e rota efetivos, além das
   capacidades de código, build, testes, debugger, Form Designer, terminal, MCP e skills.
3. **Aprofundar sob demanda:** **More** abre executor, jornada e escopo; **Settings** preserva a
   configuração completa da plataforma.

## Etapas

| Etapa | Resultado esperado | Ação disponível |
|---|---|---|
| Começar pelo objetivo | Abrir o chat com sugestões orientadas ao trabalho | **Start in Rad IA** |
| Primeiro resultado | Avaliar a saúde do projeto sem alterar arquivos | **Understand this project** |
| Plataforma completa | Descobrir recursos e documentação aplicável | **Explore capabilities** |
| Controle total | Acessar providers, agentes, consentimento, CLI, MCP e demais opções | **Open full settings** |

O primeiro resultado usa `/health`, que combina estado da IDE, compilador, build, testes e
conhecimento local para recomendar a próxima ação. Sem projeto aberto, o cartão explica esse
pré-requisito e o usuário ainda pode conversar ou criar um projeto pelo mesmo chat.

## Tela inicial do chat

Uma conversa vazia oferece quatro pontos de partida:

- **Understand this project:** prepara `/health`;
- **Fix a problem:** prepara um objetivo de investigação, correção revisada e validação;
- **Create something:** inicia um pedido de projeto, form, unit, API, teste ou funcionalidade;
- **Debug an application:** prepara uma jornada de diagnóstico runtime.

Os botões preenchem o compositor e não enviam nada automaticamente. O usuário pode revisar ou
completar o pedido antes do envio. **Explore all capabilities** prepara `/help`.

## Controle e segurança

O onboarding não instala CLIs, não modifica configurações MCP, não troca providers e não concede
consentimentos automaticamente. O modo e a rota efetivos permanecem visíveis. Operações protegidas
continuam usando preview, política de risco e consentimento.

Usuários que preferem configuração direta podem abrir **More**, **Settings**, `/scope`, `/doctor`
ou `/status` a qualquer momento. A simplificação altera a ordem de apresentação, não a capacidade
ou o controle da plataforma.
