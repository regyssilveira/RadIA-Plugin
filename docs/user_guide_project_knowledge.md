# Guia do conhecimento local do projeto

## Objetivo

O conhecimento local permite pesquisar símbolos e trechos do projeto sem depender de um serviço
externo. O índice é derivado do workspace, pode ser reconstruído e combina busca lexical com
similaridade vetorial local.

São indexados arquivos Pascal (`.pas`, `.dpr`, `.dpk`, `.inc`), formulários textuais (`.dfm`,
`.fmx`), projetos (`.dproj`, `.groupproj`) e documentação (`.md`, `.txt`, `.adoc`, `.rst`).
Companions de formulário são descobertos junto às units. A documentação é descoberta na raiz e
nas pastas `docs` e `doc`, inclusive em subpastas. DFM binário não é interpretado como texto e é
ignorado com segurança.

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

A busca retorna resultados limitados com arquivo, posição, trecho relevante, score total, parcela
lexical, parcela vetorial e uma explicação do ranking. Se o provider de embeddings falhar ou estiver
desabilitado em **Settings > Security & Consent**, o mesmo fluxo usa automaticamente o fallback lexical
determinístico. A leitura de documentos também possui limites para evitar respostas e payloads
excessivos.

Os resultados de busca e os chunks de um documento exibem a ação **Open source** no chat. Ela usa
`NavigateToFile` para abrir o arquivo diretamente na linha inicial do trecho. A navegação é somente
leitura e continua sujeita ao limite do workspace ativo e à política normal de ferramentas.

As ferramentas também expõem métricas locais, sem telemetria: a indexação e a busca informam
`durationMs`, cada resultado mantém seus scores de relevância e `GetKnowledgeStatus` informa
`estimatedIndexBytes`. O identificador do projeto acompanha todas as respostas para tornar o
isolamento entre workspaces verificável. O tamanho é uma estimativa da memória ocupada pelo
conteúdo, metadados e vetores indexados, não o tamanho exato do JSON persistido.

## Armazenamento e privacidade

Snapshots ficam em `%APPDATA%\RadIA\Knowledge`, separados por identidade derivada do projeto. O
formato 2 persiste os vetores junto aos chunks e continua lendo snapshots lexicais do formato 1.
Eles não são arquivos-fonte autoritativos e podem ser removidos para forçar reconstrução.

O recurso **Enable local semantic project knowledge (no network)** fica desabilitado por padrão.
Quando o usuário o habilita em **Settings > Security & Consent**, o provider `local-hash-v1`
calcula os vetores inteiramente no processo da IDE, sem HTTP, tokens ou envio de código. A
preferência entra em vigor imediatamente, sem reiniciar a IDE. Ao desabilitá-la, novas indexações
e buscas deixam de calcular vetores e continuam funcionando com busca lexical determinística.

Os campos **Knowledge excluded file fragments** e **Knowledge excluded project name or path
fragments** aceitam itens separados por ponto e vírgula. A comparação ignora maiúsculas e
minúsculas e procura o fragmento no caminho completo. Uma exclusão nova bloqueia imediatamente
busca e leitura do conteúdo já indexado. Na atualização seguinte, o RadIA também remove esses
arquivos do snapshot persistido. Remover um padrão permite que o conteúdo volte a ser indexado.

A arquitetura aceita providers opcionais por contrato, mas nenhum provider remoto é ativado
implicitamente. O conteúdo somente é enviado a um provider de IA quando uma ação autorizada o
inclui no contexto de uma solicitação.

## Reconstrução e problemas comuns

- Se resultados estiverem desatualizados, salve o documento e solicite reconstrução.
- Se o projeto foi movido, deixe o RadIA criar a nova identidade de índice.
- Se um snapshot estiver corrompido, feche a IDE, remova apenas a pasta correspondente e reabra.
- Arquivos fora do workspace autorizado não são indexados.
- Use exclusões para pastas geradas, código de terceiros ou projetos que não devem entrar no índice.
- Arquivos gerados, binários e formatos não suportados podem ser ignorados.
- A descoberta é limitada a 5.000 arquivos e cada arquivo é limitado a 2 MiB.

Consulte também o [guia de ferramentas agentivas](user_guide_agentic_tools.md).
