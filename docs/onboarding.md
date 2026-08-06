# Onboarding do Rad IA

O onboarding apresenta uma jornada curta pelas superfícies essenciais do Rad IA. Ele aparece
automaticamente uma única vez para cada versão do fluxo e pode ser reaberto a qualquer momento em
**Tools > Rad IA Getting Started**.

Fechar a janela interrompe o fluxo sem alterar configurações. O Rad IA grava somente a etapa atual
para não exibir novamente a janela automaticamente. Ao reabrir pelo menu, a jornada continua da
última etapa visitada. O botão **Finish** registra a conclusão.

## Etapas

| Etapa | O que ensina | Ação disponível |
|---|---|---|
| Chat | Abrir o painel acoplável e conversar sobre o projeto ativo | **Open chat** |
| Provider e executor | Configurar um provider e escolher agente nativo ou CLI | **Open provider settings** |
| Segurança | Revisar consentimento antes de leitura, alteração, build, debug ou commit | **Open consent settings** |
| CLI e MCP | Diagnosticar CLIs e conectar, reparar ou remover o bridge MCP | **Open CLI and MCP settings** |
| Terminal | Executar comandos com streaming, histórico, snippets e cancelamento | **Open terminal** |
| Prontidão | Executar `/doctor` no chat e obter score, checks e próxima ação | **Run installation doctor** |
| Novo projeto | Criar um projeto Delphi determinístico e continuar no Agent Mode | **Create a project** |

As ações abrem as telas reais do produto. O onboarding permanece disponível ao fundo para que o
usuário retorne ao roteiro depois de salvar ou fechar a superfície aberta.

## Primeira configuração recomendada

1. Configure pelo menos um provider em **AI Providers**.
2. Em **Security & Consent**, escolha como as operações de risco devem solicitar aprovação.
3. Em **CLI & MCP**, mantenha o agente nativo ou selecione uma CLI já instalada e execute o
   diagnóstico.
4. Conecte o MCP somente aos clientes desejados, depois de revisar o preview da configuração.
5. Execute **Run installation doctor**. Com o executor nativo, MCP não é requisito; com uma CLI,
   bridge e configuração MCP passam a fazer parte do aceite.
6. Confirme que `firstToolReady` está ativo e execute a primeira tool somente leitura.
7. Abra o chat e habilite visualmente o **Agent Mode** quando quiser que o Rad IA planeje e use
   ferramentas internas.

O onboarding não instala CLIs, não modifica arquivos MCP e não ativa consentimentos sozinho. Toda
operação continua dependendo da ação explícita do usuário nas telas correspondentes.
