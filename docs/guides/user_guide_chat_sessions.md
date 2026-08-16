# Guia de Uso: Painel de Chat & Gerenciamento de Sessões

> O chat também pode executar ferramentas estruturadas da IDE. Consulte o
> [Guia das Ferramentas Agentivas](user_guide_agentic_tools.md) para consentimento, preview,
> cancelamento, auditoria e resultados.

Este guia detalha o funcionamento da interface de chat do **Rad IA**, os atalhos de produtividade, o gerenciamento de múltiplas sessões e os fluxos de backup e customização de templates.

---

## 1. Interface de Chat Lateral (WebView2)

O Rad IA se acopla diretamente à barra lateral da IDE do Delphi, fornecendo um painel de chat moderno que roda sobre o motor **Microsoft Edge WebView2**.

*   **Temas Inteligentes**: A interface detecta automaticamente o tema ativo da IDE (Claro ou Escuro) e adapta seus esquemas de cores e estilos para manter a harmonia visual.
*   **Markdown & Realce de Código**: As respostas da IA suportam formatação Markdown completa e realce de sintaxe (*syntax highlighting*) otimizado para Object Pascal (usando Marked.js e Prism.js integrados localmente).
*   **Dock responsivo**: A linha principal mostra modo, provider, modelo e **Effort**. O botão
    **More** revela executor, sessão CLI, jornada, escopo e rota efetiva para quem precisar de
    controle avançado. As duas linhas se reorganizam sem rolagem horizontal quando o painel fica
    estreito.
*   **Recuperação do painel**: Se a criação, navegação ou processo do WebView2 falhar, o RadIA tenta
    recriar o painel até duas vezes por sequência de falhas. O rascunho, a posição da conversa e a
    abertura das opções avançadas são preservados somente em memória. O texto ainda não enviado
    não é gravado em disco.

