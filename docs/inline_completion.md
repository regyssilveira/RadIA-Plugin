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

Os atalhos aparecem no submenu **Rad IA** do menu contextual do editor. O primeiro pedido de cada
sessão informa qual contexto será enviado e exige consentimento explícito.

Os atalhos são bindings parciais nativos da Open Tools API e funcionam diretamente no editor, sem
abrir o menu contextual. Para alterá-los, abra **Rad IA > Settings > Security & Consent** e edite
**Inline shortcuts** usando o formato:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right; nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; reject=Ctrl+Alt+Backspace
```

As ações obrigatórias são `request`, `accept`, `nextWord`, `alternative` e `reject`. O RadIA não
salva perfis incompletos, teclas inválidas ou atalhos duplicados. A configuração é recarregada ao
voltar ao editor, sem reiniciar a IDE. Se o keymap ativo do Delphi já possuir o mesmo atalho, o
comando existente permanece prioritário e o conflito é registrado no log do RadIA.

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
- `IRadIAInlineCompletionView`: fronteira que impede o motor de escrever diretamente no editor.
- `TRadIAOTAInlineCompletionSession`: captura OTA, validação otimista, inserção e Ghost Text.

## Estado da integração

O fluxo OTA manual e a captura contínua opt-in estão conectados. Ambos capturam somente o buffer
ativo, resolvem o símbolo vigente a partir da linha do cursor e incluem metadados básicos do projeto.
A primeira linha é apresentada como Ghost Text e o buffer nunca é modificado antes do aceite.
Sugestões multilinha com linhas virtuais permanecem pendentes. O recurso só será considerado
concluído depois da validação visual na matriz de IDEs suportada.
