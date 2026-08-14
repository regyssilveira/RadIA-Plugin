# Assistência inline e Fill-in-the-Middle

Este documento descreve a assistência inline disponível no RadIA. O motor, a captura explícita e o
overlay visual estão conectados à Open Tools API.

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
7. Alternativas distintas permanecem associadas ao mesmo contexto e podem ser percorridas.
8. A camada visual exibe a sugestão selecionada e um painel compacto sem tocar no buffer.

Quando há um símbolo no cursor, o worker de completion consulta o índice semântico para acrescentar
declarações e membros resolvidos por herança. A consulta não ocorre durante a captura OTA na thread da
IDE. Se o processo semântico estiver indisponível, o pedido continua com o contexto limitado da unit;
o editor permanece responsivo e o Ghost Text continua utilizável.

Quando o cursor está após um acesso a membro, como `Form.Sa`, o RadIA consulta primeiro o índice
estrutural local. A busca filtra o prefixo, resolve membros herdados, remove duplicidades e limita a
20 candidatos. Uma continuação inequívoca é exibida imediatamente sem chamar o provider. Resultado
vazio, ambíguo ou indisponível segue automaticamente para a rota FIM já configurada. Uma nova edição
cancela tanto a espera local quanto a remota; o status de rota informa `local semantic`, quantidade
de candidatos e latência quando essa rota é usada.

A resolução local nunca trata uma lista vazia como resposta silenciosa. O motor identifica o símbolo
solicitado e retorna estado, motivo, origem e alternativas estruturais. Nomes curtos encontrados em mais
de uma unit são marcados como `short-name-ambiguous`; nesse caso nenhuma sugestão local é aplicada e o
fluxo segue para o fallback. Contêiner inexistente, prefixo sem correspondência e contrato já satisfeito
possuem motivos distintos, também expostos pelo diagnóstico profundo.

## Painel de alternativas

Depois de escolher **Solicitar uma alternativa**, o RadIA mantém a sugestão anterior em vez de
substituí-la silenciosamente. Com duas ou mais respostas distintas, o editor mostra até três
alternativas em um painel compacto abaixo da linha ativa. A opção selecionada usa a cor de seleção
da IDE e continua aparecendo como Ghost Text completo.

Use **Próxima sugestão** ou **Sugestão anterior** para comparar respostas. **Aceitar toda a
sugestão** e **Aceitar somente a próxima palavra** sempre operam sobre a alternativa destacada.
Editar o buffer, trocar de arquivo ou rejeitar a completion elimina todo o conjunto, evitando que
uma resposta pertencente a uma revisão antiga seja aplicada.

## Rota FIM dedicada e fallback

O Ghost Text possui um contrato próprio, separado do chat. O RadIA consulta a capability do
provider em tempo de execução; não presume suporte pelo nome do modelo.

- **Ollama:** usa `POST /api/generate` com `prompt` e `suffix` separados.
- **LM Studio:** usa `POST /v1/completions` com `prompt` e `suffix` separados.
- **Demais providers:** usam explicitamente o fallback de completion tradicional, com o contexto
  FIM delimitado no prompt.

Se uma rota dedicada falhar, o RadIA tenta o fallback tradicional para a mesma solicitação. Uma
mudança de arquivo, revisão, cursor, projeto ou jornada cancela o pedido anterior; resposta obsoleta
não pode chegar ao overlay.

O provider e modelo vêm primeiro de `AutocompleteProvider` e `AutocompleteModel`, quando essas
preferências existirem; caso contrário, usam o provider e modelo globais ativos. A seleção é
aplicada somente ao pedido inline e não altera a configuração global.

Para inspecionar a última decisão, use **Rad IA > Show Inline Completion Route Status** no menu do
editor ou **Ferramentas > RadIA > Rad IA Inline Completion Route Status**. O diálogo informa rota dedicada ou
fallback, provider, modelo, latência local e motivo do fallback. O mesmo diagnóstico é registrado
no log sem incluir prefixo, sufixo ou conteúdo sugerido.

