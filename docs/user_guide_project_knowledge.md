# Guia do conhecimento local do projeto

## Objetivo

O conhecimento local permite pesquisar símbolos e trechos do projeto sem depender de um serviço
externo. O índice é derivado do workspace e pode ser reconstruído.

## Ciclo do índice

Ao abrir ou trocar de projeto, o RadIA mantém um índice independente por projeto. Notificações da
OTA atualizam o documento quando ele é editado, salvo ou renomeado e removem sua identidade ativa
quando ele é fechado.

Uma alteração no buffer pode aparecer na busca antes do save. Depois de um rename, os resultados
passam a usar a nova identidade do arquivo.

## Como usar

Solicitações típicas no chat ou MCP:

- “Indexe o projeto ativo.”
- “Mostre o status do conhecimento local.”
- “Pesquise referências a `TRadIAWizard`.”
- “Leia o trecho indexado desta unit.”
- “Reconstrua o índice deste projeto.”

A busca retorna resultados limitados com arquivo, posição e trecho relevante. A leitura de
documentos também possui limites para evitar respostas e payloads excessivos.

## Armazenamento e privacidade

Snapshots ficam em `%APPDATA%\RadIA\Knowledge`, separados por identidade derivada do projeto. Eles
não são arquivos-fonte autoritativos e podem ser removidos para forçar reconstrução.

O índice permanece local. Seu conteúdo somente é enviado a um provedor quando uma ação autorizada
o inclui no contexto de uma solicitação.

## Reconstrução e problemas comuns

- Se resultados estiverem desatualizados, salve o documento e solicite reconstrução.
- Se o projeto foi movido, deixe o RadIA criar a nova identidade de índice.
- Se um snapshot estiver corrompido, feche a IDE, remova apenas a pasta correspondente e reabra.
- Arquivos fora do workspace autorizado não são indexados.
- Arquivos gerados, binários e formatos não suportados podem ser ignorados.

Consulte também o [guia de ferramentas agentivas](user_guide_agentic_tools.md).
