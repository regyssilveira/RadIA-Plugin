# Assistência inline e Fill-in-the-Middle

Este documento descreve a arquitetura de assistência inline do RadIA 2.0.0. O recurso está sendo
entregue de forma incremental. O motor, a captura explícita e o primeiro overlay visual já estão
conectados à Open Tools API.

## Objetivo

O motor Fill-in-the-Middle (FIM) recebe o código antes e depois do cursor, o arquivo, a linguagem,
o símbolo atual e um contexto explícito do projeto. O provider deve retornar somente o trecho que
falta no cursor.

O RadIA não altera o buffer enquanto apresenta uma sugestão. A escrita ocorre apenas quando o
usuário aceita a sugestão inteira ou a próxima palavra.

## Fluxo do motor

1. A integração da IDE captura prefixo, sufixo, revisão do buffer e contexto autorizado.
2. O contexto é limitado antes de sair da IDE.
3. Uma nova solicitação cancela a anterior e reinicia o debounce.
4. O cache local evita chamadas repetidas para o mesmo contexto.
5. A resposta perde cercas Markdown, sobreposição com o sufixo e conteúdo acima do limite.
6. A entrega ocorre somente se a geração e a revisão ainda forem atuais.
7. A camada visual exibe a sugestão sem tocar no buffer.

## Ações disponíveis no menu do editor

| Ação | Atalho padrão |
|---|---|
| Solicitar sugestão | `Ctrl+Alt+Espaço` |
| Aceitar toda a sugestão | `Ctrl+Alt+Direita` |
| Aceitar somente a próxima palavra | `Ctrl+Alt+Baixo` |
| Solicitar uma alternativa | `Ctrl+Alt+]` |
| Rejeitar a sugestão | `Ctrl+Alt+Backspace` |
| Aceitar revisão na linha atual | `Ctrl+Alt+Enter` |
| Rejeitar revisão na linha atual | `Ctrl+Alt+R` |

Os atalhos aparecem no submenu **Rad IA** do menu contextual do editor. O primeiro pedido de cada
sessão informa qual contexto será enviado e exige consentimento explícito.

Os atalhos são bindings parciais nativos da Open Tools API e funcionam diretamente no editor, sem
abrir o menu contextual. Para alterá-los, abra **Rad IA > Settings > Security & Consent** e edite
**Inline shortcuts** usando o formato:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right;
nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+];
reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+T;
reviewAccept=Ctrl+Alt+Enter; reviewReject=Ctrl+Alt+R
```

As ações obrigatórias são `request`, `accept`, `nextWord`, `alternative` e `reject`. Terminal e
decisões de revisão usam `terminal`, `reviewAccept` e `reviewReject`; perfis antigos recebem os
atalhos padrão automaticamente. O RadIA não
salva perfis incompletos, teclas inválidas ou atalhos duplicados. A configuração é recarregada ao
voltar ao editor, sem reiniciar a IDE. Se o keymap ativo do Delphi já possuir o mesmo atalho, o
comando existente permanece prioritário e o conflito é registrado no log do RadIA.

## Diagnóstico visual local

O menu **Tools** e o submenu **Rad IA** do editor oferecem **Preview Rad IA Ghost Text
Diagnostic**. A ação:

- usa o buffer e a posição reais do editor;
- apresenta duas linhas locais pelo mesmo controller e overlay da sugestão normal;
- não chama provider, não envia contexto e não exige conexão;
- não altera o buffer antes do aceite;
- pode ser rejeitada ou aceita pelos mesmos atalhos configurados pelo usuário.

O log registra separadamente a preparação e a pintura efetiva, incluindo apenas quantidade de
linhas e nome do arquivo. O conteúdo do buffer e da sugestão nunca entra nessa evidência. Assim, o
diagnóstico diferencia uma ação apenas disparada de um overlay realmente processado pela pintura
OTA.

## Assistência contínua e escopo

A assistência contínua nasce desligada. Para ativá-la, abra **Rad IA > Settings > Security &
Consent** e marque **Enable continuous inline completion**. O próprio texto da opção informa que
um contexto limitado do buffer ativo será enviado ao provider selecionado.

Na mesma seção é possível configurar:

- atraso de inatividade entre 250 e 5000 milissegundos;
- linguagens excluídas, separadas por ponto e vírgula;
- fragmentos de nome ou path de arquivo excluídos;
- fragmentos de nome ou path de projeto excluídos.

As alterações passam a valer sem reiniciar a IDE. O menu contextual também oferece
**Pause/Resume Inline Completion for Session**. A pausa de sessão não altera a preferência
persistida e volta ao estado normal quando a IDE é reiniciada.

No modo contínuo, o RadIA usa a API moderna `INTACodeEditorEvents` para observar o ciclo de pintura
e detectar revisões do editor; não existe polling periódico de conteúdo. Um snapshot só é
solicitado quando arquivo, revisão ou posição do cursor mudam. Contextos bloqueados pela política
não chegam ao provider.

## Segurança e privacidade

- O contexto do projeto é um campo explícito do pedido, não uma coleta oculta.
- Prefixo, sufixo e contexto possuem limites independentes da janela total do modelo.
- Uma solicitação cancelada não pode publicar uma resposta atrasada.
- O aceite deve validar a revisão capturada antes de inserir texto.
- Arquivo, hash da revisão, linha e coluna precisam continuar idênticos no momento do aceite.
- Após o aceite parcial, a view devolve um novo snapshot ao controller antes de manter o restante.
- Providers locais e remotos usam o mesmo contrato e as mesmas regras de cancelamento.
- A preferência contínua utiliza uma chave nova e segura, desligada por padrão; configurações
  antigas de autocomplete não concedem consentimento implicitamente.

## Componentes implementados

- `TRadIAInlineCompletionContext`: contexto FIM e chave estável de cache.
- `TRadIAInlineCompletionOptions`: debounce e limites.
- `IRadIAInlineCompletionProvider`: abstração para modelos locais e remotos.
- `TRadIAServiceInlineCompletionProvider`: adaptador para o provider ativo do RadIA.
- `TRadIAInlineCompletionController`: cache, cancelamento, saneamento e ações de aceite.
- `TRadIAInlineGhostLayout`: separação determinística de sugestões em linhas virtuais.
- `IRadIAInlineCompletionView`: fronteira que impede o motor de escrever diretamente no editor.
- `TRadIAOTAInlineCompletionSession`: captura OTA, validação otimista, inserção e Ghost Text.

## Estado da integração

O fluxo OTA manual e a captura contínua opt-in estão conectados. Ambos capturam somente o buffer
ativo, resolvem o símbolo vigente a partir da linha do cursor e incluem metadados básicos do projeto.
Sugestões multilinha são separadas em overlays virtuais sem modificar o buffer. A primeira linha
começa na coluna do cursor; continuações visíveis usam uma faixa após o texto real para não
encobrir código existente. Linhas que ultrapassam o fim do arquivo são desenhadas abaixo da última
linha lógica. O aceite total preserva todas as quebras, e o aceite parcial atualiza o snapshot antes
de manter o restante. O marco foi validado visualmente no Delphi 11, 12 e 13 Win32 e no Delphi 13
IDE64. O smoke abre uma unit real, confirma o editor pelo MCP e exige os eventos separados de
preparação e pintura OTA. A evidência está em `inline_completion_smoke_evidence_2.0.0.json`.
