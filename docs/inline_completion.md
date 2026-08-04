# Assistência inline e Fill-in-the-Middle

Este documento descreve a arquitetura de assistência inline do RadIA 2.0.0. O recurso está sendo
entregue de forma incremental. O motor de domínio já existe; a captura automática e a apresentação
visual no editor ainda precisam ser conectadas à Open Tools API.

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

## Ações previstas no editor

- Aceitar toda a sugestão.
- Aceitar somente a próxima palavra.
- Rejeitar a sugestão.
- Solicitar uma alternativa.
- Desativar por sessão, projeto, arquivo ou linguagem.

## Segurança e privacidade

- O contexto do projeto é um campo explícito do pedido, não uma coleta oculta.
- Prefixo, sufixo e contexto possuem limites independentes da janela total do modelo.
- Uma solicitação cancelada não pode publicar uma resposta atrasada.
- O aceite deve validar a revisão capturada antes de inserir texto.
- Providers locais e remotos usam o mesmo contrato e as mesmas regras de cancelamento.

## Componentes implementados

- `TRadIAInlineCompletionContext`: contexto FIM e chave estável de cache.
- `TRadIAInlineCompletionOptions`: debounce e limites.
- `IRadIAInlineCompletionProvider`: abstração para modelos locais e remotos.
- `TRadIAServiceInlineCompletionProvider`: adaptador para o provider ativo do RadIA.
- `TRadIAInlineCompletionController`: cache, cancelamento, saneamento e ações de aceite.
- `IRadIAInlineCompletionView`: fronteira que impede o motor de escrever diretamente no editor.

## Estado da integração

O próximo incremento conecta o controller aos adaptadores OTA existentes, implementa o overlay de
Ghost Text e registra atalhos de aceite/rejeição. Até essa conexão ser concluída e validada em IDE
real, o recurso não deve ser anunciado como disponível ao usuário final.