Se as duas tentativas falharem, feche e reabra o painel. Consulte
[Solução de problemas](troubleshooting_agentic_platform.md#painel-de-chat-e-webview2) antes de
apagar qualquer cache.

---

## 2. Atalhos de Produtividade no Chat

A área de entrada de texto do chat do Rad IA possui atalhos projetados para acelerar a digitação e navegação de prompts:

*   `Ctrl + Enter`: Envia o prompt digitado para a IA ativa.
*   `Enter`: Insere uma quebra de linha no prompt atual.
*   Seta para cima `↑` / Seta para baixo `↓`: Permite navegar rapidamente pelo histórico dos prompts que você já digitou e enviou nesta sessão de trabalho.
*   Caractere `/` (Barra): Abre o popup flutuante de autocompletar contendo a lista de atalhos rápidos (Slash Commands) cadastrados.
*   Listas longas do chat, incluindo seletores e popup de comandos, exibem barra de rolagem visível
    para navegação sem roda do mouse.

### Continuar escrevendo enquanto o RadIA trabalha

Durante uma resposta, o botão principal permanece como **Cancel request** e surge o botão **+1**.
Escreva uma continuação e clique em **+1**, ou pressione `Ctrl + Enter`, para colocá-la na fila da
conversa atual. O compositor mostra a quantidade e uma prévia da próxima mensagem.

- até cinco mensagens podem aguardar;
- **Edit** devolve a próxima mensagem ao campo sem perder o rascunho atual;
- **Clear** descarta toda a fila local;
- a próxima mensagem é enviada somente quando o turno atual termina;
- provider, modelo, executor e jornada permanecem bloqueados durante o turno e são resolvidos de
  novo no momento do envio;
- a fila existe somente na memória do painel: não entra no histórico antes do envio e não sobrevive
  ao fechamento ou recarregamento do chat.

---

## 3. Múltiplas Sessões e Histórico Persistente

O Rad IA organiza o seu trabalho em sessões persistentes de conversa. O histórico é gravado localmente em arquivos JSON seguros sob a pasta `%APPDATA%\RadIA\sessions\`.

### Gerenciamento de Conversas:
1.  **Barra Lateral Retrátil**: Clique no ícone de menu (hambúrguer) no canto superior esquerdo do chat para abrir a sidebar de sessões.
2.  **Criar Nova Conversa**: Clique no botão **[Novo Chat]** para abrir um canal limpo e desvinculado dos chats anteriores.
3.  **Renomear Conversa**: Dê um **duplo clique inline** sobre o título do chat na barra lateral para editá-lo e digite `Enter` para salvar o novo nome.
4.  **Excluir Conversa**: Clique no ícone de lixeira ao lado do título da conversa para removê-la permanentemente do histórico local.
5.  **Isolamento de Segurança**: A barra lateral de sessões e a criação/exclusão de chats ficam dinamicamente desativadas se houver uma resposta da IA sendo transmitida via streaming no momento.

### Sessões de executores CLI

Quando o chat usa um executor CLI externo, cada conversa do RadIA preserva separadamente o
identificador necessário para continuar aquela conversa no cliente. O compositor mostra
**Session: Resume** quando existe um vínculo compatível e **Session: New** quando a próxima mensagem
iniciará uma conversa externa nova. Use **New CLI session** ou `/cli new` para recomeçar sem apagar
o histórico visível do RadIA. Consulte [Executores CLI](cli_executors.md) para limites e privacidade.

### Jornada compartilhada com terminal e editor

Cada conversa pode manter uma identidade de jornada vinculada ao projeto ativo. O botão **Journey**
mostra **Link** ou **Detach**, e o compositor exibe o identificador abreviado. Ao trocar de conversa,
o RadIA restaura a jornada correspondente sem copiar mensagens para o terminal ou para o editor.
Use `/context`, `/context new`, `/context detach` e `/context switch <id>` para executar as mesmas
ações pelo teclado. Consulte [Contexto compartilhado](shared_journey_context.md) para limites,
privacidade e isolamento entre projetos.

---

## 4. Exportação de Conversas

Você pode salvar o histórico de qualquer chat para fins de documentação ou compartilhamento com a equipe:

1.  No topo do painel de chat ativo, clique no botão **Exportar**.
2.  Selecione o formato desejado:
    *   **Markdown (.md)**: Ideal para salvar em repositórios Git ou documentações internas.
    *   **HTML Autônomo**: Gera um arquivo HTML completo contendo toda a estilização e scripts de realce de sintaxe Pascal embutidos, permitindo visualizar a conversa formatada de forma offline em qualquer navegador.

---

## 5. Biblioteca de Templates e Backups

Os templates permitem criar atalhos personalizados (Slash Commands) com instruções reutilizáveis. O Rad IA separa os templates nativos do sistema daqueles criados ou modificados por você.

### Como Gerenciar Templates:
1.  Na IDE do Delphi, acesse **Tools -> Options -> Third Party -> Rad IA -> Templates**.
2.  Nesta tela, você verá a lista de templates ativos. O indicador de origem mostrará:
    *   `Default System (Read-Only)`: Templates integrados do plugin.
    *   `Default System (Customized)`: Templates nativos que você editou (salvos como overlays locais).
    *   `User Custom`: Novos templates que você cadastrou.
3.  **Restaurar Padrão**: Caso modifique um template do sistema e deseje reverter, selecione-o e clique em **Restaurar Padrão** (o overlay será removido e o prompt original reativado).

### Backup (Exportar / Importar):
*   **Exportar**: Clique em **Exportar** no painel de templates para salvar toda a sua biblioteca ativa (incluindo novos templates e customizações) em um arquivo JSON.
*   **Importar**: Clique em **Importar** e selecione o arquivo JSON de backup. O Rad IA validará as propriedades e exibirá duas opções de integração:
    *   *Merge (Mesclar)*: Adiciona as novas customizações preservando os templates locais já configurados.
    *   *Overwrite (Sobrescrever)*: Substitui inteiramente a biblioteca local pelo conteúdo do backup.

> [!CAUTION]
> **Atenção ao Sobrescrever Templates:**
> A opção **Overwrite (Sobrescrever)** apaga de forma irreversível todos os seus templates customizados e novos comandos locais que não estiverem inclusos no arquivo JSON de backup importado. Recomendamos que você faça uma exportação de segurança da sua biblioteca atual antes de executar uma importação por sobrescrita.

---

## 6. Configurações específicas da conversa

Use **Settings > Scope** no compositor para aplicar provider, modelo, executor ou limites somente à
conversa atual. A origem `session` confirma que a sessão está sobrescrevendo o projeto e o padrão
global. Use **Inherit** para restaurar um campo ou **Restore all inheritance** para limpar a sessão.
`/scope session ...` oferece o mesmo fluxo pelo teclado. Consulte
[Configurações por projeto, sessão e solicitação](hierarchical_settings.md).