Use **Rad IA > Show Semantic Editor Context** no menu do editor ou **Ferramentas > RadIA > Rad IA Semantic Editor
Context** para conferir antes da solicitação os metadados limitados compartilhados entre Ghost Text,
ações contextuais e agente: unit ativa, símbolo no cursor, imports e declarações próximas. A inspeção
é somente leitura e não altera o buffer. Quando uma ação como explicar, testar ou procurar bugs é
acionada pelo menu, esse mesmo contexto acompanha o trecho selecionado ou a unit ativa.

## Ações disponíveis no menu do editor

| Ação | Atalho padrão |
|---|---|
| Solicitar sugestão | `Ctrl+Alt+Espaço` |
| Aceitar toda a sugestão | `Ctrl+Alt+Direita` |
| Aceitar somente a próxima palavra | `Ctrl+Alt+Baixo` |
| Solicitar uma alternativa | `Ctrl+Alt+]` |
| Próxima sugestão armazenada | `Ctrl+Shift+Baixo` |
| Sugestão armazenada anterior | `Ctrl+Shift+Cima` |
| Rejeitar a sugestão | `Ctrl+Alt+Backspace` |
| Aceitar revisão na linha atual | `Ctrl+Alt+Enter` |
| Rejeitar revisão na linha atual | `Ctrl+Alt+R` |
| Próximo bloco de revisão | `Ctrl+Alt+PageDown` |
| Bloco de revisão anterior | `Ctrl+Alt+PageUp` |
| Editar bloco no cursor | `Ctrl+Alt+E` |
| Explicar bloco no cursor | `Ctrl+Alt+I` |
| Aplicar revisão resolvida | `Ctrl+Alt+A` |
| Descartar sessão de revisão | `Ctrl+Alt+Delete` |

O submenu também oferece **Show Inline Completion Route Status**, sem atalho padrão, para explicar
como a última sugestão foi executada.

Os atalhos aparecem no submenu **Rad IA** do menu contextual do editor. O primeiro pedido de cada
sessão informa qual contexto será enviado e exige consentimento explícito.

Os atalhos são bindings parciais nativos da Open Tools API e funcionam diretamente no editor, sem
abrir o menu contextual. Para alterá-los, abra **Rad IA > Settings > Editor Assistance** e edite
**Inline shortcuts** usando o formato:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right;
nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+];
completionNext=Ctrl+Shift+Down; completionPrevious=Ctrl+Shift+Up;
reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+T;
reviewAccept=Ctrl+Alt+Enter; reviewReject=Ctrl+Alt+R;
reviewNext=Ctrl+Alt+PageDown; reviewPrevious=Ctrl+Alt+PageUp;
reviewEdit=Ctrl+Alt+E; reviewExplain=Ctrl+Alt+I;
reviewApply=Ctrl+Alt+A; reviewClear=Ctrl+Alt+Delete
```

As ações obrigatórias são `request`, `accept`, `nextWord`, `alternative` e `reject`. Navegação entre
respostas usa `completionNext` e `completionPrevious`. Terminal e
decisões de revisão usam `terminal`, `reviewAccept`, `reviewReject`, `reviewNext`, `reviewPrevious`,
`reviewEdit`, `reviewExplain`, `reviewApply` e `reviewClear`; perfis antigos recebem os atalhos padrão
automaticamente. Consulte a [revisão por bloco](block_reviews.md) para entender marcadores, cores,
transações e navegação. O RadIA não
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

A assistência contínua nasce desligada. Para ativá-la, abra **Rad IA > Settings > Editor
Assistance** e marque **Enable ghost text (inline completion)**. O próprio texto da opção informa que
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
- `IRadIADedicatedFimProvider`: capability opcional para uma rota FIM nativa do provider.
- `TRadIAFimCapabilityDiscovery`: seleção por contrato, sem heurística de nome de modelo.
- `TRadIAFimDiagnostic`: rota, provider, modelo, latência e motivo de fallback da última execução.
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
de manter o restante. A integração é validada no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. O smoke
abre uma unit real, confirma o editor pelo MCP e exige preparação, pintura OTA, aceite, um único undo
restaurando o snapshot e rejeição limpa. Os resultados detalhados pertencem ao pipeline, não a `docs`.
