# Configurações por projeto, sessão e solicitação

O RadIA pode usar provider, modelo, executor e limites diferentes sem alterar a configuração global.
Isso permite, por exemplo, manter um modelo local como padrão, usar OpenAI em um projeto e reservar
um orçamento menor apenas para a próxima solicitação.

## Onde abrir

No compositor do chat, clique em **Settings > Scope**. A janela mostra o valor efetivo e sua origem
para cada campo. Quem prefere teclado pode digitar `/scope`; `/status settings` apresenta o mesmo
estado em formato textual.

## Precedência

Quando o mesmo campo aparece em mais de um nível, o RadIA usa esta ordem:

1. próxima solicitação;
2. sessão de chat atual;
3. projeto ativo;
4. configuração global;
5. padrão seguro do RadIA.

Cada campo herda de forma independente. Um projeto pode substituir somente o provider e continuar
herdando modelo, executor, timeout e limites globais.

## Campos disponíveis

| Campo | O que controla | Valores esperados |
|---|---|---|
| Provider | Serviço usado pelo chat e agente nativos | Identificador de provider registrado, como `OpenAI` ou `Gemini` |
| Model | Modelo enviado ao provider nativo | Identificador aceito pelo provider selecionado |
| Executor | Rota da próxima mensagem | `native`, `codex`, `claude`, `gemini` ou `copilot` |
| Maximum tokens | Limite de saída da solicitação nativa | Inteiro não negativo |
| Timeout (ms) | Tempo máximo da solicitação nativa ou execução CLI | Inteiro positivo em milissegundos |
| Agent token budget | Orçamento total de tokens da execução do agente | Inteiro não negativo; `0` significa sem limite próprio |

Credenciais, tokens e segredos não podem ser substituídos nesses escopos. Eles permanecem na
configuração segura global do provider ou da CLI.

Sem override de timeout, uma rota nativa usa o timeout global do provider e uma rota CLI preserva o
limite operacional de 15 minutos. O valor exibido por `/scope` já considera a rota efetiva.

## Escolher o escopo

- **Active project:** vale para todas as sessões daquele arquivo `.dproj` nesta instalação.
- **Current chat session:** vale somente para a conversa atual e tem prioridade sobre o projeto.
- **Next request only:** vale para a próxima execução iniciada com sucesso na conversa e projeto
  atuais e depois é descartado; nunca atravessa para outra sessão ou workspace.

Um override de projeto exige um projeto aberto. Um override de sessão exige uma conversa ativa. A
interface desabilita níveis indisponíveis e o comando informa a correção necessária.

## Usar pela interface

1. Clique em **Settings > Scope**.
2. Selecione **Active project**, **Current chat session** ou **Next request only**.
3. Edite somente o campo desejado e clique em **Apply**.
4. Confira **Source**: ele identifica o nível que está fornecendo o valor efetivo.
5. Clique em **Inherit** para remover o override daquele campo ou em **Restore all inheritance** para
   limpar todos os overrides do nível selecionado.
6. Quando precisar compartilhar uma configuração, selecione projeto ou sessão e use **Export
   scope...**. O arquivo escolhido contém somente os campos conhecidos daquele nível, sem caminho do
   projeto, credenciais ou conteúdo da conversa. A exportação nunca é automática.

A rota do compositor e a lista de modelos são atualizadas imediatamente; não é necessário reiniciar
o Delphi.

## Usar por comando

```text
/scope
/scope project provider OpenAI
/scope project model gpt-5.4
/scope session executor claude
/scope session timeout-ms 45000
/scope request max-tokens 2000
/scope request token-budget 12000
/scope project inherit model
/scope session clear
/status settings
```

Formato geral:

```text
/scope <project|session|request> <field> <value>
/scope <project|session|request> inherit <field>
/scope <project|session|request> clear
```

Os campos aceitos são `provider`, `model`, `executor`, `max-tokens`, `timeout-ms` e `token-budget`.
Providers e executores desconhecidos, valores vazios e limites inválidos são recusados sem alterar o
escopo anterior.

## Persistência e segurança

Overrides de projeto e sessão ficam, por padrão, fora do repositório em
`%APPDATA%\RadIA\settings\scopes`. O nome do arquivo contém um hash do identificador do escopo, não o
caminho original. A gravação é atômica e preserva campos de versões futuras. Se um arquivo estiver
corrompido, o RadIA não o sobrescreve: informa o erro para que o usuário possa inspecioná-lo.

Overrides da próxima solicitação permanecem apenas em memória. Nenhum desses arquivos armazena API
keys, tokens OAuth, conteúdo do prompt ou histórico da conversa.

## Diagnóstico

- Use `/scope` para comparar valor efetivo e origem.
- Use `/status settings` para o mesmo recorte dentro do diagnóstico do RadIA.
- Use `/status` para combinar esse estado com provider, agente, CLI, MCP, editor e projeto.
- Se uma CLI não estiver disponível, use `/doctor` e siga a ação indicada; não há fallback silencioso
  para o executor nativo.
