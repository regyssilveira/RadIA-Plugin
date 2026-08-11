# Revisão de alterações por bloco

A revisão por bloco permite decidir cada alteração proposta diretamente no editor antes de qualquer
arquivo ser modificado. O RadIA mostra um marcador no gutter — a margem à esquerda do código — para
cada bloco vinculado à revisão atual do arquivo.

## Quando ela é acionada

A sessão é criada automaticamente quando o agente ou uma integração executa `PreparePatch` ou
`PrepareMultiFilePatch`. Preparar uma alteração não escreve no buffer: apenas calcula o diff, separa
os blocos e publica os marcadores. Uma nova preparação substitui a sessão anterior para evitar que
duas propostas independentes sejam misturadas.

As ferramentas relacionadas são:

| Ferramenta | O que faz | Quando usar |
|---|---|---|
| `PreparePatch` | Prepara um arquivo e publica seus blocos. | Antes de revisar uma alteração simples. |
| `PrepareMultiFilePatch` | Prepara uma transação com vários arquivos. | Quando a mudança atravessa units. |
| `ListBlockReviews` | Lista blocos, arquivos, linhas e decisões atuais. | Para o agente ou `/tool` consultar o estado. |
| `DecideBlockReview` | Aceita, rejeita, edita ou solicita alterações com comentário, sem escrever. | Para usar a decisão do gutter pelo agente, chat ou MCP. |
| `ApplyBlockReviews` | Aplica todos os blocos resolvidos como uma transação. | Depois que não houver decisão pendente. |
| `ClearBlockReviews` | Descarta a sessão sem alterar arquivos. | Para abandonar toda a proposta. |

## Marcadores e decisões

| Cor | Estado | Efeito ao aplicar |
|---|---|---|
| Laranja | Pendente | Impede a aplicação até receber uma decisão. |
| Verde | Aceito | Usa o texto proposto. |
| Cinza | Rejeitado | Mantém o texto original. |
| Roxo | Editado | Usa o texto ajustado no comparador visual. |
| Vermelho | Alterações solicitadas | Registra o comentário e impede a aplicação. |

Clique com o botão esquerdo no marcador para abrir **Accept block**, **Reject block**, **Request
changes**, **Edit block**, **Explain block**, **Apply resolved review** e **Discard review session**.
**Request changes** exige um comentário, não altera o buffer e mantém o bloco pendente. O comentário
aparece em `ListBlockReviews`, para que agente, chat ou MCP recuperem o feedback. A edição
abre o comparador visual com o original e a proposta, permitindo ajustar o resultado antes de salvar
a decisão.

## Teclado e menu do editor

As ações também aparecem no submenu **Rad IA** do menu contextual. As ações recorrentes possuem
bindings configuráveis da Open Tools API; solicitar alterações abre o campo de comentário pelo menu
ou pelo marcador:

| Ação | Nome no perfil | Atalho padrão |
|---|---|---|
| Aceitar o bloco no cursor | `reviewAccept` | `Ctrl+Alt+Enter` |
| Rejeitar o bloco no cursor | `reviewReject` | `Ctrl+Alt+R` |
| Ir ao próximo bloco | `reviewNext` | `Ctrl+Alt+PageDown` |
| Ir ao bloco anterior | `reviewPrevious` | `Ctrl+Alt+PageUp` |
| Editar o bloco no cursor | `reviewEdit` | `Ctrl+Alt+E` |
| Explicar o bloco no cursor | `reviewExplain` | `Ctrl+Alt+I` |
| Aplicar a sessão resolvida | `reviewApply` | `Ctrl+Alt+A` |
| Descartar a sessão | `reviewClear` | `Ctrl+Alt+Delete` |

Para personalizar, abra **Rad IA > Settings > Editor Assistance** e altere **RadIA shortcut
profile**. Use pares `ação=atalho` separados por ponto e vírgula. Perfis antigos continuam válidos e
recebem os novos atalhos padrão; conflitos com o keymap do Delphi são registrados no log e o comando
já existente mantém prioridade.

## Segurança e consistência

- Cada bloco contém arquivo, intervalo e hash da revisão-base.
- Se o buffer ou arquivo divergir, o marcador deixa de ser válido e a aplicação é recusada.
- Nenhuma decisão isolada escreve no editor.
- Todos os blocos precisam estar resolvidos antes da aplicação.
- Alterações multiarquivo usam preflight, checkpoint e compensação: uma falha não deixa aplicação
  parcial silenciosa.
- Rejeitar todos os blocos conclui a sessão sem modificar o conteúdo.
- **Discard review session** remove somente a proposta; não desfaz alterações já aplicadas.

## Fluxo recomendado

1. Peça a alteração no chat ou no modo agente.
2. Aguarde a preparação e abra o primeiro arquivo indicado.
3. Percorra os marcadores com mouse, menu ou `reviewNext`/`reviewPrevious`.
4. Aceite, rejeite, edite ou solicite alterações com comentário em cada bloco.
5. Use **Apply resolved review** somente depois de revisar todos os arquivos.
6. Compile e execute os testes; se necessário, use o checkpoint ou a ferramenta de reversão da
   transação.

