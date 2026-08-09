# Contexto compartilhado de jornada

O contexto compartilhado permite continuar a mesma tarefa no chat, terminal e editor sem copiar o
histórico completo entre superfícies. Cada jornada referencia somente a conversa do RadIA, o projeto
Delphi, o executor atual e seu estado de atividade.

## Como usar

Ao abrir ou selecionar uma conversa com um projeto ativo, o RadIA cria ou restaura uma jornada para
essa combinação. O compositor mostra **Journey: _identificador_** e o terminal apresenta o mesmo
identificador e projeto.

- Clique em **Journey > Detach** ou use `/context detach` para interromper o compartilhamento.
- Clique em **Journey > Link** ou use `/context` para vincular novamente.
- Use `/context new` para descartar o vínculo atual e criar uma identidade nova.
- Ao selecionar outra conversa, o chat restaura a jornada correspondente. Use
  `/context switch <identificador>` para localizar e abrir diretamente outra jornada do projeto ativo.
- Trocar de conversa restaura a jornada daquela conversa.
- Trocar de projeto cria uma jornada diferente e impede mistura entre workspaces.

`/context` também informa conversa, executor e identificador ativos. A troca é recusada quando o
identificador pertence a outro projeto, evitando mistura de workspaces.

## O que atravessa as superfícies

| Dado | Compartilhado | Motivo |
|---|---|---|
| Identificador da jornada | Sim | Correlacionar chat, terminal e editor |
| Conversa do RadIA | Referência | Manter isolamento entre chats |
| Projeto Delphi | Referência | Impedir contexto de outro workspace |
| Executor | Sim | Explicar a rota efetiva |
| Estado `idle`, `running` ou `cancelling` | Sim | Manter o ciclo de atividade coerente |
| Histórico integral do chat | Não | Evitar exposição e contexto irrestrito |
| Saída integral do terminal | Não | Evitar envio implícito de logs |
| Conteúdo de outros arquivos | Não | Respeitar seleção e limites do editor |

O editor acrescenta apenas jornada, conversa e executor ao contexto de projeto quando o arquivo
ativo pertence ao mesmo diretório do `.dproj`. O terminal usa a identidade na autorização do
comando e continua exigindo o consentimento configurado.

## Cancelamento e privacidade

Chat e terminal publicam o mesmo estado de atividade. Ao solicitar cancelamento, a jornada passa
para `cancelling`; ao concluir o callback do processo, volta para `idle`. Esse estado não concede
permissões, não transfere credenciais e não substitui os controles de cancelamento de cada processo.

As jornadas ficam somente na memória da instância atual da IDE. Conversas e sessões CLI continuam
com sua persistência própria; fechar o Delphi remove os vínculos de jornada transitórios.
